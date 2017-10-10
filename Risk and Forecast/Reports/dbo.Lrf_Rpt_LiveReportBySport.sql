/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
 

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportBySport] 
	@LicenseeID		INT,	
	@ProductCodes	VARCHAR(MAX) = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Debug			BIT = 0,
	@Liveindicator	INT = 1,
	@AgentList		VARCHAR(MAX)

AS 
/*  
Created: 20111031@  
Task : Live Report Summary BY Sport  
DB: DBEXT.bodb02  
  
Revisions:  
	- 20111208@Jim: change bettype condition
	- 20120110@Henry: remove Licensee Type + Get data from rpt_Betting + remove currency UUS
	- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
    - 20120614@Jim: optimize code  
	- 20120726@Jim: add playercomm value 
	- 20120814@Henry: add live casino
	- 20120830@Henry: add Virtual Sports ...
	- 20121004@Jim: replace @currency input param by @currencyID
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130328@Scott: Support RNG Casino and Bingo
	- 20130618@Jim:  Restrict permission of Licensee Users by currency
	- 20130625@Jim: support to view currency UUS
	- 20130809@Jim: offer Virtual Horse Racing
	- 20131007@Jim: support Virtual Tennis
	- 20131129@Jim: support :
				182 – Virtual Greyhounds
				184 – Virtual Motor Racing
	- 20140404@Florent: offer 202 Keno
	- 20140410@Jim: fix bug #14715 (wrong RNG Casino sporttype)	
	- 20140602@Hannah: Separate Live/ Non - Live data in Live Report	
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20140915@Florent: hotfix duplicated VS bettype
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150127@Jim: support base on GBP Currency
	- 20150618@Patrick: #36263: Fix super balance isue for: AGC, GD & VG
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
	- 20151001@Jim: remove MicroGaming
	- 20151228@Bobby: #50469 - Remove RNG Casino - exclude OneRNG range bettype
	- 20160201@Victor: Include Bettrade original ticket [Redmine: 51053]
	- 20160218@Bobby: #52428 - Intergate RnG Casino product
	- 20160330@Percy: Support Voidbridge single wallet [Redmine: #55057]
	- 20160519@Jim: HotFix #57810
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
	- 20170705@Harper: Hotfix for Cash Out [RedmineID: #79546]
	- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170721@Harper: Hotfix add AB and FW to LiveReport [RedmineID: #80350]
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
	- 20170814@Harper: One RNG - Offer New Tablet Games [RedmineID: #78424]	
	- 20171009@Sophia: Add ProductCode [RedmineID : #82797]

Param's Explanation:
	@Liveindicator : indicate that whether the report will get live data or not
		+ 0: Non - Live data only
		+ 1: Live data only
		+ 2: All

	+ @AgentList: xml structure
				<ROOT>
				<Agent AgentId="12345" Currency="3"/>  
				<Agent AgentId="12345" Currency="5"/>  
				</ROOT> 
  
Example:  
  
DECLARE @FromDate DATETIME  
DECLARE @ToDate DATETIME  
DECLARE @MoveBetsDay DATETIME  
SELECT @FromDate = DATEADD(DAY, -15, GETDATE())  
SELECT @ToDate = GETDATE()  
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)
  
EXEC [Lrf_Rpt_LiveReportBySport]  @LicenseeId = 1,  @CurrencyID = 0, @FromDate=@FromDate, @ProductCode= NULL, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay  
  
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

	DECLARE @strbettypeVHR VARCHAR(100) =''
	SELECT	@strbettypeVHR = @strbettypeVHR + CAST(bettype AS VARCHAR) + ',' FROM dbo.f_VSHorseRacingByBettype()
	SELECT	@strbettypeVHR = SUBSTRING (@strbettypeVHR, 0, LEN(@strbettypeVHR))

	SELECT	@sql = 'SET NOCOUNT ON  ' + CHAR(13)

	--declare
	SELECT	@sql = @sql + '--Declare variable:' + CHAR(13)

	SELECT	@sql = @sql + 'DECLARE @TempAg AS TABLE (CustId INT, Currency INT)' + CHAR(13)
						+ 'CREATE TABLE #tmpWinloss (winlostdate DATETIME, Currency INT, SportType INT, TurnOver MONEY, Winlost MONEY, LicenseeWL MONEY, Comm MONEY, PlayerComm MONEY, AmtDueTo3rd MONEY, Betcount INT)' + CHAR(13)
						+ 'DECLARE @DocHandler INT' + CHAR(13)	
	
	--insert agentIds to temp table
	SELECT	@sql = @sql + 'BEGIN TRY' + CHAR(13)
						+ 'EXEC sp_xml_preparedocument @DocHandler OUTPUT ,''' + CONVERT(VARCHAR(MAX), @AgentList) + '''' + CHAR(13)
						+ 'INSERT INTO @TempAg (custID, currency)' + CHAR(13)
						+ 'SELECT AgentId, Currency' + CHAR(13)
						+ 'FROM OPENXML(@DocHandler, ''/ROOT/Agent'', 1) WITH (AgentId [int], Currency INT) AS Data' + CHAR(13)
						+ 'EXEC sp_xml_removedocument @DocHandler' + CHAR(13)
						+ 'END TRY' + CHAR(13)
						+ 'BEGIN CATCH' + CHAR(13)
						+ 'SELECT ErrCode = 100, ErrMsg = N''Paramter invalid.''' + CHAR(13)
						+ 'RETURN' + CHAR(13)
						+ 'END CATCH;' + CHAR(13)
						+ 'CREATE TABLE #currency(currency INT)' + CHAR(13)
						+ 'INSERT INTO #currency(currency)' + CHAR(13)
						+ 'SELECT DISTINCT Currency' + CHAR(13)
						+ 'FROM @TempAg' + CHAR(13)

	IF @ProductCodes IS NULL
		SET @ProductCodes = ''
	
	CREATE TABLE #ProductCodes (ProductCode VARCHAR(10))

	INSERT INTO #ProductCodes (ProductCode)
	SELECT	ISNULL(Val,'') 	
	FROM	dbo.strSplit(@ProductCodes,',')  

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'BA'))
		BEGIN
			SELECT	@sql = @sql + '--Get data from bettrans for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, b.currency,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 -- Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'ELSE m.SportType END as Sporttype,' + CHAR(13)
								+ 'SUM(Stake) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (comm) AS Comm,' + CHAR(13)
								+ 'SUM (playercomm) AS PlayerComm,' + CHAR(13)
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,' + CHAR(13)
								+ 'COUNT(b.transid) BetCount' + CHAR(13)
								+ 'FROM bettrans b  WITH (NOLOCK) ' + CHAR(13)
								+ 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active ba WITH (NOLOCK) ON b.recommend=ba.recommend and b.transid = ba.transid' + CHAR(13)
								+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency ' + CHAR(13)
								+ 'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid' + CHAR(13)
								+ 'WHERE b.winlostdate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.liveindicator = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.liveindicator = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY  b.winlostdate, b.currency, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'ELSE m.SportType END ' + CHAR(13)
			--BA for parlay
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, b.currency,' + CHAR(13)
								+ 'CASE' + CHAR(13) + 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'END as Sporttype,' + CHAR(13)
								+ 'SUM(Stake) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost, ' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (comm) AS Comm,' + CHAR(13)
								+ 'SUM ( playercomm  ) AS PlayerComm,' + CHAR(13)
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,' + CHAR(13)
								+ 'COUNT(b.transid) BetCount' + CHAR(13)
								+ 'FROM bettrans b  WITH (NOLOCK) ' + CHAR(13)
								+ 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active ba WITH (NOLOCK) ON b.recommend=ba.recommend and b.transid = ba.transid' + CHAR(13)
								+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.currency = t.currency ' + CHAR(13)
								+ 'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid' + CHAR(13)
								+ 'WHERE b.winlostdate BETWEEN ''' + convert(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)' + CHAR(13)
								+ 'AND b.bettype IN (9,29,2799)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY  b.winlostdate, b.currency, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'END ' + CHAR(13)
		END
 
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'RB', 'NG', 'SB', 'LC', 'VS', 'BG', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT'))		
		BEGIN
			SELECT	@sql = @sql + '--Get data from bettrans for non-BA' + CHAR(13)

			SELECT	@sql = @sql + '--Get data for Virtual Horse Racing,Virtual Greyhounds,Virtual Motor Racing ' + CHAR(13)

			SELECT	@sql = @sql + 'SELECT DISTINCT o.Orid, r.SportType INTO #tmpVS' + CHAR (13)
								+ 'FROM VSOutright o WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID' + CHAR(13)
								+ 'WHERE EventDate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, b.currency,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 31 AND 33 THEN l.Sporttype' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161 --NG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1101 AND 1199 THEN 162 --LC' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202 --Keno''s bettype' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1201 AND 1299) AND b.bettype NOT IN (1231,1232,1233,1237,1238,1220,1235,1236) THEN 180 --VS' + CHAR(13)
								+ 'WHEN b.bettype IN ('+@strbettypeVHR+') THEN vs.SportType ' + CHAR(13)
								+ 'WHEN b.bettype IN (1220,1235,1236) THEN 186 ' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- Mix Parlay Betradar' + CHAR(13)
								+ 'WHEN b.bettype = 73 THEN 252 -- Bingo' + CHAR(13)		
								+ 'WHEN b.bettype = 71 THEN 251 -- Casino' + CHAR(13)		
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208 -- New Casino' + CHAR(13)		
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209 -- New Casino' + CHAR(13)		
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210 -- New Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 7999 THEN 212' + CHAR(13)								
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219 -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211 -- AllBet' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN 220 -- Lottery' + CHAR(13)
								+ 'ELSE m.SportType END as Sporttype,' + CHAR(13)
								+ 'SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
								+ 'SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE -1 * (b.winlost - b.actual_stake) END) AS LicenseeWL,' + CHAR(13)
								+ 'SUM (comm) AS Comm,' + CHAR(13)
								+ 'SUM (playercomm) AS PlayerComm,' + CHAR(13)
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,' + CHAR(13)
								+ 'COUNT(b.transid) BetCount' + CHAR(13)
								+ 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency' + CHAR(13)
								+ 'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend AND b.transid = BA.transid' + CHAR(13)
								+ 'LEFT JOIN outright o with(nolock) ON b.matchid = o.orid' + CHAR(13)
								+ 'LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid' + CHAR(13)
								+ 'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid AND b.bettype NOT IN ('+@strbettypeVHR+') ' + CHAR(13)
								+ 'LEFT JOIN #tmpVS vs ON b.oddsid=vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)' + CHAR(13)
								+ 'WHERE b.winlostdate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.liveindicator = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.liveindicator = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904,1700,1800,1900,18000)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)' + CHAR(13) + 'AND BA.transid IS NULL' + CHAR(13)
								+ CASE
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','NG')) = 1 THEN 'AND b.bettype BETWEEN 81 AND 120 '
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SB')) = 1 THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399))'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','RB')) = 1 THEN 'AND b.bettype BETWEEN 31 AND 33'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LC')) = 1 THEN 'AND b.bettype BETWEEN 1101 AND 1199'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS')) = 1 THEN 'AND b.bettype BETWEEN 1201 AND 1299'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','BG')) = 1 THEN 'AND b.bettype = 73'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','KN')) = 1 THEN 'AND b.bettype BETWEEN 1501 AND 1599'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CS')) = 1 THEN 'AND (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999)'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VB')) = 1 THEN 'AND (b.bettype BETWEEN 4001 AND 7999)'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','FW')) = 1 THEN 'AND b.bettype BETWEEN 1011 AND 1020'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','AB')) = 1 THEN 'AND b.bettype BETWEEN 2401 AND 2499'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS2')) = 1 THEN 'AND b.bettype BETWEEN 2701 AND 2799'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LT')) = 1 THEN 'AND b.bettype BETWEEN 1021 AND 1049'
									ELSE 'AND b.bettype NOT BETWEEN 2001 AND 2009 AND b.bettype NOT BETWEEN 4001 AND 4099 AND b.bettype NOT BETWEEN 2501 AND 2699 ' END + CHAR(13)
								+ 'GROUP BY  b.winlostdate, b.currency,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 31 AND 33 THEN l.Sporttype' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161 --NG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1101 AND 1199 THEN 162 --LC' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202 --Keno''s bettype' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1201 AND 1299) AND b.bettype NOT IN (1231,1232,1233,1237,1238,1220,1235,1236) THEN 180 --VS' + CHAR(13)
								+ 'WHEN b.bettype IN (1231,1232,1233,1237,1238) THEN vs.SportType ' + CHAR(13)
								+ 'WHEN b.bettype IN (1220,1235,1236) THEN 186 ' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- Mix Parlay Betradar' + CHAR(13)
								+ 'WHEN b.bettype = 73 THEN 252 -- Bingo' + CHAR(13)
								+ 'WHEN b.bettype = 71 THEN 251 -- Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208 -- New Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209 -- New Casino' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210 -- New Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 7999 THEN 212' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219 -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211 -- AllBet' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN 220 -- Lottery' + CHAR(13)
								+ 'ELSE m.SportType END ' + CHAR(13)

			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'SB'))		
			BEGIN
				--SB for parlay
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13) 
									+ 'SELECT b.winlostdate, b.currency,' + CHAR(13)
									+ 'CASE' + CHAR(13)
									+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
									+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
									+ 'END as Sporttype,' + CHAR(13)
									+ 'SUM(stake) turnover,' + CHAR(13)
									+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
									+ 'SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,' + CHAR(13)
									+ 'SUM (comm) AS Comm,' + CHAR(13)
									+ 'SUM ( playercomm  ) AS PlayerComm,' + CHAR(13)
									+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,' + CHAR(13)
									+ 'COUNT(b.transid) BetCount' + CHAR(13)
									+ 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13)
									+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency' + CHAR(13)
									+ 'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend AND b.transid = BA.transid' + CHAR(13)
									+ 'LEFT JOIN outright o with(nolock) ON b.matchid = o.orid' + CHAR(13)
									+ 'LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid' + CHAR(13)
									+ 'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid' + CHAR(13)
									+ 'WHERE b.winlostdate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
									+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
									+ 'AND b.bettype IN (9,29)' + CHAR(13)
									+ 'AND b.statusID IN (111,112,113)' + CHAR(13) + 'AND BA.transid IS NULL' + CHAR(13)
									+ 'GROUP BY  b.winlostdate, b.currency,' + CHAR(13)
									+ 'CASE' + CHAR(13)
									+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
									+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
									+ 'END ' + CHAR(13)
			END

			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'VS2'))		
			BEGIN
				-- Betradar for parlay
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13) 
									+ 'SELECT b.winlostdate, b.currency,' + CHAR(13)								
									+ '104 as Sporttype,' + CHAR(13)
									+ 'SUM(stake) turnover,' + CHAR(13)
									+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
									+ 'SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,' + CHAR(13)
									+ 'SUM (comm) AS Comm,' + CHAR(13)
									+ 'SUM ( playercomm  ) AS PlayerComm,' + CHAR(13)
									+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,' + CHAR(13)
									+ 'COUNT(b.transid) BetCount' + CHAR(13)
									+ 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13)
									+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency' + CHAR(13)
									+ 'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend AND b.transid = BA.transid' + CHAR(13)
									+ 'LEFT JOIN outright o with(nolock) ON b.matchid = o.orid' + CHAR(13)
									+ 'LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid' + CHAR(13)
									+ 'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid' + CHAR(13)
									+ 'WHERE b.winlostdate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
									+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
									+ 'AND b.bettype IN (2799)' + CHAR(13)
									+ 'AND b.statusID IN (111,112,113)' + CHAR(13) + 'AND BA.transid IS NULL' + CHAR(13)
									+ 'GROUP BY  b.winlostdate, b.currency' + CHAR(13)								
			END
			SELECT	@sql = @sql + 'DROP TABLE #tmpVS' + CHAR(13)
		END
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		--BA
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'BA'))
		BEGIN
			SELECT	@sql = @sql + '--Get data from rpt_Betting_BA for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
								+ 'CASE' + CHAR(13) + 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'ELSE l.SportType END as Sporttype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM(CommissionA) as Comm,' + CHAR(13)
								+ 'SUM(CommissionP) as PlayerComm,'+ CHAR(13)
								+ '- SUM(b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_LicenseeReport.dbo.rpt_Betting_BA b WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN #currency c ON b.CurrencyID=c.Currency' + CHAR(13)
								+ 'LEFT JOIN league l WITH (NOLOCK) ON b.LeagueID = l.LeagueID' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND b.siteID =' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)								
								+ 'GROUP BY b.rptDate, b.currencyID, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'ELSE l.SportType END ' + CHAR(13)
			
			-- Parlay for BA
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'END AS Sporttype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (CommissionA) AS Comm,' + CHAR(13)
								+ 'SUM (CommissionP  ) AS PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #currency c ON b.CurrencyID = c.Currency' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype IN (9 ,29, 2799)' + CHAR(13)
								+ 'AND b.isBA = 1' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))' + CHAR(13)
								+ 'AND b.siteID =' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)								
								+ 'GROUP BY b.rptDate, b.currencyID, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'END' + CHAR(13)
		END

		--Not BA	
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'RB', 'NG', 'SB', 'LC', 'VS', 'BG', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT')	)
		BEGIN			
			SELECT	@sql = @sql + '--Get data from rpt_Betting for non-BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype  = 10 THEN 103' + CHAR(13)
								+ 'WHEN b.bettype  = 73	THEN 252' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202' + CHAR(13)
								+ 'WHEN b.bettype = 71 THEN 251' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 7999 THEN 212' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN 220' + CHAR(13)
								+ 'ELSE ISNULL(l.sporttype, 0)' + CHAR(13)
								+ 'END AS SportType,' + CHAR(13)
								+ 'SUM(b.turnover * CASE WHEN b.bettype=33 AND b.status IN (114,115) THEN 0.5 ELSE 1 END) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ 'SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.WinlossA ELSE  -1 * b.winloss END) AS LicenseeWL,' + CHAR(13)
								+ 'SUM(b.CommissionA) Comm,' + CHAR(13)
								+ 'SUM(b.CommissionP  ) PlayerComm,' + CHAR(13)
								+ '- SUM(b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_licenseereport.dbo.rpt_Betting b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #currency c ON b.CurrencyID = c.Currency' + CHAR(13)
								+ 'LEFT JOIN league l WITH (NOLOCK) ON b.LeagueID = l.LeagueID' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,1700,1800,1900,901,902,903,904,18000)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND b.CustomerCategory IN (-1, 1001, 1003)' + CHAR(13)
								+ 'AND b.siteID = ' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)								
								+ CASE 
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','NG')) = 1 THEN 'AND b.bettype BETWEEN 81 AND 120 '
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SB')) = 1 THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399))'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','RB')) = 1 THEN 'AND b.bettype BETWEEN 31 AND 33'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LC')) = 1 THEN 'AND b.bettype BETWEEN 1101 AND 1199'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS')) = 1 THEN 'AND b.bettype BETWEEN 1201 AND 1299'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','BG')) = 1 THEN 'AND b.bettype = 73'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','KN')) = 1 THEN 'AND b.bettype BETWEEN 1501 AND 1599'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CS')) = 1 THEN 'AND (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999)'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VB')) = 1 THEN 'AND (b.bettype BETWEEN 4001 AND 7999)'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','FW')) = 1 THEN 'AND b.bettype BETWEEN 1011 AND 1020'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','AB')) = 1 THEN 'AND b.bettype BETWEEN 2401 AND 2499'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS2')) = 1 THEN 'AND b.bettype BETWEEN 2701 AND 2799'
									WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LT')) = 1 THEN 'AND b.bettype BETWEEN 1021 AND 1049'
									ELSE 'AND b.bettype NOT BETWEEN 2001 AND 2009 AND b.bettype NOT BETWEEN 4001 AND 4099 AND b.bettype NOT BETWEEN 2501 AND 2699 ' END + CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype  = 10 THEN 103' + CHAR(13)
								+ 'WHEN b.bettype  = 73	THEN 252' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202' + CHAR(13)
								+ 'WHEN b.bettype = 71 THEN 251' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 7999 THEN 212' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN 220' + CHAR(13)
								+ 'ELSE ISNULL(l.sporttype, 0)' + CHAR(13)
								+ 'END' + CHAR(13)
			
			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'SB'))
			BEGIN	
				-- parlay for SB
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
									+ 'SELECT ' + CHAR(13) + 'b.rptDate,' + CHAR(13) + 'b.currencyID,' + CHAR(13)
									+ 'CASE' + CHAR(13)
									+ 'WHEN b.bettype = 9 THEN 101' + CHAR(13)
									+ 'WHEN b.bettype = 29 THEN 102' + CHAR(13)
									+ 'END AS SportType,' + CHAR(13)
									+ 'SUM(b.turnover) turnover,' + CHAR(13)
									+ 'SUM(b.winloss) winlost,' + CHAR(13)
									+ 'SUM(-1 * b.winloss) AS LicenseeWL,' + CHAR(13)
									+ 'SUM(b.CommissionA) Comm,' + CHAR(13) + 'sum(b.CommissionP) PlayerComm,' + CHAR(13)
									+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
									+ 'SUM(b.betcount) BetCount' + CHAR(13)
									+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH (NOLOCK)' + CHAR(13)
									+ 'INNER JOIN #currency c ON b.CurrencyID = c.Currency' + CHAR(13)
									+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
									+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
									+ 'AND b.bettype IN (9,29)' + CHAR(13)
									+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
									+ 'AND b.siteID =' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)
									+ 'AND b.isBA = 0' + CHAR(13)
									+ 'GROUP BY b.rptDate, b.currencyID,' + CHAR(13)
									+ 'CASE' + CHAR(13)
									+ 'WHEN b.bettype = 9 THEN 101' + CHAR(13)
									+ 'WHEN b.bettype = 29 THEN 102' + CHAR(13)
									+ 'END' + CHAR(13)
			END

			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'VS2'))
			BEGIN
				-- parlay for BetRadar			
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
									+ 'SELECT ' + CHAR(13) + 'b.rptDate,' + CHAR(13) + 'b.currencyID,' + CHAR(13)
									+ '104 AS SportType,' + CHAR(13)
									+ 'SUM(b.turnover) turnover,' + CHAR(13)
									+ 'SUM(b.winloss) winlost,' + CHAR(13)
									+ 'SUM(-1 * b.winloss) AS LicenseeWL,' + CHAR(13)
									+ 'SUM(b.CommissionA) Comm,' + CHAR(13) + 'sum(b.CommissionP) PlayerComm,' + CHAR(13)
									+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
									+ 'SUM(b.betcount) BetCount' + CHAR(13)
									+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH (NOLOCK)' + CHAR(13)
									+ 'INNER JOIN #currency c ON b.CurrencyID = c.Currency' + CHAR(13)
									+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
									+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
									+ 'AND b.bettype IN (2799)' + CHAR(13)
									+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
									+ 'AND b.siteID =' + CONVERT(VARCHAR(10), @LicenseeID) + CHAR(13)
									+ 'AND b.isBA = 0' + CHAR(13)					
									+ 'GROUP BY b.rptDate, b.currencyID' + CHAR(13)	
			END
		END
	END

	-- Get winlost BY Sport   
	SELECT	@sql = @sql + '-- Get winlost by Sport  ' + CHAR(13)

	SELECT	@sql = @sql + 'CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)  ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT * INTO #TempExchange FROM Lrf_f_GetExchangeDaily(''' + CONVERT(VARCHAR(10), @FDate, 120) + ''',''' + CONVERT(VARCHAR(10), @TDate, 120) + ''')' + CHAR(13)
						+ 'WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss ) ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT b.SportType, ' + CHAR(13)
						+ 'SUM(TurnOver) AS Turnover,' + CHAR(13)
						+ 'SUM(Winlost)  AS Winlost,' + CHAR(13)
						+ 'SUM(LicenseeWL) AS LicenseeWL,' + CHAR(13)
						+ 'SUM(Comm) AS Comm,' + CHAR(13)
						+ 'SUM(Playercomm) AS PlayerComm,' + CHAR(13)
						+ 'SUM(AmtDueto3rd) AS AmtDueto3rd, ' + CHAR(13)
						+ 'SUM(Betcount) AS Betcount,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.EUR) AS MONEY) AS TurnoverEUR,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.EUR) AS MONEY) AS WinlostEUR,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,' + CHAR(13)
						+ 'CAST(SUM(Playercomm * e.EUR) AS MONEY) AS PlayerCommEUR,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.USD) AS MONEY) AS TurnoverUSD,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.USD) AS MONEY) AS WinlostUSD,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD, ' + CHAR(13)
						+ 'CAST(SUM(Playercomm * e.USD) AS MONEY) AS PlayerCommUSD, ' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD, ' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.GBP) AS MONEY) AS TurnoverGBP,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.GBP) AS MONEY) AS WinlostGBP,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.GBP) AS MONEY) AS LicenseeWLGBP,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.GBP) AS MONEY) AS CommGBP, ' + CHAR(13)
						+ 'CAST(SUM(Playercomm * e.GBP) AS MONEY) AS PlayerCommGBP, ' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.GBP) AS MONEY) AS AmtDueto3rdGBP ' + CHAR(13)
						+ 'FROM #tmpWinloss b ' + CHAR(13)
						+ 'INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency ' + CHAR(13)
						+ 'GROUP BY b.SportType' + CHAR(13)
						+ 'DROP TABLE #tmpWinloss' + CHAR(13)
						+ 'DROP TABLE #TempExchange' + CHAR(13)	
						+ 'DROP TABLE #currency' + CHAR(13)					

	IF (@debug = 1)
		PRINT @sql
	ELSE
		EXEC (@sql)
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportBySport] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportBySport] TO [vnteam] 
