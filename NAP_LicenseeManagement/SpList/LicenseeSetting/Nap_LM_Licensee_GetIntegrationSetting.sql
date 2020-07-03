/*<info serverAlias="DBPTCS-bodb_PlaytechCS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_GetIntegrationSetting]
	@LicenseeId INT
AS
/*
	 Created: Amanda
	 Date: 2018-11-21
	 Task: Implement "Licensee Setting" function
	 DB: DBPTCS.bodb_PlaytechCS
	 
	 Revisions:
	  - 20181121@Amanda: Get Integration Setting of Licensee [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT SettingName
	FROM dbo.LicIntegrationSetting WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeId
END
GO