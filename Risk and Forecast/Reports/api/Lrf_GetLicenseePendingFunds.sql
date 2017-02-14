USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_GetLicenseePendingFunds]
    @LicenseeID		INT,
    @CurrencyID		INT = 0
AS 

/*
	Created: 20170119@Joseph
	Task : Dashboard API - Pending funds
	DB: DBACC.bodb02

	Revisions:
		- 20170119@Joseph: Copy from Lrf_Rpt_TurnOver [RedmineID: #70616]
	Param's Explanation:
	
*/

BEGIN
    SET NOCOUNT ON;
   
	DECLARE @tmpAg   TABLE (custID INT, currency INT);

	DECLARE @Temp TABLE (CustId INT, Currency INT);
	DECLARE @sql1 VARCHAR(500);

	SELECT  @sql1 = 'SELECT CustID, Currency
					FROM OPENQUERY(DBLIC, ''SELECT LicenseeId,CustID,Currency,Description  FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')';

	INSERT INTO @Temp (CustId, Currency)
	EXEC (@sql1);
	
	INSERT INTO @tmpAg(CustId, Currency)
	SELECT CustID, currency 
	FROM @Temp lc
	WHERE Currency <> 20
		AND (@CurrencyID = 0 OR (@CurrencyID <> 0 AND Currency = @CurrencyID));

	CREATE TABLE #tmpRpt
	(
		Winlostdate			SMALLDATETIME,
		Currency			INT,  
		PendingFund			MONEY
	);

	INSERT INTO #tmpRpt
	(
		Winlostdate, Currency, PendingFund
	)
	SELECT  p.winlostdate,
			c.currency,
			SUM(ISNULL(p.outstanding,0)) AS PendingFund
	FROM bodb_Report.dbo.rptdepwinlostbyproduct_SUM p WITH(NOLOCK)    
		INNER JOIN @tmpAg c ON p.custid = c.custid AND p.Currency = c.Currency
	GROUP BY p.winlostdate, c.currency;
			   
	INSERT INTO #tmpRpt
	(
		Winlostdate, Currency, PendingFund
	)
	SELECT  p.winlostdate,
			c.currency,
			SUM(ISNULL(p.outstanding,0)) AS PendingFund
	FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)    
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
		INNER JOIN @tmpAg a ON p.Currency = a.Currency AND a.CustID = c.Recommend
	WHERE c.roleid = 1                  
	GROUP BY p.winlostdate, c.currency;
    
	DECLARE @FromDate SMALLDATETIME,
			@ToDate SMALLDATETIME;

	SELECT	@FromDate = MIN(Winlostdate),
			@ToDate = MAX(Winlostdate)
	FROM #tmpRpt;

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpRpt);

	SELECT  SUM(b.PendingFund) AS PendingFund,
			--- EUR
			CAST(SUM(b.PendingFund * e.EUR) AS MONEY) AS PendingFundEUR,
			--- USD
			CAST(SUM(b.PendingFund * e.USD) AS MONEY) AS PendingFundUSD,
			--- GBP
			CAST(SUM(b.PendingFund * e.GBP) AS MONEY) AS PendingFundGBP,
			--- CNY
			CAST(SUM(b.PendingFund * e.CNY) AS MONEY) AS PendingFundCNY,
			--- MYR
			CAST(SUM(b.PendingFund * e.MYR) AS MONEY) AS PendingFundMYR
	FROM #tmpRpt b
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency;

	DROP TABLE #TempExchange;
	DROP TABLE #tmpRpt;
END
GO

GRANT EXECUTE ON [dbo].[Lrf_GetLicenseePendingFunds] TO [bodbLicenseeNet] 
GO
GRANT ALTER ON [dbo].[Lrf_GetLicenseePendingFunds] TO [vnteam] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetLicenseePendingFunds] TO [vnteam]
GO 