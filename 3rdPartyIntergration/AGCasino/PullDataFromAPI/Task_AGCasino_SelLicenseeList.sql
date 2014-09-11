IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_AGCasino_SelLicenseeList]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].Task_AGCasino_SelLicenseeList
GO


CREATE PROCEDURE Task_AGCasino_SelLicenseeList
AS 
/*
Created: 20140909@Victor
Task : [Task_AGCasino_SelLicenseeList]
Description: Get licensee list that offered AG Casino
DB: DBPTCS.bodb_PlaytechCS
Original:

Revisions:

Param explanation:

*/

SET NOCOUNT ON

SELECT LicenseeName, 
	CAST(SettingValue AS BIGINT) AS VersionKey 
FROM dbo.LicIntegrationSetting WITH (NOLOCK)
WHERE SettingName LIKE 'AGCasino_VersionKey'

GO

GRANT  EXECUTE  ON [dbo].Task_AGCasino_SelLicenseeList  TO [bodbLicenseeNet]
GO