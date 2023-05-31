/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_CustomerClassSitePolicyMemberSel
	@CustomerClass	SMALLINT,
	@site VARCHAR(50),
	@CurrencyID	TINYINT
AS
	/*
		Created: 20230530@Winfred
		Task: LAP - Hide Customer Class 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20230530@Winfred: LAP - Hide Customer Class [redmine:#185367]
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @siteID VARCHAR(7) 
	
	SELECT @siteID = siteID 
	FROM SiteConfig.dbo.LicVendorProfile WITH(NOLOCK)
	WHERE SiteName = @site

	CREATE TABLE #CustomerClassSitePolicy(CustomerClass	SMALLINT,Enabled BIT,SiteID	VARCHAR(7),SpreadGroup	VARCHAR(3),CurrencyID TINYINT,Platform	TINYINT,PRIMARY KEY(CustomerClass ,Platform))
	-- Get Class for Site
	INSERT INTO #CustomerClassSitePolicy(CustomerClass, Enabled, SiteID, SpreadGroup, Platform, CurrencyID)
	SELECT DISTINCT CustomerClass,c1.Enabled ,c1.SiteID	, c1.SpreadGroup , c1.Platform , c1.CurrencyID
	FROM CustomerClassSitePolicy c1 WITH(NOLOCK)
	WHERE c1.isLicensee = 1
		AND c1.CustomerClass = @CustomerClass
		AND c1.Enabled = 1
		AND c1.SiteID = @siteID
		AND c1.CurrencyID = @CurrencyID
	-- site and all currency
	INSERT INTO #CustomerClassSitePolicy(CustomerClass, Enabled, SiteID, SpreadGroup, Platform, CurrencyID)
	SELECT c2.CustomerClass,c2.Enabled	,c2.siteid	,c2.SpreadGroup ,c2.Platform  , c2.CurrencyID
	FROM CustomerClassSitePolicy c2 WITH(NOLOCK)
	WHERE c2.isLicensee = 1
		AND c2.Enabled = 1
		AND c2.CustomerClass = @CustomerClass
		AND c2.SiteID = @siteID
		AND c2.CurrencyID IS NULL
		AND NOT EXISTS (SELECT 1
						FROM #CustomerClassSitePolicy t
						WHERE t.customerClass = c2.customerClass AND t.Platform = c2.Platform )
	-- currency And  all Site
	INSERT INTO #CustomerClassSitePolicy(CustomerClass, Enabled, SiteID, SpreadGroup, Platform, CurrencyID)
	SELECT c2.CustomerClass,c2.Enabled	,c2.siteid	,c2.SpreadGroup ,c2.Platform  , c2.CurrencyID
	FROM CustomerClassSitePolicy c2 WITH(NOLOCK)
	WHERE c2.isLicensee = 1
		AND c2.Enabled = 1
		AND c2.CustomerClass = @CustomerClass
		AND c2.SiteID IS NULL
		AND c2.CurrencyID = @CurrencyID
		AND NOT EXISTS (SELECT 1
						FROM #CustomerClassSitePolicy t
						WHERE t.customerClass = c2.customerClass AND t.Platform = c2.Platform)
	
	-- all currency And  all Site
	INSERT INTO #CustomerClassSitePolicy(CustomerClass, Enabled, SiteID, SpreadGroup, Platform, CurrencyID)
	SELECT c2.CustomerClass,c2.Enabled	,c2.siteid	,c2.SpreadGroup ,c2.Platform  , c2.CurrencyID
	FROM CustomerClassSitePolicy c2 WITH(NOLOCK)
	WHERE c2.isLicensee = 1
		AND c2.Enabled = 1
		AND c2.CustomerClass = @CustomerClass
		AND c2.SiteID IS NULL
		AND c2.CurrencyID IS NULL
		AND NOT EXISTS (SELECT 1
						FROM #CustomerClassSitePolicy t
						WHERE t.customerClass = c2.customerClass AND t.Platform = c2.Platform)
	
	SELECT CustomerClass, Enabled, SiteID, SpreadGroup, Platform, CurrencyID
	FROM #CustomerClassSitePolicy
	ORDER BY CustomerClass , SpreadGroup	
	

	DROp TABLE #CustomerClassSitePolicy
END
		