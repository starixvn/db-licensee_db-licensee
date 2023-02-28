/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE OR ALTER PROCEDURE dbo.LAP_Rpt_WinlossAnalysis_BettypeSel
	@LicenseeID INT = 1,
	@SportIDs	VARCHAR(MAX) = 'ALL'
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - Get filtering bettype
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		
*/
BEGIN
	WITH CTE_Sportbook AS (
			SELECT DISTINCT m.SportType
			FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
			WHERE m.ProductID = 1
			UNION ALL
			SELECT SabaSportType AS SportType
			FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] ()
	),
	CTE_Product3rd AS (
		----------- default SB Product
		SELECT SportType
		FROM CTE_Sportbook sb
		--------------3rd Products
		UNION ALL
		SELECT m.SportType
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		LEFT JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductPrefix = p3.ProductPrefix 
		LEFT JOIN bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) ON m.ProductID = p.ProductID
		WHERE p3.Enabled = 1
			AND (@LicenseeID IS NULL OR lp.LicenseeID = @LicenseeID)
	),
	CTE_SportID AS (
		SELECT DISTINCT CAST(value AS INT) AS SportID
		FROM STRING_SPLIT(@SportIDs, ',') AS t
		WHERE @SportIDs <> 'ALL'
	),
	CTE_SabaSport AS (
		SELECT DISTINCT saba.SabaSportType, t.SportType
		FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
		OUTER APPLY
		(
			SELECT LeagueGroupID, Sporttype
			FROM OPENJSON(saba.SporttypeRef)
			WITH (Sporttype INT '$.Sporttype',
				LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
			)
			OUTER APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID INT '$')
		) AS t
	),
	result AS (
		SELECT DISTINCT	ISNULL(saba.SportType, p.SportType) AS SportType, 
			ISNULL(saba.SabaSportType,0) AS SabaSportType
		FROM CTE_Product3rd AS p
		OUTER APPLY (
			SELECT TOP 1 1 AS HasValue 
			FROM CTE_SportID AS t
			WHERE t.SportID = p.SportType
		) AS ck
		LEFT JOIN CTE_SabaSport AS saba ON saba.SabaSportType = p.SportType
		WHERE p.SportType NOT IN (150, 173) --exclude free games
			AND (ISNULL(@SportIDs, 'ALL') = 'ALL' OR ck.HasValue = 1 )
	)
	SELECT DISTINCT rs.SportType, m.Bettype
	FROM result rs
		INNER JOIN bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) ON m.SportType = rs.SportType
		LEFT JOIN bodb02.[dbo].[Lrf_f_SelExcludedBetType]() e ON e.BetType = m.BetType
	WHERE e.BetType IS NULL
		AND 1 = CASE 
					WHEN rs.SabaSportType <> -1 THEN 1
					WHEN rs.SabaSportType = -1 AND m.BetType = 29 THEN 1 
					ELSE 0 
				END
	ORDER BY rs.SportType, m.Bettype
END
