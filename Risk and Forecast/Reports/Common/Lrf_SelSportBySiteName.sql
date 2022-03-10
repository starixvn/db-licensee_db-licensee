/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_SelSportBySiteName]
(
	@SiteName VARCHAR(50),
	@ProductCodes VARCHAR(100) = NULL
)
AS 
/*  Created: 20220118@Sol
    Description: LAP - Return list sport from gamedetail table
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20220118@Sol: Initial sp - [RedmineID: #166056]

	Developer's Notes:
    Param's Explanation:  
		- @ProductCodes = N'SB,NG',
*/
BEGIN
	
	DECLARE @Product TABLE (ProductCode VARCHAR(10), OriProductCode VARCHAR(10))

	INSERT INTO @Product (ProductCode, OriProductCode)
	SELECT CASE 
				WHEN ISNULL(Val,'') = 'SB' THEN 'SB'
				WHEN ISNULL(Val,'') = 'NG' THEN 'RNG'
				WHEN ISNULL(Val,'') = 'CS' THEN 'RNG'
				WHEN ISNULL(Val,'') = 'LC' THEN 'CA'
			END AS ProductCode,
			CASE 
				WHEN ISNULL(Val,'') = 'SB' THEN NULL
				WHEN ISNULL(Val,'') = 'NG' THEN 'NG'
				WHEN ISNULL(Val,'') = 'CS' THEN 'CS'
				WHEN ISNULL(Val,'') = 'LC' THEN NULL
			END AS GameCode
	FROM dbo.strSplit(@ProductCodes,',')

	DECLARE @ProductMapping TABLE(ProductId TINYINT, ProductId3rd INT)

	INSERT INTO @ProductMapping(ProductId, ProductId3rd)
	SELECT DISTINCT sp.ProductID, gd.ProductId
	FROM bodb_Ploutos.dbo.GameDetail gd WITH(NOLOCK)
		INNER JOIN bodb_Licensee.dbo.Product3rd p WITH(NOLOCK) on gd.ProductId = p.Productid
		INNER JOIN bodb02.dbo.Products sp WITH(NOLOCK) on sp.ProductPrefix = p.ProductPrefix
	UNION
	SELECT 1, 0 -- sportbook 

	SELECT @SiteName = dbo.Lrf_f_MappingAuditSite(@SiteName)

	---filter by site and product
	IF EXISTS (SELECT TOP 1 1 FROM @Product)
	BEGIN
		SELECT g.GameCode, g.GameName
		FROM bodb_Ploutos.dbo.BrandProduct b
			INNER JOIN @ProductMapping pm
				ON b.ProductId = pm.ProductId
			INNER JOIN bodb_Ploutos.dbo.GameDetail g
				ON g.ProductId = pm.ProductId3rd
			INNER JOIN @Product p
				ON g.GameType = p.ProductCode
		WHERE b.BrandCode = @SiteName
			AND 1 = CASE 
						WHEN p.OriProductCode IS NULL THEN 1
						WHEN p.OriProductCode = 'NG' AND g.GameCode = '0161' THEN 1
						WHEN p.OriProductCode = 'CS' AND g.GameCode <> '0161' THEN 1
						ELSE 0
					END
		ORDER BY g.ProductId, g.GameCode
	END
	ELSE --filter by site only
	BEGIN
		SELECT g.GameCode, g.GameName
		FROM bodb_Ploutos.dbo.BrandProduct b
			INNER JOIN @ProductMapping pm
				ON b.ProductId = pm.ProductId
			INNER JOIN bodb_Ploutos.dbo.GameDetail g
				ON g.ProductId = pm.ProductId3rd
		WHERE b.BrandCode = @SiteName
		ORDER BY g.ProductId, g.GameCode
	END

END