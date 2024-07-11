/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_CustomerClassSitePolicyMemberSel
	@CustomerClass	SMALLINT,
	@site VARCHAR(50),
	@CurrencyID	TINYINT,
	@IsTest BIT = 0

AS
	/*
		Created: 20230530@Winfred
		Task: LAP - Hide Customer Class 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20230530@Winfred: LAP - Hide Customer Class [redmine:#185367]
			- 20240625@Winfred: LAP - Get data from Spread Management [redmine:#207016]
			- 20240627@Winfred: LAP - Risk Level Information - Get data from Spread Management [redmine:#207016]
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SiteID INT

	SELECT @siteID = siteID FROM Site WITH(NOLOCK)	WHERE site = @site
	
	SELECT SportType, Platform,  Spread
	FROM (
		SELECT
			cp.SportType,
			cp.Platform,
			MAX(cc.Spread) AS Spread,
			ROW_NUMBER() OVER(PARTITION BY cp.SportType, cp.Platform 
							   ORDER BY CASE WHEN cp.SiteID = 0 THEN - 3 ELSE cp.SiteID END DESC, cp.Currency DESC, MAX(cc.Spread) DESC) AS RowNumber
		FROM CustomerClassSpreadDetail cp WITH(NOLOCK)
			CROSS APPLY (SELECT TOP 1 
							cs.Spread
							FROM CustomerClassSpreadClass cm WITH(NOLOCK)
							INNER JOIN CustomerClassSpread cs WITH(NOLOCK) ON cm.PolicyID = cs.PolicyID 
							WHERE cm.PolicyID = cp.PolicyID AND CustomerClass = @CustomerClass AND IsTest <= @IsTest AND Enable = 1 
						) cc
		WHERE	cp.SiteID IN (0, -2, @SiteID) -- -2 : AllDeposit
			AND cp.Currency IN (0, @CurrencyID)
			AND cp.SportType NOT IN (9901, 9902)
		GROUP BY cp.SportType, cp.Currency,cp.SiteID, cp.Platform ) KQ
	WHERE RowNumber = 1
	ORDER BY SportType, Platform
END
		