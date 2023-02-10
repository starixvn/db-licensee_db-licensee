/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE OR ALTER PROCEDURE dbo.LAP_Rpt_WInlossAnalysis_SportSel
	@LicenseeID		INT = NULL,
	@ProductCodes	VARCHAR(MAX) = 'ALL'
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - GEN Bettrans
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		
*/
BEGIN
	WITH CTE_SportbookBA AS (
			SELECT DISTINCT 0 AS ProductID, p.ProductName, 
				s.SportType, s.SportName, p.ProductPrefix AS ProductCode, s.SportType AS SportOrder
			FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = m.ProductID
			INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON S.SportType = m.SportType
			WHERE p.ProductID = 1
			UNION ALL
			SELECT 0 AS ProductID, ProductName, SportType, SportName, ProductCode, SportOrder
			FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] ()
	),
	CTE_Product3rd AS (
		----------- default SB Product
		SELECT 0 AS ProductID, ProductName, SportType, SportName
			, CASE 
				WHEN ck.SBBACheck & 6 = 6 THEN 'SB,BA' 
				WHEN ck.SBBACheck & 2 = 2 THEN 'SB' 
				WHEN ck.SBBACheck & 4 = 4 THEN 'BA' 
				ELSE sb.ProductCode END AS ProductCode
			, SportOrder
		FROM CTE_SportbookBA sb
		OUTER APPLY (
			SELECT 
				( 
					POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 1) 
					+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 2)
				) AS SBBACheck

		) AS ck 
		WHERE ck.SBBACheck > 0
		--------------3rd Products
		UNION ALL
		SELECT DISTINCT p3.ProductID, p3.ProductName, 
			s.SportType, s.SportName, ISNULL(p3.ProductPrefix, p.ProductPrefix) AS ProductCode, s.SportType AS SportOrder
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		LEFT JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductPrefix = p3.ProductPrefix 
		LEFT JOIN bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) ON m.ProductID = p.ProductID
		LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON S.SportType = m.SportType
		
		WHERE p3.Enabled = 1
			AND (@LicenseeID IS NULL OR lp.LicenseeID = @LicenseeID)
	),
	CTE_Code AS (
		SELECT DISTINCT value AS Code
		FROM STRING_SPLIT(@ProductCodes, ',') AS t
	)
	SELECT ProductID, SportType, ProductName, SportName, ProductCode
	FROM CTE_Product3rd AS p
	OUTER APPLY (
		SELECT TOP 1 1 AS HasValue 
		FROM CTE_Code AS t
		CROSS APPLY (SELECT value FROM STRING_SPLIT(p.ProductCode, ',') AS t2 WHERE t2.value = t.Code ) AS t2
	) AS ck
	WHERE p.SportType IS NOT NULL
		AND (ISNULL(@ProductCodes, 'ALL') = 'ALL' OR ck.HasValue = 1 )
	ORDER BY p.ProductID
		, SportOrder
END