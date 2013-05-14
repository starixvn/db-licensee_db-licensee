set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_LicenseeBAHistoryUpdDone]
	@LicenseeID INT,
	@CustID INT,--member
	@ModifyBy INT,
	@Langkey VARCHAR(10) = 'en-US',
	@IP VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS

/*
Created: 20111101@Henry
Task : Update Done when turn off BA Member
DB: DB052.bodb_Licensee


Revisions:
	-20130413@Jim: support multi language
Param's Explanation:

*/
DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
DECLARE @LogSPData VARCHAR(5000)
SET @startRun = GETDATE()



Update [LicenseeBAHistory] WITH (ROWLOCK,UPDLOCK)
SET 
	[Status] = 'Done',
	OffDate = GETDATE(),
	OffBy = @ModifyBy
WHERE 
	LicenseeID = @LicenseeID
	AND CustID = @CustID
	AND [Status] = 'Running'
		
IF (@@ERROR <> 0)
BEGIN
	SELECT @ErrMsg = 
					CASE @Langkey 
						WHEN 'en-US' THEN 'Process turn off BA is unsuccessful !'
						ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200015,@Langkey)
					END, @ErrCode = 100
	RETURN
END	
	
	
SELECT @LogSPData = '<Lrf_LicenseeBAHistoryUpdDone LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
'CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@ModifyBy as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'


SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)

EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @ModifyBy,
		@CustID = @CustID,
		@ActionID = 2403,
		@TrackingValue = @LogSPData,
		@TrackingValue2 = '',
		@duration = @duration

GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeBAHistoryUpdDone] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeBAHistoryUpdDone] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeBAHistoryUpdDone] TO [vnteam]   


