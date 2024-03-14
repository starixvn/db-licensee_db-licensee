/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_AGCasinoWinloss]
	@FromDate				SMALLDATETIME
	, @ToDate				SMALLDATETIME
	, @MoveBetsDay			SMALLDATETIME
	, @ReportType			TINYINT			= 1
	, @AgentList			VARCHAR(MAX)
	, @BaseCurrency			VARCHAR(12) = ''
	, @DefaultBaseCurrency	VARCHAR(12) = ''
WITH RECOMPILE
AS

/*
	Created: Jim
	Date: 2014-09-18
	Task: AG Win Loss report
	DB: DBACC.bodb02

	Revisions:
		- 20141111@Jim: use f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150112@Florent: add filter ReportType
		- 20150123@Jim: support base on Currency GBP
		- 20150917@Florent: Change datasource for AG Casino
		- 20151020@Florent: get MoveBetsDay
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20161022@Jim: move table to bodb_licenseereport [RedmineID :#60449]
		- 20170301@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20170524@Harper: Make sure data correct between two stages of Balance up process [RedmineID: #77065]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20190604@Amanda: Fix bug - Dummy balance data is displayed in report [RedmineID: #114611]
		- 20190617@Amanda: Add Base currency param [RedmineID: #112531]
		- 20210622@Mark: Change on MoveBet - Add param MoveBetsDay [RedmineID: #154866]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20240226@Evan: Integrate AG promotion [Redmine #201067]

	Param's Explanation:
		+ @ReportType : 1 Daily, 2 Monthly
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (WinLostDate DATETIME, Bettype INT DEFAULT (1800), Currency INT, TurnOver MONEY DEFAULT (0), TotalTrans INT , WinLost MONEY DEFAULT (0), LicenseeWinLost MONEY DEFAULT (0), JpContribution MONEY DEFAULT (0))
	CREATE TABLE #tmpCust (CustId INT, Currency INT)
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

	INSERT INTO #tmpCust (CustId, Currency)
	SELECT co.CustID, lc.Currency
	FROM dbo.custInfo AS co WITH (NOLOCK)
		INNER JOIN @Temp AS lc ON co.recommend = lc.CustId AND lc.Currency = co.Currency

	CREATE CLUSTERED INDEX cix_CustId ON #tmpCust(CustId)
	
	DECLARE @TempFromDate	DATETIME
	DECLARE @TempToDate		DATETIME
	DECLARE @GapDate		DATETIME

	SELECT @GapDate = MAX(c.Winlostdate)
	FROM bodb_report.dbo.rptDepWinlost_AGCasino AS c WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #tmpCust tc WHERE c.Custid = tc.CustId)

	IF @ToDate > @GapDate
	BEGIN
		IF @FromDate <= @GapDate
			SET @TempFromDate = DATEADD(DAY,1,@GapDate)
		ELSE
			SET @TempFromDate = @FromDate

		DECLARE @FromDate2		DATETIME 
		DECLARE @ToDate2		DATETIME 

		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @TempFromDate <= @MoveBetsDay
				SET @FromDate2 =  DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @FromDate2 = @FromDate

			INSERT INTO #tmpResult (
				WinLostDate,
				Currency,
				TurnOver,
				TotalTrans,
				WinLost,
				LicenseeWinLost)
			SELECT
				c.winlostdate,
				c.currency,
				SUM(c.stake) AS TurnOver,
				COUNT(1) AS TotalTrans,
				SUM(c.winlost - c.actual_stake) AS WinLost,
				- SUM(c.Winlost - c.actual_stake) AS LicenseeWinLost
			FROM dbo.bettransLC AS c WITH (NOLOCK)
				INNER JOIN #tmpCust AS ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
			WHERE c.winlostdate BETWEEN @FromDate2 AND @ToDate 
				AND c.statusID IN (111, 112, 113)
				AND c.productID = 10 -- AG
			GROUP BY
				c.winlostdate,
				c.currency
		END

		IF @TempFromDate <= @MoveBetsDay 
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @ToDate2 = @MoveBetsDay
			ELSE
				SET @ToDate2 = @ToDate

			INSERT INTO #tmpResult (
				WinLostDate,
				Currency,
				TurnOver,
				TotalTrans,
				WinLost,
				LicenseeWinLost)
			SELECT
				c.winlostdate,
				c.Currency,
				SUM(c.turnover) AS TurnOver,
				SUM(c.BetCount) AS TotalTrans,
				SUM(c.winlost) AS Winlost,
				-SUM(c.winlost) AS LicenseeWinlost
			FROM DBLIC.bodb_licenseereport.dbo.rptLicWinloss2 AS c WITH (NOLOCK)
				INNER JOIN @Temp AS ag ON c.recommend = ag.Custid AND c.Currency = ag.Currency
			WHERE c.winlostdate BETWEEN @TempFromDate AND @ToDate2 
				AND c.roleid = 2
				AND c.sporttype = 250	-- AG Casino
				AND c.statusID <> 101
			GROUP BY c.Winlostdate,
				c.Currency
		END
	END

	IF @FromDate <= @GapDate
	BEGIN
		IF @ToDate >= @GapDate
			SET @TempToDate = @GapDate
		ELSE
			SET  @TempToDate = @ToDate

		INSERT INTO #tmpResult (
			WinLostDate,
			Bettype,
			Currency,
			TurnOver,
			TotalTrans,
			WinLost,
			LicenseeWinLost,
			JpContribution)
		SELECT
			c.Winlostdate,
			c.Bettype,
			ct.Currency,
			SUM(c.TurnOver) AS TurnOver,
			SUM(c.BetCount) AS TotalTrans,
			SUM(c.Winlost)  AS Winlost,
			-SUM(c.Winlost) AS LicenseeWinlost,
			ISNULL(-SUM(c.JpContribution),0) AS JpContribution
		FROM bodb_report.dbo.rptDepWinlost_AGCasino AS c WITH (NOLOCK)
			INNER JOIN #tmpCust AS ct ON c.Custid = ct.CustId
		WHERE c.Winlostdate BETWEEN @FromDate AND @TempToDate 
		GROUP BY c.Winlostdate, c.Bettype, ct.Currency
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #tmpResult)
	BEGIN
		INSERT INTO #TempExchange(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM @Temp AS a WHERE e.ExchangeID = a.Currency)
	END

	SELECT CASE
			   WHEN @ReportType = 1 THEN r.winlostdate
			   WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
			   ELSE '0'
		   END AS WinLostDate
		 , r.Currency
		 , SUM(CASE WHEN r.Bettype = 1800 THEN r.TotalTrans ELSE 0 END) AS TotalTrans

		 , SUM(r.TurnOver * e.Rate) AS TurnOver
		 , SUM(r.WinLost * e.Rate) AS Winlost
		 , SUM(CASE WHEN r.Bettype = 1800 THEN r.LicenseeWinLost ELSE 0 END * e.Rate) AS LicenseeWinlost
		 , SUM(CASE WHEN r.Bettype = 1802 THEN r.JpContribution ELSE 0 END * e.Rate) AS ContributionWinlost
		 , SUM(CASE WHEN r.Bettype = 1803 THEN r.LicenseeWinLost ELSE 0 END * e.Rate) AS PromotionWinlost
		 , SUM(CASE WHEN r.Bettype = 1801 THEN r.LicenseeWinLost ELSE 0 END * e.Rate) AS JackpotWinlost
		 , SUM(CASE WHEN r.Bettype IN (1800,1802) THEN (r.LicenseeWinLost + r.JpContribution) * e.Rate ELSE 0 END) AS TotalLicenseeWinlost

		   ---USD
		 , SUM(r.TurnOver * e.USD) AS TurnOverUSD
		 , SUM(r.WinLost * e.USD) AS WinlostUSD
		 , SUM(CASE WHEN r.Bettype = 1800 THEN r.LicenseeWinLost ELSE 0 END * e.USD) AS LicenseeWinlostUSD
		 , SUM(CASE WHEN r.Bettype = 1802 THEN r.JpContribution ELSE 0 END * e.USD) AS ContributionWinlostUSD
		 , SUM(CASE WHEN r.Bettype = 1803 THEN r.LicenseeWinLost ELSE 0 END * e.USD) AS PromotionWinlostUSD
		 , SUM(CASE WHEN r.Bettype = 1801 THEN r.LicenseeWinLost ELSE 0 END * e.USD) AS JackpotWinlostUSD
		 , SUM(CASE WHEN r.Bettype IN (1800,1802) THEN (r.LicenseeWinLost + r.JpContribution) * e.USD ELSE 0 END) AS TotalLicenseeWinlostUSD

		   ---EUR
		 , SUM(r.TurnOver * e.EUR) AS TurnOverEUR
		 , SUM(r.WinLost * e.EUR) AS WinlostEUR
		 , SUM(CASE WHEN r.Bettype = 1800 THEN r.LicenseeWinLost ELSE 0 END * e.EUR) AS LicenseeWinlostEUR
		 , SUM(CASE WHEN r.Bettype = 1802 THEN r.JpContribution ELSE 0 END * e.EUR) AS ContributionWinlostEUR
		 , SUM(CASE WHEN r.Bettype = 1803 THEN r.LicenseeWinLost ELSE 0 END * e.EUR) AS PromotionWinlostEUR
		 , SUM(CASE WHEN r.Bettype = 1801 THEN r.LicenseeWinLost ELSE 0 END * e.EUR) AS JackpotWinlostEUR
		 , SUM(CASE WHEN r.Bettype IN (1800,1802) THEN (r.LicenseeWinLost + r.JpContribution) * e.EUR ELSE 0 END) AS TotalLicenseeWinlostEUR
		   ---GBP
		 , SUM(r.TurnOver * e.GBP) AS TurnOverGBP
		 , SUM(r.WinLost * e.GBP) AS WinlostGBP
		 , SUM(CASE WHEN r.Bettype = 1800 THEN r.LicenseeWinLost ELSE 0 END * e.GBP) AS LicenseeWinlostGBP
		 , SUM(CASE WHEN r.Bettype = 1802 THEN r.JpContribution ELSE 0 END * e.GBP) AS ContributionWinlostGBP
		 , SUM(CASE WHEN r.Bettype = 1803 THEN r.LicenseeWinLost ELSE 0 END * e.GBP) AS PromotionWinlostGBP
		 , SUM(CASE WHEN r.Bettype = 1801 THEN r.LicenseeWinLost ELSE 0 END * e.GBP) AS JackpotWinlostGBP
		 , SUM(CASE WHEN r.Bettype IN (1800,1802) THEN (r.LicenseeWinLost + r.JpContribution) * e.GBP ELSE 0 END) AS TotalLicenseeWinlostGBP
		   ---DefaultRate
		 , SUM(r.TurnOver * e.DefaultRate) AS TurnOverBase
		 , SUM(r.WinLost * e.DefaultRate) AS WinlostBase
		 , SUM(CASE WHEN r.Bettype = 1800 THEN r.LicenseeWinLost ELSE 0 END * e.DefaultRate) AS LicenseeWinlostBase
		 , SUM(CASE WHEN r.Bettype = 1802 THEN r.JpContribution ELSE 0 END * e.DefaultRate) AS ContributionWinlostBase
		 , SUM(CASE WHEN r.Bettype = 1803 THEN r.LicenseeWinLost ELSE 0 END * e.DefaultRate) AS PromotionWinlostBase
		 , SUM(CASE WHEN r.Bettype = 1801 THEN r.LicenseeWinLost ELSE 0 END * e.DefaultRate) AS JackpotWinlostBase
		 , SUM(CASE WHEN r.Bettype IN (1800,1802) THEN (r.LicenseeWinLost + r.JpContribution) * e.DefaultRate ELSE 0 END) AS TotalLicenseeWinlostBase

	FROM #tmpResult AS r
		INNER JOIN #TempExchange AS e ON r.Winlostdate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
	GROUP BY --r.Winlostdate
		CASE
			WHEN @ReportType = 1 THEN r.winlostdate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
			ELSE '0'
		END
		, r.Currency
	ORDER BY CASE
				WHEN @ReportType = 1 THEN r.winlostdate
				WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			 END

	DROP TABLE #tmpResult
	DROP TABLE #tmpCust
	DROP TABLE #TempExchange
END
GO