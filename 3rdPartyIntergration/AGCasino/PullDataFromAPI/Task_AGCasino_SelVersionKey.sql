IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_AGCasino_SelVersionKey]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].Task_AGCasino_SelVersionKey
GO


CREATE PROCEDURE Task_AGCasino_SelVersionKey
AS 
/*
Created: 20140909@Victor
Task : [Task_AGCasino_SelVersionKey]
Description: Get latest version key for AG Casino product
DB: DBPTCS.bodb_PlaytechCS
Original:

Revisions:

Param explanation:

*/

SET NOCOUNT ON

SELECT CAST(VValue AS BIGINT) AS VersionKey
FROM bodb_PlaytechCS.dbo.SystemSetting WITH(NOLOCK) 
WHERE VName LIKE 'AGCasino_VersionKey'

GO

GRANT  EXECUTE  ON [dbo].Task_AGCasino_SelVersionKey  TO [bodbLicenseeNet]
GO