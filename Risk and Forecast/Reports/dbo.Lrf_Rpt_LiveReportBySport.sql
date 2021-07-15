/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportBySport] 
	@ProductCodes	VARCHAR(MAX)	= NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Debug			BIT				= 0,
	@Liveindicator	INT				= 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)		= ''
AS

/*
	Created: 20111031@
	Task: Live Report Summary BY Sport
	DB: DBEXT.bodb02

	Revisions:
		- 20111208@Jim: change bettype condition
		- 20120110@Henry: remove Licensee Type + Get data from rpt_Betting + remove currency UUS
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		- 20120614@Jim: optimize code
		- 20120726@Jim: add playercomm value 
		- 20120814@Henry: add live casino
		- 20120830@Henry: add Virtual Sports
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130328@Scott: Support RNG Casino and Bingo
		- 20130618@Jim:  Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: support Virtual Tennis
		- 20131129@Jim: support :
					182 Virtual Greyhounds
					184 Virtual Motor Racing
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
		- 20180205@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180419@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92318]
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
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200715@Louis: Add new bet types for Keno/Lottery/TableGame [RedmineID: #137625]
		- 20200728@Hogan: Integrate SA Gaming [RedmineID: #128493]		
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201022@Louis: Integrate PG Soft [RedmineID: #139182]
		- 20201126@Hogan: Integrate Joker [RedmineID: #141408]
		- 20201202@Louis: Licensee Spread Setting [RedmineID: #142532]	
		- 20201202@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369] 
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]
		- 20200122@Hogan: Integrate GDG [RedmineID: #147267]
		- 20210122@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]
		- 20210330@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210409@Hogan: Integrate AE Casino Lucky Draw [RedmineID: #151984]
		- 20210416@Hogan: Integrate Habanero RNG Games [RedmineID: #150843]
		- 20210428@Hogan: Integrate WM Live Casino [RedmineID: #140944]
		- 20210519@Louis: Integrate Big Gaming product [RedmineID: #146773]
		- 20210525@Hogan: Integrate Vgaming [RedmineID: #151583]
		- 20210630@Hogan: Integrate Creative Gaming [RedmineID: #152619]

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
	EXEC [Lrf_Rpt_LiveReportBySport]  @CurrencyID = 0, @FromDate=@FromDate, @ProductCode= NULL, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay  
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
	
	SELECT	@sql = @sql + 'DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)' + CHAR(13)
	SELECT	@sql = @sql + 'INSERT INTO @ExcludedBetType (ProductCode, BetType)' + CHAR(13)
	SELECT	@sql = @sql + 'SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()' + CHAR(13)

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
						+ ')' + CHAR(13)

	IF @ProductCodes IS NULL
		SET @ProductCodes = ''

	CREATE TABLE #ProductCodes (ProductCode VARCHAR(10))

	INSERT INTO #ProductCodes (ProductCode)
	SELECT ISNULL(Val, '')
	FROM dbo.strSplit(@ProductCodes, ',')

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
								+ 'AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)' + CHAR(13)
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
								+ 'WHERE b.winlostdate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)' + CHAR(13)
								+ 'AND b.bettype IN (9,29,2799)' + CHAR(13)
								+ 'AND ((' + CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
								+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
								+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'GROUP BY  b.winlostdate, b.currency, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'END ' + CHAR(13)
		END

		-- exclude PP Prize 4300, 4299, 4298, 4297
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'NG', 'SB', 'VS', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP', 'CC', 'SG', 'VRG', 'TG', 'I4D', 'SXG', 'SBC', 'SAG', 'PGS', 'JK', 'GDG', 'SLT', 'HB', 'WM', 'BGG', 'VGA', 'CG'))
		BEGIN
			SELECT @sql = @sql + '--Get data from bettrans for non-BA' + CHAR(13)

			SELECT	@sql = @sql + '--Get data for Virtual Horse Racing,Virtual Greyhounds,Virtual Motor Racing ' + CHAR(13)

			SELECT	@sql = @sql + 'SELECT DISTINCT o.Orid, r.SportType INTO #tmpVS' + CHAR (13)
								+ 'FROM VSOutright o WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID' + CHAR(13)
								+ 'WHERE EventDate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.winlostdate, b.currency,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161 --NG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 8101 AND 8120 THEN 164 --NG:Happy5' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3601 AND 3610 THEN 168 --Happy 5 Linked Games' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202 --Keno''s bettype' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1201 AND 1299) AND b.bettype NOT IN (1231,1232,1233,1237,1238,1220,1235,1236) THEN 180 --VS' + CHAR(13)
								+ 'WHEN b.bettype IN ('+@strbettypeVHR+') THEN vs.SportType ' + CHAR(13)
								+ 'WHEN b.bettype IN (1220,1235,1236) THEN 186 ' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- Mix Parlay Betradar' + CHAR(13)
								+ 'WHEN b.bettype = 71 THEN 251 -- Casino' + CHAR(13)		
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208 -- New Casino' + CHAR(13)		
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209 -- New Casino' + CHAR(13)		
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210 -- New Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN 212' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219 -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211 -- AllBet' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1099 THEN 220 -- Lottery' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4296 THEN 248 -- PP' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN 165 -- CC' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4301 AND 4600 THEN 247 -- SG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4601 AND 4900 THEN 245 -- VRG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4901 AND 5000 THEN 222 -- TG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5001 AND 5099 THEN 223 -- I4D' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3101 AND 3149 THEN 243 -- SXG' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1611 AND 1697) AND b.matchid <> 150 THEN 200 -- SBC' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3001 AND 3099 THEN 244 -- SAG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6001 AND 6300 THEN 232 -- PGS' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6401 AND 6700 THEN 234 -- JK' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5701 AND 5799 THEN 236 -- GDG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3611 AND 3620 THEN 169 -- SLT' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7001 AND 7300 THEN 238 -- HB' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3401 AND 3499 THEN 233 -- WM' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3501 AND 3599 THEN 239 -- BGG' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 3801 AND 3899) AND b.matchid <> 173 THEN 171 -- VGA' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7301 AND 7600 THEN 167 -- CG' + CHAR(13)
									
								+ 'ELSE m.SportType END as Sporttype,' + CHAR(13)
								+ 'SUM(stake) turnover,' + CHAR(13)
								+ 'SUM(b.winlost - b.actual_stake) AS Winlost,' + CHAR(13)
								+ '- SUM(b.winlost - b.actual_stake) AS LicenseeWL,' + CHAR(13)
								+ 'SUM (comm) AS Comm,' + CHAR(13)
								+ 'SUM (playercomm) AS PlayerComm,' + CHAR(13)
								+ '- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,' + CHAR(13)
								+ 'COUNT(b.transid) BetCount' + CHAR(13)

				SELECT	@sql = @sql + 'FROM bettrans b  WITH (NOLOCK)' + CHAR(13)
								+ 'INNER JOIN @TempAg t  ON b.recommend =t.custid AND b.Currency = t.Currency' + CHAR(13)
								+ 'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend AND b.transid = BA.transid' + CHAR(13)
								+ 'LEFT JOIN outright o with(nolock) ON b.matchid = o.orid' + CHAR(13)
								+ 'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid AND b.bettype NOT IN ('+@strbettypeVHR+') ' + CHAR(13)
								+ 'LEFT JOIN #tmpVS vs ON b.oddsid=vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)' + CHAR(13)
								+ 'WHERE b.winlostdate BETWEEN ''' + CONVERT(VARCHAR(10), @TempFromDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TDate, 120) + '''' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.liveindicator = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.liveindicator = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904,1700,1800,1900,18000)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND b.bettype NOT BETWEEN 1101 AND 1199' + CHAR(13)
								+ 'AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)' + CHAR(13)
								+ 'AND b.statusID IN (111,112,113)' + CHAR(13) + 'AND BA.transid IS NULL' + CHAR(13) + 'AND (1 <> 1' + CHAR(13)
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','NG')) = 1 THEN 'OR (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) OR (b.bettype BETWEEN 3601 AND 3610) '+ CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SB')) = 1 THEN 'OR (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399) OR (b.Bettype BETWEEN 9001 and 9399) OR (b.Bettype BETWEEN 9400 and 9699) OR b.Bettype = 38)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS')) = 1 THEN 'OR b.bettype BETWEEN 1201 AND 1299' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','KN')) = 1 THEN 'OR b.bettype BETWEEN 1501 AND 1599' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CS')) = 1 THEN 'OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VB')) = 1 THEN 'OR (b.bettype BETWEEN 4001 AND 4100)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','FW')) = 1 THEN 'OR b.bettype BETWEEN 1011 AND 1020' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','AB')) = 1 THEN 'OR b.bettype BETWEEN 2401 AND 2499' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS2')) = 1 THEN 'OR b.bettype BETWEEN 2701 AND 2829' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LT')) = 1 THEN 'OR b.bettype BETWEEN 1021 AND 1099' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','PP')) = 1 THEN 'OR b.bettype BETWEEN 4101 AND 4296' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CC')) = 1 THEN 'OR b.bettype BETWEEN 1901 AND 1999' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SG')) = 1 THEN 'OR b.bettype BETWEEN 4301 AND 4600' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VRG')) = 1 THEN 'OR b.bettype BETWEEN 4601 AND 4900' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','TG')) = 1 THEN 'OR b.bettype BETWEEN 4901 AND 5000' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','I4D')) = 1 THEN 'OR b.bettype BETWEEN 5001 AND 5099' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SXG')) = 1 THEN 'OR b.bettype BETWEEN 3101 AND 3149' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SBC')) = 1 THEN 'OR (b.bettype BETWEEN 1611 AND 1697 AND b.matchid <> 150)' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SAG')) = 1 THEN 'OR b.bettype BETWEEN 3001 AND 3099' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','PGS')) = 1 THEN 'OR b.bettype BETWEEN 6001 AND 6300' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','JK')) = 1 THEN 'OR b.bettype BETWEEN 6401 AND 6700' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','GDG')) = 1 THEN 'OR b.bettype BETWEEN 5701 AND 5799' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SLT')) = 1 THEN 'OR b.bettype BETWEEN 3611 AND 3620' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','HB')) = 1 THEN 'OR b.bettype BETWEEN 7001 AND 7300' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','WM')) = 1 THEN 'OR b.bettype BETWEEN 3401 AND 3499' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','BGG')) = 1 THEN 'OR b.bettype BETWEEN 3501 AND 3599' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VGA')) = 1 THEN 'OR (b.bettype BETWEEN 3801 AND 3899 AND b.matchid <> 173)' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CG')) = 1 THEN 'OR b.bettype BETWEEN 7301 AND 7600' + CHAR(13) ELSE '' END
								+ ') ' + CHAR(13)
								+ 'GROUP BY b.winlostdate, b.currency,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161 --NG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 8101 AND 8120 THEN 164 --NG:Happy5' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3601 AND 3610 THEN 168 --Happy 5 Linked Games' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202 --Keno''s bettype' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1201 AND 1299) AND b.bettype NOT IN (1231,1232,1233,1237,1238,1220,1235,1236) THEN 180 --VS' + CHAR(13)
								+ 'WHEN b.bettype IN (1231,1232,1233,1237,1238) THEN vs.SportType ' + CHAR(13)
								+ 'WHEN b.bettype IN (1220,1235,1236) THEN 186 ' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 10 THEN 103 -- Outright' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- Mix Parlay Betradar' + CHAR(13)
								+ 'WHEN b.bettype = 71 THEN 251 -- Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208 -- New Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209 -- New Casino' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210 -- New Casino' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN 212' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219 -- Fishing World' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211 -- AllBet' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1099 THEN 220 -- Lottery' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4296 THEN 248 -- PP' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN 165 -- CC' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4301 AND 4600 THEN 247 -- SG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4601 AND 4900 THEN 245 -- VRG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4901 AND 5000 THEN 222 -- TG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5001 AND 5099 THEN 223 -- I4D' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3101 AND 3149 THEN 243 -- SXG' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1611 AND 1697) AND b.matchid <> 150 THEN 200 -- SBC' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3001 AND 3099 THEN 244 -- SAG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6001 AND 6300 THEN 232 -- PGS' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6401 AND 6700 THEN 234 -- JK' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5701 AND 5799 THEN 236 -- GDG' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3611 AND 3620 THEN 169 -- SLT' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7001 AND 7300 THEN 238 -- HB' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3401 AND 3499 THEN 233 -- WM' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3501 AND 3599 THEN 239 -- BGG' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 3801 AND 3899) AND b.matchid <> 173 THEN 171 -- VGA' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7301 AND 7600 THEN 167 -- CG' + CHAR(13)
								+ 'ELSE m.SportType END ' + CHAR(13)

			IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'SB'))
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
									+ 'AND ((' + CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
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
									+ 'AND ((' + CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.livehomescore = 0)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.livehomescore = 1)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
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
								+ 'INNER JOIN #LicenseeList ll ON b.SiteID = ll.LicenseeID AND b.CurrencyID = ll.Currency' + CHAR(13)
								+ 'LEFT JOIN league l WITH (NOLOCK) ON b.LeagueID = l.LeagueID' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,901,902,903,904)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)' + CHAR(13)
								+ 'AND ((' + CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
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
								+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
								+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND b.bettype IN (9 ,29, 2799)' + CHAR(13)
								+ 'AND b.isBA = 1' + CHAR(13)
								+ 'AND (('+CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR ('+CAST(@Liveindicator AS VARCHAR(2))+' = 2))' + CHAR(13)								
								+ 'GROUP BY b.rptDate, b.currencyID, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 29 THEN 102 --System Parlay' + CHAR(13)
								+ 'WHEN b.bettype = 2799 THEN 104 -- VS2 Parlay' + CHAR(13)
								+ 'END' + CHAR(13)
		END

		--Not BA, -- exclude PP Prize 4300, 4299, 4298, 4297
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'NG', 'SB', 'VS', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP', 'CC', 'SG', 'VRG', 'TG', 'I4D', 'SXG', 'SBC', 'SAG', 'PGS', 'JK', 'GDG', 'SLT', 'HB', 'WM', 'BGG', 'VGA', 'CG'))
		BEGIN
			SELECT	@sql = @sql + '--Get data from rpt_Betting for non-BA' + CHAR(13)

			SELECT	@sql = @sql + 'INSERT INTO #tmpWinloss' + CHAR(13)
								+ 'SELECT b.rptDate, b.currencyID,' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype  = 10 THEN 103' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 8101 AND 8120 THEN 164' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3601 AND 3610 THEN 168' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202' + CHAR(13)
								+ 'WHEN b.bettype = 71 THEN 251' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN 212' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1099 THEN 220' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4296 THEN 248' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN 165' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4301 AND 4600 THEN 247' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4601 AND 4900 THEN 245' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4901 AND 5000 THEN 222' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5001 AND 5099 THEN 223' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3101 AND 3149 THEN 243' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1611 AND 1697) AND b.TicketType <> 2 THEN 200' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3001 AND 3099 THEN 244' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6001 AND 6300 THEN 232' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6401 AND 6700 THEN 234' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5701 AND 5799 THEN 236' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3611 AND 3620 THEN 169' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7001 AND 7300 THEN 238' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3401 AND 3499 THEN 233' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3501 AND 3599 THEN 239' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 3801 AND 3899) AND b.TicketType <> 2 THEN 171' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7301 AND 7600 THEN 167' + CHAR(13)
								+ 'ELSE ISNULL(l.sporttype, 0)' + CHAR(13)
								+ 'END AS SportType,' + CHAR(13)
								+ 'SUM(b.turnover) turnover,' + CHAR(13)
								+ 'SUM(b.winloss) winlost,' + CHAR(13)
								+ '- SUM(b.winloss) AS LicenseeWL,' + CHAR(13)
								+ 'SUM(b.CommissionA) Comm,' + CHAR(13)
								+ 'SUM(b.CommissionP  ) PlayerComm,' + CHAR(13)
								+ '- SUM(b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + CHAR(13)
								+ 'SUM(b.betcount) BetCount' + CHAR(13)
								+ 'FROM bodb_licenseereport.dbo.rpt_Betting b WITH ( NOLOCK )' + CHAR(13)
								+ 'INNER JOIN #LicenseeList ll ON b.SiteID = ll.LicenseeID AND b.CurrencyID = ll.Currency' + CHAR(13)
								+ 'LEFT JOIN league l WITH (NOLOCK) ON b.LeagueID = l.LeagueID' + CHAR(13)
			SELECT	@sql = @sql + 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
								+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
								+ 'AND ((' + CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
								+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
								+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
								+ 'AND b.bettype NOT IN (9,29,2799,1700,1800,1900,901,902,903,904,18000)' + CHAR(13)
								+ 'AND (b.bettype < 911 OR b.bettype > 914)' + CHAR(13)
								+ 'AND b.bettype NOT BETWEEN 1101 AND 1199' + CHAR(13)
								+ 'AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)' + CHAR(13)
								+ 'AND b.CustomerCategory IN (-1, 1001, 1003)' + CHAR(13)
								+ 'AND (1 <> 1' + CHAR(13)	
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','NG')) = 1 THEN 'OR (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) OR (b.bettype BETWEEN 3601 AND 3610) '+ CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SB')) = 1 THEN 'OR (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399) OR (b.Bettype BETWEEN 9001 and 9399) OR (b.Bettype BETWEEN 9400 and 9699) OR b.Bettype = 38)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS')) = 1 THEN 'OR b.bettype BETWEEN 1201 AND 1299' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','KN')) = 1 THEN 'OR b.bettype BETWEEN 1501 AND 1599' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CS')) = 1 THEN 'OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VB')) = 1 THEN 'OR (b.bettype BETWEEN 4001 AND 4100)' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','FW')) = 1 THEN 'OR b.bettype BETWEEN 1011 AND 1020' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','AB')) = 1 THEN 'OR b.bettype BETWEEN 2401 AND 2499' + CHAR(13) ELSE '' END 
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VS2')) = 1 THEN 'OR b.bettype BETWEEN 2701 AND 2829' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','LT')) = 1 THEN 'OR b.bettype BETWEEN 1021 AND 1099' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','PP')) = 1 THEN 'OR b.bettype BETWEEN 4101 AND 4296' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CC')) = 1 THEN 'OR b.bettype BETWEEN 1901 AND 1999' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SG')) = 1 THEN 'OR b.bettype BETWEEN 4301 AND 4600' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VRG')) = 1 THEN 'OR b.bettype BETWEEN 4601 AND 4900' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','TG')) = 1 THEN 'OR b.bettype BETWEEN 4901 AND 5000' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','I4D')) = 1 THEN 'OR b.bettype BETWEEN 5001 AND 5099' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SXG')) = 1 THEN 'OR b.bettype BETWEEN 3101 AND 3149' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SBC')) = 1 THEN 'OR (b.bettype BETWEEN 1611 AND 1697 AND b.TicketType <> 2)' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SAG')) = 1 THEN 'OR b.bettype BETWEEN 3001 AND 3099' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','PGS')) = 1 THEN 'OR b.bettype BETWEEN 6001 AND 6300' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','JK')) = 1 THEN 'OR b.bettype BETWEEN 6401 AND 6700' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','GDG')) = 1 THEN 'OR b.bettype BETWEEN 5701 AND 5799' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','SLT')) = 1 THEN 'OR b.bettype BETWEEN 3611 AND 3620' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','HB')) = 1 THEN 'OR b.bettype BETWEEN 7001 AND 7300' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','WM')) = 1 THEN 'OR b.bettype BETWEEN 3401 AND 3499' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','BGG')) = 1 THEN 'OR b.bettype BETWEEN 3501 AND 3599' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','VGA')) = 1 THEN 'OR (b.bettype BETWEEN 3801 AND 3899 AND b.TicketType <> 2)' + CHAR(13) ELSE '' END
								+ CASE WHEN (SELECT TOP 1 1 FROM #ProductCodes WHERE ProductCode IN ('','CG')) = 1 THEN 'OR b.bettype BETWEEN 7301 AND 7600' + CHAR(13) ELSE '' END
								+ ') ' + CHAR(13)
								+ 'GROUP BY b.rptDate, b.currencyID, ' + CHAR(13)
								+ 'CASE' + CHAR(13)
								+ 'WHEN b.bettype  = 10 THEN 103' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 81 AND 120 THEN 161' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 8101 AND 8120 THEN 164' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3601 AND 3610 THEN 168' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1501 AND 1599 THEN 202' + CHAR(13)
								+ 'WHEN b.bettype = 71 THEN 251' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2101 AND 2199 THEN 208' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2201 AND 2299 THEN 209' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 2301 AND 2399) OR (b.bettype BETWEEN 2901 AND 2999) THEN 210' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4001 AND 4100 THEN 212' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1011 AND 1020 THEN 219' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 2401 AND 2499 THEN 211' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1021 AND 1099 THEN 220' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4101 AND 4296 THEN 248' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 1901 AND 1999 THEN 165' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4301 AND 4600 THEN 247' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4601 AND 4900 THEN 245' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 4901 AND 5000 THEN 222' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5001 AND 5099 THEN 223' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3101 AND 3149 THEN 243' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 1611 AND 1697) AND b.TicketType <> 2 THEN 200' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3001 AND 3099 THEN 244' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6001 AND 6300 THEN 232' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 6401 AND 6700 THEN 234' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 5701 AND 5799 THEN 236' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3611 AND 3620 THEN 169' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7001 AND 7300 THEN 238' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3401 AND 3499 THEN 233' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 3501 AND 3599 THEN 239' + CHAR(13)
								+ 'WHEN (b.bettype BETWEEN 3801 AND 3899) AND b.TicketType <> 2 THEN 171' + CHAR(13)
								+ 'WHEN b.bettype BETWEEN 7301 AND 7600 THEN 167' + CHAR(13)
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
									+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
									+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
									+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
									+ 'AND b.bettype IN (9,29)' + CHAR(13)
									+ 'AND ((' + CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
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
									+ 'INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency' + CHAR(13)
									+ 'WHERE b.rptDate BETWEEN ''' + CONVERT(VARCHAR(10), @FDate, 120) + ''' AND ''' + CONVERT(VARCHAR(10), @TempToDate, 120) + '''' + CHAR(13)
									+ 'AND b.status NOT IN (-1,103)' + CHAR(13)
									+ 'AND b.bettype IN (2799)' + CHAR(13)
									+ 'AND ((' + CAST(@Liveindicator AS VARCHAR(2))+' = 0 and b.IsLive = 0)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 1 and b.IsLive = 1)' + CHAR(13)
									+ 'OR (' + CAST(@Liveindicator AS VARCHAR(2))+' = 2))'	+ CHAR(13)
									+ 'AND b.isBA = 0' + CHAR(13)					
									+ 'GROUP BY b.rptDate, b.currencyID' + CHAR(13)	
			END
		END
	END

	-- Get winlost BY Sport
	SELECT	@sql = @sql + '-- Get winlost by Sport  ' + CHAR(13)

	SELECT	@sql = @sql + 'CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)  ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT FromDate, ToDate, ExchangeID, Rate INTO #TempExchange FROM Lrf_f_GetExchangeRate(''' + CONVERT(VARCHAR(10), @FDate, 120) + ''',''' + CONVERT(VARCHAR(10), @TDate, 120)+ ''',''' + @BaseCurrency + ''',''''' + ')' + CHAR(13)
						+ 'WHERE ExchangeID IN (SELECT DISTINCT Currency FROM #tmpWinloss ) ' + CHAR(13)

	SELECT	@sql = @sql + 'SELECT b.SportType, ' + CHAR(13)
						+ 'SUM(Betcount) AS Betcount,' + CHAR(13)
						+ 'CAST(SUM(TurnOver*e.Rate) AS MONEY) AS Turnover,' + CHAR(13)
						+ 'CAST(SUM(Winlost*e.Rate) AS MONEY) AS Winlost,' + CHAR(13)
						+ 'CAST(SUM(LicenseeWL*e.Rate) AS MONEY) AS LicenseeWL,' + CHAR(13)
						+ 'CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm,' + CHAR(13)
						+ 'CAST(SUM(Playercomm * e.Rate) AS MONEY) AS PlayerComm,' + CHAR(13)
						+ 'CAST(SUM(AmtDueto3rd*e.Rate) AS MONEY) AS AmtDueto3rd' + CHAR(13)
						+ 'FROM #tmpWinloss b ' + CHAR(13)
						+ 'INNER JOIN #TempExchange e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate AND e.exchangeid = b.currency ' + CHAR(13)
						+ 'GROUP BY b.SportType' + CHAR(13)
						+ 'DROP TABLE #tmpWinloss' + CHAR(13)
						+ 'DROP TABLE #TempExchange' + CHAR(13)
						+ 'DROP TABLE #LicenseeList' + CHAR(13)

	IF (@debug = 1)
		PRINT @sql
	ELSE
		EXEC (@sql)
END
GO
