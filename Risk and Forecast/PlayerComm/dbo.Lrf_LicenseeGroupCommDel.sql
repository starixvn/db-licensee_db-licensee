/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommDel]
	@LicenseeID INT,
	@GroupCommID INT,
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@IsResetDefault BIT=0,
	@Langkey NVARCHAR(10)='en-US'	,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT,
	@StrCustID VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Delete Group Commission
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20130413@Jim: support multi language
		- 20131023@Hannah: offer Live Casino commission
		- 20131114@Jim: support to write log for delete group comm action
		- 20131126@Hannah: offer RNG Casino commission
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
		- 20171024@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20190731@Winnie: Commission Group - RNG Casino Comm of Members are not cleared when deleting Group Comm [RedmineID: #117845]
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]  
		 
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON 
		
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT, @custID_cnt INT
	SET @startRun = GETDATE()

	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)
	DECLARE @IsexistMember BIT = 0

	DECLARE @SBComm DECIMAL(9,8), 
		@NGComm DECIMAL(9,8),
		@RNGComm DECIMAL(9,8),
		@ParlayComm DECIMAL(9,8), 		
		--@AllbetComm DECIMAL(9,8),
		@MacauComm DECIMAL(9,8),
		@PPComm DECIMAL(9,8),
		--@GDComm DECIMAL(9,8),
		--@AGComm DECIMAL(9,8),
		@FWComm DECIMAL(9,8),
		@GroupColor VARCHAR(20), 
		@GroupName VARCHAR(100), 
		@IsDefault BIT
	
	IF @IsRemovePlayercomm = 1
	BEGIN
		SET @custID_cnt = (SELECT COUNT(1) FROM LicenseeCustComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID)
		
		IF @custID_cnt > 200000
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'You have reached the maximum number of updating customers'' commission. Please contact Customer Service to process your request.'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200049,@Langkey)
										END, @ErrCode = 100
			RETURN
		END
	END
	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
	)
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This Group does not exist!'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200016,@Langkey) 
										END, @ErrCode = 100	
	END
	ELSE
	BEGIN
		--Get old setting
		SELECT @SBComm=SBComm,
			@NGComm=NGComm,
			@RNGComm=RNGComm,
			@ParlayComm=ParlayComm,			
			--@AllbetComm=AllbetComm,
			@MacauComm=MacauComm,
			@PPComm=PPComm,
			--@GDComm=GDComm,
			--@AGComm=AGComm,
			@FWComm = FWComm,
			@GroupColor=color,
			@GroupName=GroupName,
			@IsDefault=IsDefault
		FROM dbo.LicenseeGroupComm WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID 
			AND ID = @GroupCommID
		
		IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM dbo.LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND  IsDefault=1 AND IsActive = 1 AND ID=@GroupCommID)
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This is the default group. Do you want to proceed?'
														ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200017,@Langkey) 
														END , @ErrCode = 101	
			RETURN
		END
		--#1 delete group, keep comm of member: @IsRemovePlayercomm = 0
		IF @IsRemovePlayercomm=0
		BEGIN
			UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			
			DECLARE @TempCustID AS TABLE (CustID INT,IsFinished BIT)
			DECLARE @TempList_batch AS TABLE (CustID INT)
			
			INSERT INTO @TempCustID (CustID)
			SELECT ls.custid
			FROM dbo.LicenseeCustComm ls WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ls.CustID = c.custid
			WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID
			
			IF @@ROWCOUNT > 0
			BEGIN
				WHILE (1=1)
				BEGIN
					DELETE FROM @TempList_batch
					
					UPDATE TOP (2000) t
						SET IsFinished = 1
					OUTPUT deleted.CustID 
					INTO @TempList_batch (custID)
					FROM @TempCustID t
					WHERE IsFinished IS NULL
					
					--Check empty batches
					IF (@@ROWCOUNT = 0)	BREAK

					SET @strCustID = STUFF((SELECT ',' + CAST(custid AS VARCHAR(20))
									FROM @TempList_batch
									FOR XML PATH('')
									),1,1,'')
					--Update GroupcommID = 0 for LicenseeCustComm
					BEGIN TRY
						EXEC dbo.Lrf_ExecRep_00
								@strCustId = @strCustID,
								@LicenseeID = @LicenseeID,
								@GroupCommID = @GroupCommID,
								@isClearGroupComm = 1
								
					END TRY
					BEGIN CATCH
						SELECT @ErrCode = ERROR_NUMBER()
							, @ErrMsg = ERROR_MESSAGE()
					END CATCH
				END	
			END
		END	
		--#1 delete group, clear comm of member: @IsRemovePlayercomm = 1
		ELSE IF @IsRemovePlayercomm=1
		BEGIN
			UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID AND IsActive=1		
			
			--get list of affected Customers
			SELECT @StrCustID=''
			
			--Remove commission of players in group
			SET @IsexistMember = (SELECT TOP (1) 1 
								FROM LicenseeCustComm ls WITH (NOLOCK)
								WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID)
						
			IF @IsexistMember = 1			
			BEGIN
				--Update List of affected Customers               
				EXEC [Lrf_CustomerUpdMemberComm] 
					@LicenseeID=@LicenseeID,
					@StrCustID='',
					@UserID=@UserID,
					@GroupCommID=0,
					@SBComm=0,
					@NGComm=0,
					@RNGComm=0,
					@ParlayComm=0,	
					--@AllbetComm=0,
					@MacauComm=0,
					@PPComm=0,
					--@GDComm=0,
					--@AGComm=0,
					@FWComm = 0,
					@IsUpdateNG=1,
					@IsUpdateRNG=1,					
					--@IsUpdateAllbet=1,
					@IsUpdateMacau=1,
					@IsUpdatePP=1,
					--@IsUpdateGD=1,
					--@IsUpdateAG=1,
					@IsUpdateFW = 1,
					@isClearGroupComm = 1,
					@ClearGroupCommGroupID = @GroupCommID,
					@IsUpdateGroupComm = 1,
					@IP=@IP,
					@ErrCode=@ErrCode OUTPUT,
					@ErrMsg=@ErrMsg OUTPUT
					
					SELECT @StrCustID=''
					SELECT @StrCustID = STUFF(
						(   SELECT  ',' + CONVERT(NVARCHAR(20), a.custid) 
							FROM dbo.LicenseeCustComm b WITH (NOLOCK)
								INNER JOIN CustDB.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
							WHERE a.SyncCasino = 1 AND b.LicenseeID = @LicenseeID AND b.GroupCommID = @GroupCommID	
							FOR XML PATH('')
						)
						, 1
						, 1
						, '')
			END
			
			IF @ErrCode<>0
				RETURN
		END

		--write log
		SET @endRun = GETDATE()
		SET @duration  = datediff (millisecond,@startRun,@endRun)	
		
		SELECT @LogSPData = '<Lrf_LicenseeGroupCommDel GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'IsRemovePlayercomm="'+ COALESCE(CAST(@IsRemovePlayercomm as VARCHAR(50)),SPACE(1)) + '" ' +
		'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +			
		--'AllbetComm="'+ COALESCE(CAST(@AllbetComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'MacauComm="'+ COALESCE(CAST(@MacauComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'PPComm="'+ COALESCE(CAST(@PPComm as VARCHAR(50)),SPACE(1)) + '" ' +
		--'GDComm="'+ COALESCE(CAST(@GDComm as VARCHAR(50)),SPACE(1)) + '" ' +
		--'AGComm="'+ COALESCE(CAST(@AGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'FWComm="'+ COALESCE(CAST(@FWComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

		SELECT @TrackingValue2 = '<Lrf_LicenseeGroupCommDel GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
		'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'IsRemovePlayercomm="'+ COALESCE(CAST(@IsRemovePlayercomm as VARCHAR(50)),SPACE(1)) + '" ' +
		'RNGComm="'+ COALESCE(CAST(@RNGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'ParlayComm="'+ COALESCE(CAST(@ParlayComm as VARCHAR(50)),SPACE(1)) + '" ' +			
		--'AllbetComm="'+ COALESCE(CAST(@AllbetComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'MacauComm="'+ COALESCE(CAST(@MacauComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'PPComm="'+ COALESCE(CAST(@PPComm as VARCHAR(50)),SPACE(1)) + '" ' +
		--'GDComm="'+ COALESCE(CAST(@GDComm as VARCHAR(50)),SPACE(1)) + '" ' +
		--'AGComm="'+ COALESCE(CAST(@AGComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'FWComm="'+ COALESCE(CAST(@FWComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
		
		EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @UserID,
			@CustID = @LicenseeID,
			@ActionID = 2611,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @TrackingValue2,
			@duration = @duration	
	END
END
GO