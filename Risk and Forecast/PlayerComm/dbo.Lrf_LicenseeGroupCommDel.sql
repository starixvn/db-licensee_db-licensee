set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommDel]
	@LicenseeID INT,
	@GroupCommID INT,
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@IsResetDefault BIT=0,
	@Langkey NVARCHAR(10)='en-US'	,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Delete Group Commission
DB: DB052.bodb_Licensee


Revisions:
	-20130413@Jim: support multi language
Param's Explanation:

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = GETDATE()

DECLARE @LogSPData VARCHAR(MAX)
DECLARE @TrackingValue2 VARCHAR(MAX)

DECLARE @SBComm DECIMAL(9,8) , @RacingComm DECIMAL(9,8) ,@NGComm DECIMAL(9,8),@GroupColor VARCHAR(20), @GroupName VARCHAR(100), @IsDefault BIT

IF NOT EXISTS(
	SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
)
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This Group does not exist!'
									ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200016,@Langkey) 
									END, @ErrCode = 100	
END
ELSE
BEGIN
	--Get old setting
	SELECT @SBComm=SBComm,@NGComm=NGComm,@RacingComm=RacingComm,@GroupColor=color,@GroupName=GroupName,@IsDefault=IsDefault
	FROM LicenseeGroupComm WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
	
	IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND  IsDefault=1 AND IsActive = 1 AND ID=@GroupCommID)
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This is the default group. Do you want to proceed?'
													ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200017,@Langkey) 
													END , @ErrCode = 101	
		RETURN
	END

	IF @IsRemovePlayercomm=0
	BEGIN
		UPDATE LicenseeGroupComm WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
		WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID
		
		UPDATE LicenseeCustComm WITH (ROWLOCK,UPDLOCK) SET GroupCommID=0
		WHERE GroupCommID=@GroupCommID
		
	END
	ELSE IF @IsRemovePlayercomm=1
	BEGIN
		UPDATE LicenseeGroupComm WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
		WHERE LicenseeID = @LicenseeID AND ID = @GroupCommID AND IsActive=1
		
		
		--Remove commission of players in group
		--get list of affected Customers
		DECLARE @strCustID VARCHAR(MAX)
		 SELECT @strCustID = STUFF(
                        (   SELECT  ',' + CONVERT(NVARCHAR(20), custid) 
                            FROM LicenseeCustComm WITH (NOLOCK)
							WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID
                            FOR xml path('')
                        )
                        , 1
                        , 1
                        , '')
        
        IF LTRIM(RTRIM(@strCustID)) <> ''
        BEGIN
			--Update List of affected Customers               
			EXEC [Lrf_CustomerUpdMemberComm] @LicenseeID=@LicenseeID,@strCustID=@strCustID,@UserID=@UserID,@GroupCommID=0,@SBComm=0,@NGComm=0,@RacingComm=0,@IsUpdateNG=1,@IsUpdateRacing=1,@IP=@IP,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		END
		
		IF @ErrCode<>0
			RETURN
		
		--Delete players out of LicenseeCustComm
		DELETE FROM LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		WHERE GroupCommID=@GroupCommID
			
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
		'RacingComm="'+ COALESCE(CAST(@RacingComm as VARCHAR(50)),SPACE(1)) + '" ' +
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
		'RacingComm="'+ COALESCE(CAST(@RacingComm as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
	
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				@UserID = @UserID,
				@CustID = @LicenseeID,
				@ActionID = 2611,
				@TrackingValue = @LogSPData,
				@TrackingValue2 = @TrackingValue2,
				@duration = @duration

	
	
END

	
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeGroupCommDel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeGroupCommDel] TO [vnteam] 