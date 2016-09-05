
ALTER  PROCEDURE [dbo].[Lrf_FunctionsSel]	
	
AS
/*
	Created by: [20111210@Jacob]
	Task: Break down permission for account management
	DB: DB052.bodb_Licensee
	Param's Explanation:		
	Revisions:
		- 20160714@Victor: Add two new columns to Functions table [Remine: #58537]
		 
	Example:
		EXEC [dbo].[Lrf_FunctionsSel]
*/

SET NOCOUNT ON

SELECT [FunctionId],
	[Name],
	[Description],
	[ParentId],
	[Url],
	[IsMenu],
	[DisplayOrder],
	[IsActive],
	[IsNew],
	[FunctionKey],
	[Environment] 
	[IsFunction]
FROM [dbo].[Functions] WITH(NOLOCK)
WHERE IsActive = 1

GO
GRANT EXECUTE ON [dbo].[Lrf_FunctionsSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_FunctionsSel] TO [vnteam] 