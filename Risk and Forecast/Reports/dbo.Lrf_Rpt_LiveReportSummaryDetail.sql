USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummaryDetail] 
	@LicenseeID		INT,
	@UserID			INT,
	@CurrencyID		INT = NULL,
	@ProductCode	VARCHAR(20) = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Debug			BIT = 0,
	@Liveindicator	INT = 1
AS 
/*  
Created: 20111115@Henry  
Task : Live Report Summary by Sport  
DB: DBEXT.bodb02  
  
Revisions:  
  
	Return 3 tables:  
	WinlostBySport  
	WinlostByCurrency  
	WinlostByBetType  
	
	- 20111208@Jim: change bettype condition 
	- 20120110@Henry: remove Licensee Type + Get data from rpt_Betting + remove currency UUS
	- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
	- 20120614@Jim: optimize code 	 
	- 20120725@Jim: add playercomm value 
	- 20120815@Henry: add Live casino
	- 20120831@Henry: add Virtual Sports
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130328@Scott: Support RNG Casino and Bingo
	- 20130618@Jim:  Restrict permission of Licensee Users by currency
	- 20130625@Jim: support to view Currency UUS
	- 20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
	- 20140404@Florent: offer Keno product	
	- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150127@Jim: support base on GBP Currency
	- 20150209@Don: remove index hint IX_srecommend
    - 20150415@Jim: change to use f_GroupBettype instead of LRF_view_bettype_SS
	- 20150618@Patrick: #36263: Fix super balance isue for: AGC, GD & VG
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
	- 20151001@Jim: remove MicroGaming
	- 20151228@Bobby: #50469 - Remove RNG Casino - exclude OneRNG range bettype
	- 20160201@Victor: Include Bettrade original ticket [Redmine: 51053]
	- 20160218@Bobby: #52428 - Intergate RnG Casino product
	- 20160218@Bobby: #52787 - Fix bug for showing parlay when choosing specific product code
	- 20160330@Percy: Support Voidbridge single wallet [Redmine: #55057]
	- 20160413@Victor: support MKK currency code
	- 20160519@Jim: HotFix #57810
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
Param's Explanation:  
	@Liveindicator : indicate that whether the report will get live data or not
		+ 0: Non - Live data only
		+ 1: Live data only
		+ 2: All  
Example:  
  
DECLARE @FromDate DATETIME  
DECLARE @ToDate DATETIME  
DECLARE @MoveBetsDay DATETIME  
SELECT @FromDate = DATEADD(DAY, -15, GETDATE())  
SELECT @ToDate = GETDATE()  
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)
  
EXEC [Lrf_Rpt_LiveReportSummaryDetail]  @LicenseeId = 1, @CurrencyID = 0, @FromDate=@FromDate, @ProductCode= NULL, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay  
  
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME,
			@sql			VARCHAR(MAX),
			@FDate			SMALLDATETIME,
			@TDate			SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate

	IF @CurrencyID IS NULL
		SET @CurrencyID = 0

	SELECT	@sql = 'SET NOCOUNT ON  ' + CHAR(13)

	--declare
	SELECT	@sql = @sql + '--Declare variable:' + CHAR(13)

	SELECT	@sql = @sql + 'DECLARE @TempAg TABLE (CustId INT, Currency INT)' + CHAR(13)
						+ 'CREATE TABLE #tmpWinloss (winlostdate DATETIME, Currency INT, BetType INT, TurnOver MONEY, Winlost MONEY, LicenseeWL MONEY, Comm MONEY, PlayerComm MONEY, AmtDueTo3rd MONEY, Betcount INT)' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT currencyID, LicenseeID INTO #currency' + CHAR(13)
						+ 'FROM dbo.Lrf_f_GetCurrencybyUser(' + CONVERT(VARCHAR(20), @licenseeID) + ', ' + CONVERT(VARCHAR(20), @userID) + ', 1)' + CHAR(13) -- System is default = 1 (LRF)
						+ 'WHERE (' + CONVERT(VARCHAR(10), @CurrencyID) + ' = 0 OR (' + CONVERT(VARCHAR(10), @CurrencyID) + ' <> 0 AND CurrencyID = ' + CONVERT(VARCHAR(20), @CurrencyID) + '))' + CHAR(13)

	--insert agentIds to temp table
	SELECT	@sql = @sql + 'INSERT  INTO @TempAg (CustId, Currency)' + CHAR(13)
						+ 'SELECT  CustID, Currency' + CHAR(13)
						+ 'FROM  bodb_Licensee.dbo.f_SelLicenseeCust('+CONVERT(VARCHAR(20),@licenseeID)+') lc ' + CHAR(13)
						+ 'INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID' + CHAR(13)
						+ 'WHERE lc.LicenseeID =' + convert(VARCHAR(10), @LicenseeID) + CHAR(13)
						+ CASE WHEN @CurrencyID <> 0 THEN 'AND lc.Currency = ' + CONVERT(VARCHAR(10), @CurrencyID) ELSE '' END + CHAR(13)

	IF @ProductCode IS NULL
		SET @ProductCode = ''

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		--BA
		IF @ProductCode IN ('', 'BA')
		BEGIN
			SELECT	@sql = @sql + '-- Get data from bettrans for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13) 
								+ 'SELECT ' + CHAR(13) + 'b.winlostdate, ' + CHAR(13) + 't.currency,' + CHAR(13) + 'b.bettype,' + CHAR(13) 
								+ 'SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END) turnover,' + CHAR(13) 
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13) + '0 AS LicenseeWL,' + CHAR(13) 
								+ 'SUM (comm ) AS Comm,' + CHAR(13) + 'SUM (b.playercomm  ) AS PlayerComm,' + CHAR(13) 
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,  ' + CHAR(13) 
								+ 'COUNT(b.transid) BetCount' + CHAR(13)
								+ 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13) 
								+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency' + CHAR(13) 
								+ 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON t.custid=ba.recommend and b.transid = ba.transid' + CHAR(13) 
								+ 'WHERE b.winlostdate BETWEEN ''' + convert(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)'  + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,901,902,903,904)'  + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.liveindicator = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.liveindicator = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype' + CHAR(13)

			--BA for parlay
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, t.currency, b.bettype,' + CHAR(13)
								+ 'SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (comm ) AS Comm,' + CHAR(13)
								+ 'SUM (b.playercomm  ) AS PlayerComm,'+ CHAR(13)
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,  ' + CHAR(13) 
								+ 'COUNT(b.transid) BetCount' + CHAR(13)
								+ 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13) 
								+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency' + CHAR(13) 
								+ 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON t.custid=ba.recommend and b.transid = ba.transid' + CHAR(13) 
								+ 'WHERE b.winlostdate BETWEEN ''' + convert(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)'  + CHAR(13)
								+ 'AND b.bettype IN (9,29)'  + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype' + CHAR(13)
		END

		--Not BA
		IF	@ProductCode IN ('', 'NG', 'SB', 'RB', 'LC', 'VS', 'BG', 'KN', 'CS', 'VB')
		BEGIN
			SELECT	@sql = @sql + '--Get data from bettrans for non - BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, t.currency, b.bettype,' + CHAR(13)
								+ 'SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
								+ 'SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE  -1 * (b.winlost - b.actual_stake) END) AS LicenseeWL,' + CHAR(13)
								+ 'SUM(comm) AS Comm,' + CHAR(13)
								+ 'SUM(b.playercomm) AS PlayerComm,' + CHAR(13)
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd, ' + CHAR(13)
								+ 'COUNT(b.transid) BetCount' + CHAR(13)
								+ 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN @TempAg t  ON b.recommend = t.custid AND b.Currency = t.Currency ' + CHAR(13)
								+ 'LEFT JOIN dbo.match m WITH (NOLOCK) ON b.matchID=m.matchID' + CHAR(13)
								+ 'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON t.custid=ba.recommend and  b.transid = BA.transid' + CHAR(13)
								+ 'WHERE b.winlostdate BETWEEN ''' + convert(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND b.Bettype <= 19999' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,901,902,903,904)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.liveindicator = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.liveindicator = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND BA.transid IS NULL' + CHAR(13)
								+ CASE 
									WHEN @ProductCode = 'NG' THEN 'AND b.bettype BETWEEN 81 AND 120 '
									WHEN @ProductCode = 'SB' THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399))'
									WHEN @ProductCode = 'RB' THEN 'AND b.bettype BETWEEN 31 AND 33'
									WHEN @ProductCode = 'LC' THEN 'AND b.bettype BETWEEN 1101 AND 1199'
									WHEN @ProductCode = 'VS' THEN 'AND b.bettype BETWEEN 1201 AND 1299'
									WHEN @ProductCode = 'BG' THEN 'AND b.bettype = 73'
									WHEN @ProductCode = 'KN' THEN 'AND b.bettype BETWEEN 1501 AND 1599'
									WHEN @ProductCode = 'CS' THEN 'AND (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399)'
									WHEN @ProductCode = 'VB' THEN 'AND b.bettype BETWEEN 4001 AND 7999'
									ELSE 'AND b.bettype NOT BETWEEN 2001 AND 2009 ' END + CHAR(13)
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype' + CHAR(13)
			--SB for parlay
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, t.currency, b.bettype,' + CHAR(13)
								+ 'SUM(stake) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
								+ 'SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,' + CHAR(13)
								+ 'SUM (comm) AS Comm,' + CHAR(13)
								+ 'SUM (b.playercomm) AS PlayerComm,' + CHAR(13)
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd, ' + CHAR(13)
								+ 'COUNT(b.transid) BetCount' + CHAR(13)
								+ 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency ' + CHAR(13)
								+ 'LEFT JOIN dbo.match m WITH (NOLOCK) ON b.matchID = m.matchID' + CHAR(13)
								+ 'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON t.custid=ba.recommend and  b.transid = BA.transid' + CHAR(13)
								+ 'WHERE b.winlostdate BETWEEN ''' + convert(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)' + CHAR(13)
								+ 'AND b.bettype IN (9,29)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND BA.transid IS NULL' + CHAR(13)
								+ CASE
									WHEN @ProductCode = 'NG' THEN 'AND b.bettype BETWEEN 81 AND 120 '
									WHEN @ProductCode = 'SB' THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999)) '
									WHEN @ProductCode = 'RB' THEN 'AND b.bettype BETWEEN 31 AND 33'
									WHEN @ProductCode = 'LC' THEN 'AND b.bettype BETWEEN 1101 AND 1199'
									WHEN @ProductCode = 'VS' THEN 'AND b.bettype BETWEEN 1201 AND 1299'
									WHEN @ProductCode = 'BG' THEN 'AND b.bettype = 73'
									WHEN @ProductCode = 'KN' THEN 'AND b.bettype BETWEEN 1501 AND 1599'
									WHEN @ProductCode = 'CS' THEN 'AND (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399)'
									WHEN @ProductCode = 'VB' THEN 'AND b.bettype BETWEEN 4001 AND 7999'
									ELSE '' END + CHAR(13)
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype	' + CHAR(13)
		END
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		--BA
		IF @ProductCode = ''
			OR @ProductCode = 'BA'
		BEGIN
			SELECT	@sql = @sql + '--Get data from rpt_Betting_BA for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID, b.bettype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (CommissionA) as Comm,'+ CHAR(13)
								+ 'SUM (CommissionP) as PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_licenseereport.dbo.rpt_Betting_BA b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #Currency c ON b.siteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,901,902,903,904)' + CHAR(13)
								+ 'AND b.siteID =' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID =' + convert(VARCHAR(10), @CurrencyID) ELSE '' END + CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)

			SELECT	@sql = @sql + '--Get data from rpt_BettingParlay for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID, b.bettype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (CommissionA) as Comm,' + CHAR(13)
								+ 'SUM (CommissionP) as PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN #Currency c ON b.siteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype IN (9,29)' + CHAR(13)
								+ 'AND b.isBA = 1' + CHAR(13)
								+ 'AND b.siteID =' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID =' + convert(VARCHAR(10), @CurrencyID) ELSE '' END + CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)
		END

		--Not BA
		IF @ProductCode IN ('', 'RB', 'NG', 'SB', 'LC', 'VS', 'BG', 'KN', 'CS', 'VB')
		BEGIN
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID, b.bettype,' + CHAR(13)
								+ 'SUM(b.turnover * CASE WHEN b.bettype=33 AND b.status IN (114,115) THEN 0.5 ELSE 1 END) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ 'SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.WinlossA ELSE  -1 * b.winloss END) AS LicenseeWL,' + CHAR(13)
								+ 'SUM(b.CommissionA) Comm,' + CHAR(13) + 'sum( b.CommissionP ) PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_licenseereport.dbo.rpt_Betting b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,1700,1800,1900,901,902,903,904)' + CHAR(13)
								+ 'AND b.CustomerCategory IN (-1, 1001)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND b.siteID =' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)
								+ CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID =' + CONVERT(VARCHAR(10), @CurrencyID) ELSE '' END + CHAR(13)
								+ CASE 
									WHEN @ProductCode = 'NG' THEN 'AND b.bettype BETWEEN 81 AND 120 '
									WHEN @ProductCode = 'SB' THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) '
									WHEN @ProductCode = 'RB' THEN 'AND b.bettype BETWEEN 31 AND 33'
									WHEN @ProductCode = 'LC' THEN 'AND b.bettype BETWEEN 1101 AND 1199'
									WHEN @ProductCode = 'VS' THEN 'AND b.bettype BETWEEN 1201 AND 1299'
									WHEN @ProductCode = 'BG' THEN 'AND b.bettype = 73'
									WHEN @ProductCode = 'KN' THEN 'AND b.bettype BETWEEN 1501 AND 1599'
									WHEN @ProductCode = 'CS' THEN 'AND (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399)'
									WHEN @ProductCode = 'VB' THEN 'AND b.bettype BETWEEN 4001 AND 7999'
									ELSE 'AND b.bettype NOT BETWEEN 2001 AND 2009' END + CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)

			-- parlay for SB			
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID, b.bettype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'sum(b.winloss) winlost,' + CHAR(13)
								+ 'SUM(-1 * b.winloss) AS LicenseeWL,' + CHAR(13)
								+ 'sum(b.CommissionA) Comm,' + CHAR(13)
								+ 'sum( b.CommissionP ) PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'sum(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + convert(VARCHAR(10), @FDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype IN (9,29)' + CHAR(13)
								+ 'AND b.isBA = 0' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND b.siteID =' + convert(VARCHAR(10), @LicenseeID) + CHAR(13)
								+ CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID =' + convert(VARCHAR(10), @CurrencyID) ELSE '' END + CHAR(13)
								+ CASE 
									WHEN @CurrencyID <> 0
										THEN 'AND b.CurrencyID =' + convert(VARCHAR(10), @CurrencyID)
									ELSE ''
									END + CHAR(13) + CASE 
									WHEN @ProductCode = 'NG' THEN 'AND b.bettype BETWEEN 81 AND 120 '
									WHEN @ProductCode = 'SB' THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) '
									WHEN @ProductCode = 'RB' THEN 'AND b.bettype BETWEEN 31 AND 33'
									WHEN @ProductCode = 'LC' THEN 'AND b.bettype BETWEEN 1101 AND 1199'
									WHEN @ProductCode = 'VS' THEN 'AND b.bettype BETWEEN 1201 AND 1299'
									WHEN @ProductCode = 'BG' THEN 'AND b.bettype = 73'
									WHEN @ProductCode = 'KN' THEN 'AND b.bettype BETWEEN 1501 AND 1599'
									WHEN @ProductCode = 'CS' THEN 'AND (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399)'
									WHEN @ProductCode = 'VB' THEN 'AND b.bettype BETWEEN 4001 AND 7999'
									ELSE '' END + CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)
		END
	END

	-- Get winlost by currency  
	SELECT	@sql = @sql + 'CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)' + CHAR(13)

	SELECT	@sql = @sql + ' SELECT * INTO #TempExchange FROM Lrf_f_GetExchangeDaily(''' + CONVERT(VARCHAR(10), @FDate, 120) + ''',''' + CONVERT(VARCHAR(10), @TDate, 120) + ''')' + CHAR(13)
						+ 'WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss ) ' + CHAR(13)

	SELECT	@sql = @sql + '-- Get winlost by currency  ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT CASE WHEN e.Code = ''VND'' THEN ''INH'' ELSE e.code END AS Currency, ' + CHAR(13)
						+ 'SUM(TurnOver) AS Turnover,' + CHAR(13)
						+ 'SUM(Winlost)  AS Winlost,' + CHAR(13)
						+ 'SUM(LicenseeWL) AS LicenseeWL,' + CHAR(13)
						+ 'SUM(Comm) AS Comm,' + CHAR(13)
						+ 'SUM(PlayerComm) AS PlayerComm,' + CHAR(13)
						+ 'SUM(AmtDueto3rd) AS AmtDueto3rd, ' + CHAR(13)
						+ 'SUM(Betcount) AS Betcount,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.EUR) AS MONEY) AS TurnoverEUR,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.EUR) AS MONEY) AS WinlostEUR,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.USD) AS MONEY) AS TurnoverUSD,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.USD) AS MONEY) AS WinlostUSD,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD, ' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD, ' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD, ' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.GBP) AS MONEY) AS TurnoverGBP,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.GBP) AS MONEY) AS WinlostGBP,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.GBP) AS MONEY) AS LicenseeWLGBP,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.GBP) AS MONEY) AS CommGBP,' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.GBP) AS MONEY) AS PlayerCommGBP,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.GBP) AS MONEY) AS AmtDueto3rdGBP' + CHAR(13)
						+ 'FROM #tmpWinloss b WITH (NOLOCK)' + CHAR(13)
						+ 'INNER JOIN #TempExchange e ' + CHAR(13)
						+ 'ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency ' + CHAR(13)
						+ 'GROUP BY CASE WHEN e.Code = ''VND'' THEN ''INH'' ELSE e.code END' + CHAR(13)
						+ 'ORDER BY CASE WHEN e.Code = ''VND'' THEN ''INH'' ELSE e.code END ' + CHAR(13)

	-- Get winlost by bettype   
	SELECT	@sql = @sql + '-- Get winlost by bettype  ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.GroupTypeID ELSE b.bettype END bettype,' + CHAR(13)
						+ 'SUM(TurnOver) AS Turnover,' + CHAR(13)
						+ 'SUM(Winlost)  AS Winlost,' + CHAR(13)
						+ 'SUM(LicenseeWL) AS LicenseeWL,' + CHAR(13)
						+ 'SUM(Comm) AS Comm,' + CHAR(13)
						+ 'SUM(PlayerComm) AS PlayerComm,' + CHAR(13)
						+ 'SUM(AmtDueto3rd) AS AmtDueto3rd,' + CHAR(13)
						+ 'SUM(Betcount) AS Betcount,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.EUR) AS MONEY) AS TurnoverEUR, ' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.EUR) AS MONEY) AS WinlostEUR,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.USD) AS MONEY) AS TurnoverUSD,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.USD) AS MONEY) AS WinlostUSD,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD,' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.GBP) AS MONEY) AS TurnoverGBP,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.GBP) AS MONEY) AS WinlostGBP,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.GBP) AS MONEY) AS LicenseeWLGBP,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.GBP) AS MONEY) AS CommGBP,' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.GBP) AS MONEY) AS PlayerCommGBP,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.GBP) AS MONEY) AS AmtDueto3rdGBP' + CHAR(13)
						+ 'FROM #tmpWinloss b  WITH (NOLOCK) ' + CHAR(13)
						+ 'LEFT JOIN dbo.f_GroupBettype() ss ON b.bettype = ss.bettype'+CHAR(13)
						+ 'INNER JOIN bettype bt WITH (nolock) ON b.bettype = bt.typeid ' + CHAR(13)
						+ 'INNER JOIN #TempExchange e' + CHAR(13)
						+ 'ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency ' + CHAR(13)
						+ 'GROUP BY CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId ELSE b.bettype END' + CHAR(13)
						+ 'ORDER BY CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.GroupTypeID ELSE b.bettype END' + CHAR(13)
						+ 'DROP TABLE #tmpWinloss' + CHAR(13)
						+ 'DROP TABLE #TempExchange' + CHAR(13)
						+ 'DROP TABLE #Currency' + CHAR(13)

	IF @Debug = 1
		PRINT @sql
	ELSE
		EXEC (@sql)
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportSummaryDetail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportSummaryDetail] TO [vnteam] AS [dbo]