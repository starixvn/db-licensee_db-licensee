/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.LAP_f_SettlementTime_ProductSel ()
RETURNS TABLE
AS
/*
	Created: 20240915@Bobby
	Task: 209631 - LAP - Winloss Analysis - SettleTime
	DB: DBACC/bodb02

	Revisions:
		- 20240915@Bobby: Created [RedmineID: #209631]
		- 20250311@Kelvin: Integrate Virtual Sports 7 - Kiron [RedmineID: #219083]
*/

RETURN
	WITH CTE_ProductGroup AS (
		SELECT DISTINCT ProductPrefix, GroupProductPrefix
		FROM (
			SELECT 'VS', 'VS'
			UNION ALL
			SELECT 'VS2', 'VS'
			UNION ALL
			SELECT 'LG', 'VS'
			UNION ALL
			SELECT 'VS4', 'VS'
			UNION ALL
			SELECT 'VS5', 'VS'
			UNION ALL
			SELECT 'VS6', 'VS'
			UNION ALL
			SELECT 'VS7', 'VS'
			UNION ALL
			SELECT 'SB', 'SB'
			UNION ALL
			SELECT 'SLT', 'SB'
			UNION ALL
			SELECT 'BTC', 'SB'
			UNION ALL
			SELECT 'NG', 'NG'
			
		) AS t (ProductPrefix, GroupProductPrefix)
	), CTE_ProductList AS (
		SELECT p.ProductId, p.ProductPrefix, gp.ProductID AS GroupProductId, cte.GroupProductPrefix
		FROM dbo.Products p WITH(NOLOCK)
			INNER JOIN CTE_ProductGroup cte ON cte.ProductPrefix = p.ProductPrefix
			INNER JOIN dbo.Products gp WITH(NOLOCK) ON gp.ProductPrefix = cte.GroupProductPrefix
	)
	SELECT ProductId, ProductPrefix, GroupProductId, GroupProductPrefix 
	FROM (VALUES('SB'),('VS'),('NG')) AS p (ProductCode) -->supported product
	INNER JOIN CTE_ProductList cte ON cte.GroupProductPrefix = p.ProductCode