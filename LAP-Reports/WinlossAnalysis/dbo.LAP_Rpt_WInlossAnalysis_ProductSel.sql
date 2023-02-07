USE bodb02;
GO
CREATE OR ALTER PROCEDURE dbo.LAP_Rpt_WInlossAnalysis_ProductSel
	@LicenseeID		INT = 1
AS
BEGIN
	SET NOCOUNT ON;

	SELECT ProducID, ProductName, ProductCode
	FROM (
		SELECT 0 AS ProducID, p.ProductName, p.ProductPrefix AS ProductCode
		FROM bodb02.dbo.Products p WITH(NOLOCK) 
		WHERE p.ProductID = 1
		UNION ALL
		SELECT DISTINCT p3.ProductID, p3.ProductName, p3.ProductPrefix AS ProductCode
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		WHERE p3.Enabled = 1
			AND (@LicenseeID IS NULL OR lp.LicenseeID = @LicenseeID)
	) AS p
	ORDER BY p.ProducID ASC
END