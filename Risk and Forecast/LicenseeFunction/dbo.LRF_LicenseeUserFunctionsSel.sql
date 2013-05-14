ALTER  PROCEDURE [dbo].[Lrf_LicenseeUserFunctionsSel]	
	@LicenseeId INT,
	@UserId INT	
AS
/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:
		@UserId: Gell all functions which UserId = @UserId has permission
	Revisions:
	
	Example:
		EXEC [dbo].[Lrf_LicenseeUserFunctionsSel] @LicenseeId=1,  @UserId = 1
*/

SET NOCOUNT ON

SELECT FunctionId
FROM [dbo].[LicenseeUserFunctions] WITH(NOLOCK)
WHERE LicenseeId = @LicenseeId AND UserId = @UserId
	  

GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeUserFunctionsSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeUserFunctionsSel] TO [vnteam] 