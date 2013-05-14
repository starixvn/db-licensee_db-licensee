set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE [dbo].[Lrf_LicenseeGroupCommIns]
	@LicenseeID INT,
	@GroupName VARCHAR(100),
	@SBComm decimal(9,8),
	@RacingComm decimal(9,8),
	@NGComm decimal (9,8),
	@GroupColor VARCHAR(20),
	@UserID INT,
	@IP varchar(40),
	@GroupCommID INT=0 OUTPUT,
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Insert new Group Commission
DB: DB052.bodb_Licensee


Revisions:
	- 20121227@Henry: Add column IsDefault
	- 20130413@Jim: support multi language
Param's Explanation:

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = GETDATE()

DECLARE @LogSPData VARCHAR(MAX)
DECLARE @TrackingValue2 VARCHAR(MAX)

SELECT @GroupName = rtrim(ltrim(@GroupName))

--Validate data
IF @SBComm>0.15 OR @RacingComm>0.15 OR @NGComm>0.15
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not greater than 0.15'
									ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
									END, @ErrCode = 100
END

IF NOT EXISTS(
	SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND	GroupName = @GroupName AND IsActive = 1
)
BEGIN
	IF @IsDefault=1
	BEGIN
		IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND  IsDefault=1 AND IsActive = 1 )
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Another group is currently set as default. Wanna set this group as default?'
												ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200018,@Langkey)
												END, @ErrCode = 102	
			RETURN
		END
		
		--Reset IsDefault Old to 0
		Update LicenseeGroupComm WITH (ROWLOCK,UPDLOCK)
		SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND IsDefault=1
		
	END

	INSERT INTO LicenseeGroupComm (LicenseeID,GroupName,SBComm,RacingComm,NGComm,color,isDefault)
	VALUES (@LicenseeID,@GroupName,@SBComm,@RacingComm,@NGComm,@GroupColor,@IsDefault)
	
	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Process create new group commission has been failed!'
								ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200019,@Langkey)
								END , @ErrCode = 101
	END	
	
	SELECT @GroupCommID = @@IDENTITY
	
	SELECT @GroupCommID = isnull(@GroupCommID,0)
	
	SET @endRun = GETDATE()
	SET @duration  = datediff (millisecond,@startRun,@endRun)	

	SELECT @LogSPData = '<Lrf_LicenseeGroupCommIns GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
	'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
	'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'RacingComm="'+ COALESCE(CAST(@RacingComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
	'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<Lrf_LicenseeGroupCommIns GroupCommID="'+ COALESCE(CAST(@GroupCommID as VARCHAR(50)),SPACE(1)) + '" ' +
	'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +
	'SBComm="'+ COALESCE(CAST(@SBComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'NGComm="'+ COALESCE(CAST(@NGComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'RacingComm="'+ COALESCE(CAST(@RacingComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
	'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" />'
	
	
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				@UserID = @UserID,
				@CustID = @GroupCommID,
				@ActionID = 2609,
				@TrackingValue = @LogSPData,
				@TrackingValue2 = @TrackingValue2,
				@duration = @duration
	
END
ELSE
BEGIN
	SELECT @ErrMsg =CASE @Langkey WHEN  'en-US' THEN 'This Group Name has been created before!'
								  ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200020,@Langkey)
								  END, @ErrCode = 102
END

		
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeGroupCommIns] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeGroupCommIns] TO [vnteam]  
 

