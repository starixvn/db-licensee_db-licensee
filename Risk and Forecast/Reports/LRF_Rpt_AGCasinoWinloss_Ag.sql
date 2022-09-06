/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[LRF_Rpt_AGCasinoWinloss_Ag]
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@AgentList				VARCHAR(MAX),
	@BaseCurrency			VARCHAR(12)		= '',
	@DefaultBaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: Jim
	Date: 2014-09-18
	Task: AG Win Loss report
	DB: DBEXT.bodb02
	Original: DBACC.bodb02

	Revisions:
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20150917@Florent: Change datasource for AG Casino
		- 20151020@Florent: get MoveBetsDay
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20170524@Harper: Make sure data correct between two stages of Balance up process [RedmineID: #77065]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20190617@Amanda: Add Base currency param [RedmineID: #112531]
		- 20210622@Mark: Change on MoveBet - Add param MoveBetsDay [RedmineID: #154866]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 2022831@Sol: Deposit - AWS - Modify jobs of separated wallet - Move table rptDepWinlost_AGCasino to DB05x - [RedmineID: #176479]

*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (
		CustId			INT,
		WinLostDate		DATETIME,
		Currency		INT,
		TurnOver		MONEY,
		TotalTrans		INT,
		WinLost			MONEY,
		LicenseeWinLost	MONEY )

	CREATE TABLE #tmpCust (
		Recommend	INT,
		CustId		INT,
		Currency	INT )

	CREATE TABLE #TempExchange(FromDate DATETIME, ToDate DATETIME, ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)

	DECLARE @Temp AS TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @Temp(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	INSERT INTO #tmpCust (
		Recommend,
		CustID,
		Currency )
	SELECT
		lc.CustId AS Recommend,
		co.CustID,
		lc.Currency
	FROM
		dbo.custInfo AS co WITH (NOLOCK)
		INNER JOIN @Temp AS lc ON lc.CustId = co.Recommend AND co.Currency = lc.Currency

	DECLARE @TempFromDate	DATETIME
	DECLARE @TempToDate		DATETIME
	DECLARE @GapDate		DATETIME

	SELECT @GapDate = MAX(c.Winlostdate)
	FROM bodb_LicenseeReport.dbo.rptDepWinlost_AGCasino AS c WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #tmpCust tc WHERE c.Custid = tc.CustId)
	
	IF @ToDate > @GapDate
	BEGIN
		IF @FromDate <= @GapDate
			SET @TempFromDate =  DATEADD(DAY,1,@GapDate)
		ELSE
			SET @TempFromDate = @FromDate

		DECLARE @FromDate2	DATETIME
		DECLARE @ToDate2	DATETIME

		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @TempFromDate <= @MoveBetsDay 
				SET @FromDate2 =  DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @FromDate2 = @FromDate

			INSERT INTO #tmpResult (
				CustId,
				WinLostDate,
				Currency,
				TurnOver,
				TotalTrans,
				WinLost,
				LicenseeWinLost )
			SELECT
				c.recommend,
				c.winlostdate,
				c.currency,
				SUM(c.stake)		AS TurnOver,
				COUNT(1)			AS TotalTrans,
				SUM(c.winlost - c.actual_stake)	AS Winlost,
				- SUM(c.Winlost - c.actual_stake)	AS LicenseeWinlost
			FROM dbo.bettransLC AS c WITH (NOLOCK)
				INNER JOIN #tmpCust AS ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
			WHERE c.Winlostdate BETWEEN @FromDate2 AND @ToDate
				AND c.statusID IN (111, 112, 113)
				AND c.productID = 10 -- AG
			GROUP BY c.Recommend,
				c.Winlostdate,
				c.Currency
		END

		IF @TempFromDate <= @MoveBetsDay 
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @ToDate2 = @MoveBetsDay
			ELSE
				SET @ToDate2 = @ToDate

			INSERT INTO #tmpResult (
				CustId,
				WinLostDate,
				Currency,
				TurnOver,
				TotalTrans,
				WinLost,
				LicenseeWinLost )
			SELECT
				c.Recommend,
				c.Winlostdate,
				c.Currency,
				SUM(c.TurnOver) AS TurnOver,
				SUM(c.BetCount) AS TotalTrans,
				SUM(c.Winlost)  AS Winlost,
				-SUM(c.Winlost) AS LicenseeWinlost
			FROM bodb_licenseereport.dbo.rptLicWinloss2 AS c WITH (NOLOCK)
				INNER JOIN (SELECT DISTINCT Recommend, Currency FROM #tmpCust) AS ct ON c.Custid = ct.Recommend AND c.Currency = ct.Currency
			WHERE c.Winlostdate BETWEEN @TempFromDate AND @ToDate2
				AND c.roleid = 2
				AND c.sporttype = 250 -- AG Casino
				AND c.statusID <> 101
			GROUP BY c.Recommend,
				c.Winlostdate,
				c.Currency
		END
	END

	IF @FromDate <= @GapDate
	BEGIN
		IF @ToDate >= @GapDate
			SET @TempToDate = @GapDate
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO #tmpResult (
			CustId,
			WinLostDate,
			Currency,
			TurnOver,
			TotalTrans,
			WinLost,
			LicenseeWinLost )
		SELECT
			ct.recommend AS CustID,
			c.Winlostdate,
			c.Currency,
			SUM(c.TurnOver) AS TurnOver,
			SUM(c.BetCount) AS TotalTrans,
			SUM(c.Winlost)  AS Winlost,
			-SUM(c.Winlost) AS LicenseeWinlost
		FROM bodb_LicenseeReport.dbo.rptDepWinlost_AGCasino AS c WITH (NOLOCK)
			INNER JOIN #tmpCust AS ct ON c.CustID = ct.CustID AND c.Currency = ct.Currency
		WHERE c.Winlostdate BETWEEN @FromDate AND @TempToDate 
		GROUP BY ct.Recommend,
			c.Winlostdate,
			c.Currency
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #tmpResult)
	BEGIN
		INSERT INTO #TempExchange(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM @Temp a WHERE e.ExchangeID = a.Currency)
	END

	SELECT r.CustID
		,c.Username
		,r.Currency
		,SUM(r.TotalTrans)	AS TotalTrans

		,SUM(r.TurnOver			* e.Rate)	AS TurnOver
		,SUM(r.WinLost			* e.Rate)	AS Winlost
		,SUM(r.LicenseeWinLost	* e.Rate)	AS LicenseeWinlost
		---USD
		,SUM(r.TurnOver			* e.USD)	AS TurnOverUSD
		,SUM(r.WinLost			* e.USD)	AS WinlostUSD
		,SUM(r.LicenseeWinLost	* e.USD)	AS LicenseeWinlostUSD
		---EUR
		,SUM(r.TurnOver			* e.EUR)	AS TurnOverEUR
		,SUM(r.WinLost			* e.EUR)	AS WinlostEUR
		,SUM(r.LicenseeWinLost	* e.EUR)	AS LicenseeWinlostEUR
		---GBP
		,SUM(r.TurnOver			* e.GBP)	AS TurnOverGBP
		,SUM(r.WinLost			* e.GBP)	AS WinlostGBP
		,SUM(r.LicenseeWinLost	* e.GBP)	AS LicenseeWinlostGBP
		---Default Base Currency
		,SUM(r.TurnOver			* e.DefaultRate)	AS TurnOverBase
		,SUM(r.WinLost			* e.DefaultRate)	AS WinlostBase
		,SUM(r.LicenseeWinLost	* e.DefaultRate)	AS LicenseeWinlostBase
	FROM #tmpResult AS r
		INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON r.CustID = c.CustID
		INNER JOIN #TempExchange AS e ON r.Winlostdate BETWEEN e.FromDate AND e.ToDate AND r.currency = e.ExchangeId
	GROUP BY r.CustId
		,c.Username
		,r.CustID
		,r.Currency
	ORDER BY c.Username

	---------
	DROP TABLE #tmpResult
	DROP TABLE #tmpCust
	DROP TABLE #TempExchange
END
GO