/*<info serverAlias="DBEXT-bodb02" selecters="bodbLicenseeNet,wsv_lap,wsv_alp" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[LAP_f_WinlossAnalysis_BettypeMatrix] (
	@ProductCheck	VARCHAR(MAX),
	@SportCheck		VARCHAR(MAX),
	@BettypeCheck	VARCHAR(MAX),
	@SBBACheck		TINYINT
)
RETURNS TABLE
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - Bettype matrix
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465] 
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20240304@Evan: Grant execute new acc [RedmineID: #201283]
		- 20242901@Evan: Enhance code use function Lrf_f_GroupBettype [RedmineID: #199347]
		
*/
RETURN
	WITH CTE_SabaSport AS (
		SELECT saba.SabaSportType, t.SportType
		FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
		OUTER APPLY
		(
			SELECT Sporttype, LeagueGroupID
			FROM OPENJSON(saba.SporttypeRef)
			WITH (Sporttype INT '$.Sporttype', 
				LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
			)
			OUTER APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID INT '$')
		) AS t
		WHERE saba.IsShowUI = 1
	),
	CTE_SportInput AS (
		SELECT CAST(value AS INT) AS sporttype
		FROM STRING_SPLIT(@SportCheck, ',')
	),
	CTE_SportFilter AS (
		SELECT saba.SportType 
		FROM CTE_SportInput AS f
		INNER JOIN CTE_SabaSport saba ON saba.SabaSportType = f.sporttype
		WHERE f.sporttype < 0
		UNION ALL
		SELECT sporttype FROM CTE_SportInput
	),
	CTE_GroupBettype AS (
		SELECT Bettype, GroupTypeID FROM bodb02.dbo.Lrf_f_GroupBettype()	
	),
	CTE_BettypeInput AS (
		SELECT CAST(value AS INT) AS Bettype 
		FROM STRING_SPLIT(@BettypeCheck, ',') AS t
	),
	CTE_BettypeFilter AS (
		SELECT gbt.bettype
		FROM CTE_BettypeInput AS t
		INNER JOIN CTE_GroupBettype gbt ON gbt.GroupTypeId = t.Bettype	
		UNION 
		SELECT Bettype
		FROM CTE_BettypeInput t
	),
	CTE_ProductFilter AS (
		SELECT ex.Code
		FROM (
			SELECT SBBACheck = @SBBACheck
		) AS ck
		OUTER APPLY (
			SELECT Code
			FROM (VALUES('SLT'),('BTC')) AS t (Code)
			WHERE ck.SBBACheck > 2
			UNION 
			SELECT Code
			FROM (VALUES('SB')) AS t (Code)
			WHERE ck.SBBACheck & 4 = 0
				AND ck.SBBACheck & 8 = 8
		) AS ex
		UNION 
		SELECT value AS Code 
		FROM STRING_SPLIT(@ProductCheck, ',') AS t
	),
	CTE_Product AS (
		SELECT 0 AS ProductID, p.ProductPrefix AS ProductCode
		FROM bodb02.dbo.Products p WITH(NOLOCK) 
		WHERE p.ProductID = 1
		UNION ALL
		SELECT DISTINCT p3.ProductID, p3.ProductPrefix AS ProductCode
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
			INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		WHERE p3.Enabled = 1
	)
	SELECT tbl.ProductId, tbl.Bettype, tbl.RefTable, tbl.EventType,
		CASE WHEN cont.Bettype IS NOT NULL THEN 1 ELSE 0 END AS IsContributionBettype,
		tbl.Product3rdId,
		IIF(e.Bettype > 0, 1, 0) AS IsPriceBettype,
		tbl.GroupTypeId
	FROM (
		SELECT DISTINCT p.ProductID, 
			p3.ProductID AS Product3rdID,
			m.BetType, 
			m.RefTable,
			m.EventType,
			gbt.GroupTypeId
		FROM CTE_Product p3 WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductPrefix = p3.ProductCode
			LEFT JOIN bodb02.dbo.Lrf_f_GroupProduct() lf ON p.Productid = lf.GroupProductId
			INNER JOIN bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) ON m.ProductID = ISNULL(lf.ProductID,p.ProductID)
			LEFT JOIN CTE_ProductFilter pm ON pm.Code = p3.ProductCode
			LEFT JOIN CTE_SportFilter sm ON sm.SportType = m.SportType
			LEFT JOIN CTE_BettypeFilter bm ON bm.bettype = m.BetType
			LEFT JOIN bodb02.dbo.Lrf_f_GroupBettype() gbt ON gbt.bettype = m.Bettype
		WHERE (@ProductCheck IS NULL OR pm.Code IS NOT NULL)
			AND (@SportCheck IS NULL OR sm.SportType > 0)
			AND (@BettypeCheck IS NULL OR bm.bettype > 0)
			AND p.ProductID NOT IN (11, 31, 37) -- NOT Support Saba Promotion, AG-Casino & Exchange
	) AS tbl
		LEFT JOIN bodb02.[dbo].[Lrf_f_SelExcludedBetType]() e ON e.BetType = tbl.BetType
		LEFT JOIN bodb02.dbo.Lrf_f_GroupProduct() lf ON tbl.Productid = lf.Productid AND lf.GroupProductId <> lf.ProductId
		OUTER APPLY 
		(
			SELECT f.Bettype
			FROM bodb02.dbo.f_BettypePrizeGroup() f
			WHERE f.BettypeGroup = 'Contribution'
				AND f.Bettype = tbl.bettype
		) AS cont
		WHERE e.BetType IS NULL
			AND cont.Bettype IS NULL
			AND  (lf.Productid IS NULL OR ISNULL(@ProductCheck, 'ALL') <> 'ALL') -- exclude product in group product
	;