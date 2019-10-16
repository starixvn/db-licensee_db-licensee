/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lap_ReadLog_UserLog_UserControl]
	@CustID INT = -1,
	@StartDate DateTime,
	@EndDate DateTime,
	@ActionIDList as [TVP_Int] READONLY
AS
/*
	Created: 20190925@Jason(TW)
	Description: LAP - Create SP to select Player Admin log
	DB: DBLOG.bodb_CustomerLog
   
	Revisions:
		- 20190925@Jason: Create SP[Redmine: #112658]
*/
BEGIN
	SET NOCOUNT ON
	
	IF @CustId >= 0
		BEGIN
			SELECT 
				LogID, CustID, LogDate, UserID, TypeID, ActionID, Duration, Doing 
			FROM [UserLog_UserControl] WITH (NOLOCK)
			WHERE CustID = @CustID
				AND ActionID IN (SELECT Val From @ActionIDList)
				AND LogDate BETWEEN @StartDate AND @EndDate
		END
	ELSE
		BEGIN
			SELECT 
				LogID, CustID, LogDate, UserID, TypeID, ActionID, Duration, Doing 
			FROM [UserLog_UserControl] WITH (NOLOCK)
			WHERE ActionID IN (SELECT Val From @ActionIDList)
			    AND LogDate BETWEEN @StartDate AND @EndDate
		END
END
GO