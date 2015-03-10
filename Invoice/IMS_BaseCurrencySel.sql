USE [bodb02]
GO
CREATE PROCEDURE [dbo].[IMS_BaseCurrencySel]
AS
/*  
	Created: Kevin
	Date: 20130418
	Task : Report - Licensee Settlement Report
	DB: DB052.bodb02
	Revisions: 
		20150202@Patrick: Add more GBP currency

	Param's Explanation: 
*/  
BEGIN
	SET NOCOUNT ON
	SELECT e.exchangeid AS currency
		, e.Code AS currencyname
	FROM dbo.Exchange e	WITH(NOLOCK)
	WHERE exchangeid IN(3, 6, 13, 12)
	ORDER BY 
		CASE WHEN exchangeid = 6 THEN 1
			WHEN exchangeid = 3 THEN 2
			WHEN exchangeid = 13 THEN 3
			WHEN exchangeid = 12 THEN 4
		END
END

GO

GRANT EXECUTE ON [dbo].[IMS_BaseCurrencySel] TO [bodbAdminNet] AS [dbo]
GO


