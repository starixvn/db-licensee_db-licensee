USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummary]
	  @LicenseeID INT
	, @UserID INT
	, @CurrencyID INT = NULL
	, @FromDate SMALLDATETIME
	, @ToDate SMALLDATETIME
	, @MoveBetsDay SMALLDATETIME
	, @Liveindicator INT = 1

AS 
/*
Created: 20111031@Henry
Task : Live Report Summary
DB: DB052.bodb02

Revisions:
	-20111208@Jim: change bettype condition
	-20120109@Henry: enhance performance + remove @LicenseeType + remove currency UUS
	-20120214@Jim: change to use  table ExchangeDaily by function Lrf_f_GetExchangeDaily  
	-20120614@Jim: optimize code 
	-20120726@Jim: add playercomm value 
	-20120815@Henry: add Live casino
	-20120831@Henry: add Virtual Sports
	-20121004@Jim: replace @currency input param by @currencyID
	-20121115@Henry: Only Sportsbook needs to exclude BA
	-20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	-20130328@Scott: Support RNG Casino and Bingo
	-20130514@Jim:  Restrict permission of Licensee Users by currency
	-20130625@Jim: support to view currency UUS
	-20130809@Jim: offer Virtual Horse Racing
	-20131007@Jim: support Virtual Tennis
	-20140404@Florent: support Keno product
	-20140602@Hannah: Separate Live/ Non - Live data in Live Report
	-20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	-20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	-20150127@Jim: support base on GBP Currency
	- 20150618@Patrick: #36263: Fix super balance isue for: AGC, GD & VG
	- 20150612@Jim: support MicroGaming 
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
Param's Explanation:
	@IsLive : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
	
Example: 
	
DECLARE @DateFrom DATETIME
DECLARE @DateTo DATETIME
DECLARE @MoveBetsDay DATETIME
SELECT @DateFrom = DATEADD(DAY, -15, GETDATE())
SELECT @DateTo = GETDATE()
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)

EXEC [Lrf_Rpt_LiveReportSummary] @LicenseeId = 1, @CurrencyID = 0, @FromDate=@DateFrom, @ToDate=@DateTo, @MoveBetsDay = @MoveBetsDay

*/
SET NOCOUNT ON

DECLARE @TempFromDate DATETIME
DECLARE @TempToDate DATETIME
DECLARE @FDate SMALLDATETIME
DECLARE @TDate SMALLDATETIME

--to Deal With Parameter Sniffing
SELECT @FDate = @FromDate
	, @TDate = @ToDate

IF @CurrencyID IS NULL
	SET @CurrencyID = 0

CREATE TABLE #tmpWinloss (
	winlostdate DATETIME
	, Currency INT
	, ProductCode VARCHAR(3)
	, TurnOver MONEY
	, Winlost MONEY
	, LicenseeWL MONEY
	, Comm MONEY
	, PlayerComm MONEY
	, AmtDueTo3rd MONEY
	, Betcount INT
	)

SELECT currencyID
	, LicenseeID
INTO #currency
FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1) -- System is default=1 (LRF)
WHERE (
		@CurrencyID = 0
		OR (
			@CurrencyID <> 0
			AND CurrencyID = @CurrencyID
			)
		)

DECLARE @TempAg AS TABLE (CustId INT, Currency INT)

INSERT INTO @TempAg (CustId,Currency)
SELECT lc.CustID, lc.Currency 
FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID
	AND lc.Currency = c.CurrencyID
WHERE (
		@CurrencyID = 0
		OR (Currency = @CurrencyID)
		)
/*
DECLARE @site VARCHAR(50)

SELECT @site = LicenseeName
FROM bodb_licensee.dbo.Licensees(NOLOCK)
WHERE LicenseeID = @LicenseeID

DECLARE @Super AS TABLE (
	custid INT PRIMARY KEY
	, currency INT
	)

INSERT INTO @Super (
	custid
	, currency
	)
SELECT CustID
	, currency
FROM Dep_CustSuper dc WITH (NOLOCK)
INNER JOIN #Currency c ON dc.Currency = c.CurrencyID
WHERE site = @site
*/
IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay
		SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate

	--BA
	INSERT INTO #tmpWinloss
	SELECT b.winlostdate
		, t.currency
		, 'BA' AS ProductCode
		, SUM(stake) turnover
		, SUM(b.winlost - b.actual_stake) AS Winlost
		, 0 AS LicenseeWL
		, SUM(comm) AS Comm
		, SUM(b.playercomm) AS PlayerComm
		, - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
		, COUNT(b.transid) BetCount
	FROM dbo.bettrans b WITH (
			NOLOCK
			, INDEX = IX_srecommend
			)
	INNER JOIN @TempAg t ON b.recommend = t.custid AND b.Currency = t.Currency 
	INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON t.custid = BA.recommend
		AND b.transid = BA.transid
	WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND b.statusID IN (111, 112, 113)
		AND (b.liveindicator = @Liveindicator
			OR @Liveindicator = 2)
		AND (b.bettype NOT IN (9,29,901,902,903))
	GROUP BY b.winlostdate
		, t.currency

	--BA for Parlay
	INSERT INTO #tmpWinloss
	SELECT b.winlostdate
		, t.currency
		, 'BA' AS ProductCode
		, SUM(stake) turnover
		, SUM(b.winlost - b.actual_stake) AS Winlost
		, 0 AS LicenseeWL
		, SUM(comm) AS Comm
		, SUM(b.playercomm) AS PlayerComm
		, - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
		, COUNT(b.transid) BetCount
	FROM dbo.bettrans b WITH (
			NOLOCK
			, INDEX = IX_srecommend
			)
	INNER JOIN @TempAg t ON b.recommend = t.custid AND b.currency = t.currency
	INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON t.custid = BA.recommend
		AND b.transid = BA.transid
	WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND b.statusID IN (111, 112, 113)
		AND (b.livehomescore = @Liveindicator
			OR @Liveindicator = 2)
		AND (b.bettype IN (9,29))
	GROUP BY b.winlostdate
		, t.currency

	--RB
	INSERT INTO #tmpWinloss
	SELECT b.winlostdate
		, t.currency
		, 'RB' AS ProductCode
		, SUM(CASE 
				WHEN b.bettype IN (33, 43)
					AND liveawayscore = 0
					THEN stake / 2
				ELSE stake
				END) turnover
		, SUM(b.winlost - b.actual_stake) AS Winlost
		, SUM(b.awinlost) AS LicenseeWL
		, SUM(comm) AS Comm
		, SUM(playercomm) AS PlayerComm
		, - SUM((b.winlost - b.actual_stake + awinlost + comm)) AmountDueTo3rd
		, COUNT(b.transid) BetCount
	FROM dbo.bettrans b WITH (
			NOLOCK
			)
	INNER JOIN @TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
	WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND b.bettype BETWEEN 31 AND 33
		AND b.statusID IN (111, 112, 113)
		AND (b.liveindicator = @Liveindicator
			OR @Liveindicator = 2)
	GROUP BY b.winlostdate
		, t.currency
		, b.bettype

	--SB
	INSERT INTO #tmpWinloss
	SELECT b.winlostdate
		, t.currency
		, 'SB' AS ProductCode
		, SUM(stake) turnover
		, SUM(b.winlost - b.actual_stake) AS Winlost
		, SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL
		, SUM(comm) AS Comm
		, SUM(b.playercomm) AS PlayerComm
		, - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
		, COUNT(b.transid) BetCount
	FROM dbo.bettrans b WITH (
			NOLOCK
			)
	INNER JOIN @TempAg t ON b.recommend = t.custid AND b.Currency = t.Currency
	WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND (
			b.bettype < 31
			OR (b.bettype BETWEEN 121 AND 999)
			OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			)
		AND (b.bettype NOT IN (9,29,901,902,903))
		AND b.tpositiontaking <> 0
		AND b.statusID IN (111, 112, 113)
		AND (b.liveindicator = @Liveindicator
			OR @Liveindicator = 2)
	GROUP BY b.winlostdate
		, t.currency
		, b.bettype

	--parlay for SB
	INSERT INTO #tmpWinloss
	SELECT b.winlostdate
		, t.currency
		, 'SB' AS ProductCode
		, SUM(stake) turnover
		, SUM(b.winlost - b.actual_stake) AS Winlost
		, SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL
		, SUM(comm) AS Comm
		, SUM(b.playercomm) AS PlayerComm
		, - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
		, COUNT(b.transid) BetCount
	FROM dbo.bettrans b WITH (
			NOLOCK
			)
	INNER JOIN @TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
	WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND (
			b.bettype IN (9,29)
			)
		AND b.tpositiontaking <> 0
		AND b.statusID IN (111, 112, 113)
		AND (b.livehomescore = @Liveindicator
			OR @Liveindicator = 2)
	GROUP BY b.winlostdate
		, t.currency
		, b.bettype

	--Others
	INSERT INTO #tmpWinloss
	SELECT b.winlostdate
		, t.currency
		, CASE 
			WHEN bettype BETWEEN 81 AND 120
				THEN 'NG'
			WHEN b.bettype BETWEEN 1101 AND 1199
				THEN 'LC'
			WHEN b.bettype BETWEEN 1201 AND 1299
				THEN 'VS'
			WHEN b.bettype = 71
				THEN 'CS'
			WHEN b.bettype = 73
				THEN 'BG'
			WHEN b.bettype BETWEEN 1501 AND 1599 --Keno
				THEN 'KN'
			WHEN b.bettype BETWEEN 2001 AND 2007
				THEN 'MGC'
			END AS ProductCode
		, SUM(stake) turnover
		, SUM(b.winlost - b.actual_stake) AS Winlost
		, SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL
		, SUM(comm) AS Comm
		, SUM(b.playercomm) AS PlayerComm
		, - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
		, COUNT(b.transid) BetCount
	FROM dbo.bettrans b WITH (
			NOLOCK
			)
	INNER JOIN @TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
	WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
		AND b.bettype NOT IN (31, 32, 33)
		AND b.statusID IN (111, 112, 113)
		AND (
			b.bettype BETWEEN 81 AND 120
			OR b.bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 1201 AND 1299
			OR b.bettype IN (71, 73) --RNG CASINO & BINGO
			OR b.bettype BETWEEN 1501 AND 1599 --Keno
			OR b.bettype BETWEEN 2001 AND 2007
			)
		AND (
			(b.liveindicator = @Liveindicator
			OR @Liveindicator = 2)
			)
	GROUP BY b.winlostdate
		, t.currency
		, b.bettype
END

IF @FDate <= @MoveBetsDay
BEGIN
	IF @TDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET @TempToDate = @TDate

	INSERT INTO #tmpWinloss
	SELECT
	b.rptdate,
	b.currencyID,
	'BA' AS ProductCode,
	sum(b.turnover) turnover,
	sum(b.winloss) winlost,
	0 AS LicenseeWL,
	sum(b.CommissionA) Comm,
	sum( b.CommissionP  ) PlayerComm,
	- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
	sum(b.betcount) BetCount
	FROM bodb_Licensee.dbo.rpt_Betting_BA b WITH ( NOLOCK )
			INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID
	WHERE b.rptDate BETWEEN @FDate AND @TempToDate
		AND b.status NOT IN (-1,103)
		AND b.siteID = @LicenseeID
		--AND ((@CurrencyID <> 0) OR (b.CurrencyID =@CurrencyID))
		AND ((@Liveindicator = 0 and b.IsLive = 0)
			OR (@Liveindicator = 1 and b.IsLive = 1)
			OR (@Liveindicator = 2))
		AND b.bettype NOT IN (9,29,901,902,903)
	GROUP BY 
	b.rptdate, b.currencyID

	-- parlay for BA
	INSERT INTO #tmpWinloss
	SELECT
	b.rptdate,
	b.currencyID,
	'BA' AS ProductCode,
	sum(b.turnover) turnover,
	sum(b.winloss) winlost,
	0 AS LicenseeWL,
	sum(b.CommissionA) Comm,
	sum( b.CommissionP  ) PlayerComm,
	- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
	sum(b.betcount) BetCount
	FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )
			INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID
	WHERE b.rptDate BETWEEN @FDate AND @TempToDate
		AND b.status NOT IN (-1,103)
		AND b.Bettype NOT IN (901,902,903)
		AND b.siteID = @LicenseeID
		--AND ((@CurrencyID <> 0) OR (b.CurrencyID =@CurrencyID))
		AND ((@Liveindicator = 0 and b.IsLive = 0)
			OR (@Liveindicator = 1 and b.IsLive = 1)
			OR (@Liveindicator = 2))
		AND b.isBA = 1
	GROUP BY 
	b.rptdate, b.currencyID

	INSERT INTO #tmpWinloss
		SELECT 
		b.rptDate,
		b.currencyID,
		CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN 'NG'
			WHEN (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399))
				THEN 'SB'
			WHEN b.bettype BETWEEN 31 AND 33 
				THEN 'RB'
			WHEN b.bettype BETWEEN 1101 AND 1199 
				THEN 'LC'
			WHEN b.bettype BETWEEN 1201 AND 1299
				THEN 'VS'
			WHEN b.bettype = 71
				THEN 'CS'
			WHEN b.bettype = 73
				THEN 'BG'
			WHEN b.bettype BETWEEN 1501 AND 1599
				THEN 'KN'
			WHEN b.bettype BETWEEN 2001 AND 2007
				THEN 'MGC'	
		END AS ProductCode,
		SUM(b.turnover * CASE WHEN b.bettype=33 AND b.status IN (114,115) THEN 0.5 ELSE 1 END) turnover,
		sum(b.winloss) winlost,
		SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.WinlossA ELSE  -1 * b.winloss END) AS LicenseeWL,
		sum(b.CommissionA) Comm,
		sum( b.CommissionP  ) PlayerComm,
		- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
		sum(b.betcount) BetCount
		FROM bodb_Licensee.dbo.rpt_Betting b WITH ( NOLOCK )
				INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID
		WHERE b.rptDate BETWEEN @FDate AND @TempToDate
			AND b.status NOT IN (-1,103)
			AND b.siteID =@LicenseeID
			--AND ((@CurrencyID <> 0) OR (b.CurrencyID =@CurrencyID))
			AND ((@Liveindicator = 0 and b.IsLive = 0)
				OR (@Liveindicator = 1 and b.IsLive = 1)
				OR (@Liveindicator = 2))
			AND b.CustomerCategory = -1
		AND b.bettype NOT IN (9,29,1700,1800,1900,901,902,903)	
		GROUP BY b.rptDate, b.currencyID,
		CASE 
			WHEN b.bettype BETWEEN 81 AND 120
				THEN 'NG'
			WHEN (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999)OR (b.Bettype BETWEEN 1301 and 1399) )
				THEN 'SB'
			WHEN b.bettype BETWEEN 31 AND 33 
				THEN 'RB'
			WHEN b.bettype BETWEEN 1101 AND 1199 
				THEN 'LC'
			WHEN b.bettype BETWEEN 1201 AND 1299
				THEN 'VS'
			WHEN b.bettype = 71
				THEN 'CS'
			WHEN b.bettype = 73
				THEN 'BG'
			WHEN b.bettype BETWEEN 1501 AND 1599
				THEN 'KN'
			WHEN b.bettype BETWEEN 2001 AND 2007
				THEN 'MGC'		
		END

		-- parlay for SB
		INSERT INTO #tmpWinloss
		SELECT 
		b.rptDate,
		b.currencyID,
		'SB' AS ProductCode,
		SUM(b.turnover) turnover,
		sum(b.winloss) winlost,
		SUM(-1 * b.winloss) AS LicenseeWL,
		sum(b.CommissionA) Comm,
		sum( b.CommissionP  ) PlayerComm,
		- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
		sum(b.betcount) BetCount
		FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )
				INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID
		WHERE b.rptDate BETWEEN @FDate AND @TempToDate
			AND b.status NOT IN (-1,103)
			AND b.Bettype NOT IN (901,902,903)
			AND b.siteID =@LicenseeID
			--AND ((@CurrencyID <> 0) OR (b.CurrencyID =@CurrencyID))
			AND ((@Liveindicator = 0 and b.IsLive = 0)
				OR (@Liveindicator = 1 and b.IsLive = 1)
				OR (@Liveindicator = 2))
			AND b.isBA = 0
		GROUP BY b.rptDate, b.currencyID
END

CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)

SELECT *
INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
WHERE exchangeid IN (
		SELECT DISTINCT Currency
		FROM #tmpWinloss
		)

SELECT ProductCode
	, CASE ProductCode
		WHEN 'BA'
			THEN 'BA'
		WHEN 'RB'
			THEN 'Racing'
		WHEN 'NG'
			THEN 'Number Game'
		WHEN 'LC'
			THEN 'Live Casino'
		WHEN 'VS'
			THEN 'Virtual Sports'
		WHEN 'CS'
			THEN 'RNG Casino'
		WHEN 'BG'
			THEN 'Bingo'
		WHEN 'KN'
			THEN 'Keno'
		WHEN 'MGC'
			THEN 'Microgaming'
		ELSE 'Sportsbook'
		END AS ProductName
	, SUM(TurnOver) AS Turnover
	, SUM(Winlost) AS Winlost
	, SUM(LicenseeWL) AS LicenseeWL
	, SUM(Comm) AS Comm
	, SUM(playercomm) AS PlayerComm
	, SUM(AmtDueto3rd) AS AmtDueto3rd
	, SUM(Betcount) AS Betcount
	,
	--BaseEUR  
	CAST(SUM(TurnOver * e.EUR) AS MONEY) AS TurnoverEUR
	, CAST(SUM(Winlost * e.EUR) AS MONEY) AS WinlostEUR
	, CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR
	, CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR
	, CAST(SUM(playercomm * e.EUR) AS MONEY) AS PlayerCommEUR
	, CAST(SUM(AmtDueto3rd * e.EUR) AS MONEY) AS AmtDueto3rdEUR
	-- BaseUSD
	, CAST(SUM(TurnOver * e.USD) AS MONEY) AS TurnoverUSD
	, CAST(SUM(Winlost * e.USD) AS MONEY) AS WinlostUSD
	, CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD
	, CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD
	, CAST(SUM(playercomm * e.USD) AS MONEY) AS PlayerCommUSD
	, CAST(SUM(AmtDueto3rd * e.USD) AS MONEY) AS AmtDueto3rdUSD
	-- BaseGBP
	, CAST(SUM(TurnOver * e.GBP) AS MONEY) AS TurnoverGBP
	, CAST(SUM(Winlost * e.GBP) AS MONEY) AS WinlostGBP
	, CAST(SUM(LicenseeWL * e.GBP) AS MONEY) AS LicenseeWLGBP
	, CAST(SUM(Comm * e.GBP) AS MONEY) AS CommGBP
	, CAST(SUM(playercomm * e.GBP) AS MONEY) AS PlayerCommGBP
	, CAST(SUM(AmtDueto3rd * e.GBP) AS MONEY) AS AmtDueto3rdGBP
	
FROM #tmpWinloss b
INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate
	AND e.exchangeid = b.currency
WHERE b.ProductCode IS NOT NULL
GROUP BY ProductCode
ORDER BY ProductName

DROP TABLE #Currency

DROP TABLE #tmpWinloss

DROP TABLE #TempExchange



GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportSummary] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportSummary] TO [vnteam]