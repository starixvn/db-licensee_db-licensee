/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_CustomerClassSitePolicySel
	@site VARCHAR(50),
	@IsTest BIT = 0 
AS
	/*
		Created: 20201103@Winfred
		Task: Problem Account - Get customer class site policy 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20201103@Winfred: Get SpreadGroup on customer class [redmine:#144706]
			- 20210329@Winfred: Get Platform on customer class site policy [redmine:#144706]
			- 20240627@Winfred: LAP - Risk Level Information - Get data from Spread Management [redmine:#207016]
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SiteID INT

	SELECT @siteID = siteID FROM Site WITH(NOLOCK)	WHERE site = @site
	-- Get Class for Site
	SELECT SportType, Platform,Currency, CustomerClass, Spread
	FROM (
		SELECT
			cp.SiteID ,
			cp.SportType,
			cp.Platform,
			cp.Currency,
			cc.CustomerClass,
			MAX(cs.Spread) AS Spread,
			ROW_NUMBER() OVER(PARTITION BY cp.SportType, cc.CustomerClass, cp.Currency, cp.Platform 
							 ORDER BY CASE WHEN cp.SiteID = 0 THEN -3 ELSE  cp.SiteID END DESC, MAX(cs.Spread) DESC) AS RowNumber
		FROM CustomerClassSpreadDetail cp WITH(NOLOCK)
			CROSS APPLY (SELECT TOP 1 PolicyID, Spread
						 FROM CustomerClassSpread cm WITH(NOLOCK)
						 WHERE cm.PolicyID = cp.PolicyID AND IsTest <= @IsTest AND Enable = 1 
						) cs
			CROSS APPLY (SELECT CustomerClass
							FROM CustomerClassSpreadClass cm WITH(NOLOCK)
							WHERE cm.PolicyID = cp.PolicyID 
						) cc
		WHERE	cp.SiteID IN (0, -2, @SiteID) -- -2 : AllDeposit
			AND cp.SportType NOT IN (9901, 9902)
		GROUP BY cp.SiteID, cp.SportType, cc.CustomerClass, cp.Currency, cp.Platform ) KQ
	WHERE RowNumber = 1
	ORDER BY CustomerClass, SportType, Currency, Platform
	
END
		