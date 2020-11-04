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
			- 20201103@Winfred: Get RepeatedBets  and SpreadGroup on customer class [redmine:#144706]
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @siteID VARCHAR(7) 
	
	SELECT @siteID = siteID 
	FROM SiteConfig.dbo.LicVendorProfile WITH(NOLOCK)
	WHERE SiteName = @site
	-- Get Class for Site
	;WITH T as (
	SELECT CustomerClass,Liveindicator,SportType,LeagueGroupID,BetDelay,NextBetInterval,MaxBet,MaxPerMatch	,c1.SiteID	, c1.RepeatedBets
	FROM CustomerClassPolicy c1 WITH(NOLOCK)
	WHERE c1.isLicensee = 1
		AND c1.Enabled = 1
		AND c1.SiteID = @siteID
	)
	SELECT CustomerClass,Liveindicator,SportType,LeagueGroupID,BetDelay,NextBetInterval,MaxBet,MaxPerMatch,siteid ,RepeatedBets 
	FROM T 
	UNION ALL
	SELECT c2.CustomerClass,c2.Liveindicator,c2.SportType,c2.LeagueGroupID,c2.BetDelay,c2.NextBetInterval,c2.MaxBet,c2.MaxPerMatch	,c2.siteid	,c2.RepeatedBets
	FROM CustomerClassPolicy c2 WITH(NOLOCK)
	WHERE c2.isLicensee = 1
		AND c2.Enabled = 1
		AND c2.SiteID IS NULL
		AND NOT EXISTS (SELECT 1
						FROM T
						WHERE t.customerClass = c2.customerClass
							AND t.SportType = c2.SportType
							AND t.Liveindicator = c2.Liveindicator
							AND t.LeagueGroupID = c2.LeagueGroupID
						)
	ORDER BY CustomerClass,SportType,LeagueGroupID,Liveindicator 		
END
		