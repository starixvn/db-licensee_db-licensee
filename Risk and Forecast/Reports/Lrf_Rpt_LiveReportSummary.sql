/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummary]
	@AgentList		VARCHAR(MAX),
	@ProductCodes	VARCHAR(MAX)	= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Liveindicator	INT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20111031@Henry
	Task: Live Report Summary
	DB: DBEXT.bodb02

	Revisions:
		- 20111208@Jim: change bettype condition
		- 20120109@Henry: enhance performance + remove @LicenseeType + remove currency UUS
		- 20120214@Jim: change to use  table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		- 20120614@Jim: optimize code 
		- 20120726@Jim: add playercomm value 
		- 20120815@Henry: add Live casino
		- 20120831@Henry: add Virtual Sports
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130328@Scott: Support RNG Casino and Bingo
		- 20130514@Jim:  Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: support Virtual Tennis
		- 20140404@Florent: support Keno product
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150618@Patrick: #36263: Fix super balance isue for: AGC, GD & VG
		- 20150612@Jim: support MicroGaming 
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20151001@Jim: remove MicroGaming
		- 20151228@Bobby: Remove RNG Casino
		- 20151228@Bobby: #50469 - Remove RNG Casino - exclude OneRNG range bettype
		- 20160120@Victor: Fix bug missing bettrade original tickets [Redmine: #51053]
		- 20160218@Bobby: #52428 - Intergate RnG Casino product
		- 20160330@Percy: Support Voidbridge single wallet [Redmine: #55057]
		- 20160519@Jim: HotFix #57810
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20160804@Percy: Enhance Performance - using faster index on bettrans [RedmineID: #60770]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170328@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170705@Harper: Hotfix for Cash Out [RedmineID: #79546]
		- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170721@Harper: Hotfix add AB and FW to LiveReport [RedmineID: #80350]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20170814@Harper: One RNG - Offer New Tablet Games [RedmineID: #78424]
		- 20171009@Sophia: Add ProductCode [RedmineID : #82797]
		- 20180205@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180418@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92318]
		- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181101@Amanda: Remove parameter @LicenseeId [Redmine: #103935]
		- 20181127@Paul: Add OPTION(RECOMPILE) [RedmineID: #105398]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190304@Amanda: Integrate PP Promotion Prize [RedmineID: #109471]
		- 20190516@Amanda: Remove hard code for product name [RedmineID: #113398]
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
		- 20201215@Louis: Licensee Spread Setting - Fix Missing Block [RedmineID: #142532]	
		- 20201216@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369] 
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
		- 20242901@Evan: Integrate VS4 [RedmineID: #199347]
						 Fix missing ticket parlay of BA [RedmineID: #196313]
		- 20240308@Eddie: Integrate UU Slots and change 'bodbLicenseeNet' to 'wsv_lap' account [RedmineID: #201098]

	Param's Explanation:
		+ @IsLive : indicate that whether the report will get live data or not
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

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX CIX_TempAg ON #TempAg (CustId);

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT,@AgentList

		INSERT INTO #TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH; 

	DECLARE @TempFromDate	SMALLDATETIME,
			@TempToDate		SMALLDATETIME,
			@FDate			SMALLDATETIME,
			@TDate			SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate	

	CREATE TABLE #tmpWinloss
	(
		WinLostDate SMALLDATETIME,
		Currency	INT,
		ProductCode VARCHAR(20),
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY,
		Comm		MONEY,
		PlayerComm	MONEY,
		AmtDueTo3rd MONEY,
		BetCount	INT
	)

	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

	CREATE TABLE #LicenseeList(LicenseeID INT, Currency INT)

	CREATE CLUSTERED INDEX IX_LicenseeList_cl ON #LicenseeList(LicenseeID, Currency)

	INSERT INTO #LicenseeList(LicenseeID, Currency)
	SELECT DISTINCT LicenseeID, Currency
	FROM bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK)
	WHERE EXISTS (	SELECT 1
					FROM #TempAg t
					WHERE t.CustId = lc.CustID AND t.Currency = lc.Currency )

	IF @ProductCodes IS NULL
		SET @ProductCodes = ''

	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2) 
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 3))
	
	CREATE TABLE #tmpBettype ( Bettype INT, ProductCode VARCHAR(10))
	INSERT INTO #tmpBettype
	SELECT a.Bettype,IIF(a.ProductId IN (63,69),'SB',b.ProductCode) AS ProductCode
	FROM dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductCodes,null,null,@SBBACheck) a 
	INNER JOIN (SELECT DISTINCT ProductID, ProductCode FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductCodes)) b ON a.ProductId = b.ProductID
	WHERE NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = a.Bettype) AND a.Bettype <> 72
			AND (a.bettype < 901 OR a.bettype > 904)
			AND (a.bettype < 911 OR a.bettype > 914)

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		--Get ticket BA
		IF ',' + @ProductCodes + ',' LIKE '%,BA,%'
		BEGIN
			;WITH CTE AS
			(
				SELECT transid
				FROM bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK)
					INNER JOIN #TempAg t ON BA.recommend = t.CustId
				UNION
				SELECT NULL
			)
			INSERT INTO #tmpWinloss (WinLostDate, Currency, ProductCode, Turnover, WinLost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, BetCount)
			SELECT
				b.winlostdate,
				t.currency,
				'BA' AS ProductCode,
				SUM(b.stake) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS LicenseeWL,
				SUM(b.comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid
				INNER JOIN CTE ON b.transid = CTE.TransID
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.statusID IN (111, 112, 113)
				AND (b.liveindicator = @Liveindicator OR @Liveindicator = 2)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.bettype NOT IN (9,29)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			GROUP BY
				b.winlostdate,
				t.currency
			OPTION(RECOMPILE)
		END

		--Get ticket parlay for BA
		IF ',' + @ProductCodes + ',' LIKE '%,BA,%'
		BEGIN	
			INSERT INTO #tmpWinloss (WinLostDate, Currency, ProductCode, Turnover, WinLost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, BetCount)
			SELECT
				b.winlostdate,
				t.currency,
				'BA' AS ProductCode,
				SUM(stake) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS LicenseeWL,
				SUM(comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active ba WITH (NOLOCK) ON b.recommend = ba.recommend AND b.TransId = ba.TransID
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.bettype IN (9,29)
				AND b.statusID IN (111, 112, 113)
				AND (b.livehomescore = @Liveindicator OR @Liveindicator = 2)
			GROUP BY
				b.winlostdate,
				t.currency
		END

		--Get ticket non BA
		INSERT INTO #tmpWinloss (WinLostDate, Currency, ProductCode, Turnover, WinLost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, BetCount)
		SELECT
			b.winlostdate,
			t.currency,
			bt.ProductCode,
			SUM(stake) turnover,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM(b.comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
			COUNT(b.transid) BetCount
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.bettype = bt.Bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend = BA.recommend AND b.TransId = BA.TransId
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype NOT IN (9,29,2799,10449))
			AND b.tpositiontaking <> 0
			AND b.statusID IN (111, 112, 113)
			AND (b.liveindicator = @Liveindicator OR @Liveindicator = 2)
			AND BA.TransId IS NULL
			AND 1 = CASE
				WHEN b.bettype BETWEEN 1611 AND 1697 AND b.matchid = 150 THEN 0
				WHEN b.bettype BETWEEN 3801 AND 3899 AND b.matchid = 173 THEN 0
				ELSE 1
			END
		GROUP BY
			b.winlostdate,
			t.currency,
			bt.ProductCode
			
		--Get ticket parlay
		INSERT INTO #tmpWinloss (WinLostDate, Currency, ProductCode, Turnover, WinLost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, BetCount)
		SELECT
			b.winlostdate,
			t.currency,
			bt.ProductCode,
			SUM(stake) turnover,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM(comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
			COUNT(b.transid) BetCount
		FROM
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #TempAg t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.bettype = bt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.bettype IN (9,29,2799,10449)
			AND b.tpositiontaking <> 0
			AND b.statusID IN (111, 112, 113)
			AND (b.livehomescore = @Liveindicator OR @Liveindicator = 2)
		GROUP BY
			b.winlostdate,
			t.currency,
			bt.ProductCode
	END
	
	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		-- BA
		IF ',' + @ProductCodes + ',' LIKE '%,BA,%'
		BEGIN
			INSERT INTO #tmpWinloss (WinLostDate, Currency, ProductCode, Turnover, WinLost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, BetCount)
			SELECT
				b.WinlostDate,
				l.Currency,
				'BA' AS ProductCode,
				SUM(b.turnover) turnover,
				SUM(b.Winlost) winlost,
				0 AS LicenseeWL,
				SUM(b.AComm) Comm,
				SUM( b.PComm  ) PlayerComm,
				- SUM (b.Winlost+b.AWinlost+b.AComm) AmountDueTo3rd,
				SUM(b.betcount) BetCount
			FROM
				bodb_licenseereport.dbo.rptLicenseeWinloss b WITH ( NOLOCK )
				INNER JOIN #TempAg l ON b.Recommend = l.CustId 
			WHERE
				b.WinlostDate BETWEEN @FDate AND @TempToDate
				AND b.StatusId NOT IN (-1,103)
				AND (b.LiveIndicator = @Liveindicator OR @Liveindicator = 2)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND b.Product3rdId = 3 --BA
			GROUP BY
				b.WinlostDate,
				l.Currency
		END
		
		--Get Ticket non BA
		INSERT INTO #tmpWinloss (WinLostDate, Currency, ProductCode, Turnover, WinLost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, BetCount)
		SELECT 
			b.WinlostDate,
			l.Currency,
			bt.ProductCode,
			SUM(b.turnover) turnover,
			SUM(b.Winlost) winlost,
			- SUM(b.Winlost) AS LicenseeWL,
			SUM(b.AComm) Comm,
			SUM( b.PComm) PlayerComm,
			- SUM(b.Winlost + b.AWinlost + b.AComm) as AmountDueTo3rd,
			SUM(b.betcount) BetCount
		FROM
			bodb_licenseereport.dbo.rptLicenseeWinloss b WITH (NOLOCK)
			INNER JOIN #TempAg l ON b.Recommend = l.CustId 
			INNER JOIN #tmpBettype bt ON b.Bettype = bt.Bettype
		WHERE
			b.WinlostDate BETWEEN @FDate AND @TempToDate
			AND b.StatusId NOT IN (-1,103)
			AND (b.LiveIndicator = @Liveindicator OR @Liveindicator = 2) 
			AND 1 = CASE WHEN b.bettype BETWEEN 1611 AND 1697 AND b.Sporttype = 150 THEN 0
						WHEN b.bettype BETWEEN 3801 AND 3899 AND b.Sporttype = 173 THEN 0
					ELSE 1 END	
			AND b.Product3rdId <> 3
		GROUP BY
			b.WinlostDate,
			l.Currency,
			bt.ProductCode
	END

	---------------------------------

	CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)

	CREATE TABLE #TempExchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT);
	CREATE CLUSTERED INDEX CIX_TempExchange ON #TempExchange(ExchangeID);

	INSERT INTO #TempExchange (FromDate , ToDate , ExchangeId , Rate)
	SELECT FromDate
		 , ToDate
		 , ExchangeId
		 , Rate
	FROM Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #TempAg a WHERE e.ExchangeID = a.Currency)

	SELECT
		b.ProductCode,
		SUM(b.BetCount) AS Betcount,
		CAST(SUM(b.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(b.WinLost		* e.Rate) AS MONEY) AS Winlost,
		CAST(SUM(b.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(b.Comm			* e.Rate) AS MONEY) AS Comm,
		CAST(SUM(b.PlayerComm	* e.Rate) AS MONEY) AS PlayerComm,
		CAST(SUM(b.AmtDueTo3rd	* e.Rate) AS MONEY) AS AmtDueto3rd
	FROM
		#tmpWinloss b
		INNER JOIN #TempExchange e ON e.ExchangeID = b.currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
	WHERE b.ProductCode IS NOT NULL
	GROUP BY ProductCode
	ORDER BY ProductCode

	DROP TABLE IF EXISTS #TempAg
	DROP TABLE IF EXISTS #tmpWinloss
	DROP TABLE IF EXISTS #TempExchange
	DROP TABLE IF EXISTS #LicenseeList
	DROP TABLE IF EXISTS #tmpBettype
END
GO