/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

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
	DB: DBACC.bodb02

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
		- 20240226@Evan: Integrate AG promotion + remove un-use code [Redmine #201067]
		- 20241011@Kelvin: AG Casino Win Loss - Enhance consistency check [RedmineID: #211837]
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (
		CustId			INT,
		WinLostDate		DATETIME,
		Bettype 		INT DEFAULT (1800),
		Currency		INT,
		TurnOver		MONEY DEFAULT (0),
		TotalTrans		INT,
		WinLost			MONEY DEFAULT (0),
		LicenseeWinLost	MONEY DEFAULT (0), 
		JpContribution MONEY DEFAULT (0))

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

	CREATE CLUSTERED INDEX cix_CustId ON #tmpCust(CustId)

	DECLARE @TempFromDate	DATE = @FromDate
	DECLARE @TempToDate		DATE = @ToDate


	INSERT INTO #tmpResult (
		CustId,
		WinLostDate,
		Bettype,
		Currency,
		TurnOver,
		TotalTrans,
		WinLost,
		LicenseeWinLost,
		JpContribution )
	SELECT
		ct.recommend AS CustID,
		c.Winlostdate,
		c.Bettype,
		ct.Currency,
		SUM(c.TurnOver) AS TurnOver,
		SUM(c.BetCount) AS TotalTrans,
		SUM(c.Winlost)  AS Winlost,
		-SUM(c.Winlost) AS LicenseeWinlost,
		ISNULL(-SUM(c.JpContribution),0) AS JpContribution
	FROM bodb_LicenseeReport.dbo.rptDepWinlost_AGCasino AS c WITH (NOLOCK)
		INNER JOIN #tmpCust AS ct ON c.CustID = ct.CustID
	WHERE c.Winlostdate BETWEEN @TempFromDate AND @TempToDate 
	GROUP BY ct.Recommend,
		c.Winlostdate,
		c.Bettype, 
		ct.Currency

	IF EXISTS (SELECT TOP(1) 1 FROM #tmpResult)
	BEGIN
		INSERT INTO #TempExchange(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM @Temp a WHERE e.ExchangeID = a.Currency)
	END

	SELECT r.CustID
		, c.Username
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