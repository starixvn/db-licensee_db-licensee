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
	
	DECLARE @siteID INT 
	
	SELECT @siteID = siteID 
	FROM SiteConfig.dbo.LicVendorProfile WITH(NOLOCK)
	WHERE SiteName = @site
	
	;WITH T as (
	SELECT CustomerClass,Liveindicator,SportType,LeagueGroupID,BetDelay,NextBetInterval,MaxBet,MaxPerMatch,
		ROW_NUMBER () OVER (PARTITION BY CustomerClass,Liveindicator,SportType,LeagueGroupID ORDER BY ISNULL(SiteID,0) DESC) rn
	FROM CustomerClassPolicy c1 WITH(NOLOCK)
	WHERE isLicensee = 1
		AND Enabled = 1
		AND (SiteID IS NULL OR SiteID = @SiteID)
	)
	SELECT CustomerClass,Liveindicator,SportType,LeagueGroupID,BetDelay,NextBetInterval,MaxBet,MaxPerMatch
	FROM T 
	WHERE rn = 1
END
		