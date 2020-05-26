/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm]
(
	@LicenseeID INT,
	@strCustID VARCHAR(MAX) = '',--member
	@UserID INT,
	@GroupCommID INT = 0,
	@SBComm DECIMAL(9,8)=0,
	@NGComm DECIMAL(9,8)=0,	
	@RNGComm DECIMAL(9,8)=0,
	@ParlayComm DECIMAL(9,8)=0,	
	@AllbetComm DECIMAL(9,8)=0,	
	@MacauComm DECIMAL(9,8)=0,	
	@PPComm DECIMAL(9,8)=0,	
	@GDComm DECIMAL(9,8)=0,	
	@AGComm DECIMAL(9,8)=0,	
	@FWComm DECIMAL(9,8)=0,	
	@IsUpdateSB BIT = 1,
	@IsParlayComm BIT = 1,
	@IsUpdateComm BIT=1,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,	
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@IsUpdateGD BIT = 0,
	@IsUpdateAG BIT = 0,
	@IsUpdateFW BIT = 0,
	@IsUpdateGroupComm BIT = 0,
	@IP VARCHAR(40),
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
)
AS
/*
	Created: 20120726@Henry
	Task : Update Commission of Player
	DB: DBCUST/bodb_licensee

	Revisions:
		- 20130124@Daniel: Change link server alias & failover writelog to DBTXN 
		- 20130413@Jim: support multi language
		- 20131023@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20131226@winnie: Change to DBTXN.CustDB
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20140618@Francis: Enhance performance
		- 20140618@Francis: Update Comm info and write logs using batch by batch in stead of row by row method
		- 20150513@Jim: force BA member get SB comm zero
		- 20151005@Jim:HotFix #45031
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
		- 20171017@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180704@Winnie:  LAP - There is a locking DB resource when doing 1st deposit many sessions at same time [Redmine: #97829]
		- 20180809@Sophia: HA - remove LicenseeCustInfo table [Redmine: #99464]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180827@Elodie: Change to use DBCUST.CustDB.dbo.Customer [Redmine: #99464]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20181205@Winnie: LAP-Security Risks found_settings [RedmineID: #105701]
		- 20200409@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200416@Max: Move Code Update LicenseeCustComm to Execrep SP [Redmine: #131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]

	Param's Explanation:
		1. To update a member/batch members without GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx, @IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		2. To update a member/batch members with GroupCommID
EXEC [Lrf_CustomerUpdMemberComm_907] @LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupCommID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx,@IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		3. To update member group without update commission
EXEC [Lrf_CustomerUpdMemberComm_907] @IsUpdateComm=0,@LicenseeID=xx,@strCustID,xx,@UserID=xx,@GroupCommID=xx,@SBComm=xx,@NGComm=xx,@RNGComm=xx,@IsUpdateNG=xx,@IsUpdateRNG=xx,@IP=xx,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT

	SET @startRun = GETDATE()

	DECLARE @TotalMemCount INT

	DECLARE @LogSPData VARCHAR(4000)
	DECLARE @LogSPData2 VARCHAR(4000)
	DECLARE @MacauLicenseeID INT

	SELECT  @MacauLicenseeID =  LicenseeID
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName ='Macaubet'
		
	SELECT @strCustID = ltrim(rtrim(@strCustID))

	IF @strCustID = '' AND @IsUpdateGroupComm = 0
	BEGIN
		SELECT @ErrCode=101
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US'THEN 'Wrong input, please check again!'
										ELSE  CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
						END 	
		RETURN
	END

	IF @GroupCommID>0 --Get SBComm,NGComm,RNGComm From Group
	BEGIN
		--Check existence
		IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND id = @GroupCommID AND IsActive=1)
		BEGIN
			SELECT @ErrCode=101
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'The Group Commission does not exist, please check again!'
										   ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200001,@Langkey)		
										   END
			RETURN
		END
	
		SELECT @SBComm=SBComm
			,@NGComm=NGComm
			,@RNGComm=RNGComm
			,@ParlayComm= ParlayComm
			,@AllbetComm = AllbetComm
			,@MacauComm = MacauComm
			,@PPComm = PPComm
			--,@GDComm = GDComm
			--,@AGComm = AGComm
			,@FWComm = FWComm
		FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND id = @GroupCommID AND IsActive=1
	END

	SELECT @SBComm=ISNULL(@SBComm,0)
		,@NGComm=ISNULL(@NGComm,0)
		,@RNGComm=ISNULL(@RNGComm,0)
		,@ParlayComm = ISNULL(@ParlayComm,0)
		,@AllbetComm = ISNULL(@AllbetComm,0)
		,@MacauComm = ISNULL(@MacauComm,0)
		,@PPComm = ISNULL(@PPComm,0)
		--,@GDComm = ISNULL(@GDComm,0)
		--,@AGComm = ISNULL(@AGComm,0)
		,@FWComm = ISNULL(@FWComm,0)
		--Validate data
	IF @SBComm>0.15 OR @NGComm>0.15 OR @RNGComm>0.15 OR @ParlayComm > 0.15
		OR @AllbetComm > 0.15 OR @MacauComm > 0.15 OR @PPComm > 0.15 
		--OR @GDComm > 0.15 OR @AGComm > 0.15
		OR @FWComm > 0.15
	BEGIN
		SELECT @ErrCode=101
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Player commission should not be greater than'
										ELSE 	CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END +'0.15'
		RETURN
	END
	DECLARE @TempLicenseeBA AS TABLE (CustID INT)
	
	DECLARE @TempCustID AS TABLE (CustID INT,IsFinished BIT)
	DECLARE @TempList_batch AS TABLE (CustID INT)
	
	IF @IsUpdateGroupComm = 1 AND @strCustID = ''
	BEGIN
		INSERT INTO @TempCustID (CustID)
		SELECT ls.custid
		FROM LicenseeCustComm ls WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ls.CustID = c.custid
		WHERE ls.LicenseeID = @LicenseeID AND ls.GroupCommID = @GroupCommID
		
		SELECT @TotalMemCount=@@ROWCOUNT
		
	END
	ELSE IF @strCustID <> ''
	BEGIN
		INSERT INTO @TempCustID (CustID)
		SELECT c.CustID
		FROM CustDB.dbo.Customer c WITH (NOLOCK) 
			INNER JOIN dbo.f_SplitString (@strCustID,',') AS tmp ON RTRIM(LTRIM(tmp.val)) = c.custid
		OPTION (MAXRECURSION 0)
		
		SELECT @TotalMemCount=@@ROWCOUNT
		
	END
	
	--Call execrep to update player commission
	IF @IsUpdateComm=1
	BEGIN
		IF @TotalMemCount=1
			EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Direct] 
				@CustID=@strCustID
				,@SBComm=@SBComm
				,@NGComm=@NGComm
				,@ParlayComm = @ParlayComm
				,@AllbetComm=@AllbetComm	
				,@MacauComm=@MacauComm
				,@PPComm=@PPComm
				,@FWComm = @FWComm
				,@IsUpdateSB = @IsUpdateSB
				,@IsParlayComm = @IsParlayComm
				,@IsUpdateNG=@IsUpdateNG			
				,@IsUpdateAllbet=@IsUpdateAllbet
				,@IsUpdateMacau=@IsUpdateMacau	
				,@IsUpdatePP=@IsUpdatePP	
				,@IsUpdateFW = @IsUpdateFW
		ELSE
		BEGIN	
			--- separate BA member with Non-BA
			--BA and not belong Macaubet have got SBcomm=0	
			
			DECLARE @strBA 	VARCHAR(MAX)
			
			IF @LicenseeID <> @MacauLicenseeID
			BEGIN 
				INSERT INTO @TempLicenseeBA (CustID)
				SELECT t.CustID 
				FROM @TempCustID  t
					INNER JOIN dbo.LicenseeBAHistory ba WITH (NOLOCK) ON t.CustID=ba.CustID
				WHERE ba.Status ='Running' AND ba.LicenseeID = @LicenseeID 
				ORDER BY t.[CustID]
			END	 
				 
			SELECT @strBA = STUFF((SELECT ',' + CAST(CustID AS VARCHAR(20))
							FROM @TempLicenseeBA
							FOR XML PATH('')
							),1,1,'')
			IF @strBA  <> ''
			BEGIN				
				EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Main] 
					@strCustID=@strBA
					,@SBComm=0
					,@NGComm=@NGComm
					,@ParlayComm = 0	
					,@AllbetComm = @AllbetComm
					,@MacauComm = @MacauComm
					,@PPComm = @PPComm
					,@FWComm = @FWComm
					,@IsUpdateSB = @IsUpdateSB
					,@IsParlayComm = @IsParlayComm
					,@IsUpdateNG=@IsUpdateNG
					,@IsUpdateAllbet=@IsUpdateAllbet
					,@IsUpdateMacau=@IsUpdateMacau
					,@IsUpdatePP=@IsUpdatePP
					,@IsUpdateFW = @IsUpdateFW
			END					
			-- Non-BA and BA under Macaubet have got SBcomm=@SBcomm
			DECLARE  @strNonBA 	VARCHAR(MAX)
			
			SELECT @strNonBA = STUFF((SELECT ',' + CAST(t.[CustID] AS VARCHAR(20))
								FROM @TempCustID  t
									LEFT JOIN @TempLicenseeBA ba ON t.CustID = ba.CustID
								WHERE ba.CustID IS NULL
								ORDER BY t.[CustID]
								FOR XML PATH('')
							),1,1,'')
			
			IF @strNonBA  <> ''
			BEGIN
				EXEC CustDB.dbo.[Lrf_CustomerUpdMemberComm_Main] 
					@strCustID=@strNonBA
					,@SBComm=@SBComm
					,@NGComm=@NGComm
					,@ParlayComm = @ParlayComm					
					,@AllbetComm = @AllbetComm
					,@MacauComm = @MacauComm
					,@PPComm = @PPComm
					,@FWComm = @FWComm
					,@IsUpdateSB = @IsUpdateSB
					,@IsParlayComm = @IsParlayComm
					,@IsUpdateNG=@IsUpdateNG
					,@IsUpdateAllbet=@IsUpdateAllbet
					,@IsUpdateMacau=@IsUpdateMacau
					,@IsUpdatePP=@IsUpdatePP
					,@IsUpdateFW = @IsUpdateFW
			END
		END
	END	
	
	SET @endRun = GETDATE()
	SET @duration  = DATEDIFF (millisecond,@startRun,@endRun)	

	--Write Log
	-- new value
	SELECT @LogSPData = 'GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" '+
		'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'AllbetComm="'+ COALESCE(CAST(@AllbetComm as VARCHAR(50)),SPACE(1)) + '" '+
		'MacauComm="'+ COALESCE(CAST(@MacauComm as VARCHAR(50)),SPACE(1)) + '" '+
		'PPComm="'+ COALESCE(CAST(@PPComm as VARCHAR(50)),SPACE(1)) + '" '+
		'FWComm="'+ COALESCE(CAST(@FWComm as VARCHAR(50)),SPACE(1)) + '" '
		--'GDComm="'+ COALESCE(CAST(@GDComm as VARCHAR(50)),SPACE(1)) + '" '+
		--'AGComm="'+ COALESCE(CAST(@AGComm as VARCHAR(50)),SPACE(1)) + '" '

	-- old value
	SELECT @LogSPData2 = 'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
	
	WHILE (1=1)
	BEGIN
	
		DELETE FROM @TempList_batch
		
		UPDATE TOP (4500) t
			SET IsFinished = 1
		OUTPUT deleted.CustID 
		INTO @TempList_batch (custID)
		FROM @TempCustID t
		WHERE IsFinished IS NULL
		
		--Check empty batches
		IF (@@ROWCOUNT = 0)
			BREAK

		SET @strCustID = STUFF((SELECT ',' + CAST(custid AS VARCHAR(20))
						FROM @TempList_batch
						FOR XML PATH('')
						),1,1,'')
		BEGIN TRY
		
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_UpdMemComm_RunSP
						@UserID = @UserID,
						@strCustID = @strCustID,
						@ActionID = 2612,
						@LogSPData = @LogSPData,
						@LogSPData2 = @LogSPData2,
						@duration = @duration
		END TRY
		BEGIN CATCH
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_UpdMemComm_RunSP
						@UserID = @UserID,
						@strCustID = @strCustID,
						@ActionID = 2612,
						@LogSPData = @LogSPData,
						@LogSPData2 = @LogSPData2,
						@duration = @duration
		END CATCH
		
		
		--Update LicenseeCustComm
		IF (@IsUpdateComm = 1)
		BEGIN
			BEGIN TRY
			
			EXEC dbo.Lrf_ExecRep_00
					@strCustId = @strCustID,
					@LicenseeID = @LicenseeID,
					@GroupCommID = @GroupCommID,
					@MacauLicenseeID = @MacauLicenseeID,
					@IsUpdateNG = @IsUpdateNG,
					@IsUpdateRNG = @IsUpdateRNG,	
					@IsUpdateAllbet = @IsUpdateAllbet,
					@IsUpdateMacau = @IsUpdateMacau,
					@IsUpdatePP = @IsUpdatePP,
					--@IsUpdateGD = @IsUpdateGD,
					--@IsUpdateAG = @IsUpdateAG,
					@IsUpdateFW = @IsUpdateFW,
					@SBComm = @SBComm,
					@NGComm = @NGComm,	
					@RNGComm = @RNGComm,
					@ParlayComm = @ParlayComm,	
					@AllbetComm = @AllbetComm,	
					@MacauComm = @MacauComm,	
					@PPComm = @PPComm,	
					--@GDComm = @GDComm,	
					--@AGComm = @AGComm,
					@FWComm = @FWComm
			END TRY
			BEGIN CATCH
				SELECT @ErrCode = ERROR_NUMBER()
					, @ErrMsg = ERROR_MESSAGE()
			END CATCH
			
		END
		
	END	
END
GO

