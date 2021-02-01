/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_PlatformWinloss]
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
	@ShowSXG	BIT = 0, -- Sexy Gaming
	@ShowI4D	BIT = 0,
	@ShowSBC	BIT = 0, -- Saba Club
	@ShowSAG	BIT = 0, -- SA Gaming
	@ShowPGS	BIT = 0, -- PG Soft
	@ShowJK		BIT = 0, -- Joker
	@ShowGDG	BIT = 0, -- GDG
	@PlatformType	TINYINT			= 0,
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT		= 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)		= ''
AS

/*
	Created: 20160406@Victor
	Task : Platform WinLoss Report
	DB: DBEXT/bodb02

	Revisions:
		- 20160719@Jim: Allbet - Live Casino Integration for Licensees (#59624)
		- 20160727@Jim: LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
		- 20161128@Paul: enhance performance [RedmineID :#66801]
		- 20170301@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170706@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170802@Sophia: Add new betfrom [redmine: #80687]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20171020@Harper: LRF - Add "New Asia" in platform list [RedmineID: #85203]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180418@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92318]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20181113@Joseph: New betfrom Mobile App (o) [RedmineID: #104587]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181211@Joseph: New betfrom Mobile China View (c) [RedmineID: #106088]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
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
		- 20200715@Louis: Add new bet types for Keno/Lottery/TableGame [RedmineID: #137625]
		- 20200728@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201022@Louis: Integrate PG Soft [RedmineID: #139182]
		- 20201126@Hogan: Integrate Joker [RedmineID: #141408]
		- 20201202@Louis: Licensee Spread Setting [RedmineID: #142532]	
		- 20201202@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369]
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]	
		- 20200122@Hogan: Integrate GDG [RedmineID: #147267]

	Param's Explanation:
		+ @PlatformType: 0: All
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
		+ @Drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover onlly)
		+ @showSB: Show SportsBook bets
		+ @ShowNG: Show Number game bets
		+ @ShowBA: Show Bet Aggregator bets (combined WITH Sportsbook or Number Game)
		+ @ShowCS: Show RNG Casino (OneRNG)
		+ @ShowKN: Show Keno
		+ @ShowVB: Show Voidbridge
		+ @ShowAB: Show Allbet
		+ @ShowFW: Show Fishing World
		+ @ShowVS2: Show Virtual sport 2
		+ @ShowLT: Show Lottery
		+ @ShowPP: Show PP
		+ @ShowCC: Show Card club
		+ @MoveBetsDay: The day we move tickets to bettrans14
*/

BEGIN
	SET NOCOUNT ON

	IF DATEDIFF(MONTH, @FromDate, @ToDate) > 1
		RETURN

	CREATE TABLE #WinLoss (
		Winlostdate DATE,
		Currency	INT ,
		ProductPrefix	VARCHAR(10),
		PlatformType	TINYINT,
		Turnover	MONEY, 
		Winlost		MONEY, 
		LicenseeWL	MONEY,
		playercomm	MONEY,
		BetCount	BIGINT
	)

	DECLARE @TempFromDate SMALLDATETIME,
			@TempToDate SMALLDATETIME, 
			@FDate SMALLDATETIME,
			@TDate SMALLDATETIME,
			@SportTypeSQL NVARCHAR(MAX) = '',
			@BetTypeSQL NVARCHAR(MAX) = '',
			@BetTypeSelectSQL NVARCHAR(MAX) = '',
			@BetTypeWhereSQL NVARCHAR(MAX) = ''

	CREATE TABLE #sporttype (sporttype INT, ProductPrefix VARCHAR(10))
	CREATE TABLE #bettype (bettype INT PRIMARY KEY, ProductPrefix VARCHAR(10))
	CREATE TABLE #tempAg (custID INT, Currency INT)

	CREATE CLUSTERED INDEX ix_tempAg_cl ON #tempAg(Currency, custID)

	CREATE TABLE #rptLicWinloss2(
		currency	SMALLINT,
		sporttype	SMALLINT,
		winlostdate	SMALLDATETIME,
		isBA		BIT,
		Turnover	MONEY,
		Winlost		MONEY,
		LicenseeWL	MONEY,
		playercomm	MONEY,
		BetCount	MONEY,
		PlatformType TINYINT
	)

	DECLARE @ExcludedBetType TABLE (ProductId TINYINT, BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductId, BetType)
	SELECT ProductId, BetType FROM Lrf_f_SelExcludedBetType()

	--to Deal WITH Parameter Sniffing
	SELECT @FDate = @FromDate,
		@TDate = @ToDate 

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

	IF @ShowSB = 1
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (0, ''SB'')'
	END

	IF @ShowNG = 1
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (161, ''NG''), (164, ''NG''), (168, ''NG'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN (typeid BETWEEN 81 AND 120) OR (typeid BETWEEN 8101 AND 8120) OR (typeid BETWEEN 3601 AND 3610) THEN ''NG''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 81 AND 120) OR (typeid BETWEEN 8101 AND 8120) OR (typeid BETWEEN 3601 AND 3610)'
	END

	IF @ShowVS = 1
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (180, ''VS'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1201 AND 1299 THEN ''VS''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1201 AND 1299)'
	END

	IF @ShowCS = 1 -- RNG Casino
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (251, ''CS''), (208, ''CS''), (209, ''CS''), (210, ''CS'')'

		SET @BetTypeSQL = @BetTypeSQL + '
			SELECT 71, ''CS''
			UNION ALL
			SELECT DISTINCT bettype, ''CS''
			FROM dbo.SportBettypeMatrix WITH(NOLOCK)
			WHERE sporttype IN (208, 209, 210)'
	END

	IF @ShowKN = 1 -- Keno
	BEGIN 
		SET @SportTypeSQL = @SportTypeSQL + ', (202, ''KN'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1501 AND 1599 THEN ''KN''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1501 AND 1599)'
	END

	IF @showVB = 1 -- Voidbridge
	BEGIN 
		SET @SportTypeSQL = @SportTypeSQL + ', (212, ''VB'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 4001 AND 4100 THEN ''VB''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4001 AND 4100)'
	END

	IF @showAB = 1 -- Allbet
	BEGIN 
		SET @SportTypeSQL = @SportTypeSQL + ', (211, ''AB'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 2401 AND 2499 THEN ''AB''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 2401 AND 2499)'
	END

	IF @showFW = 1 -- Fishing World
	BEGIN 
		SET @SportTypeSQL = @SportTypeSQL + ', (219, ''FW'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1011 AND 1020 THEN ''FW''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1011 AND 1020)'
	END

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (190, ''VS2''), (193, ''VS2'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 2701 AND 2829 THEN ''VS2''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 2701 AND 2829)'
	END

	IF @ShowLT = 1 -- Lottery
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (220, ''LT'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1021 AND 1099 THEN ''LT''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1021 AND 1099)'
	END
	
	IF @ShowPP = 1 -- PP -- exclude 4300, 4299, 4298, 4297
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (248, ''PP'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 4101 AND 4296 THEN ''PP''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4101 AND 4296)'
	END
	
	IF @ShowCC = 1 -- Card Club -- exclude 1906
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (165, ''CC'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN (typeid BETWEEN 1901 AND 1999) AND typeid <> 1906 THEN ''CC''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1901 AND 1999 AND typeid <> 1906)'
	END

	IF @ShowSG = 1 -- Spadegaming 
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (247, ''SG'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 4301 AND 4600 THEN ''SG''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4301 AND 4600)'
	END

	IF @ShowVRG = 1 -- Virtual Games
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (245, ''VRG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 4601 AND 4900 THEN ''VRG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4601 AND 4900)'
	END
	
	IF @ShowTG = 1 -- Table Games
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (222, ''TG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 4901 AND 5000 THEN ''TG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4901 AND 5000)'
	END

	IF @ShowI4D = 1 -- Indo 4D
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (223, ''I4D'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 5001 AND 5099 THEN ''I4D''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 5001 AND 5099)'
	END

	IF @ShowSXG = 1 -- Sexy Gamming
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (243, ''SXG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 3101 AND 3199 THEN ''SXG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3101 AND 3199)'
	END

	IF @ShowSBC = 1 -- Saba Club
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (200, ''SBC'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1611 AND 1699 THEN ''SBC''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1611 AND 1699)'
	END

	IF @ShowSAG = 1 -- SA Gaming 
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (244, ''SAG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN (typeid BETWEEN 3001 AND 3099) AND typeid <> 3007 THEN ''SAG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3001 AND 3099 AND typeid <> 3007)'
	END

	IF @ShowPGS = 1 -- PG Soft
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (232, ''PGS'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 6001 AND 6300 THEN ''PGS''	
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 6001 AND 6300)'
	END

	IF @ShowJK = 1 -- Joker
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (234, ''JK'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 6401 AND 6700 THEN ''JK''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 6401 AND 6700)'
	END

	IF @ShowGDG = 1 -- GDG
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (236, ''GDG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 5701 AND 5799 THEN ''GDG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 5701 AND 5799)'
	END

	SET @SportTypeSQL = STUFF(@SportTypeSQL, 1, 1, '')

	SET @BetTypeWhereSQL = STUFF(@BetTypeWhereSQL, 1, 3, '')

	IF @SportTypeSQL <> ''
	BEGIN
		SET @SportTypeSQL = N'INSERT INTO #sporttype (sporttype, ProductPrefix) VALUES' + @SportTypeSQL

		EXEC sys.sp_executesql @SportTypeSQL
	END

	IF @BetTypeSelectSQL <> ''
	BEGIN
		SET @BetTypeSQL = '
			INSERT INTO #bettype(bettype, ProductPrefix)
			SELECT typeid, CASE ' + @BetTypeSelectSQL + 'END
			FROM bettype WITH(NOLOCK)
			WHERE' + @BetTypeWhereSQL + CASE WHEN @BetTypeSQL <> '' THEN '
			UNION ALL' + @BetTypeSQL ELSE '' END

		EXEC sys.sp_executesql @BetTypeSQL
	END
	ELSE IF @BetTypeSQL <> ''
	BEGIN
		SET @BetTypeSQL = '
			INSERT INTO #bettype(bettype, ProductPrefix)
			' + @BetTypeSQL

		EXEC sys.sp_executesql @BetTypeSQL
	END

	CREATE TABLE #Exchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT)

	INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') t_ex
	WHERE EXISTS (SELECT 1 FROM #tempAg t_ag WHERE t_ag.Currency = t_ex.ExchangeID)

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate
	
		DECLARE @HWHLCutDate SMALLDATETIME = '2019-10-01' -- half won/ half lose cut date
	
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)

			SELECT
				b.Winlostdate, 
				b.currency,
				'BA' AS ProductPrefix,
				pl.PlatformType,
				SUM( stake
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
								AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS LicenseeWL,
				SUM(b.playercomm) AS PlayerComm,
				--------BetCount-----------
				COUNT(b.transid) 
					* CASE WHEN @drawfilter = 2 THEN
							CASE WHEN b.statusID = 111 THEN 0
							ELSE 1 END
						ELSE 1 END
					   BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS tma ON tma.CustID = b.recommend AND b.currency = tma.currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			GROUP BY
				b.winlostdate,
				b.currency,
				b.statusID,
				pl.PlatformType
		END
	
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
			SELECT
				b.winlostdate,
				tma.currency,
				'SB' AS ProductPrefix,
				pl.PlatformType,
				SUM( CASE WHEN b.bettype = 34 AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE WHEN b.statusID = 111 THEN 0
							WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
							WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM (  b.playercomm ) AS PlayerComm,
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
					OR b.Bettype = 38					 -- Single Match Parlay
				) 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.ProductId = 0 AND e.BetType = b.BetType)
				AND b.tpositiontaking <>0
			GROUP BY
				b.winlostdate,
				tma.currency,
				b.statusID,
				pl.PlatformType
		END

		IF (@ShowNG=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB =1  OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1 
			OR @ShowSAG = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 OR @ShowGDG = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
			SELECT 
				b.Winlostdate,
				tma.currency,
				bt.ProductPrefix AS ProductPrefix,
				pl.PlatformType,
				SUM(
					CASE WHEN b.bettype = 34 AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
					*
					CASE WHEN @drawfilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END
				) turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM ( b.playercomm ) AS PlayerComm,
				--------BetCount-----------
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				  BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS tma ON tma.custID = b.recommend AND b.currency = tma.currency
				INNER JOIN #bettype AS bt ON b.bettype = bt.bettype
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND (b.bettype NOT BETWEEN 1611 AND 1699 OR b.matchid <> 150)
			GROUP BY
				b.winlostdate,
				tma.currency,
				b.statusID,
				bt.ProductPrefix, 
				pl.PlatformType
		END
	END

	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		INSERT INTO #rptLicWinloss2(currency, sporttype, winlostdate, isBA, PlatformType,Turnover, winlost, LicenseeWL, playercomm, BetCount)
		SELECT
			b.currency,
			b.sporttype,
			b.winlostdate,
			b.isBA,
			pl.PlatformType,
			SUM(b.turnover
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) AS Turnover,
			SUM(b.winlost) AS Winlost,
			- SUM(b.winlost) AS LicenseeWL,
			SUM ( b.playercomm ) AS PlayerComm,
			--------BetCount-----------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END AS BetCount
		FROM bodb_licenseereport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN #tempAg AS ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
		WHERE b.winlostdate BETWEEN @FDate AND @TempToDate
			AND b.roleid = 1  
			AND b.statusID <> 101 --exclude REJECT bets
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			AND b.sporttype <> 150
		GROUP BY
			b.currency,
			b.sporttype,
			b.winlostdate,
			b.statusID,
			b.isBA,
			pl.PlatformType

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
			SELECT 
				b.winlostdate,
				b.currency,
				'BA' AS ProductPrefix,
				b.PlatformType,
				SUM(b.turnover),
				SUM(b.winlost), 
				0 AS LicenseeWL,
				SUM(b.playercomm ) AS PlayerComm,
				--------BetCount-----------
				SUM(b.betcount)
			FROM #rptLicWinloss2 b WITH ( NOLOCK )
			WHERE b.isBA = 1
			GROUP BY
				b.winlostdate,
				b.currency,
				b.PlatformType
		END

		IF (@showSB = 1 or @ShowNG = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1 
			OR @ShowSAG = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 OR @ShowGDG = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
			SELECT 
				b.winlostdate,
				b.currency,
				t.ProductPrefix,
				b.PlatformType,
				SUM(b.Turnover),
				SUM(b.winlost),
				SUM(b.LicenseeWL) AS LicenseeWL,
				SUM(b.playercomm ) AS PlayerComm,
				--------BetCount-----------
				SUM(b.betcount)
			FROM #rptLicWinloss2 AS b WITH (NOLOCK)
				INNER JOIN #sporttype AS t ON b.sporttype = t.sporttype
			WHERE b.isBA = 0 OR b.isBA IS NULL
			GROUP BY
				b.winlostdate,
				b.currency,
				t.ProductPrefix,
				b.PlatformType
		END
	END

	----Delete zero data 
	DELETE #WinLoss WHERE Betcount = 0 AND Turnover = 0 AND Winlost = 0 AND LicenseeWL = 0 AND PlayerComm = 0

	SELECT 
		w.ProductPrefix, 
		w.PlatformType,
		SUM(Betcount)		AS Betcount,
		SUM(Turnover * e.Rate)		AS Turnover,
		SUM(Winlost * e.Rate)		AS Winlost,
		SUM(LicenseeWL * e.Rate)	AS LicenseeWL,
		SUM(PlayerComm * e.Rate)	AS PlayerComm
	FROM #WinLoss AS w
		INNER JOIN #Exchange AS e on w.Currency = e.exchangeid AND w.Winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY
		w.ProductPrefix,
		w.PlatformType
	ORDER BY
		w.PlatformType,
		w.ProductPrefix

	DROP TABLE #sporttype
	DROP TABLE #bettype
	DROP TABLE #Exchange
	DROP TABLE #WinLoss
	DROP TABLE #tempAg
	DROP TABLE #rptLicWinloss2
	DROP TABLE #PlatformList
END
GO