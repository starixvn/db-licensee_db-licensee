USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Lrf_GetLicenseeTodayWithdrawal]    Script Date: 2/8/2017 1:27:42 PM ******/
DROP PROCEDURE [dbo].[Lrf_GetLicenseeTodayWithdrawal]
GO

/****** Object:  StoredProcedure [dbo].[Lrf_GetLicenseeTodayWithdrawal]    Script Date: 2/8/2017 1:27:42 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Lrf_GetLicenseeTodayWithdrawal]
    @LicenseeID		INT,
    @CurrencyID		INT = 0,
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
*/

BEGIN
	SET NOCOUNT ON;
   
	DECLARE @tmpAg   TABLE (custID INT, currency INT);
	DECLARE @fdate   SMALLDATETIME;
 
	SELECT	@fdate = @ReportDate;

	DECLARE @Temp TABLE (CustId INT, Currency INT);
	DECLARE @sql1 VARCHAR(MAX);

	SELECT  @sql1 = 'SELECT CustID, Currency
					FROM OPENQUERY(DBLIC, ''SELECT LicenseeId,CustID,Currency,Description FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')';

	INSERT INTO @Temp (CustId, Currency)
	EXEC (@sql1);
	
	INSERT INTO @tmpAg(custID, currency)
	SELECT CustID, currency 
	FROM @Temp lc
	WHERE Currency <> 20
		AND (@CurrencyID = 0 OR (@CurrencyID <> 0 AND Currency = @CurrencyID));

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

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@fdate, @fdate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpRpt);

	SELECT  SUM(b.Withdrawal) AS Withdrawal,
			--- EUR
			CAST(SUM(b.Withdrawal * e.EUR) AS MONEY) AS WithdrawalEUR,
			--- USD
			CAST(SUM(b.Withdrawal * e.USD) AS MONEY) AS WithdrawalUSD,
			--- GBP
			CAST(SUM(b.Withdrawal * e.GBP) AS MONEY) AS WithdrawalGBP,
			--- CNY
			CAST(SUM(b.Withdrawal * e.CNY) AS MONEY) AS WithdrawalCNY,
			--- MYR
			CAST(SUM(b.Withdrawal * e.MYR) AS MONEY) AS WithdrawalMYR,
			--- THB
			CAST(SUM(b.Withdrawal * e.THB) AS MONEY) AS WithdrawalTHB,
			--- IDR
			CAST(SUM(b.Withdrawal * e.IDR) AS MONEY) AS WithdrawalIDR
	FROM #tmpRpt b
		INNER JOIN #TempExchange e ON e.exchangeid = b.currency
	WHERE e.ExchangeDate = @fdate;

	DROP TABLE #TempExchange;
	DROP TABLE #tmpRpt;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Lrf_GetLicenseeTodayWithdrawal] TO [bodbLicenseeNet] AS [dbo]
GO

GRANT ALTER ON [dbo].[Lrf_GetLicenseeTodayWithdrawal] TO [vnteam] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Lrf_GetLicenseeTodayWithdrawal] TO [vnteam] AS [dbo]
GO


