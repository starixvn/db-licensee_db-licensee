/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[LRF_Rpt_AGCasinoWinloss_Mem]
	@CustId					INT, --- recommend
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@AgentList				VARCHAR(MAX),
	@BaseCurrency			VARCHAR(3) = '',
	@DefaultBaseCurrency	VARCHAR(3) = ''
AS

/*
	Created: Jim
	Date: 2014-09-18
	Task: AG Win Loss report
	DB: DBACC.bodb02

	Revisions:
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20141121@Jim: as more table alias 
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
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (
		CustID			INT,
		WinLostDate		DATETIME,
		Currency		INT,
		TurnOver		MONEY,
		TotalTrans		INT,
		WinLost			MONEY,
		LicenseeWinLost	MONEY )
	
	CREATE TABLE #tmpCust (
		CustId INT,
		Currency INT )

	CREATE TABLE #TempExchange (FromDate DATETIME, ToDate DATETIME, ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)

	DECLARE @Temp AS TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
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

	INSERT INTO #tmpCust (CustId, Currency)
	SELECT co.CustID,
		lc.Currency
	FROM
		dbo.custInfo AS co WITH (NOLOCK)
		INNER JOIN @Temp AS lc ON lc.CustId = co.Recommend AND co.Currency = lc.Currency
	WHERE lc.CustId = @CustId

	DECLARE @TempFromDate	DATETIME
	DECLARE @TempToDate		DATETIME
	DECLARE @GapDate		DATETIME

	SELECT @GapDate = MAX(c.Winlostdate)
	FROM bodb_report.dbo.rptDepWinlost_AGCasino AS c WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #tmpCust AS tc WHERE c.Custid = tc.CustId)

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
				c.custid,
				c.winlostdate,
				c.currency,
				SUM(c.stake)		AS TurnOver,
				COUNT(1)			AS TotalTrans,
				SUM(c.winlost - c.actual_stake)	AS Winlost,
				- SUM(c.Winlost - c.actual_stake)	AS LicenseeWinlost
			FROM dbo.bettransLC AS c WITH (NOLOCK)
				INNER JOIN #tmpCust AS ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
			WHERE c.winlostdate BETWEEN @FromDate2 AND @ToDate 
				AND c.statusID IN (111, 112, 113)
				AND c.productID = 10 -- AG
			GROUP BY c.CustId,
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
				c.CustID,
				c.Winlostdate,
				c.Currency,
				SUM(c.TurnOver) AS TurnOver,
				SUM(c.BetCount) AS TotalTrans,
				SUM(c.Winlost)  AS Winlost,
				-SUM(c.Winlost) AS LicenseeWinlost
			FROM DBLIC.bodb_licenseereport.dbo.rptLicWinloss2 AS c WITH (NOLOCK)
				INNER JOIN #tmpCust AS ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
			WHERE c.Winlostdate BETWEEN @TempFromDate AND @ToDate2
				AND c.roleid = 1
				AND c.sporttype = 250 -- AG Casino
				AND c.statusID <> 101
			GROUP BY c.CustId,
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
			CustID,
			Winlostdate,
			Currency,
			TurnOver,
			TotalTrans,
			Winlost,
			LicenseeWinlost)
		SELECT
			c.Custid,
			c.Winlostdate,
			c.Currency,
			SUM(c.TurnOver) AS TurnOver,
			SUM(c.BetCount) AS TotalTrans,
			SUM(c.Winlost)  AS Winlost,
			-SUM(c.Winlost) AS LicenseeWinlost
		FROM bodb_report.dbo.rptDepWinlost_AGCasino AS c WITH (NOLOCK)
			INNER JOIN #tmpCust AS ct ON c.CustID = ct.CustID AND c.Currency = ct.Currency
		WHERE c.Winlostdate BETWEEN @FromDate AND @TempToDate 
		GROUP BY c.CustId,
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

	SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
		,c.Username
		,r.Currency
		,SUM(r.TotalTrans) AS TotalTrans

		,SUM(r.TurnOver			* e.Rate)	AS TurnOver
		,SUM(r.Winlost			* e.Rate)	AS Winlost
		,SUM(r.LicenseeWinlost	* e.Rate)	AS LicenseeWinlost
		---USD
		,SUM(r.TurnOver			* e.USD)	AS TurnOverUSD
		,SUM(r.Winlost			* e.USD)	AS WinlostUSD
		,SUM(r.LicenseeWinlost	* e.USD)	AS LicenseeWinlostUSD
		---EUR
		,SUM(r.TurnOver			* e.EUR)	AS TurnOverEUR
		,SUM(r.Winlost			* e.EUR)	AS WinlostEUR
		,SUM(r.LicenseeWinlost	* e.EUR)	AS LicenseeWinlostEUR
		---GBP
		,SUM(r.TurnOver			* e.GBP)	AS TurnOverGBP
		,SUM(r.Winlost			* e.GBP)	AS WinlostGBP
		,SUM(r.LicenseeWinlost	* e.GBP)	AS LicenseeWinlostGBP
		---Base Currency
		,SUM(r.TurnOver			* e.DefaultRate)	AS TurnOverBase
		,SUM(r.Winlost			* e.DefaultRate)	AS WinlostBase
		,SUM(r.LicenseeWinlost	* e.DefaultRate)	AS LicenseeWinlostBase
	FROM #tmpResult AS r
		INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.CustID = r.CustID
		INNER JOIN #TempExchange AS e ON r.Winlostdate BETWEEN e.FromDate AND e.ToDate AND r.currency = e.ExchangeId
	GROUP BY SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2))
		,c.Username
		,r.Currency
	ORDER BY c.Username

	---------
	DROP TABLE #tmpCust
	DROP TABLE #tmpResult
	DROP TABLE #TempExchange
END
GO