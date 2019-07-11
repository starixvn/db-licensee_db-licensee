/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_GetCustomerBalance] 
	@LicenseeID		INT,
	@CurrencyIDList	VARCHAR(500)	= '',
	@ReportDate		SMALLDATETIME,
	@BaseCurrency	VARCHAR(3) = ''
AS

/*  
	Created: 20170120@Joseph 
	Task : Dashboard API - Get Current Customer Balance  
	DB: DBACC/bodb02
	Original: Lrf_Rpt_CustomerBalance  
  
	Revisions:  
		- 20170120@Joseph: Copy from Lrf_Rpt_PlatformWinloss [RedmineID: #70616]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]
		- 20170814@Alex  : Restrict permission by currency  [RedmineID: #80855]
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]
		- 20181120@Kathy: Tunning SP - got timeout error [RedmineId:#104824]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]

	Param's Explanation:  
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @tmpAg TABLE (
		custID		INT
		,Currency	INT
	)

	DECLARE @Currency TABLE (
		Currency	INT
	)
	
	DECLARE @Exchange TABLE (
		ExchangeID	INT
		,Rate		FLOAT
	)

	INSERT INTO @Currency(Currency)
	SELECT val
    FROM dbo.strSplit(@CurrencyIDList, ',')

	INSERT INTO @tmpAg (CustId,Currency)
	SELECT CustID,Currency 
	FROM bodb_licensee.dbo.f_SelLicenseeCust(@LicenseeID) a
	WHERE EXISTS (SELECT 1 FROM @Currency c WHERE a.Currency = c.Currency)

	INSERT INTO @Exchange(ExchangeID, Rate)
	SELECT ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@ReportDate, @ReportDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @Currency c WHERE e.ExchangeID = c.Currency)

	SELECT	SUM(b.ClosingBalance * e.Rate)	AS ClosingBalance
	FROM	@tmpAg a
			INNER JOIN @Exchange e ON a.Currency = e.ExchangeID
			CROSS APPLY (
				SELECT	TOP (1) SUM(b.ClosingBalance) AS ClosingBalance
				FROM	bodb_Report.dbo.rptDepWinlost b WITH (NOLOCK)
				WHERE	b.winlostdate = @ReportDate
						AND b.recommend = a.CustId 
						AND b.Currency = a.Currency
			) b

	SET NOCOUNT OFF
END

GO