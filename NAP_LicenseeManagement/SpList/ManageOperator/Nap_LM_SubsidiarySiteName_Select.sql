/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_SubsidiarySiteName_Select]
AS
/*
	 Created: Amanda
	 Date: 2018-09-24
	 Task: Implement "Manage operatorID" function
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20180924@Amanda: Select Lrf Site Name which enable subsidiary  [Redmine: #83584]
	  - 20190103@Amanda: Add more condition  [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT SiteName
	FROM LicVendorProfile WITH(NOLOCK)
	WHERE [Disable] = 0
END
GO
