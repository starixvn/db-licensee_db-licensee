set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_CustomerInfoIns]
	@CustID INT,--member
	@Recommend INT,
	@Username VARCHAR(50),
	@Username2 VARCHAR(50),
	@Currency INT,
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS

/*
Created: 20111226@Henry
Task : Insert customer info to LicenseeCustinfo when create new member
DB: DB052.bodb_Licensee


Revisions:
	
Param's Explanation:

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
DECLARE @LogSPData VARCHAR(5000)
SET @startRun = GETDATE()


IF NOT EXISTS(
	SELECT TOP 1 1 FROM LicenseeCustinfo WITH (NOLOCK)
	WHERE CustID = @CustID
)
BEGIN
	INSERT INTO LicenseeCustinfo (CustId,recommend,username,username2,currency)
	VALUES (@CustID,@Recommend,@Username,@Username2,@Currency)
	
	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrMsg = CASE @Langkey
							WHEN 'en-US' THEN 'Process copy data to LicenseeCustinfo has been failed!'
							ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200006,@Langkey)
							END
	END	
	
END
ELSE
BEGIN
	SELECT @ErrMsg = CASE @Langkey
					WHEN 'en-US' THEN 'The custid has been inserted to LicenseeCustinfo before!'
					ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200007,@Langkey)
					END
END

SELECT @LogSPData = '<Lrf_CustomerInfoIns CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
	'Recommend="'+ COALESCE(CAST(@Recommend as VARCHAR(50)),SPACE(1)) + '" ' +
	'Username="'+ COALESCE(CAST(@Username as VARCHAR(50)),SPACE(1)) + '" ' +
	'Username2="'+ COALESCE(CAST(@Username2 as VARCHAR(50)),SPACE(1)) + '" ' +
	'Currency="'+ COALESCE(CAST(@Currency as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'
	
	
	


SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)

EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
	@UserID = @CustID,
	@CustID = @CustID,
	@ActionID = 2408,
	@TrackingValue = @LogSPData,
	@TrackingValue2 = '',
	@duration = @duration


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerInfoIns] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerInfoIns] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerInfoIns] TO [vnteam]  

