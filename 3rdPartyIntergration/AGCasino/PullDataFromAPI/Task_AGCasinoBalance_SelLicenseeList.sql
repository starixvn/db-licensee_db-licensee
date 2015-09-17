IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Task_AGCasinoBalance_SelLicenseeList]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].Task_AGCasinoBalance_SelLicenseeList
GO

ALTER PROCEDURE [dbo].[Task_AGCasinoBalance_SelLicenseeList]
AS 
/*
Created: 20150116@Winnie
Task : [Task_AGCasinoBalance_SelLicenseeList]
Description: Get licensee list that offered AG Casino Balance
DB: DBPTCS.bodb_PlaytechCS
Original:

Revisions:

Param explanation:

*/

SET NOCOUNT ON

SELECT DISTINCT LicenseeName
FROM dbo.LicIntegrationSetting WITH (NOLOCK)
WHERE [AllowApiBalance]=1 AND SettingName LIKE 'AGCasino_VersionKey'

GO

GRANT  EXECUTE  ON [dbo].Task_AGCasinoBalance_SelLicenseeList  TO [bodbLicenseeNet]
GO