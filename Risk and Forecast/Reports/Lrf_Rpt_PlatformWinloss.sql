/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_PlatformWinloss]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
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
	@ShowSLT	BIT = 0, -- SLT
	@ShowHB		BIT = 0, -- Habanero
	@ShowWM		BIT = 0, -- WM Live Casino
	@ShowBGG	BIT = 0, -- Big Gaming
	@ShowVGA	BIT = 0, -- Vgaming
	@ShowCG		BIT = 0, -- Creative Gaming
	@ShowAP		BIT = 0, -- AdvantPlay
	@ShowAPM	BIT = 0, -- AdvantPlay Mini
	@ShowVS3	BIT = 0, -- Virtual Sports 3
	@ShowBTC	BIT = 0, -- Bitcoin
	@ShowFGGL	BIT = 0, -- FGG Guaranteed Gaming
	@ShowMXG	BIT = 0, -- MaxGame
	@PlatformType	VARCHAR(100)	= 'All',
	@DrawFilter		SMALLINT		= 1,
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
		- 20210122@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]
		- 20210330@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210409@Hogan: Integrate AE Casino Lucky Draw [RedmineID: #151984]
		- 20210416@Hogan: Integrate Habanero RNG Games [RedmineID: #150843]
		- 20210428@Hogan: Integrate WM Live Casino [RedmineID: #140944]
		- 20210518@Mark: Support multiple selection on Platform filter [Redmine: #153102]
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

	Param's Explanation:
		+ @PlatformType: List of platform type (ex: 1,2,3,..)
			All: All
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

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #WinLoss (
		WinLostDate DATE,
		Currency	INT ,
		ProductPrefix	VARCHAR(10),
		PlatformType	TINYINT,
		Turnover	MONEY, 
		WinLost		MONEY, 
		LicenseeWL	MONEY,
		PlayerComm	MONEY,
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

	CREATE TABLE #SportType (SportType INT PRIMARY KEY, ProductPrefix VARCHAR(10))
	CREATE TABLE #BetType (BetType INT PRIMARY KEY, ProductPrefix VARCHAR(10))

	CREATE TABLE #rptLicWinloss2 (
		Currency		SMALLINT,
		SportType		SMALLINT,
		WinLostDate		SMALLDATETIME,
		IsBA			BIT,
		Turnover		MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		PlayerComm		MONEY,
		BetCount		MONEY,
		PlatformType	TINYINT
	)

	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

	--to Deal WITH Parameter Sniffing
	SELECT @FDate = @FromDate,
		@TDate = @ToDate 

	CREATE TABLE #PlatformList (betfrom NVARCHAR(1) PRIMARY KEY, PlatformType TINYINT)

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
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN (typeid BETWEEN 4001 AND 4100) OR (typeid BETWEEN 5800 AND 5999) THEN ''VB''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4001 AND 4100) OR (typeid BETWEEN 5800 AND 5999)'
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
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 4101 AND 4296 OR typeid BETWEEN 6701 AND 7000 THEN ''PP''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4101 AND 4296) OR typeid BETWEEN 6701 AND 7000'
	END
	
	IF @ShowCC = 1 -- Card Club -- exclude 1906
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (165, ''CC'')'
		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1901 AND 1999 THEN ''CC''
				'
		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1901 AND 1999)'
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

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 3101 AND 3149 THEN ''SXG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3101 AND 3149)'
	END

	IF @ShowSBC = 1 -- Saba Club exclude SBC Jackpot(1698, 1699)
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (200, ''SBC'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1611 AND 1697 THEN ''SBC''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1611 AND 1697)'
	END

	IF @ShowSAG = 1 -- SA Gaming 
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (244, ''SAG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 3001 AND 3099 THEN ''SAG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3001 AND 3099)'
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

	IF @ShowSLT = 1 -- SLT
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (169, ''SLT'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 3611 AND 3620 THEN ''SLT''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3611 AND 3620)'
	END

	IF @ShowHB = 1 -- HB
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (238, ''HB'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 7001 AND 7300 THEN ''HB''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 7001 AND 7300)'
	END
	
	IF @ShowWM = 1 -- WM
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (233, ''WM'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 3401 AND 3499 THEN ''WM''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3401 AND 3499)'
	END

	IF @ShowBGG = 1 -- Big Gaming
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (239, ''BGG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 3501 AND 3599 THEN ''BGG''				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3501 AND 3599)'
	END


	IF @ShowVGA = 1 -- VGA
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (171, ''VGA'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 3801 AND 3899 THEN ''VGA''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 3801 AND 3899)'
	END

	IF @ShowCG = 1 -- CG
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (167, ''CG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 7301 AND 7600 THEN ''CG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 7301 AND 7600)'
	END

	IF @ShowAP = 1 -- AP
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (172, ''AP'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 7701 AND 7799 THEN ''AP''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 7701 AND 7799)'
	END

	IF @ShowAPM = 1 -- APM
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (174, ''APM'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 7801 AND 7899 THEN ''APM''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 7801 AND 7899)'
	END

	IF @ShowVS3 = 1 -- VS3
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (231, ''VS3'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 5301 AND 5399 THEN ''VS3''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 5301 AND 5399)'
	END

	IF @ShowBTC = 1 -- Bitcoin
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (175, ''BTC'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 7901 AND 7999 THEN ''BTC''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 7901 AND 7999)'
	END
	
	IF @ShowFGGL = 1 -- FGGL
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (176, ''FGGL'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 8201 AND 8299 THEN ''FGGL''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 8201 AND 8299)'
	END
	
	IF @ShowMXG = 1 -- MaxGame
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (237, ''MXG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 5401 AND 5499 THEN ''MXG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 5401 AND 5499)'
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

	-- Group products under SB into SB
	DECLARE @SBProductList VARCHAR(100) = 'SB'

	SET @SBProductList = dbo.Lrf_f_GroupProductCode(@SBProductList)

	UPDATE #BetType
	SET ProductPrefix = 'SB'
	WHERE ProductPrefix <> 'SB'
		AND ',' + @SBProductList + ',' LIKE '%,' + ProductPrefix + ',%'

	UPDATE #SportType
	SET ProductPrefix = 'SB'
	WHERE ProductPrefix <> 'SB'
		AND ',' + @SBProductList + ',' LIKE '%,' + ProductPrefix + ',%'

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
				SUM(b.stake
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
				COUNT(b.transid) * CASE
										WHEN @DrawFilter = 2 THEN CASE
																	WHEN b.statusID = 111 THEN 0
																	ELSE 1
																END
										ELSE 1
									END AS BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS tma ON tma.CustId = b.recommend
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
			INSERT INTO #WinLoss (WinLostDate, Currency, ProductPrefix, PlatformType, Turnover, WinLost, LicenseeWL, PlayerComm, BetCount)
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
				SUM(b.playercomm) AS PlayerComm,
				COUNT(b.transid) * CASE
										WHEN @drawfilter = 2 THEN CASE
																	WHEN b.statusID = 111 THEN 0
																	ELSE 1
																END
										ELSE 1
									END AS BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tempAg AS tma ON tma.CustID = b.recommend
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND (b.bettype <= 30
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
					OR (b.Bettype BETWEEN 9400 AND 9998) -- Cricket AIO
					OR (b.Bettype BETWEEN 3900 AND 3999) -- Volleyball AIO
					OR b.Bettype = 38					 -- Single Match Parlay
				) 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.ProductCode = 'SB' AND e.BetType = b.BetType)
				AND b.tpositiontaking <>0
			GROUP BY
				b.winlostdate,
				tma.currency,
				b.statusID,
				pl.PlatformType
		END

		IF (@ShowNG=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB =1  OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1 OR @ShowSAG = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 
			OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 OR @ShowGDG = 1 OR @ShowSLT = 1 OR @ShowHB = 1 OR @ShowWM = 1 OR @ShowBGG = 1
			OR @ShowVGA = 1 OR @ShowCG = 1 OR @ShowAP = 1 OR @ShowAPM = 1 OR @ShowVS3 = 1 OR @ShowBTC = 1 OR @ShowFGGL = 1 OR @ShowMXG = 1)
		BEGIN
			INSERT INTO #WinLoss (WinLostDate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, PlayerComm, BetCount)
			SELECT
				b.Winlostdate,
				tma.currency,
				bt.ProductPrefix,
				pl.PlatformType,
				SUM(b.stake * CASE WHEN @DrawFilter IN (2,3) AND b.statusID = 111 THEN 0 ELSE 1 END) AS turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM(b.playercomm) AS PlayerComm,
				COUNT(b.transid) * CASE
										WHEN @DrawFilter = 2 THEN CASE
																	WHEN b.statusID = 111 THEN 0
																	ELSE 1 END
										ELSE 1
									END AS BetCount
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS tma ON tma.CustId = b.recommend
				INNER JOIN #BetType AS bt ON b.bettype = bt.BetType
				INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND (b.bettype NOT BETWEEN 1611 AND 1697 OR b.matchid <> 150)
				AND (b.bettype NOT BETWEEN 3801 AND 3899 OR b.matchid <> 173)
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

		INSERT INTO #rptLicWinloss2 (Currency, SportType, WinLostDate, IsBA, PlatformType,Turnover, WinLost, LicenseeWL, PlayerComm, BetCount)
		SELECT
			b.currency,
			b.sporttype,
			b.winlostdate,
			b.isBA,
			pl.PlatformType,
			SUM(b.turnover * CASE
								WHEN @DrawFilter IN (2,3) THEN CASE
																	WHEN b.statusID = 111 THEN 0
																	WHEN b.statusID IN (114, 115) THEN 0.5
																	ELSE 1
																END
								ELSE 1
							END) AS Turnover,
			SUM(b.winlost) AS Winlost,
			- SUM(b.winlost) AS LicenseeWL,
			SUM(b.playercomm) AS PlayerComm,
			SUM(b.betcount) * CASE
								WHEN @DrawFilter = 2 THEN CASE
															WHEN b.statusID = 111 THEN 0
															ELSE 1
														END
								ELSE 1
							END AS BetCount
		FROM bodb_licenseereport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS ag ON b.recommend = ag.CustId
			INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
		WHERE b.winlostdate BETWEEN @FDate AND @TempToDate
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			AND b.sporttype NOT IN (150, 173)
		GROUP BY
			b.currency,
			b.sporttype,
			b.winlostdate,
			b.statusID,
			b.isBA,
			pl.PlatformType

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #WinLoss (WinLostDate, Currency, ProductPrefix, PlatformType, Turnover, WinLost, LicenseeWL, PlayerComm, BetCount)
			SELECT 
				b.winlostdate,
				b.currency,
				'BA' AS ProductPrefix,
				b.PlatformType,
				SUM(b.Turnover),
				SUM(b.WinLost), 
				0 AS LicenseeWL,
				SUM(b.PlayerComm) AS PlayerComm,
				SUM(b.BetCount)
			FROM #rptLicWinloss2 b WITH (NOLOCK)
			WHERE b.isBA = 1
			GROUP BY
				b.winlostdate,
				b.currency,
				b.PlatformType
		END

		IF (@showSB = 1 OR @ShowNG = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1 OR @ShowSAG = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 
			OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 OR @ShowGDG = 1 OR @ShowSLT = 1 OR @ShowHB = 1 OR @ShowWM = 1 OR @ShowBGG = 1 OR @ShowVGA = 1
			OR @ShowCG = 1 OR @ShowAP = 1 OR @ShowAPM = 1 OR @ShowVS3 = 1 OR @ShowBTC = 1 OR @ShowFGGL = 1 OR @ShowMXG = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, WinLost, LicenseeWL, PlayerComm, BetCount)
			SELECT
				b.winlostdate,
				b.currency,
				t.ProductPrefix,
				b.PlatformType,
				SUM(b.Turnover),
				SUM(b.WinLost),
				SUM(b.LicenseeWL) AS LicenseeWL,
				SUM(b.PlayerComm) AS PlayerComm,
				SUM(b.BetCount)
			FROM #rptLicWinloss2 AS b WITH (NOLOCK)
				INNER JOIN #SportType AS t ON b.sporttype = t.SportType
			WHERE b.isBA = 0 OR b.isBA IS NULL
			GROUP BY
				b.winlostdate,
				b.currency,
				t.ProductPrefix,
				b.PlatformType
		END
	END

	-- Delete zero data
	DELETE #WinLoss WHERE Betcount = 0 AND Turnover = 0 AND Winlost = 0 AND LicenseeWL = 0 AND PlayerComm = 0

	-- Get exchange rate
	DECLARE @Exchange TABLE (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT)

	INSERT INTO @Exchange (FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') t_ex
	WHERE EXISTS (SELECT 1 FROM #TempAg t_ag WHERE t_ag.Currency = t_ex.ExchangeID)

	SELECT
		w.ProductPrefix,
		w.PlatformType,
		SUM(w.BetCount)		AS BetCount,
		SUM(w.Turnover		* e.Rate)	AS Turnover,
		SUM(w.WinLost		* e.Rate)	AS WinLost,
		SUM(w.LicenseeWL	* e.Rate)	AS LicenseeWL,
		SUM(w.PlayerComm	* e.Rate)	AS PlayerComm
	FROM #WinLoss AS w
		INNER JOIN @Exchange AS e on w.Currency = e.exchangeid AND w.Winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY
		w.ProductPrefix,
		w.PlatformType
	ORDER BY
		w.PlatformType ASC,
		w.ProductPrefix ASC

	DROP TABLE #SportType
	DROP TABLE #BetType
	DROP TABLE #WinLoss
	DROP TABLE #TempAg
	DROP TABLE #rptLicWinloss2
	DROP TABLE #PlatformList
END
GO
