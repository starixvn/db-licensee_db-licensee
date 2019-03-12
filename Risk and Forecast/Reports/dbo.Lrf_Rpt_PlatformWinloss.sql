/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_PlatformWinloss]   
	@FromDate	SMALLDATETIME,  
	@ToDate		SMALLDATETIME,   
	@showSB		BIT=0,  
	@ShowNG		BIT=0, 
	@ShowBA		BIT=0,
	@ShowVS		BIT=0,
	@ShowKN		BIT=0,
	@ShowCS		BIT=0,
	@ShowVB		BIT=0,		
	@ShowAB		BIT=0,
	@ShowFW		BIT=0,
	@ShowVS2	BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT		BIT = 0, -- Lottery
	@ShowPP		BIT = 0, -- PP
	@ShowCC		BIT = 0, -- Card club
	@PlatformType	TINYINT=0, 
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
AS

/*  Created: 20160406@Victor
    Task : Platform WinLoss Report 
    DB: DBEXT/bodb02  
   
    Revisions:  
		- 20160719@Jim: Allbet - Live Casino Integration for Licensees (#59624)
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
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
						11: Others (v)
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover onlly)
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

	IF DATEDIFF(MONTH,@FromDate,@ToDate) > 1
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

	CREATE TABLE #bettype	(bettype INT PRIMARY KEY, ProductPrefix VARCHAR(10))

	CREATE TABLE #tempAg	(custID INT, Currency INT)

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

	--to Deal WITH Parameter Sniffing
	SELECT @FDate=@FromDate,@TDate=@ToDate 

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
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #PlatformList (betfrom NVARCHAR(1), PlatformType TINYINT)
	INSERT INTO #PlatformList (betfrom, PlatformType)
	SELECT	d.betfrom, d.PlatformType
	FROM (
		VALUES	(1, 'd'),
				(2, 'a'),
				(3, 'e'),
				(4, 'm'),
				(3, 'u'),
				(5, 'l'),
				(1, 'g'),
				(6, 'r'),
				(7, 'x'),
				(2, 'z'),
				(8, 'o'),
				(9, 'c'),
				(10, 't'),
				(11, 'v')
	) d(PlatformType, betfrom)
	WHERE d.PlatformType = @PlatformType OR @PlatformType = 0

	IF @ShowSB = 1  
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (0, ''SB'')'
	END

	IF @ShowNG = 1	
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (161, ''NG''), (164, ''NG'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN (typeid BETWEEN 81 AND 120) OR (typeid BETWEEN 8101 AND 8120) THEN ''NG''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 81 AND 120) OR (typeid BETWEEN 8101 AND 8120)'
	END

	IF @ShowVS = 1	
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (180, ''VS'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1201 AND 1299 THEN ''VS''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1201 AND 1299)'
	END

	IF @ShowCS=1 -- RNG Casino
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (251, ''CS''), (208, ''CS''), (209, ''CS''), (210, ''CS'')'

		SET @BetTypeSQL = @BetTypeSQL + '
			SELECT 71, ''CS''
			UNION ALL
			SELECT DISTINCT bettype, ''CS''
			FROM dbo.SportBettypeMatrix WITH(NOLOCK)
			WHERE sporttype IN (208, 209, 210)'
	END

	IF @ShowKN=1 -- Keno
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

	IF @showFW = 1 -- Fishing World. 
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

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1021 AND 1049 THEN ''LT''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1021 AND 1049)'
	END
	
	IF @ShowPP = 1 -- PP -- exclude 4300, 4299
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (248, ''PP'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 4101 AND 4298 THEN ''PP''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 4101 AND 4298)'
	END
	
	IF @ShowCC = 1 -- Card Club
	BEGIN
		SET @SportTypeSQL = @SportTypeSQL + ', (165, ''CC'')'

		SET @BetTypeSelectSQL = @BetTypeSelectSQL + 'WHEN typeid BETWEEN 1901 AND 1999 THEN ''CC''
				'

		SET @BetTypeWhereSQL = @BetTypeWhereSQL + ' OR (typeid BETWEEN 1901 AND 1999)'
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
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate
	
		DECLARE @HWHLCutDate SMALLDATETIME = '2019-10-01' -- half won/ half lose cut date
	
		IF @ShowBA=1
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
							WHEN b.winlostdate >= @HWHLCutDate AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
							WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,	
				0 as LicenseeWL,
				SUM(b.playercomm  ) as PlayerComm,
				--------BetCount-----------
				COUNT(b.transid) 
					* CASE WHEN @drawfilter = 2 THEN
							CASE WHEN b.statusID = 111 THEN 0
							ELSE 1 END
						ELSE 1 END
					   BetCount
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #tempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID  IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			GROUP BY   b.winlostdate, b.currency, b.statusID, pl.PlatformType
		END
	
		IF (@ShowSB=1)
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
							WHEN b.winlostdate < @HWHLCutDate AND (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,	
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL ,
				SUM (   b.playercomm ) as PlayerComm,
				--------BetCount-----------
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #tempAg tma ON tma.CustID=b.recommend  AND b.currency = tma.currency
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID  IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND (b.bettype<=30 OR (b.bettype BETWEEN 121 AND 999)
								  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
								  OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0
								  OR b.Bettype = 38					 -- Single Match Parlay
				) 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.tpositiontaking <>0
			GROUP BY  b.winlostdate, tma.currency, b.statusID, pl.PlatformType
		END
	
	
		IF (@ShowNG=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB =1  OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1 OR @ShowPP = 1 OR @ShowCC = 1)
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
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL ,
				SUM ( b.playercomm ) as PlayerComm,
				--------BetCount-----------
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #tempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID  IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			GROUP BY   b.winlostdate, tma.currency, b.statusID, bt.ProductPrefix, 
				pl.PlatformType

		END
	END		
				
	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @TDate

		INSERT INTO #rptLicWinloss2(currency, sporttype, winlostdate, isBA, PlatformType,Turnover, winlost, LicenseeWL, playercomm, BetCount)
		SELECT	b.currency,
				b.sporttype,
				b.winlostdate,
				b.isBA,
				pl.PlatformType,
				SUM(b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				) AS Turnover,
				SUM(b.winlost) AS Winlost,
				- SUM(b.winlost) AS LicenseeWL ,
				SUM ( b.playercomm ) as PlayerComm,
				--------BetCount-----------
				SUM(b.betcount)
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END AS BetCount
		FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN 	#tempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
		WHERE b.Winlostdate BETWEEN @FDate AND @TempToDate
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.bettype NOT IN (4300, 4299) -- exclude PP Prize
		GROUP BY b.currency,
				b.sporttype,	
				b.winlostdate,
				b.statusID,
				b.isBA,
				pl.PlatformType

		IF @ShowBA=1 
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
			SELECT 
				b.winlostdate,
				b.currency,
				'BA' AS ProductPrefix,
				b.PlatformType,

				SUM(b.turnover),     
				SUM(b.winlost),  
				0 as LicenseeWL,
				SUM(b.playercomm ) AS PlayerComm, 
				--------BetCount-----------
				SUM(b.betcount)
			FROM #rptLicWinloss2 b WITH ( NOLOCK )
			WHERE b.isBA = 1	
			GROUP BY b.winlostdate, b.currency, b.PlatformType
			
		END

		IF (@showSB = 1 or @ShowNG = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1 OR @ShowPP = 1 OR @ShowCC = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
			SELECT 
				b.winlostdate,
				b.currency,
				t.ProductPrefix,
				b.PlatformType,
				SUM(b.Turnover),
				SUM(b.winlost),
				SUM(b.LicenseeWL) AS LicenseeWL ,
				SUM(b.playercomm ) as PlayerComm,
				--------BetCount-----------
				SUM(b.betcount)
			FROM #rptLicWinloss2 b WITH ( NOLOCK )
				INNER JOIN #sporttype t ON b.sporttype = t.sporttype
			WHERE (b.isBA = 0 OR b.isBA IS NULL)
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
	FROM #WinLoss w 
		INNER JOIN  #Exchange e on w.Currency=e.exchangeid AND w.Winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY
		w.ProductPrefix, w.PlatformType
	ORDER BY w.PlatformType, w.ProductPrefix

	DROP TABLE #sporttype
	DROP TABLE #bettype
	DROP TABLE #Exchange
	DROP TABLE #WinLoss
	DROP TABLE #tempAg

END
GO