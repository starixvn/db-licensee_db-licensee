CREATE OR ALTER PROCEDURE LAP_Rpt_LicenseeAnalysis_SportTreeSel
	@LicenseeID		INT = NULL,
	@ProductIds		VARCHAR(MAX) = 'ALL'
AS
BEGIN
	WITH cteProduct AS (
		----------- default SB Product
		SELECT DISTINCT p.ProductID, p.ProductName, 
			s.SportType, s.SportName, p.ProductPrefix AS ProductCode, s.SportType AS SportOrder
		FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = m.ProductID
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON S.SportType = m.SportType
		WHERE p.ProductID = 1
		UNION ALL
		SELECT ProductID, ProductName, SportType, SportName, ProductCode, SportOrder
		FROM [dbo].[LAP_f_LicenseeAnalysis_SabaSportSel] ()
		--------------3rd Products
		UNION ALL
		SELECT DISTINCT p.ProductID, p.ProductName, 
			s.SportType, s.SportName, ISNULL(p3.ProductPrefix, p.ProductPrefix) AS ProductCode, s.SportType AS SportOrder
		FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = m.ProductID
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON S.SportType = m.SportType
		INNER JOIN bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK) ON p3.ProductPrefix = p.ProductPrefix 
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p.ProductID = lp.ProductID
		WHERE @LicenseeID IS NULL 
			OR lp.LicenseeID = @LicenseeID
	)
	SELECT ProductID, SportType, ProductName, SportName, ProductCode
	FROM cteProduct AS p
	WHERE ISNULL(@ProductIds, 'ALL') = 'ALL' 
		OR ',' + @ProductIDs + ',' LIKE '%,' + CAST(p.ProductID AS VARCHAR(3)) + ',%'
	ORDER BY p.ProductID
		, SportOrder
END