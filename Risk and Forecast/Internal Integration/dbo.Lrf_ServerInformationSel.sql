CREATE  PROCEDURE [dbo].[Lrf_InformationSel]
	
AS
/*
	Created by: [20120510@jacob
	Task: Licensee Integration
	DB: DB052.bodb_Licensee
	Param's Explanation:
	
	
	Revisions:
	- 20111004@Henry: LRF Backup Domain
*/

SET NOCOUNT ON


SELECT 'SSOLink' AS [Type], 'http://www.006660.com/sso.aspx' AS [Value]


GO
GRANT EXECUTE ON [Lrf_InformationSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_InformationSel] TO [vnteam]  