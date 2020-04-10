/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommUpd]
	@LicenseeID INT,
	@GroupCommID INT,
	@GroupName VARCHAR(100),
	@SBComm decimal(9,8),
	@ParlayComm decimal(9,8),
	@NGComm decimal (9,8)=0,
	@RNGComm decimal(9,8)=0,
	@AllbetComm decimal (9,8)=0,
	@MacauComm decimal (9,8)=0,
	@PPComm decimal (9,8)=0,
	@GDComm decimal (9,8)=0,
	@AGComm decimal (9,8)=0,	
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,	
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@IsUpdateGD BIT = 0,
	@IsUpdateAG BIT = 0,
	@GroupColor VARCHAR(20),
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@UserID INT,
	@IP varchar(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT,
	@StrCustID VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Update Group Commission
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20121227@Henry: Add column IsDefault
		- 20130413@Jim: support multi language 	
		- 20131023@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140630@Francis: Remove link-server when calling write log sp
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774] 
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	
	IF (@IsUpdateNG = 0) AND  (@IsUpdateRNG = 0) 
	BEGIN
		UPDATE [dbo].[LicenseeGroupComm]
		SET
			 GroupName = @GroupName,
			 color = @GroupColor,
			 IsDefault = @IsDefault
		WHERE id = @GroupCommID AND Licenseeid = @LicenseeID
		RETURN
	END
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()

	DECLARE @GroupName_Old VARCHAR(100)
		,@GroupColor_Old VARCHAR(20)
		,@SBComm_Old DECIMAL(9,8)
		,@ParlayComm_Old DECIMAL(9,8)
		,@NGComm_Old DECIMAL(9,8)
		,@RNGComm_Old DECIMAL(9,8)		
		,@AllbetComm_Old DECIMAL(9,8)
		,@MacauComm_Old DECIMAL(9,8)
		,@PPComm_Old DECIMAL(9,8)
		,@GDComm_Old DECIMAL(9,8)
		,@AGComm_Old DECIMAL(9,8)
		,@IsDefault_Old BIT
		
	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)

	DECLARE @FlagUpdateGroupProperty BIT, @FlagUpdateComm BIT, @FlagUpdateIsDefault BIT

	SELECT @FlagUpdateGroupProperty=0,@FlagUpdateComm=0,@FlagUpdateIsDefault=0

	SELECT @GroupName = rtrim(ltrim(@GroupName))

	--Validate data
	IF @SBComm>0.15 OR @NGComm>0.15 OR @RNGComm>0.15 OR @ParlayComm >0.15 
		OR @AllbetComm>0.15 OR @MacauComm>0.15 OR @PPComm>0.15 OR @GDComm>0.15 OR @AGComm>0.15 
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not greater than '
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END +'0.15', @ErrCode = 100
		RETURN
	END

	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
	)
	BEGIN
		SELECT @ErrMsg =CASE @Langkey WHEN 'en-US' THEN 'This Group does not exist!'
									  ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200016,@Langkey)
									 END , @ErrCode = 101	
		RETURN
	END
	ELSE
	BEGIN
		SELECT @GroupName_Old=GroupName
			,@GroupColor_Old=color
			,@SBComm_Old=SBComm
			,@ParlayComm_Old=ParlayComm
			,@NGComm_Old=NGComm
			,@RNGComm_Old=RNGComm	
			,@AllbetComm_Old=AllbetComm
			,@MacauComm_Old=MacauComm
			,@PPComm_Old=PPComm
			,@GDComm_Old=GDComm
			,@AGComm_Old=AGComm				
			,@IsDefault_Old=IsDefault			
		FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID

		--Update IsDefault
		IF @IsDefault <> @IsDefault_Old
		BEGIN
			IF @IsDefault=1 --Set IsDefault for current update group
			BEGIN
				--Check exist ISDefault
				IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND ID <> @GroupCommID AND IsDefault=1 AND IsActive = 1)
				BEGIN
					SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Another group is currently set as default. Wanna set this group as default?'
													ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200018,@Langkey)
													END, @ErrCode = 103	
					RETURN
				END
				
				--Reset IsDefault Old to 0
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND IsDefault=1
				
				--Set IsDefault for current group
				UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=1 WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
				
				SET @FlagUpdateIsDefault=1
			END
			ELSE
			BEGIN
				UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
				
				SET @FlagUpdateIsDefault=1
			END
			
		END

		--Update Group Name and Group Color
		IF @GroupName_Old <> @GroupName OR @GroupColor_Old <> @GroupColor
		BEGIN
			IF EXISTS(
				SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK)
				WHERE LicenseeID = @LicenseeID AND GroupName=@GroupName AND ID <> @GroupCommID AND IsActive=1
			)
			BEGIN
				SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'This group name has been already chosen, please try another name!'
											   ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200020,@Langkey)
											   END , @ErrCode = 102
				RETURN
			END
			ELSE
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET GroupName=@GroupName,color=@GroupColor
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
				IF @@ROWCOUNT=1
				BEGIN			
					SET @FlagUpdateGroupProperty=1
				END
			END	
		END

		--Update Group Comm + Member Comm + all the comm settings
		IF @SBComm_Old<>@SBComm 
			OR @ParlayComm_Old<>@ParlayComm 
			OR @NGComm_Old <> @NGComm 
			OR @RNGComm_Old <> @RNGComm	
			OR @AllbetComm_Old <> @AllbetComm 
			OR @MacauComm_Old <> @MacauComm 
			OR @PPComm_Old <> @PPComm 
			OR @GDComm_Old <> @GDComm 
			OR @AGComm_Old <> @AGComm 			
		BEGIN
			--Sportsbook
			Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
			SET SBComm=@SBComm
				,ParlayComm = @ParlayComm
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			
			--NG
			IF @IsUpdateNG=1 
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET NGComm=@NGComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--RNG
			IF @IsUpdateRNG=1
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET RNGComm=@RNGComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--Allbet
			IF @IsUpdateAllbet=1 
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET AllbetComm=@AllbetComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--Macau Game
			IF @IsUpdateMacau=1 
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET MacauComm=@MacauComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--PP
			IF @IsUpdatePP=1 
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET PPComm=@PPComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--GD
			IF @IsUpdateGD=1 
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET GDComm=@GDComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--AG
			IF @IsUpdateAG=1 
			BEGIN
				Update dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
				SET AGComm=@AGComm
				WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			END
			
			--get list of affected Customers
			SELECT @StrCustID = STUFF(
				(   SELECT  ',' + CONVERT(NVARCHAR(20), custid) 
					FROM LicenseeCustComm WITH (NOLOCK)
					WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID
					FOR xml path('')
				)
				, 1
				, 1
				, '')
			
			IF LTRIM(RTRIM(@StrCustID)) <> ''
			BEGIN
				--Update List of affected Customers               
				EXEC [Lrf_CustomerUpdMemberComm] 
					@LicenseeID=@LicenseeID
					,@StrCustID=@StrCustID
					,@UserID=@UserID
					,@GroupCommID=@GroupCommID
					,@SBComm=@SBComm
					,@ParlayComm=@ParlayComm
					,@NGComm=@NGComm
					,@RNGComm=@RNGComm
					,@AllbetComm=@AllbetComm
					,@MacauComm=@MacauComm
					,@PPComm=@PPComm
					,@GDComm=@GDComm
					,@AGComm=@AGComm	
					,@IsUpdateNG=@IsUpdateNG
					,@IsUpdateRNG=@IsUpdateRNG					
					,@IsUpdateAllbet=@IsUpdateAllbet
					,@IsUpdateMacau=@IsUpdateMacau
					,@IsUpdatePP=@IsUpdatePP
					,@IsUpdateGD=@IsUpdateGD
					,@IsUpdateAG=@IsUpdateAG
					,@IP=@IP
					,@Langkey=@langkey
					,@ErrCode=@ErrCode OUTPUT
					,@ErrMsg=@ErrMsg OUTPUT 
				WITH RECOMPILE
					
				SELECT @StrCustID = STUFF(
					(   SELECT  ',' + CONVERT(NVARCHAR(20), a.custid) 
						FROM dbo.LicenseeCustComm b WITH (NOLOCK)
						INNER JOIN CustDB.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
						WHERE b.LicenseeID = @LicenseeID AND b.GroupCommID = @GroupCommID and a.SyncCasino = 1
						FOR xml path('')
					)
					, 1
					, 1
					, '')
			END
					
			SET @FlagUpdateComm = 1
		END						

		IF @FlagUpdateComm=1 OR @FlagUpdateGroupProperty=1 OR @FlagUpdateIsDefault=1 --Writelog
		BEGIN
			SET @endRun = GETDATE()
			SET @duration  = datediff (millisecond,@startRun,@endRun)	
		
			SELECT @LogSPData = '<Lrf_LicenseeGroupCommUpd GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
			'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
			'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
			'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" ' +			
			'AllbetComm="'+ COALESCE(CAST(@AllbetComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'MacauComm="'+ COALESCE(CAST(@MacauComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'PPComm="'+ COALESCE(CAST(@PPComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'GDComm="'+ COALESCE(CAST(@GDComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'AGComm="'+ COALESCE(CAST(@AGComm as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateRNG="'+ COALESCE(CAST(@IsUpdateRNG as VARCHAR(50)),SPACE(1)) + '" ' +			
			'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
			'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
			'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
			'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
			'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

			SELECT @TrackingValue2 = '<Lrf_LicenseeGroupCommUpd GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
			'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
			'GroupName="'+ COALESCE(CAST(@GroupName_Old as VARCHAR(100)),SPACE(1)) + '" ' +
			'SBComm="'+ COALESCE(CAST(@SBComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'ParlayComm="'+ COALESCE(CAST(@ParlayComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'NGComm="'+ COALESCE(CAST(@NGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'RNGComm="'+ COALESCE(CAST(@RNGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +			
			'AllbetComm="'+ COALESCE(CAST(@AllbetComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'MacauComm="'+ COALESCE(CAST(@MacauComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'PPComm="'+ COALESCE(CAST(@PPComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'GDComm="'+ COALESCE(CAST(@GDComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'AGComm="'+ COALESCE(CAST(@AGComm_Old as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateNG="'+ COALESCE(CAST(@IsUpdateNG as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateRNG="'+ COALESCE(CAST(@IsUpdateRNG as VARCHAR(50)),SPACE(1)) + '" ' +			
			'IsUpdateAllbet="'+ COALESCE(CAST(@IsUpdateAllbet as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateMacau="'+ COALESCE(CAST(@IsUpdateMacau as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdatePP="'+ COALESCE(CAST(@IsUpdatePP as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateGD="'+ COALESCE(CAST(@IsUpdateGD as VARCHAR(50)),SPACE(1)) + '" ' +
			'IsUpdateAG="'+ COALESCE(CAST(@IsUpdateAG as VARCHAR(50)),SPACE(1)) + '" ' +
			'GroupColor="'+ COALESCE(CAST(@GroupColor_Old as VARCHAR(40)),SPACE(1)) + '" ' +
			'IsDefault="'+ COALESCE(CAST(@IsDefault_Old as VARCHAR(40)),SPACE(1)) + '" ' +
			'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
			'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
			'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
		
			EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
					@UserID = @UserID,
					@CustID = @GroupCommID,
					@ActionID = 2610,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@duration = @duration
		END
		IF @IsUpdateRNG=0
		SELECT @StrCustID = ''
	END
END	
GO 
  