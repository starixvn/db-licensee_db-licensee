/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_SelSportBySiteName]
(
	@SiteName VARCHAR(50)
)
AS 
/*  Created: 20220118@Sol
    Description: LAP - Return list sport from gamedetail table
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20220118@Sol: Initial sp - [RedmineID: #166056]

	Developer's Notes:
    Param's Explanation:  
*/
BEGIN
	
	DECLARE @ProductMapping TABLE(ProductId TINYINT, ProductId3rd INT)

	INSERT INTO @ProductMapping(ProductId, ProductId3rd)
	SELECT DISTINCT sp.ProductID, gd.ProductId
	FROM bodb_Ploutos.dbo.GameDetail gd WITH(NOLOCK)
		INNER JOIN bodb_Licensee.dbo.Product3rd p WITH(NOLOCK) on gd.ProductId = p.Productid
		INNER JOIN bodb02.dbo.Products sp WITH(NOLOCK) on sp.ProductPrefix = p.ProductPrefix
	UNION
	SELECT 1, 0 -- sportbook 

	IF (@SiteName = 'IvoryBet')
	BEGIN
		SET @SiteName = 'ivorysport'
	END

	SELECT g.GameCode, g.GameName
	FROM bodb_Ploutos.dbo.BrandProduct b
		INNER JOIN @ProductMapping pm
			ON b.ProductId = pm.ProductId
		INNER JOIN bodb_Ploutos.dbo.GameDetail g
			ON g.ProductId = pm.ProductId3rd
	WHERE b.BrandCode = @SiteName
	ORDER BY g.ProductId, g.GameCode

END