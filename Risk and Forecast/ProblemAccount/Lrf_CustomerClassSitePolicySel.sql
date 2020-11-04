/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_ProblemAccount_CustomerClassSitePolicySel
	@site VARCHAR(50)
AS
	/*
		Created: 20201103@Winfred
		Task: Problem Account - Get customer class site policy 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20201103@Winfred: Get SpreadGroup on customer class [redmine:#144706]
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @siteID VARCHAR(7) 
	
	SELECT @siteID = siteID 
	FROM SiteConfig.dbo.LicVendorProfile WITH(NOLOCK)
	WHERE SiteName = @site
	-- Get Class for Site
	;WITH T as (
	SELECT CustomerClass,c1.Enabled ,c1.SiteID	, c1.SpreadGroup
	FROM CustomerClassSitePolicy c1 WITH(NOLOCK)
	WHERE c1.isLicensee = 1
		AND c1.Enabled = 1
		AND c1.SiteID = @siteID
	)
	SELECT CustomerClass,Enabled,siteid ,SpreadGroup 
	FROM T 
	UNION ALL
	SELECT c2.CustomerClass,c2.Enabled	,c2.siteid	,c2.SpreadGroup
	FROM CustomerClassSitePolicy c2 WITH(NOLOCK)
	WHERE c2.isLicensee = 1
		AND c2.Enabled = 1
		AND c2.SiteID IS NULL
		AND NOT EXISTS (SELECT 1
						FROM T
						WHERE t.customerClass = c2.customerClass
						)
	ORDER BY CustomerClass 		
END
		