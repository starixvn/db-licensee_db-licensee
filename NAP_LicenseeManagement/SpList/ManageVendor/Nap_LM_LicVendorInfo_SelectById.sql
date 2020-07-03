/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_LicVendorInfo_SelectById]
	@VendorId VARCHAR(50)
AS
/*
	 Created: Walter
	 Date: 2018-02-13
	 Task: Implement Vendor Info Management
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20180213@Walter: Select Vendor Info By Vendor Id [Redmine: #83584]
	  
	 Example:
	  exec Nap_LM_LicVendorInfo_SelectById @VendorId='59dq84e'
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT TOP(1)
		   VendorID
		  ,SiteName
		  ,PortalUrl
		  ,InternalUrl
		  ,LRF_Url AS LrfUrl
		  ,AffiliateUrl
		  ,Exclusions
	  FROM LicVendorProfile WITH(NOLOCK)
	  WHERE VendorID = @VendorId
END
GO