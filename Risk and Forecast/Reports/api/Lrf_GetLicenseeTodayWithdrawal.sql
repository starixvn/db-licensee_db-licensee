/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_GetLicenseeTodayWithdrawal]
    @LicenseeID		INT,
    @CurrencyIDList VARCHAR(500)  = 0,
    @ReportDate		SMALLDATETIME,
    @BaseCurrency	VARCHAR(3) = ''
AS 

/*
	Created: 
	Task: 
	DB: DBACC.bodb02
	Original: Lrf_Rpt_TurnOver
	Revisions:
		- 20170208@Paul: Create new [RedmineID: #70616]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]
		- 20170814@Alex  : Restrict permission by currency  [RedmineID: #80855]
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
*/

BEGIN
	SET NOCOUNT ON;
   
	DECLARE @tmpAg   TABLE (custID INT, currency INT);
	DECLARE @fdate   SMALLDATETIME;
 
	SELECT	@fdate = @ReportDate;

	DECLARE @Currency TABLE (Currency INT);
	
	INSERT INTO @Currency(Currency)
	SELECT val
    FROM dbo.strSplit(@CurrencyIDList, ',')

	INSERT INTO @tmpAg (CustId, Currency)
	SELECT CustID,Currency FROM bodb_licensee.dbo.f_SelLicenseeCust(@LicenseeID) a
	WHERE EXISTS (SELECT 1 FROM @Currency c WHERE a.Currency = c.Currency)

	CREATE TABLE #tmpRpt
	(
		Currency			INT,
		Withdrawal			MONEY
	);
		
	INSERT INTO #tmpRpt
	(
		Currency, Withdrawal
	)
	SELECT b.currency,
		SUM(ISNULL(b.withdrawal,0))
	FROM bodb_report.dbo.rptdepwinlost b WITH(NOLOCK)
		INNER JOIN @tmpAg a ON b.recommend = a.CustId AND b.Currency = a.Currency	
	WHERE b.winlostdate = @fdate
	GROUP BY b.currency;

	CREATE TABLE #TempExchange(
		ExchangeID	INT,
		Rate		FLOAT
	)
	
	INSERT INTO #TempExchange(ExchangeID, Rate)
	SELECT ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@fdate, @fdate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @Currency c WHERE e.ExchangeID = c.Currency)

	SELECT  CAST(SUM(b.Withdrawal * e.Rate) AS MONEY) AS Withdrawal
	FROM #tmpRpt b
		INNER JOIN #TempExchange e ON e.exchangeid = b.currency

	DROP TABLE #TempExchange;
	DROP TABLE #tmpRpt;

	SET NOCOUNT OFF;
END

GO