/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
USE bodb_Licensee
GO

ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommDel]
	@LicenseeID INT,
	@GroupCommID INT,
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@IsResetDefault BIT=0,
	@Langkey NVARCHAR(10)='en-US'	,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT,
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
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON 
		
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()

	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)

	DECLARE @SBComm DECIMAL(9,8), 
		@NGComm DECIMAL(9,8),
		@RNGComm DECIMAL(9,8),
		@ParlayComm DECIMAL(9,8), 		
		@GroupColor VARCHAR(20), 
		@GroupName VARCHAR(100), 
		@IsDefault BIT

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

		IF @IsRemovePlayercomm=0
		BEGIN
			UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
			
			UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK) SET GroupCommID=0
			WHERE GroupCommID=@GroupCommID
			
		END
		ELSE IF @IsRemovePlayercomm=1
		BEGIN
			UPDATE dbo.LicenseeGroupComm WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
			WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID AND IsActive=1		
			
			--Remove commission of players in group
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
					@LicenseeID=@LicenseeID,
					@StrCustID=@StrCustID,
					@UserID=@UserID,
					@GroupCommID=0,
					@SBComm=0,
					@NGComm=0,
					@RNGComm=0,
					@ParlayComm=0,				
					@IsUpdateNG=1,
					@IsUpdateRNG=1,					
					@IP=@IP,
					@ErrCode=@ErrCode OUTPUT,
					@ErrMsg=@ErrMsg OUTPUT
					
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
			
			IF @ErrCode<>0
				RETURN
			
			--Update players out of LicenseeCustComm GroupCommID
			UPDATE LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
			SET 
				SBComm = 0,
				NGComm = 0,
				RNGComm = 0,
				ParlayComm = 0,				
				GroupCommID = 0
			WHERE GroupCommID = @GroupCommID				

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
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
		
		EXEC LAP_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @UserID,
			@CustID = @LicenseeID,
			@ActionID = 2611,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @TrackingValue2,
			@duration = @duration	
	END
END
GO