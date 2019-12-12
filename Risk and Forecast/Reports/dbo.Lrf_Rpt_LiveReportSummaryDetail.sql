/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummaryDetail]
	@ProductCodes	VARCHAR(MAX) = NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Debug			BIT = 0,
	@Liveindicator	INT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
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
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
	- 20170705@Harper: Hotfix for Cash Out [RedmineID: #79546]
	- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170705@Harper: Hotfix for Cash Out [RedmineID: #79546]
	- 20170721@Harper: Hotfix add AB and FW to LiveReport [RedmineID: #80350]	
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
	- 20170814@Harper: One RNG - Offer New Tablet Games [RedmineID: #78424]
	- 20171009@Sophia: Add ProductCode [RedmineID : #82797]
	- 20180205@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
	- 20180515@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
	- 20180418@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92318]
	- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
	- 20181101@Amanda: Remove parameter @LicenseeId [Redmine: #103935]
	- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
	- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
	- 20190304@Amanda: Integrate PP Promotion Prize [RedmineID: #109471]
	- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
	- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
	- 20191121@Amanda: Exclude PP Promotion and Tournament Prize [RedmineID: #123804]
	- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
	- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
	
Param's Explanation:  
	+ @Liveindicator : indicate that whether the report will get live data or not
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
  
EXEC [Lrf_Rpt_LiveReportSummaryDetail] @CurrencyID = 0, @FromDate=@FromDate, @ProductCode= NULL, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay  
  
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

	SELECT	@sql = 'SET NOCOUNT ON  ' + CHAR(13)

	--declare
	SELECT	@sql = @sql + '--Declare variable:' + CHAR(13)

	SELECT	@sql = @sql + 'DECLARE @TempAg TABLE (CustId INT, Currency INT)' + CHAR(13)
						+ 'CREATE TABLE #tmpWinloss (winlostdate DATETIME, Currency INT, ProductCode VARCHAR(10), BetType INT, TurnOver MONEY, Winlost MONEY, LicenseeWL MONEY, Comm MONEY, PlayerComm MONEY, AmtDueTo3rd MONEY, Betcount INT)' + CHAR(13)
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
						+ 'CREATE TABLE #LicenseeList(LicenseeID INT, Currency INT)' + CHAR(13)
						+ 'CREATE CLUSTERED INDEX IX_LicenseeList_cl ON #LicenseeList(LicenseeID, Currency)' + CHAR(13)
						+ 'INSERT INTO #LicenseeList(LicenseeID, Currency)' + CHAR(13)
						+ 'SELECT DISTINCT LicenseeID, Currency' + CHAR(13)
						+ 'FROM bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK)' + CHAR(13)
						+ 'WHERE EXISTS(' + CHAR(13)
						+ '		   SELECT 1' + CHAR(13)
						+ '		   FROM @TempAg t' + CHAR(13)
						+ '		   WHERE t.CustId = lc.CustID' + CHAR(13)
						+ '			   AND t.Currency = lc.Currency' + CHAR(13)
						+ '	   )' + CHAR(13)


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

		--BA
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'BA'))
		BEGIN
			SELECT	@sql = @sql + '-- Get data from bettrans for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13) 
								+ 'SELECT ' + CHAR(13) + 'b.winlostdate, ' + CHAR(13) + 't.currency,' + CHAR(13) 
								+ '''BA'' AS ProductCode,' + CHAR(13)
								+ 'b.bettype,' + CHAR(13) 
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
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904)'  + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)'  + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.liveindicator = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.liveindicator = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype' + CHAR(13)

			--BA for parlay
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, t.currency,' + CHAR(13)
								+ '''BA'' AS ProductCode,' + CHAR(13)
								+ 'b.bettype,' + CHAR(13)
								+ 'SUM(stake) turnover,' + CHAR(13)
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
								+ 'AND b.bettype IN (9,29,2799)'  + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype' + CHAR(13)
		END

		--Not BA, -- exclude PP Prize 4300, 4299
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'NG', 'SB', 'VS', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP', 'CC', 'SG'))

		BEGIN
			SELECT	@sql = @sql + '--Get data from bettrans for non - BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, t.currency, '
								+ 'CASE' + CHAR(13)		
								+ 'WHEN b.bettype <= 30 OR b.bettype BETWEEN 121 AND 999 OR b.Bettype BETWEEN 1301 and 1399 OR b.Bettype BETWEEN 9001 and 9086 OR b.Bettype = 38 THEN ''SB''' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN ''NG''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1201 AND 1299 THEN ''VS''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN ''KN'' -- Keno' + CHAR(13)
								+ 'WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN ''CS'' -- RNG CASINO' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN ''VB'' -- Voidbridge' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN ''FW'' -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN ''AB'' -- AllBet' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN ''VS2''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN ''LT''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4298 THEN ''PP''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN ''CC''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4301 AND 4600 THEN ''SG''' + CHAR(13)
								+ 'END AS ProductCode,' + CHAR(13)
								+ 'b.bettype,' + CHAR(13)
								+ 'SUM(stake) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
								+ '- SUM(b.winlost - b.actual_stake) AS LicenseeWL,' + CHAR(13)
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
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904,1700,1800,1900,18000)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.liveindicator = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.liveindicator = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND BA.transid IS NULL' + CHAR(13) + 'AND (1 <> 1' + CHAR(13)
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','NG')) = 1 THEN 'OR (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) '+ CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SB')) = 1 THEN 'OR (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399) OR (b.Bettype BETWEEN 9001 and 9086) OR b.Bettype = 38)' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS')) = 1 THEN 'OR b.bettype BETWEEN 1201 AND 1299' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','KN')) = 1 THEN 'OR b.bettype BETWEEN 1501 AND 1599' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CS')) = 1 THEN 'OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VB')) = 1 THEN 'OR (b.bettype BETWEEN 4001 AND 4100)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','FW')) = 1 THEN 'OR b.bettype BETWEEN 1011 AND 1020' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','AB')) = 1 THEN 'OR b.bettype BETWEEN 2401 AND 2499' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS2')) = 1 THEN 'OR b.bettype BETWEEN 2701 AND 2829' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LT')) = 1 THEN 'OR b.bettype BETWEEN 1021 AND 1049' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','PP')) = 1 THEN 'OR b.bettype BETWEEN 4101 AND 4298' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CC')) = 1 THEN 'OR b.bettype BETWEEN 1901 AND 1999' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SG')) = 1 THEN 'OR b.bettype BETWEEN 4301 AND 4600' + CHAR(13) ELSE '' END
								+ ') ' + CHAR(13)
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype,' + CHAR(13)
								+ 'CASE' + CHAR(13)		
								+ 'WHEN b.bettype <= 30 OR b.bettype BETWEEN 121 AND 999 OR b.Bettype BETWEEN 1301 and 1399 OR b.Bettype BETWEEN 9001 and 9086 OR b.Bettype = 38 THEN ''SB''' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN ''NG''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1201 AND 1299 THEN ''VS''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN ''KN'' -- Keno' + CHAR(13)
								+ 'WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN ''CS'' -- RNG CASINO' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN ''VB'' -- Voidbridge' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN ''FW'' -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN ''AB'' -- AllBet' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN ''VS2''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN ''LT''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4298 THEN ''PP''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN ''CC''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN ''SG''' + CHAR(13)
								+ 'END' + CHAR(13)
			

			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'SB'))
			BEGIN
				--SB for parlay
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
									+ 'SELECT b.winlostdate, t.currency,' + CHAR(13)
									+ '''SB'' AS ProductCode,' + CHAR(13)
									+ 'b.bettype,' + CHAR(13)
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
								+ 'GROUP BY  b.winlostdate, t.currency, b.bettype	' + CHAR(13)
			END

			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'VS2'))
			BEGIN
				-- Parlay of BetRadar
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
									+ 'SELECT b.winlostdate, t.currency,' + CHAR(13)
									+ '''VS2'' AS ProductCode,' + CHAR(13)
									+ 'b.bettype,' + CHAR(13)
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
									+ 'AND b.bettype IN (2799)' + CHAR(13)
									+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
									+ 'AND BA.transid IS NULL' + CHAR(13)									
									+ 'GROUP BY  b.winlostdate, t.currency, b.bettype	' + CHAR(13)
			END		
		END
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		--BA
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'BA'))
		BEGIN
			SELECT	@sql = @sql + '--Get data from rpt_Betting_BA for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID,'
								+ '''BA'' AS ProductCode,' + CHAR(13)
								+ 'b.bettype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (CommissionA) as Comm,'+ CHAR(13)
								+ 'SUM (CommissionP) as PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_licenseereport.dbo.rpt_Betting_BA b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)								
								+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)

			SELECT	@sql = @sql + '--Get data from rpt_BettingParlay for BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
								+ '''BA'' AS ProductCode,' + CHAR(13)
								+ 'b.bettype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '0 AS LicenseeWL,' + CHAR(13)
								+ 'SUM (CommissionA) as Comm,' + CHAR(13)
								+ 'SUM (CommissionP) as PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype IN (9,29,2799)' + CHAR(13)
								+ 'AND b.isBA = 1' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)
		END

		--Not BA, -- exclude PP Prize 4300, 4299
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'NG', 'SB', 'VS', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP', 'CC', 'SG'))			
		BEGIN
			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
								+ 'CASE' + CHAR(13)		
								+ 'WHEN b.bettype <= 30 OR b.bettype BETWEEN 121 AND 999 OR b.Bettype BETWEEN 1301 and 1399 OR b.Bettype BETWEEN 9001 and 9086 OR b.Bettype = 38 THEN ''SB''' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN ''NG''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1201 AND 1299 THEN ''VS''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN ''KN'' -- Keno' + CHAR(13)
								+ 'WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN ''CS'' -- RNG CASINO' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN ''VB'' -- Voidbridge' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN ''FW'' -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN ''AB'' -- AllBet' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN ''VS2''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN ''LT''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4298 THEN ''PP''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN ''CC''' + CHAR(13)
								+ 'END AS ProductCode,' + CHAR(13)
								+ 'b.bettype,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '- SUM(b.winloss) AS LicenseeWL,' + CHAR(13)
								+ 'SUM(b.CommissionA) Comm,' + CHAR(13) + 'sum( b.CommissionP ) PlayerComm,' + CHAR(13)
								+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_licenseereport.dbo.rpt_Betting b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,1700,1800,1900,901,902,903,904,18000)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND b.CustomerCategory IN (-1, 1001, 1003)' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND (1 <> 1' + CHAR(13)
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','NG')) = 1 THEN 'OR (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) '+ CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SB')) = 1 THEN 'OR (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399) OR (b.Bettype BETWEEN 9001 and 9086) OR b.Bettype = 38)' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS')) = 1 THEN 'OR b.bettype BETWEEN 1201 AND 1299' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','KN')) = 1 THEN 'OR b.bettype BETWEEN 1501 AND 1599' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CS')) = 1 THEN 'OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VB')) = 1 THEN 'OR (b.bettype BETWEEN 4001 AND 4100)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','FW')) = 1 THEN 'OR b.bettype BETWEEN 1011 AND 1020' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','AB')) = 1 THEN 'OR b.bettype BETWEEN 2401 AND 2499' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS2')) = 1 THEN 'OR b.bettype BETWEEN 2701 AND 2829' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LT')) = 1 THEN 'OR b.bettype BETWEEN 1021 AND 1049' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','PP')) = 1 THEN 'OR b.bettype BETWEEN 4101 AND 4298' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CC')) = 1 THEN 'OR b.bettype BETWEEN 1901 AND 1999' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SG')) = 1 THEN 'OR b.bettype BETWEEN 4301 AND 4600' + CHAR(13) ELSE '' END 
								+ ') ' + CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, b.bettype,' + CHAR(13)
								+ 'CASE' + CHAR(13)		
								+ 'WHEN b.bettype <= 30 OR b.bettype BETWEEN 121 AND 999 OR b.Bettype BETWEEN 1301 and 1399 OR b.Bettype BETWEEN 9001 and 9086 OR b.Bettype = 38 THEN ''SB''' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN ''NG''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1201 AND 1299 THEN ''VS''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN ''KN'' -- Keno' + CHAR(13)
								+ 'WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 THEN ''CS'' -- RNG CASINO' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN ''VB'' -- Voidbridge' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN ''FW'' -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN ''AB'' -- AllBet' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN ''VS2''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1049 THEN ''LT''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4298 THEN ''PP''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN ''CC''' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN ''SG''' + CHAR(13)
								+ 'END' + CHAR(13)


			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'SB'))
			BEGIN
				-- parlay for SB			
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
									+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
									+ '''SB'' AS ProductCode,' + CHAR(13)
									+ 'b.bettype,' + CHAR(13)
									+ 'SUM(b.turnover) turnover,' + CHAR(13)
									+ 'sum(b.winloss) winlost,' + CHAR(13)
									+ 'SUM(-1 * b.winloss) AS LicenseeWL,' + CHAR(13)
									+ 'sum(b.CommissionA) Comm,' + CHAR(13)
									+ 'sum( b.CommissionP ) PlayerComm,' + CHAR(13)
									+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
									+ 'sum(b.betcount) BetCount' + CHAR(13)
									+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )' + CHAR(13)
									+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
									+ 'WHERE b.rptDate BETWEEN ''' + convert(VARCHAR(10), @FDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
									+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
									+ 'AND b.bettype IN (9,29)' + CHAR(13)
									+ 'AND b.isBA = 0' + CHAR(13)
									+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)					
									+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)
			END

			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'VS2'))
			BEGIN
				-- Parlay for BetRadar		
				SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
									+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
									+ '''VS2'' AS ProductCode,' + CHAR(13)
									+ 'b.bettype,' + CHAR(13)
									+ 'SUM(b.turnover) turnover,' + CHAR(13)
									+ 'sum(b.winloss) winlost,' + CHAR(13)
									+ 'SUM(-1 * b.winloss) AS LicenseeWL,' + CHAR(13)
									+ 'sum(b.CommissionA) Comm,' + CHAR(13)
									+ 'sum( b.CommissionP ) PlayerComm,' + CHAR(13)
									+ '- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
									+ 'sum(b.betcount) BetCount' + CHAR(13)
									+ 'FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )' + CHAR(13)
									+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
									+ 'WHERE b.rptDate BETWEEN ''' + convert(VARCHAR(10), @FDate, 120) + ''' AND ''' + convert(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
									+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
									+ 'AND b.bettype IN (2799)' + CHAR(13)
									+ 'AND b.isBA = 0' + CHAR(13)
									+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
									+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)		
									+ 'GROUP BY b.rptDate, b.currencyID, b.bettype' + CHAR(13)
			END
		END
	END

	-- Get winlost by currency  
	SELECT	@sql = @sql + 'CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)' + CHAR(13)

	SELECT	@sql = @sql + ' SELECT FromDate, ToDate, ExchangeID, Rate INTO #TempExchange FROM Lrf_f_GetExchangeRate(''' + CONVERT(VARCHAR(10), @FDate, 120) + ''',''' + CONVERT(VARCHAR(10), @TDate, 120) + ''',''' + @BaseCurrency + ''','''''  + ')' + CHAR(13)
						+ 'WHERE ExchangeID IN (SELECT DISTINCT Currency FROM #tmpWinloss ) ' + CHAR(13)

	SELECT	@sql = @sql + '-- Get winlost by currency  ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT b.currency AS Currency, ' + CHAR(13)
						+ 'SUM(Betcount) AS Betcount,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.Rate) AS MONEY) AS Turnover,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.Rate) AS MONEY) AS Winlost,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.Rate) AS MONEY) AS LicenseeWL,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm,' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.Rate) AS MONEY) AS AmtDueto3rd' + CHAR(13)
						+ 'FROM #tmpWinloss b WITH (NOLOCK)' + CHAR(13)
						+ 'INNER JOIN #TempExchange e ' + CHAR(13)
						+ 'ON b.winlostdate BETWEEN e.FromDate AND e.ToDate AND e.exchangeid = b.currency ' + CHAR(13)
						+ 'GROUP BY b.currency' + CHAR(13)

	-- Get winlost by bettype   
	SELECT	@sql = @sql + '-- Get winlost by bettype  ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT b.ProductCode, CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.GroupTypeID ELSE b.bettype END bettype,' + CHAR(13)
						+ 'SUM(Betcount) AS Betcount,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.Rate) AS MONEY) AS Turnover, ' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.Rate) AS MONEY) AS Winlost,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.Rate) AS MONEY) AS LicenseeWL,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm,' + CHAR(13)
						+ 'CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.Rate) AS MONEY) AS AmtDueto3rd' + CHAR(13)
						+ 'FROM #tmpWinloss b  WITH (NOLOCK) ' + CHAR(13)
						+ 'LEFT JOIN dbo.f_GroupBettype() ss ON b.bettype = ss.bettype'+CHAR(13)
						+ 'INNER JOIN bettype bt WITH (nolock) ON b.bettype = bt.typeid ' + CHAR(13)
						+ 'INNER JOIN #TempExchange e' + CHAR(13)
						+ 'ON b.winlostdate BETWEEN e.FromDate AND e.ToDate AND e.exchangeid = b.currency ' + CHAR(13)
						+ 'GROUP BY b.ProductCode, CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId ELSE b.bettype END' + CHAR(13)
						+ 'ORDER BY CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.GroupTypeID ELSE b.bettype END' + CHAR(13)
						+ 'DROP TABLE #tmpWinloss' + CHAR(13)
						+ 'DROP TABLE #TempExchange' + CHAR(13)	
						+ 'DROP TABLE #LicenseeList' + CHAR(13)					

	IF @Debug = 1
		PRINT @sql
	ELSE
		EXEC (@sql)
END
GO