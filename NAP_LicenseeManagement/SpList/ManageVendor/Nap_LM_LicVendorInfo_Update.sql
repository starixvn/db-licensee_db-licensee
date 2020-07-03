/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_LicVendorInfo_Update]
	@VendorId VARCHAR(50),
	@LrfUrl VARCHAR(200) = NULL,
	@AffiliateUrl VARCHAR(200) = NULL,
	@Exclusions VARCHAR(MAX) = NULL
AS
/*
	 Created: Walter
	 Date: 2018-02-14
	 Task: Implement Vendor Info Management
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20180214@Walter: Update Vendor Info: PortalUrl, InternalUrl, LrfUrl, AffiliateUrl [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	UPDATE LicVendorProfile WITH (ROWLOCK, UPDLOCK)
	SET LRF_Url = @LrfUrl,
		AffiliateUrl = @AffiliateUrl,
		Exclusions = @Exclusions
	WHERE VendorID = @VendorId
END
GO