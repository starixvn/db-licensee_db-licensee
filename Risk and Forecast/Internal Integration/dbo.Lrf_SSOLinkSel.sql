ALTER  PROCEDURE [dbo].[Lrf_SSOLinkSel]
	
AS
/*
	Created by: [20120510@Jacob]
	Task: Return SSO Link
	DB: DB052.bodb_Licensee
	Param's Explanation:
	
	
	Revisions:

*/

SET NOCOUNT ON
  
SELECT 'SSOLink' AS [Type], 'http://www.006660.com/sso.aspx' AS [Value]  


GO
GRANT EXECUTE ON [Lrf_SSOLinkSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SSOLinkSel] TO [vnteam]   