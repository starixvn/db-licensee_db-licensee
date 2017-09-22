USE [bodb_PlaytechCS]
GO

/****** Object:  Stored Procedure dbo.DBA_EnableGoldDeluxeService    Script Date: 4/27/2015 5:39:41 PM ******/
ALTER PROCEDURE [dbo].[DBA_EnableGoldDeluxeService]
	@LicenseeName varchar(50),
	@SettingName varchar(50) --'GoldDeluxe_VersionKey'
AS
/*
	Creator: Jim.Tran
	Date: 2015-04-27
	DB: DBPTCS
	Description: Enable Gold Deluxe service for Licensee
	Revision: 	

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @LicenseeID INT = NULL

	SELECT @LicenseeID = LicenseeID FROM bodb_licensee.dbo.Licensees WITH (NOLOCK) WHERE LicenseeName = @LicenseeName

	INSERT INTO LicIntegrationSetting (LicenseeID, LicenseeName, SettingName, SettingValue,AllowApiBalance)
	SELECT @LicenseeID, @LicenseeName, @SettingName, 0,0
	
END

GO