USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_GetLicenseePendingFunds]
	@AgentList	VARCHAR(MAX)
AS 

/*
	Created: 20170119@Joseph
	Task : Dashboard API - Pending funds
	DB: DBACC.bodb02

	Revisions:
		- 20170119@Joseph: Copy from Lrf_Rpt_TurnOver [RedmineID: #70616]
		- 20170323@Paul: Implement Cash Out [RedmineID: #71727]
	Param's Explanation:
	
*/

BEGIN
    SET NOCOUNT ON;
   
	CREATE TABLE #tmpAg (custID INT, currency INT);

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #tmpAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data
		WHERE Currency <> 20

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #tmpRpt
	(
		Winlostdate   SMALLDATETIME,
		Currency   INT,  
		PendingFund   MONEY
	);

	INSERT INTO #tmpRpt
	(
		Winlostdate, Currency, PendingFund
	)
	SELECT  p.winlostdate,
			a.currency,
			SUM(ISNULL(p.outstanding,0)) AS PendingFund
	FROM bodb_Report.dbo.rptdepwinlostbyproduct_SUM p WITH(NOLOCK)  
		INNER JOIN #tmpAg a ON a.CustID = p.custid
	WHERE sporttype NOT IN (-6, -7, -8, -9)
	GROUP BY p.winlostdate, a.currency
	HAVING SUM(ISNULL(p.outstanding,0)) > 0;
 
	INSERT INTO #tmpRpt
	(
		Winlostdate, Currency, PendingFund
	)
	SELECT  p.winlostdate,
		a.currency,
		SUM(ISNULL(p.outstanding,0)) AS PendingFund
	FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)    
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
		INNER JOIN #tmpAg a ON a.CustID = c.Recommend
	WHERE c.roleid = 1      
		AND sporttype NOT IN (-6, -7, -8, -9)            
	GROUP BY p.winlostdate, a.currency
	HAVING SUM(ISNULL(p.outstanding,0)) > 0;

	CREATE TABLE #WinLossDate(
		WinLossDate SMALLDATETIME
	);

	INSERT INTO #WinLossDate(WinLossDate)
	SELECT DISTINCT winlostdate
	FROM #tmpRpt;

	CREATE TABLE #TempExchange(
		ExchangeDate SMALLDATETIME,
		exchangeid INT,
		EUR FLOAT,
		USD FLOAT,
		GBP FLOAT,
		CNY FLOAT,
		MYR FLOAT
	);

	INSERT INTO #TempExchange(ExchangeDate, exchangeid, EUR, USD,GBP, CNY, MYR)
	SELECT ExchangeDate, exchangeid, EUR, USD,GBP, CNY, MYR
	FROM #WinLossDate w
		CROSS APPLY Lrf_f_GetExchangeDaily(w.WinLossDate, w.WinLossDate) e
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
	DROP TABLE #tmpAg;
	DROP TABLE #WinLossDate;
END
GO

GRANT EXECUTE ON [dbo].[Lrf_GetLicenseePendingFunds] TO [bodbLicenseeNet] 
GO
GRANT ALTER ON [dbo].[Lrf_GetLicenseePendingFunds] TO [vnteam] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetLicenseePendingFunds] TO [vnteam]
GO 