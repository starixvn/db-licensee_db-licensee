/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[Lrf_f_Sel_PromotionExcludedBetType]()
RETURNS TABLE
AS
/*
	Creator: Kelvin@20250722
	Task: Get promotion and excluded bettype for job sum
	DB: DBEXT-bodb02,DBACC-bodb02
	Revision:
		- 20250722@Kelvin: Enhancement to speed up integrate new casino product - Phase 2 [RedmineID: #232697]

	Example:
	SELECT * FROM dbo.Lrf_f_Sel_PromotionExcludedBetType()
*/
RETURN
	WITH CTE_Bettype AS
	(
		SELECT
			DISTINCT bt.BetType, bt.SportType, bt.ProductID, p.ProductPrefix, bt.RefTable
		FROM
			dbo.SportBettypeMatrix(NOLOCK) bt
			INNER JOIN dbo.Products(NOLOCK) p ON p.ProductID = bt.ProductID
	)
	,CTE_BetTypeExclude AS
	(
		SELECT
			DISTINCT bt.BetType, bt.SportType
		FROM 
			CTE_Bettype bt
			INNER JOIN dbo.Lrf_f_SelExcludedBetType() e ON e.BetType = bt.BetType AND e.SportType = bt.SportType
	)
	,CTE_NotBetEffective AS -- using logic BetEffective in rptLicWinloss2 (Task_DailyRptLicWinloss2_Bettrans, Task_DailyRptLicWinloss2)
	(
		SELECT
			DISTINCT bt.BetType, bt.SportType
		FROM
			CTE_Bettype bt
		WHERE 
			EXISTS (	SELECT 1 
						FROM CTE_BetTypeExclude e
						WHERE e.BetType = bt.BetType AND e.SportType = bt.SportType
							AND e.SportType <> 246			-- Saba Promotion
							AND e.BetType NOT IN (999, 997) -- OddsAdjustment, OddsBoostBonus
					)
			OR (bt.BetType BETWEEN 1611 AND 1699 AND bt.SportType = 150) -- SBC FreeBets
			OR (bt.bettype BETWEEN 3801 AND 3899 AND bt.SportType = 173) -- VGA FreeBets
			OR (bt.bettype BETWEEN 8700 AND 8709)						 -- Player Tips
	)
	,CTE_ExtraPayout AS --using logic for Extra Payout Report
	(
		SELECT
			DISTINCT bt.BetType, bt.SportType
			, CASE WHEN e.BetType IS NOT NULL THEN e.PromotionType
				WHEN (bt.ProductPrefix = 'SBC' AND bt.BetType NOT IN (1698, 1699) AND bt.SportType = 150) THEN 4201
				WHEN (bt.ProductPrefix = 'VGA' AND bt.BetType NOT IN (3897, 3898, 3899) AND bt.SportType = 173) THEN 6601
				WHEN bt.BetType = 8700 THEN 7401
			ELSE NULL END AS PromotionType
		FROM
			CTE_Bettype bt
			LEFT JOIN dbo.Lrf_f_SelExcludedBetType() e ON e.BetType = bt.BetType AND e.SportType = bt.SportType
		WHERE
			(e.BetType IS NOT NULL AND e.BetType <> 999)
			OR (bt.ProductPrefix = 'SBC' AND bt.BetType NOT IN (1698, 1699) AND bt.SportType = 150)
			OR (bt.ProductPrefix = 'VGA' AND bt.BetType NOT IN (3897, 3898, 3899) AND bt.SportType = 173)
			OR bt.BetType IN (8700)
	)
	,CTE_Final AS
	(
		/* Get exclude BetType in function Lrf_f_SelExcludedBetType */
		SELECT
			DISTINCT bt.BetType
			, IIF(bt.BetType IN (999, 997), bt.BetType, bt.SportType) AS SportType -- convert SportType (999, 997) to join with bettrans.matchid, others promotion bettype : bettrans.matchid = SportType
			, bt.ProductID, bt.ProductPrefix, bt.RefTable
			, CASE WHEN b.BetType IS NOT NULL THEN 1 ELSE 0 END AS IsNotBetEffective
			, p.PromotionType
		FROM
			CTE_Bettype bt
			INNER JOIN CTE_BetTypeExclude e ON e.BetType = bt.BetType AND e.SportType = bt.SportType
			LEFT JOIN CTE_NotBetEffective b ON b.BetType = bt.BetType AND b.SportType = bt.SportType
			LEFT JOIN CTE_ExtraPayout p ON p.BetType = bt.BetType AND p.SportType = bt.SportType

		UNION
		/* Get exclude BetType for special product */
		SELECT
			DISTINCT bt.BetType
			, bt.SportType
			, bt.ProductID, bt.ProductPrefix, bt.RefTable
			, CASE WHEN b.BetType IS NOT NULL THEN 1 ELSE 0 END AS IsNotBetEffective
			, p.PromotionType
		FROM
			CTE_Bettype bt
			LEFT JOIN CTE_NotBetEffective b ON b.BetType = bt.BetType AND b.SportType = bt.SportType
			LEFT JOIN CTE_ExtraPayout p ON p.BetType = bt.BetType AND p.SportType = bt.SportType
		WHERE
			(bt.BetType BETWEEN 1611 AND 1699 AND bt.SportType = 150)		--SBC FreeBets
			OR (bt.bettype BETWEEN 3801 AND 3899 AND bt.SportType = 173)	-- VGA FreeBets
			OR (bt.bettype BETWEEN 8700 AND 8709)							-- Player Tips
			OR (bt.bettype BETWEEN 1801 AND 1803)							-- AGC Jackpot Contribution and Jackpot Prize and Promotion
			OR (bt.bettype BETWEEN 11001 AND 11049)							-- SABA Coins
	)
	SELECT DISTINCT BetType, SportType, ProductID, ProductPrefix, Reftable, IsNotBetEffective, PromotionType
	FROM CTE_Final
