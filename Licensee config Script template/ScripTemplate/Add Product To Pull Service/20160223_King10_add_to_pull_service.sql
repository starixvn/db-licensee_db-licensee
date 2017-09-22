/*
Support #52669 : 
 run on DBPTCS/bodb_PlaytechCS
*/
USE bodb_PlaytechCS
GO
 
EXEC  [dbo].[DBA_EnableAGCasinoService] @LicenseeName = 'King10', @SettingName ='AGCasino_VersionKey'
GO
EXEC  [dbo].[DBA_EnableGoldDeluxeService] @LicenseeName = 'King10', @SettingName ='GoldDeluxe_VersionKey'