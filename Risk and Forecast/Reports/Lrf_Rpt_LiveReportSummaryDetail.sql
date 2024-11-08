/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummaryDetail]
	@AgentList		VARCHAR(MAX),
	@ProductCodes	VARCHAR(MAX)	= NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Liveindicator	INT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20111115@Henry
	Task: Live Report Summary by Sport
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
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
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
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20211105@Hogan: Integrate AdvantPlay RNG & Mini [RedmineID: #158186]
		- 20211214@Kos: Integrate PP 20 new games [RedmineID: #165772]
		- 20220224@Hogan: Integrate Virtual Sports 3 (Leap Gaming)[RedmineID: #145337]
		- 20220317@Kos: Integrate Cricket phase 2 [RedmineID: #168034]
		- 20220328@Hogan: Macau Games Add new Range bettype[RedmineID: #170607]
		- 20220429@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220601@Hogan: Integrate FGG Guaranteed Gaming [RedmineID: #167897]
		- 20220601@Hogan: Integrate MaxGame [RedmineID: #172919]
		- 20220714@Hogan: Integrate Volleyball AIO [RedmineID: #175143]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20230130@Evan: Integrate Jili [RedmineID: #182914]
	    - 20230303@Evan: Remove inactive products CB, FW, GD, GDG [Redmine: 181424]  
		- 20230523@Evan: Integrate YeeBet LC [RedmineID: #187947]
		- 20230626@Evan: Integrate MG-RNG (Normal+Promotion Game) [RedmineID: #189988]
		- 20230801@Evan: Integrate Virtual Sports 3 (Leap Gaming New) [RedmineID: #190908]
		- 20231107@Evan: Integrate SEAL Entertainment [RedmineID: #180648]
		- 20231117@Evan: Integrate WE Live Casino [RedmineID: #196573]
		- 20231213@Evan: Integrate Live22 [RedmineID: #197702]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only + Remove VS3 (old) [RedmineID: #199523]
		- 20240308@Eddie: Integrate UU Slots and change 'bodbLicenseeNet' to 'wsv_lap' account [RedmineID: #201098]
		- 20242503@Evan: Enhance code to avoid hardcode  [RedmineID: #199843]
		- 20240509@Evan: Integrate VS4 [RedmineID: #199347]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]
		- 20241107@Kelvin: Integrate VS5 [RedmineID: #207582]

	Param's Explanation:
		+ @Liveindicator: indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME,
			@FDate			SMALLDATETIME,
			@TDate			SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate

	--Declare variable:
	DECLARE @ExcludedBetType TABLE (
		  ProductCode VARCHAR(10)
		, BetType INT
	)
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode
		 , BetType
	FROM Lrf_f_SelExcludedBetType()
	

	-- 
	DROP TABLE IF EXISTS #tmpWinloss
	DROP TABLE IF EXISTS #TempExchange
	DROP TABLE IF EXISTS #LicenseeList
	DROP TABLE IF EXISTS #tmpBettype
	DROP TABLE IF EXISTS #TempAg
	
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX CIX_TempAg ON #TempAg (CustId);

	CREATE TABLE #tmpWinloss (
		  winlostdate DATETIME
		, Currency INT
		, ProductCode VARCHAR(10)
		, BetType INT
		, TurnOver MONEY
		, Winlost MONEY
		, LicenseeWL MONEY
		, Comm MONEY
		, PlayerComm MONEY
		, AmtDueTo3rd MONEY
		, Betcount INT
	)
	DECLARE @DocHandler INT

	--insert agentIds to temp table
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
								  , @AgentList
		INSERT INTO #TempAg (custID, currency)
		SELECT AgentId
			 , Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100
			 , ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH;

	CREATE TABLE #LicenseeList (
		  LicenseeID INT
		, Currency INT
	)
	CREATE CLUSTERED INDEX IX_LicenseeList_cl ON #LicenseeList (LicenseeID, Currency)
	INSERT INTO #LicenseeList (LicenseeID, Currency)
	SELECT DISTINCT LicenseeID
				  , Currency
	FROM bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK)
	WHERE EXISTS (
			SELECT 1
			FROM #TempAg t
			WHERE t.CustId = lc.CustID
				AND t.Currency = lc.Currency
		)

	IF @ProductCodes IS NULL
		SET @ProductCodes = ''
	
	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2))
	
	CREATE TABLE #tmpBettype ( Bettype INT, ProductCode VARCHAR(10), ProductID SMALLINT)
	INSERT INTO #tmpBettype
	SELECT a.Bettype, ISNULL(lf.GroupProductPrefix,IIF(a.ProductId IN (63,69),'SB',b.ProductPrefix)) AS ProductCode, a.ProductID
	FROM dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductCodes,null,null,@SBBACheck) a
	INNER JOIN dbo.Products b WITH(NOLOCK) ON a.ProductId = b.ProductID 
	LEFT JOIN dbo.Lrf_f_GroupProduct() lf ON a.ProductId = lf.ProductId
	WHERE NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = a.Bettype) AND a.Bettype <> 72
			AND (a.bettype < 901 OR a.bettype > 904)
			AND (a.bettype < 911 OR a.bettype > 914)

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		INSERT INTO #tmpWinloss (winlostdate, Currency, ProductCode, BetType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.winlostdate
				, t.currency
				, bt.ProductCode
				, b.bettype
				, SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake / 2 ELSE stake END)
				, SUM(b.winlost - b.actual_stake) AS Winlost
				, - SUM(b.winlost - b.actual_stake) AS LicenseeWL
				, SUM(comm) AS Comm
				, SUM(b.playercomm) AS PlayerComm
				, -SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
				, COUNT(b.TransId) BetCount
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN #TempAg t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.bettype = bt.Bettype
			OUTER APPLY
			(
				SELECT ISNULL(CASE WHEN b.bettype IN (9,29,2799,10449,11099) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
			) s
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)
			AND (s.liveindicator = @Liveindicator OR @Liveindicator = 2)
			AND 1 = CASE
				WHEN b.bettype BETWEEN 1611 AND 1697 AND b.matchid = 150 THEN 0
				WHEN b.bettype BETWEEN 3801 AND 3899 AND b.matchid = 173 THEN 0
				ELSE 1 
			END
		GROUP BY b.winlostdate
				, t.currency
				, bt.ProductCode
				, b.bettype
			
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		--Not BA, -- exclude PP Prize 4300, 4299, 4298, 4297
		
		INSERT INTO #tmpWinloss (winlostdate, Currency, ProductCode, BetType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.rptDate
			 , b.CurrencyID
			 , bt.ProductCode
			 , b.bettype
			 , SUM(b.turnover) turnover
			 , SUM(b.WinLoss) winlost
			 , -SUM(b.WinLoss) AS LicenseeWL
			 , SUM(b.CommissionA) Comm
			 , SUM(b.CommissionP) PlayerComm
			 , -SUM(b.WinLoss + b.WinLossA + b.CommissionA) AmountDueTo3rd
			 , SUM(b.betcount) BetCount
		FROM bodb_LicenseeReport.dbo.rpt_Betting b WITH (NOLOCK)
			INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency
			INNER JOIN #tmpBettype bt ON b.Bettype = bt.Bettype
		WHERE b.rptDate BETWEEN @FDate AND @TempToDate
			AND b.status NOT IN (-1, 103)
			AND b.bettype NOT IN (9, 29, 2799,10449,11099)
			AND b.CustomerCategory IN (-1, 1001, 1003)
			AND (b.IsLive = @Liveindicator OR @Liveindicator = 2)
			AND 1 = CASE WHEN b.bettype BETWEEN 1611 AND 1697 AND b.TicketType = 2 THEN 0
						WHEN b.bettype BETWEEN 3801 AND 3899 AND b.TicketType = 2 THEN 0
					ELSE 1 END	
		GROUP BY b.rptDate
			   , b.CurrencyID
			   , b.bettype
			   , bt.ProductCode

		-- Get parlay tickets
		INSERT INTO #tmpWinloss (winlostdate, Currency, ProductCode, BetType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.rptDate
			 , b.CurrencyID
			 , bt.ProductCode
			 , b.bettype
			 , SUM(b.turnover) turnover
			 , SUM(b.WinLoss) winlost
			 , SUM(-1 * b.WinLoss) AS LicenseeWL
			 , SUM(b.CommissionA) Comm
			 , SUM(b.CommissionP) PlayerComm
			 , -SUM(b.WinLoss + b.WinLossA + b.CommissionA) AmountDueTo3rd
			 , SUM(b.betcount) BetCount
		FROM bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH (NOLOCK)
			INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency
			INNER JOIN #tmpBettype bt ON b.Bettype = bt.Bettype
		WHERE b.rptDate BETWEEN @FDate AND @TempToDate
			AND b.status NOT IN (-1, 103)
			AND b.bettype IN (9, 29, 2799,10449,11099)
			AND (b.IsLive = @Liveindicator OR @Liveindicator = 2)
		GROUP BY b.rptDate
			,b.CurrencyID
			,ProductCode
			,b.bettype

	END

	-- Get winlost by currency  
	CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)

	CREATE TABLE #TempExchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT);
	CREATE CLUSTERED INDEX CIX_TempExchange ON #TempExchange(ExchangeID);

	INSERT INTO #TempExchange (FromDate , ToDate , ExchangeId , Rate)
	SELECT FromDate
		 , ToDate
		 , ExchangeId
		 , Rate
	FROM Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '')
	WHERE ExchangeId IN (SELECT DISTINCT Currency FROM #tmpWinloss)

	-- Get winlost by currency  
	SELECT b.currency AS Currency
		 , SUM(Betcount) AS Betcount
		 , CAST(SUM(TurnOver * e.Rate) AS MONEY) AS Turnover
		 , CAST(SUM(Winlost * e.Rate) AS MONEY) AS Winlost
		 , CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		 , CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm
		 , CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		 , CAST(SUM(AmtDueto3rd * e.Rate) AS MONEY) AS AmtDueto3rd
	FROM #tmpWinloss b WITH (NOLOCK)
		INNER JOIN #TempExchange e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND e.ExchangeId = b.currency
	GROUP BY b.currency

	-- Get winlost by bettype  
	SELECT b.ProductCode
		 , CASE
			   WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
			   ELSE b.bettype
		   END bettype
		 , SUM(Betcount) AS Betcount
		 , CAST(SUM(TurnOver * e.Rate) AS MONEY) AS Turnover
		 , CAST(SUM(Winlost * e.Rate) AS MONEY) AS Winlost
		 , CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		 , CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm
		 , CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		 , CAST(SUM(AmtDueto3rd * e.Rate) AS MONEY) AS AmtDueto3rd
	FROM #tmpWinloss b WITH (NOLOCK)
		LEFT JOIN dbo.Lrf_f_GroupBettype() ss ON b.bettype = ss.bettype
		INNER JOIN bettype bt WITH (NOLOCK) ON b.bettype = bt.typeid
		INNER JOIN #TempExchange e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND e.ExchangeId = b.currency
	GROUP BY b.ProductCode
		   , CASE
				 WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
				 ELSE b.bettype
			 END
	ORDER BY CASE
		WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
		ELSE b.bettype 
	END

END
GO
