ALTER PROCEDURE [dbo].[Lrf_UserLog_LoginSel]
    @UserId INT,
	@UserName AS VARCHAR(50),
    @FromDate DATETIME,
    @ToDate DATETIME,    
    @IsAdminAccess BIT = 0,
    @PageSize INT = 100,
    @PageIndex INT = 1
AS 
/* Created:20110704@Henry
    Task: View Log Login function
    DB: bodb_CustomerLog
	Revisions:
		
    Param's Explaination:    
	- @UserId: a customer which we want to view actions affect to.
	- @UserName: customer name type in textbox to search
	- @FromDate: date range to view log
	- @ToDate: date range to view log
*/

SET NOCOUNT ON ;


--pending






GO
GRANT EXECUTE ON [dbo].[Lrf_UserLog_LoginSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserLog_LoginSel] TO [vnteam] 