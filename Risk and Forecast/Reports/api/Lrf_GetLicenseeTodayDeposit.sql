/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_GetLicenseeTodayDeposit]
    @LicenseeID		INT,
    @CurrencyIDList VARCHAR(500)  = 0,
    @ReportDate		SMALLDATETIME
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
*/

BEGIN
	SET NOCOUNT ON;
   
	DECLARE @tmpAg   TABLE (custID INT, currency INT);
	DECLARE @fdate   SMALLDATETIME;
 
	SELECT	@fdate = @ReportDate;

	DECLARE @Temp TABLE (CustId INT, Currency INT);

	INSERT INTO @Temp (CustId, Currency)
	SELECT CustID,Currency FROM bodb_licensee.dbo.f_SelLicenseeCust(@LicenseeID)
	
	INSERT INTO @tmpAg(custID, currency)
	SELECT CustID, currency 
	FROM @Temp lc
	WHERE Currency IN
                (
                    SELECT val
                    FROM dbo.strSplit(@CurrencyIDList, ',')
                );

	CREATE TABLE #tmpRpt
	(
		Currency			INT,
		Deposit				MONEY
	);
		
	INSERT INTO #tmpRpt
	(
		Currency, Deposit
	)
	SELECT b.currency,
		SUM(ISNULL(b.deposit,0))
	FROM bodb_report.dbo.rptdepwinlost b WITH(NOLOCK)
		INNER JOIN @tmpAg a ON b.recommend = a.CustId AND b.Currency = a.Currency	
	WHERE b.winlostdate = @fdate
	GROUP BY b.currency;

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@fdate, @fdate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpRpt);

	SELECT  SUM(b.Deposit) AS Deposit,
			--- EUR
			CAST(SUM(b.Deposit * e.EUR) AS MONEY) AS DepositEUR,
			--- USD
			CAST(SUM(b.Deposit * e.USD) AS MONEY) AS DepositUSD,
			--- GBP
			CAST(SUM(b.Deposit * e.GBP) AS MONEY) AS DepositGBP,
			--- CNY
			CAST(SUM(b.Deposit * e.CNY) AS MONEY) AS DepositCNY,
			--- MYR
			CAST(SUM(b.Deposit * e.MYR) AS MONEY) AS DepositMYR,
			--- THB
			CAST(SUM(b.Deposit * e.THB) AS MONEY) AS DepositTHB,
			--- IDR
			CAST(SUM(b.Deposit * e.IDR) AS MONEY) AS DepositIDR
	FROM #tmpRpt b
		INNER JOIN #TempExchange e ON e.exchangeid = b.currency
	WHERE e.ExchangeDate = @fdate;

	DROP TABLE #TempExchange;
	DROP TABLE #tmpRpt;

	SET NOCOUNT OFF;
END

GO
