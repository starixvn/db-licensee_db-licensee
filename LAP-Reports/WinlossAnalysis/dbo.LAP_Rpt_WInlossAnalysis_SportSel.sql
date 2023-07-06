/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.LAP_Rpt_WinlossAnalysis_SportSel
	@LicenseeID		INT = NULL,
	@ProductCodes	VARCHAR(MAX) = 'ALL'
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - Get filtering sporttype
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]
		
*/
BEGIN
	WITH CTE_Code AS (
		SELECT t.Code 
		FROM (
			SELECT ProductCodes =  CONCAT(@ProductCodes, IIF(((',' + @ProductCodes + ',' LIKE '%,SB,%') OR (',' + @ProductCodes + ',' LIKE '%,BA,%')), ',SLT,BTC',''))
		) AS c
		CROSS APPLY (
			SELECT DISTINCT value AS Code
			FROM STRING_SPLIT(c.ProductCodes, ',') AS t
		) AS t
	),
	CTE_SportbookBA AS (
			SELECT DISTINCT 0 AS ProductID, p.ProductName, 
				s.SportType, s.SportName, CONCAT(p.ProductPrefix,',BA') AS ProductCode, s.SportType AS SportOrder
			FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = m.ProductID
			INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON S.SportType = m.SportType
			WHERE p.ProductID = 1
			UNION ALL
			SELECT 0 AS ProductID, ProductName, SabaSportType AS SportType, SportName, CONCAT(ProductCode,',BA') AS ProductCode, SportOrder
			FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] ()
			WHERE IsShowUI = 1
	),
	CTE_Product3rd AS (
		----------- default SB Product
		SELECT 0 AS ProductID, ProductName, SportType, SportName, ProductCode, SportOrder
		FROM CTE_SportbookBA sb
		--------------3rd Products
		UNION ALL
		SELECT p3.ProductID, 
			p3.ProductName, 
			s.SportType, s.SportName, ISNULL(p3.ProductPrefix, p.ProductPrefix) AS ProductCode, s.SportType AS SportOrder
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		LEFT JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductPrefix = p3.ProductPrefix 
		LEFT JOIN bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) ON m.ProductID = p.ProductID
		LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON S.SportType = m.SportType
		WHERE p3.Enabled = 1
			AND (@LicenseeID IS NULL OR lp.LicenseeID = @LicenseeID)
	),
	result AS (
		SELECT DISTINCT
			CASE WHEN ProductID IN (0,63,69) THEN 0 ELSE ProductID END AS ProductID,
			CASE WHEN ProductID IN (0,63,69) THEN 'Sportsbook' ELSE ProductName END AS ProductName,
			CASE 
				WHEN ProductID IN (0, 63,69) AND sbba.SBBACheck & 6 = 6 THEN 'SB,BA' 
				WHEN ProductID IN (0, 63,69) AND sbba.SBBACheck & 2 = 2 THEN 'SB' 
				WHEN ProductID IN (0, 63,69) AND sbba.SBBACheck & 4 = 4 THEN 'BA' 
				ELSE ProductCode END AS ProductCode,
			SportType, SportName, SportOrder
		FROM CTE_Product3rd AS p
		OUTER APPLY (
			SELECT TOP 1 1 AS HasValue 
			FROM CTE_Code AS t
			CROSS APPLY (SELECT value FROM STRING_SPLIT(p.ProductCode, ',') AS t2 WHERE t2.value = t.Code ) AS t2
		) AS ck
		OUTER APPLY (
			SELECT 
				( 
					POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 1) 
					+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 2)
				) AS SBBACheck
		) AS sbba 
		WHERE p.SportType NOT IN (150, 173, 27) --exclude free games & hide Cricket(27)
			AND (ISNULL(@ProductCodes, 'ALL') = 'ALL' OR ck.HasValue = 1 )
	)
	SELECT ProductID, ProductName, ProductCode, SportType, SportName 
	FROM result
	ORDER BY ProductID
		, SportOrder
END
GO