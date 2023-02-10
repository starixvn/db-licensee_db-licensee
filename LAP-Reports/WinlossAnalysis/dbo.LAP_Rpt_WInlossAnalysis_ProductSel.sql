/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE OR ALTER PROCEDURE dbo.LAP_Rpt_WInlossAnalysis_ProductSel
	@LicenseeID		INT = 1
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - GEN Bettrans
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		
*/
BEGIN
	SET NOCOUNT ON;

	WITH CTE_ExcludePayout AS (
		SELECT e.product3rdId
		FROM (
			SELECT VALUE 
			FROM STRING_SPLIT('32,37,39,42,45,34,66,36,21,74,56', ',') AS t
		) AS e (product3rdId)
	)
	SELECT p.product3rdId, p.ProductName, p.ProductCode
	FROM (
		SELECT 0 AS product3rdId, p.ProductName, p.ProductPrefix AS ProductCode
		FROM bodb02.dbo.Products p WITH(NOLOCK) 
		WHERE p.ProductID = 1
		UNION ALL
		SELECT DISTINCT p3.ProductID AS product3rdId, p3.ProductName, p3.ProductPrefix AS ProductCode
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		WHERE p3.Enabled = 1
			AND (@LicenseeID IS NULL OR lp.LicenseeID = @LicenseeID)
	) AS p
	LEFT JOIN CTE_ExcludePayout e ON e.product3rdId = p.product3rdId
	WHERE e.product3rdId IS NULL
	ORDER BY p.product3rdId ASC
END