ALTER PROCEDURE [dbo].[Lrf_CustomerUpdDanger]
	@CustID INT,
	@UserID INT,
	@Danger INT,
	@Language VARCHAR(10) = 'en-us',
	@IP VARCHAR(40),
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS

/*
Created: 20111101@Henry
Task : Update Danger Level of member
DB: DBTRANS.bodb02


Revisions:
	
Param's Explanation:

*/

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
DECLARE @LogSPData VARCHAR(5000)
SET @startRun = GETDATE()

UPDATE custinfo WITH(ROWLOCK, UPDLOCK)
	SET Danger = @Danger 
	WHERE custid = @custid 
	
IF (@@ERROR <> 0)
BEGIN
	SELECT @ErrMsg =
					CASE @Language 
						WHEN 'en-us' THEN 'Could not update danger level for this member !'
						WHEN 'zh-cn' THEN N'Could not update danger level for this member !'
						WHEN 'zh-tw' THEN N'Could not update danger level for this member !'
						WHEN 'TH' THEN N'Could not update danger level for this member !'
						WHEN 'Ja' THEN N'Could not update danger level for this member !'
						WHEN 'KO' THEN N'Could not update danger level for this member !'
						ELSE N'Could not update danger level for this member !'
					END, @ErrCode = 100
END


	
	
SELECT @LogSPData = '<Lrf_CustomerUpdDanger CustID="'+ COALESCE(CAST(@CustID as VARCHAR(50)),SPACE(1)) + '" ' +
'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
'Language="'+ COALESCE(CAST(@Language as VARCHAR(10)),SPACE(1)) + '" ' +
'Danger="'+ COALESCE(CAST(@Danger as VARCHAR(40)),SPACE(1)) + '" ' +
'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'


SET @endRun = GETDATE()
SET @duration  = datediff (millisecond,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @UserID,
		@CustID = @CustID,
		@ActionID = 2402,
		@TrackingValue = @LogSPData,
		@TrackingValue2 = '',
		@duration = @duration


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdDanger] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdDanger] TO [Dot_Member]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdDanger] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdDanger] TO [vnteam]   