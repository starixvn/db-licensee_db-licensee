/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_PlatformWinlossDetail]
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@showSB		BIT = 0,
	@ShowNG		BIT = 0,
	@ShowBA		BIT = 0,
	@ShowVS		BIT = 0,
	@ShowKN		BIT = 0,
	@ShowCS		BIT = 0,
	@ShowVB		BIT = 0,
	@ShowAB		BIT = 0,
	@ShowFW		BIT = 0,
	@ShowVS2	BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT		BIT = 0, -- Lottery
	@ShowPP		BIT = 0, -- PP
	@ShowCC		BIT = 0, -- Card club
	@ShowSG		BIT = 0, -- Spadegaming 
	@ShowVRG	BIT = 0, -- Virtual Games
	@ShowTG		BIT = 0, -- Table Games
	@ShowI4D	BIT = 0, -- Indo 4D
	@ShowSXG	BIT = 0, -- Sexy Gaming
	@ShowSBC	BIT = 0, -- Saba club
	@ShowSAG	BIT = 0, -- SA Gaming
	@ShowPGS	BIT = 0, -- PG Soft
	@ShowJK		BIT = 0, -- Joker
	@ShowGDG	BIT = 0, -- GDG
	@PlatformType	TINYINT			= 0,
	@MoveBetsDay	SMALLDATETIME,
	@DrawFilter		SMALLINT		= 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)		= ''
AS

/*
	Created: 20160406@Victor
	Task: Platform WinLoss Report - Detail view
	DB: DBEXT.bodb02

	Revisions:
		- 20160719@Jim: Allbet - Live Casino Integration for Licensees (#59624)
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
		- 20170301@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170706@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170802@Sophia: Add new betfrom [redmine: #80687]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20171020@Harper: LRF - Add "New Asia" in platform list [RedmineID: #85203]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180418@Amanda: LAP - Integrate PP [RedmineID: #92318]
		- 20180809@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20181113@Joseph: New betfrom Mobile App (o) [RedmineID: #104587]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181211@Joseph: New betfrom Mobile China View (c) [RedmineID: #106088]
		- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
		- 20190619@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
		- 20190829@Amanda: Remove platform y,s and add platform t [RedmineID: #119010]
		- 20190910@Amanda: Add bet types that support Half Won/ Half Lose [RedmineID: #118300]
		- 20190923@Amanda: Change the way to handle Half Won/ Half Lose bet types [RedmineID: #119879]
		- 20191121@Amanda: Exclude PP Promotion and Tournament Prize [RedmineID: #123804]
		- 20191219@Amanda: Add platform v [RedmineID: #125553]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20191226@Vickie: Add platform 0 and change ID platform v[RedmineID: #125824]
		- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
		- 20200306@Kos: Enhance performance [RedmineID: #129722]
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200306@Vickie: Update Param's Explanation for 3 new betfrom [Redmine: #129253]
		- 20200108@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200622@Hogan: Update Param's Explanation for 3 new betfrom 4, 5, 6 [Redmine: #136107]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200728@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201022@Louis: Integrate PG Soft [RedmineID: #139182]
		- 20201126@Hogan: Integrate Joker [RedmineID: #141408]
		- 20201202@Louis: Licensee Spread Setting [RedmineID: #142532]	
		- 20201202@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369]
		- 20201224@Hogan: Integrate GDG [RedmineID: #147267]

	Param's Explanation:
		+ @PlatformType:  0: All
						1: Asia (d, g)
						2: China (a, z)
						3: Euro (e, u) (and Euro 12bet (u))
						4: WAP (m)
						5: MOBILE (l)
						6: TABLET (r)
						7: New Asia (x)
						8: Mobile App (o)
						9: Mobile China View (c)
						10: Deep Link (t)
						11:	Native App
						12: E-Sports Web Desktop (1, 4)
						13: E-Sports Web Mobile (2, 5)
						14: E-Sports App (3, 6)
						88: Others (v)
		+ @drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover onlly)
		+ @excludeTest: remove currency UUS
		+ @showSB: Show SportsBook bets
		+ @ShowNG: Show Number game bets
		+ @ShowBA: Show Bet Aggregator bets (combined WITH Sportsbook or Number Game)
		+ @ShowCS: Show RNG Casino (OneRNG)
		+ @ShowKN: Show Keno
		+ @ShowVB: Show Voidbridge
		+ @ShowAB: Show Allbet
		+ @ShowFW : Show Fishing World
		+ @ShowVS2: Show Virtual sport 2
		+ @ShowLT: Show Lottery
		+ @ShowPP : Show PP
		+ @ShowCC : Show Card club
		+ @MoveBetsDay: The day we move tickets to bettrans14
*/

BEGIN
	SET NOCOUNT ON

	IF DATEDIFF(MONTH, @FromDate, @ToDate) > 1
		RETURN

	CREATE TABLE #WinLoss (
		Winlostdate	DATE,
		CustID		INT,
		Currency	INT,
		Turnover	MONEY, 
		Winlost		MONEY, 
		LicenseeWL	MONEY,
		playercomm	MONEY,
		AmtDueToBA	MONEY,
		CommBA		MONEY,
		Company		MONEY,
		BetCount	BIGINT
		)

	DECLARE @TempFromDate	DATETIME 
	DECLARE @TempToDate		DATETIME 
	DECLARE @FDate			DATETIME
	DECLARE @TDate			DATETIME
	DECLARE @ProductList	VARCHAR (500)

	CREATE TABLE #sporttype (sporttype INT, ProductPrefix VARCHAR(10))
	CREATE TABLE #bettype (bettype INT PRIMARY KEY, ProductPrefix VARCHAR(10))
	CREATE TABLE #tempAg (custID INT, Currency INT)
		
	DECLARE @ExcludedBetType TABLE (ProductId TINYINT, BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductId, BetType)
	SELECT ProductId, BetType FROM Lrf_f_SelExcludedBetType()

	--to Deal WITH Parameter Sniffing
	SELECT @FDate = @FromDate,
		@TDate = @ToDate 

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #tempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #PlatformList (betfrom NVARCHAR(1), PlatformType TINYINT)

	INSERT INTO #PlatformList (betfrom, PlatformType)
	SELECT betfrom, PlatformType
	FROM Lrf_f_BetFromType_Sel(@PlatformType)

	CREATE TABLE #Exchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT)

	IF @ShowSB = 1
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')

	IF @ShowNG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')
	END	

	IF @ShowVS = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
	END

	IF @ShowCS = 1 -- RNG Casino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CS', 'CS')
	END

	IF @ShowKN = 1 -- Keno
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')
	END

	IF @showVB = 1 -- Voidbridge
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VB', 'VB')
	END

	IF @showAB = 1 -- Allbet
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AB', 'AB')
	END

	IF @showFW = 1 -- Fishing World. 
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'FW', 'FW')
	END

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END

	IF @ShowLT = 1 -- Lottery
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'LT', 'LT')
	END
	
	IF @ShowPP = 1 -- PP
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'PP', 'PP')
	END
	
	IF @ShowCC = 1 -- Card Club
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CC', 'CC')
	END

	IF @ShowSG = 1 -- Spadegaming
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SG', 'SG')
	END

	IF @ShowVRG = 1 -- Virtual Games
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VRG', 'VRG')
	END

	IF @ShowTG = 1 -- Table Games
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'TG', 'TG')
	END

	IF @ShowI4D = 1 -- Indo 4D
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'I4D', 'I4D')
	END

	IF @ShowSXG = 1 -- Sexy Gaming
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SXG', 'SXG')
	END

	IF @ShowSBC = 1 -- Saba Club
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SBC', 'SBC')
	END

	IF @ShowSAG = 1 -- Spadegaming
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SAG', 'SAG')
	END
	
	IF @ShowPGS = 1 -- PG Soft
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'PGS', 'PGS')
	END

	IF @ShowJK = 1 -- Joker
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'JK', 'JK')
	END

	IF @ShowGDG = 1 -- GDG
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'GDG', 'GDG')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO #bettype ( bettype, ProductPrefix )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)

		IF @ShowCS = 1
			DELETE #bettype
			WHERE bettype = 72 AND ProductPrefix = 'CS'

		IF @showSB = 1
			DELETE #bettype
			WHERE ProductPrefix IN ('SB')
			
		IF @ShowPP = 1
			DELETE #bettype
			WHERE bettype IN (4300, 4299, 4298, 4297) AND ProductPrefix = 'PP' -- exclude PP Prize, Jackpot Prize, Contribution
		
		IF @ShowSAG = 1
			DELETE #bettype
			WHERE bettype = 3007 AND ProductPrefix = 'SAG' -- exclude SAG Tip ticket
	
		IF @ShowCC = 1
			DELETE #bettype
			WHERE ProductPrefix = 'CC' AND bettype = 1906

		-- Insert Sport Type
		INSERT INTO #sporttype ( sporttype, ProductPrefix )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)
		WHERE sporttype <> 150
	END

	INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeId, Rate
	FROM Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #tempAg ag WHERE e.ExchangeId = ag.Currency)

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate
	
		DECLARE @HWHLCutDate SMALLDATETIME = '2019-10-01' -- half won/ half lose cut date
	
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, AmtDueToBA, CommBA, Company, BetCount)
			SELECT
				b.winlostdate,
				b.CustID,
				b.currency,
				SUM( stake
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE WHEN b.statusID = 111 THEN 0
							WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
							WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN (1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS LicenseeWL,
				SUM(b.playercomm) AS PlayerComm,
				- SUM (b.winlost - b.actual_stake + b.awinlost + b.comm) AS AmountDueToBA,
				SUM (b.comm) AS CommBA,
				0 AS Company,
				--------BetCount-----------
				COUNT(b.transid) 
					* CASE WHEN @drawfilter = 2 THEN
							CASE WHEN b.statusID = 111 THEN 0
							ELSE 1 END
						ELSE 1 END
					   BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS tma ON tma.CustID = b.recommend AND b.currency = tma.currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.transid = BA.transid
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			GROUP BY
				b.winlostdate,
				b.custid,
				b.currency,
				b.statusID
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, AmtDueToBA, CommBA, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.CustID,
				tma.currency,
				SUM( CASE WHEN b.bettype = 34 AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE WHEN b.statusID = 111 THEN 0
							WHEN b.winlostdate >= @HWHLCutDate
								AND b.statusID IN (112, 113)
								AND b.modds IN (-0.25, 0.25)
								AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
							WHEN b.winlostdate < @HWHLCutDate
								AND (b.statusID = 112 OR b.statusID = 113)
								AND ABS(modds) = 0.25
								AND b.bettype IN (1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM(b.playercomm) AS PlayerComm,
				0 AS AmountDueToBA,
				0 AS CommBA,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm)  AS Company,
				--------BetCount-----------
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS tma ON tma.CustID = b.recommend AND b.currency = tma.currency
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND (b.bettype <= 30
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
					OR b.Bettype = 38					   -- Single Match Parlay
				) 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.ProductId = 0 AND e.BetType = b.BetType)
				AND b.tpositiontaking <>0
			GROUP BY
				b.winlostdate,
				b.CustID,
				tma.currency,
				b.statusID
		END

		IF (@ShowNG = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW = 1 OR @ShowVS2 = 1 OR @ShowLT = 1 
			 OR @ShowSAG = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 OR @ShowGDG = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, AmtDueToBA, CommBA, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.CustID,
				tma.currency,
				SUM( CASE WHEN b.bettype = 34 AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END
					) turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM(b.playercomm ) AS PlayerComm,
				0 AS AmountDueToBA,
				0 AS CommBA,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm)  AS Company,
				--------BetCount-----------
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS tma ON tma.CustID = b.recommend AND b.currency = tma.currency
				INNER JOIN #bettype AS bt ON b.bettype = bt.bettype
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND (b.bettype NOT BETWEEN 1611 AND 1699 OR b.matchid <> 150)
			GROUP BY
				b.winlostdate,
				b.CustID,
				tma.currency,
				b.statusID
		END
	END

	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, AmtDueToBA, CommBA, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.custid,
				b.currency,
				SUM(b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				),
				SUM(b.winlost),
				0 AS LicenseeWL,
				SUM(b.playercomm ) AS PlayerComm, 
				- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
				SUM (comm) AS CommBA,
				0 AS Company,
				--------BetCount-----------
				SUM(b.betcount)
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
			FROM bodb_licenseereport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 1
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND ISNULL(b.isBA,0) = 1
			GROUP BY
				b.winlostdate,
				b.CustID,
				b.currency,
				b.statusID
		END

		IF (@showSB = 1 or @ShowNG = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1 
			OR @ShowSAG = 1 OR @ShowPP = 1 OR @showCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 OR @ShowGDG = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, AmtDueToBA, CommBA, Company, BetCount)
			SELECT
				b.winlostdate,
				b.custid, 
				b.currency,
				SUM(b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				),
				SUM(b.winlost),
				- SUM(b.winlost) AS LicenseeWL,
				SUM ( b.playercomm ) AS PlayerComm,
				0 AS AmtDueToBA,
				0 AS CommBA,
				- SUM(b.awinlost + b.winlost + b.comm)  AS Company,
				--------BetCount-----------
				SUM(b.betcount)
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
			FROM bodb_licenseereport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
				INNER JOIN #sporttype AS t ON b.sporttype = t.sporttype
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 1
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND ISNULL(b.isBA,0) = 0
			GROUP BY
				b.winlostdate,
				b.CustID,
				b.currency,
				b.statusID
		END
	END

	----Delete zero data 
	DELETE #WinLoss 
	WHERE Betcount = 0 
		AND Turnover = 0 
		AND Winlost = 0 
		AND LicenseeWL = 0 
		AND PlayerComm = 0 
		AND CommBA = 0 
		AND AmtDuetoBA = 0 
		AND Company = 0

	SELECT 
		w.CustID,
		c.username, 
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
		w.Currency,
		SUM(Betcount)	AS Betcount,
		SUM(TurnOver	* e.Rate)	AS Turnover,
		SUM(Winlost		* e.Rate)	AS Winlost,
		SUM(LicenseeWL	* e.Rate)	AS LicenseeWL,
		SUM(PlayerComm	* e.Rate)	AS PlayerComm,
		SUM(CommBA		* e.Rate)	AS CommBA,
		SUM(AmtDuetoBA	* e.Rate)	AS AmtDuetoBA,
		SUM(Company		* e.Rate)	AS Company
	FROM #WinLoss AS w
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON w.custid = c.custid
		INNER JOIN #Exchange AS e on w.Currency = e.exchangeid AND w.Winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY
		w.CustID,
		w.Currency,
		c.username,
		c.username2
	ORDER BY 5,2

	DROP TABLE #bettype
	DROP TABLE #sporttype
	DROP TABLE #tempAg
	DROP TABLE #WinLoss
	DROP TABLE #Exchange
	DROP TABLE #PlatformList
END
GO 
