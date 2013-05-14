ALTER  PROCEDURE [dbo].[LRF_UserFullPermissionSel]	
	@LicenseeId INT	
AS
/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:
		@UserId: Gell all functions which UserId = @UserId has permission
	Revisions:
	
	Example:
		EXEC [dbo].[LRF_UserFullPermissionSel] @LicenseeId=1
*/

SET NOCOUNT ON

DECLARE @CommonFunctionCount INT

SELECT @CommonFunctionCount = COUNT(l.FunctionId)
FROM [dbo].[LicenseeFunctions] l WITH(NOLOCK) 
INNER JOIN [dbo].[Functions] f WITH(NOLOCK) ON f.FunctionId = l.FunctionId
WHERE l.LicenseeId = @LicenseeId
AND f.FunctionId <> 6  AND f.ParentId <> 6 -- Manage account function has id = 6



SELECT UserId
FROM [dbo].[LicenseeUserFunctions] WITH(NOLOCK)
WHERE LicenseeId = @LicenseeId 
GROUP BY UserId 
HAVING COUNT(*) >= @CommonFunctionCount
	  

GO
GRANT EXECUTE ON [dbo].[LRF_UserFullPermissionSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_UserFullPermissionSel] TO [vnteam] 