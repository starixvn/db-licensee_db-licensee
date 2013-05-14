ALTER  PROCEDURE [dbo].[Lrf_GetDBCurrentDatetime]
	
AS
/*
	Created by: [20110704@Henry]
	Task: Login to LRF thru Internal site
	DB: DB052.bodb_Licensee
	Param's Explanation:
	
	
	Revisions:
	
*/

SET NOCOUNT ON


SELECT getdate() as CurrentDateTime


GO
GRANT EXECUTE ON [Lrf_GetDBCurrentDatetime] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetDBCurrentDatetime] TO [vnteam]  