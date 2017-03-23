USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Lrf_GetLicenseeTodayDeposit]    Script Date: 2/8/2017 1:27:16 PM ******/
DROP PROCEDURE [dbo].[Lrf_GetLicenseeTodayDeposit]
GO

/****** Object:  StoredProcedure [dbo].[Lrf_GetLicenseeTodayDeposit]    Script Date: 2/8/2017 1:27:16 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Lrf_GetLicenseeTodayDeposit]
	@ReportDate	SMALLDATETIME,
	@AgentList	VARCHAR(MAX)
AS 

/*
	Created: 
	Task: 
	DB: DBACC.bodb02
	Original: Lrf_Rpt_TurnOver
	Revisions:
		- 20170208@Paul: Create new [RedmineID: #70616]
		- 20170323@Paul: Implement Cash Out [RedmineID: #71727]
*/

BEGIN
	SET NOCOUNT ON;
   
	DECLARE @tmpAg   TABLE (custID INT, currency INT);
	DECLARE @fdate   SMALLDATETIME;
 
	SELECT	@fdate = @ReportDate;

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @tmpAg(CustId, Currency)
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
			CAST(SUM(b.Deposit * e.MYR) AS MONEY) AS DepositMYR
	FROM #tmpRpt b
		INNER JOIN #TempExchange e ON e.exchangeid = b.currency
	WHERE e.ExchangeDate = @fdate;

	DROP TABLE #TempExchange;
	DROP TABLE #tmpRpt;

	SET NOCOUNT OFF;
END

GO

GRANT EXECUTE ON [dbo].[Lrf_GetLicenseeTodayDeposit] TO [bodbLicenseeNet] AS [dbo]
GO

GRANT ALTER ON [dbo].[Lrf_GetLicenseeTodayDeposit] TO [vnteam] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Lrf_GetLicenseeTodayDeposit] TO [vnteam] AS [dbo]
GO


