/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_ProblemAccount_CustomerClassPolicySel
	@site VARCHAR(50)
AS
	/*
		Created: 20200909@Johnson
		Task: Problem Account - Get customer class policy 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20200909@Johnson: initial sp [redmine:#141157]
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @siteID VARCHAR(7) 
	
	SELECT @siteID = siteID 
	FROM SiteConfig.dbo.LicVendorProfile WITH(NOLOCK)
	WHERE SiteName = @site
	
	;WITH T as (
	SELECT CustomerClass,Liveindicator,SportType,LeagueGroupID,BetDelay,NextBetInterval,MaxBet,MaxPerMatch	,c1.SiteID	
	FROM CustomerClassPolicy c1 WITH(NOLOCK)
	WHERE isLicensee = 1
		AND Enabled = 1
		AND SiteID = @siteID
	)
	SELECT CustomerClass,Liveindicator,SportType,LeagueGroupID,BetDelay,NextBetInterval,MaxBet,MaxPerMatch,siteid
	FROM T 
	UNION ALL
	SELECT CustomerClass,Liveindicator,SportType,LeagueGroupID,BetDelay,NextBetInterval,MaxBet,MaxPerMatch	,siteid	
	FROM CustomerClassPolicy c2 WITH(NOLOCK)
	WHERE isLicensee = 1
		AND Enabled = 1
		AND SiteID IS NULL
		AND NOT EXISTS (SELECT 1
						FROM T
						WHERE t.customerClass = c2.customerClass
							AND t.SportType = c2.SportType
							AND t.Liveindicator = c2.Liveindicator
							AND t.LeagueGroupID = c2.LeagueGroupID
						)
	ORDER BY CustomerClass,SportType,LeagueGroupID,Liveindicator 		
END
		