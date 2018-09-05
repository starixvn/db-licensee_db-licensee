USE [bodb_PlaytechCS]
GO
/****** Object:  StoredProcedure [dbo].[DBA_EnableAGCasinoService]    Script Date: 04/16/2015 16:41:36 ******/

ALTER PROCEDURE [dbo].[DBA_EnableAGCasinoService]
	@LicenseeName varchar(50),
	@SettingName varchar(50) --'AGCasino_VersionKey'
AS
/*

Creator: Kiwi.Tran
Date: 2014-12-09
DB: DBPTCS
Description: Enable AG Casino service for Licensee
Revision: -20150416@Jim: add more column AllowApiBalance
	

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @LicenseeID INT = NULL

	SELECT @LicenseeID = LicenseeID FROM bodb_licensee.dbo.Licensees WITH (NOLOCK) WHERE LicenseeName = @LicenseeName

	INSERT INTO LicIntegrationSetting (LicenseeID, LicenseeName, SettingName, SettingValue,AllowApiBalance)
	SELECT @LicenseeID, @LicenseeName, @SettingName, 0,0
	
END