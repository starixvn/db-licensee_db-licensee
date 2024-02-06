/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.LAP_Rpt_WinlossAnalysis_BettypeSel
	@LicenseeID		INT = 1,
	@ProductCodes	VARCHAR(MAX) = 'ALL'
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - Get filtering bettype
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		- 20231214@Evan: Hide Upcoming bettype [RedmineID: #197020]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]

		
*/
BEGIN
	WITH CTE_Filter AS (
		SELECT t.Code 
		FROM (
			SELECT ProductCodes =  CONCAT(@ProductCodes, IIF(((',' + @ProductCodes + ',' LIKE '%,SB,%') OR (',' + @ProductCodes + ',' LIKE '%,BA,%')), ',SLT,BTC',''))
		) AS c
		CROSS APPLY (
			SELECT DISTINCT value AS Code
			FROM STRING_SPLIT(c.ProductCodes, ',') AS t
		) AS t
	),
	CTE_Product3rd AS (
		----------- default SB Product
		SELECT ProductID, CONCAT(ProductPrefix,',BA') AS ProductCode
		FROM dbo.Products sb
		WHERE ProductID=1
		--------------3rd Products
		UNION ALL
		SELECT p.ProductID, p3.ProductPrefix
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		LEFT JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductPrefix = p3.ProductPrefix 
		WHERE p3.Enabled = 1
			AND (@LicenseeID IS NULL OR lp.LicenseeID = @LicenseeID)
	),
	CTE_GroupBettype AS (
		SELECT Bettype, GroupTypeID FROM bodb02.dbo.Lrf_f_GroupBettype()
		--UNION ALL 
		--SELECT Bettype, GroupTypeID FROM bodb02.dbo.f_GroupBettype3rd()
	),
	result AS (
		SELECT DISTINCT	p.ProductID
			,ISNULL(gbt.GroupTypeId, m.BetType) AS BetType,
			CASE 
				WHEN p.ProductID IN (1, 63,69) AND saba.SBBACheck & 6 = 6 THEN 'SB,BA' 
				WHEN p.ProductID IN (1, 63,69) AND saba.SBBACheck & 2 = 2 THEN 'SB' 
				WHEN p.ProductID IN (1, 63,69) AND saba.SBBACheck & 4 = 4 THEN 'BA' 
				ELSE p.ProductCode 
			END AS ProductCode
		FROM CTE_Product3rd AS p
		LEFT JOIN bodb02.dbo.Lrf_f_GroupProduct() lf ON p.ProductID = lf.GroupProductId
		OUTER APPLY (
			SELECT TOP 1 1 AS HasValue 
			FROM CTE_Filter AS t
			CROSS APPLY (SELECT value FROM STRING_SPLIT(p.ProductCode, ',') AS t2 WHERE t2.value = t.Code ) AS t2
		) AS ck
		INNER JOIN dbo.SportBettypeMatrix m ON m.ProductID = ISNULL(lf.ProductID,p.ProductID)
		LEFT JOIN CTE_GroupBettype gbt ON gbt.bettype = m.bettype
		LEFT JOIN bodb02.[dbo].[Lrf_f_SelExcludedBetType]() e ON e.BetType = m.BetType
		OUTER APPLY (
			SELECT 
				( 
					POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 1) 
					+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 2)
				) AS SBBACheck
		) AS saba 
		WHERE m.[Enabled] = 1
			AND m.SportType NOT IN (150, 173) --exclude free games
			AND (ISNULL(@ProductCodes, 'ALL') = 'ALL' OR ck.HasValue = 1 )
			AND e.BetType IS NULL
			AND m.Bettype NOT IN (9, 18999) -- exclude Mix Parlay
	)
	SELECT rs.ProductCode, rs.BetType
	FROM result rs
		INNER JOIN bettype b WITH (NOLOCK) ON rs.BetType = b.typeid
		LEFT JOIN bodb02.dbo.Lrf_f_GroupProduct() lf ON rs.ProductID = lf.ProductId AND lf.GroupProductId <> lf.ProductId
	WHERE b.typenamee NOT LIKE '%Upcoming%' AND (lf.ProductId IS NULL OR ISNULL(@ProductCodes, 'ALL') <> 'ALL') -- exclude product in group product
	ORDER BY rs.ProductID, rs.BetType
END
GO
