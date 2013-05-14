
ALTER  PROCEDURE [dbo].[Lrf_LicenseeFunctionsSel]	
	@LicenseeId INT	
AS
/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:		
	Revisions:
	
	Example:
		EXEC [dbo].[Lrf_LicenseeFunctionsSel] @LicenseeId = 1
*/

SET NOCOUNT ON

SELECT [FunctionId]
FROM [dbo].[LicenseeFunctions] WITH(NOLOCK)
WHERE LicenseeId = @LicenseeId

GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeFunctionsSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeFunctionsSel] TO [vnteam] 