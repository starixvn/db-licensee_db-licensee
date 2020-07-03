/*<info serverAlias="DBPTCS-bodb_PlaytechCS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_PullServiceSetting]
	@LicenseeId		INT,
	@LicenseeName	VARCHAR(50),
	@SettingName	VARCHAR(50), --'AGCasino_VersionKey/GoldDeluxe_VersionKey'
	@IsDelete		BIT = 0
AS
/*
	 Created: Amanda
	 Date: 2019-04-18
	 Task: Add/Remove pull service setting
	 DB: DBPTCS-bodb_PlaytechCS
	 Original: DBA_Lrf_PullServiceSetting
	 
	 Revisions:
	  - 20190418@Amanda: Copy from SP DBA_Lrf_PullServiceSetting [Redmine: #111321]
*/
BEGIN
	SET NOCOUNT ON

	IF @IsDelete = 1
	BEGIN
		DELETE dbo.LicIntegrationSetting WITH (ROWLOCK) WHERE LicenseeId = @LicenseeId AND LicenseeName = @LicenseeName AND SettingName = @SettingName
		RETURN 
	END

	IF NOT EXISTS (SELECT 1 FROM dbo.LicIntegrationSetting WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND SettingName = @SettingName)
	BEGIN
		INSERT INTO dbo.LicIntegrationSetting (LicenseeID, LicenseeName, SettingName, SettingValue, AllowApiBalance)
		SELECT @LicenseeID, @LicenseeName, @SettingName, 0,0
	END
END