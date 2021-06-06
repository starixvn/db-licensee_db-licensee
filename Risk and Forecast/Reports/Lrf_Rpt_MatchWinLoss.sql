/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLoss]
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@showSB			BIT = 0,
	@showNG			BIT = 0,
	@showBA			BIT = 0,
	@ShowVS			BIT = 0,
	@showVS2		BIT = 0,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
AS

/*
	Created: 20120529@Don
	DB: DBEXT.bodb02
	Original: Lrf_Rpt_MatchWinLoss

	Revisions:
		- 20120815@Henry: add live casino
		- 20120820@Jim: add more bettype, sporttype, showtime columns in the result
		- 20120831@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130401@Scott: add more parameter @ShowCS,@ShowBG
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20140423@Kyan: offer Virtual Speedway, Virtual Cycling
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20140915@Florent: hotfix duplicated VS bettype
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20150123@Jim: support base on Currency GBP
		- 20150622@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170704@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20191118@Amanda: Remove unused param [RedmineID: #120336]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]

	Param's Explanation:
		 + @AgentList: xml structure
				<ROOT>
					<Agent AgentId="12345" Currency="3"/>
					<Agent AgentId="12345" Currency="5"/>
				</ROOT> 
*/

/* demo script
exec Lrf_Rpt_MatchWinLoss @LicenseeID=3,@LicenseeType=default,@CurrencyName=default,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showNG=0,@showBA=0  
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ExchangeDaily TABLE(ExchangeId INT, Rate FLOAT)

	DECLARE @bettype		TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @ProductList	VARCHAR(500)

	DECLARE @_Date AS DATETIME
	SET @_Date = @Date

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()
				
	DECLARE @TempAg AS TABLE ( CustId INT, Currency INT )
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [INT], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	DECLARE @AgMatchWLDetails TABLE
	(
		Winlostdate		SMALLDATETIME,
		KickoffTime		DATETIME,
		Currency		INT,
		matchid			INT,
		homeid			INT,
		awayid			INT,
		bettype			SMALLINT,
		ProductName		VARCHAR(4),
		leagueid		INT,
		turnover		MONEY,
		MemberWinLost	MONEY,
		LicenseeWL		MONEY, --Sportbook and NumberGame
		AmtDueToBA		MONEY,
		CommBA			MONEY,
		PlayerComm		MONEY,
		race			NVARCHAR(20),
		matchcode		NVARCHAR(50),
		isNeutral		BIT,
		sporttype		SMALLINT,
		showtime		NVARCHAR(50),
		betcount		INT
	)

	CREATE TABLE #TempBetList (
		Winlostdate		DATETIME,
		KickoffTime		DATETIME,
		currency		INT,
		Bettype			INT,
		Stake			MONEY,
		Winlost			MONEY,
		awinlost		MONEY,
		comm			MONEY,
		oddsid			INT,
		playercomm		MONEY,
		MatchID			INT,
		Liveawayscore	SMALLINT,
		tpositiontaking	SMALLMONEY,
		betcount		INT
	)

	IF @ShowNG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')
	END

	IF @ShowVS = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS') 
	END

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @bettype ( bettype, ProductCode )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	END

	IF @_Date > @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #TempBetList
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				b.bettype,
				SUM(b.stake) AS Stake,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS awinlost,
				SUM(b.comm),
				b.oddsid,
				SUM(b.playercomm) AS PlayerComm,
				b.matchid,
				0 AS Liveawayscore,
				0 AS tpositiontaking,
				COUNT(1) betcount
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.CustId AND b.currency = a.Currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend = BA.recommend AND b.transid = BA.transid
			WHERE b.winlostdate = @_Date
				AND b.statusID IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			GROUP BY
				b.Winlostdate,
				b.currency,
				b.oddsid,
				b.bettype,
				b.matchid

			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				'BA', --b.bettype,
				m.leagueid,
				SUM(b.Stake),
				SUM(b.Winlost),
				0 AS LicenseeWL,
				-SUM(b.Winlost +  b.awinlost + b.comm) AS AmtDueToBA,
				SUM(b.comm) AS CommBA,
				SUM(b.playercomm) AS PlayerComm,
				'',
				m.matchcode,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.sporttype,
				m.showtime,
				SUM(b.betcount) betcount
			FROM #TempBetList b
				INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid
			GROUP BY
				b.Winlostdate,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				m.leagueid,
				m.matchcode,
				m.isNeutral,
				m.sporttype,
				m.showtime
		END

		--Get general data
		TRUNCATE TABLE #TempBetList

		INSERT INTO #TempBetList
		SELECT
			b.Winlostdate,
			NULL,
			b.currency,
			b.bettype,
			SUM(b.stake) AS Stake,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			SUM(b.awinlost) AS awinlost,
			SUM(b.comm) AS comm,
			b.oddsid,
			SUM(b.playercomm) AS playercomm,
			b.matchid,
			b.Liveawayscore,
			b.tpositiontaking,
			COUNT(1) betcount
		FROM dbo.bettrans AS b WITH (NOLOCK )
			INNER JOIN @TempAg AS a ON b.recommend = a.CustId AND b.currency = a.Currency
		WHERE b.winlostdate = @_Date
			AND b.statusID IN (111, 112, 113)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			AND b.matchid > 0
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.oddsid,
			b.matchid,
			b.liveawayscore,
			b.tpositiontaking

		IF @showSB = 1
		BEGIN
			--exclude BA tickets
			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				'SB', --b.bettype,
				m.leagueid,
				SUM(b.Stake),
				SUM(b.Winlost),
				-SUM(b.Winlost) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(b.playercomm) AS PlayerComm,
				'',
				m.matchcode,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.sporttype,
				'' AS ShowTime,
				SUM(b.betcount) AS betcount
			FROM #TempBetList b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid  
			WHERE (b.bettype < 31 
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) -- new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
					OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO
					OR b.Bettype = 38					 -- Single Match Parlay
				)
				AND b.tpositiontaking <> 0
			GROUP BY
				b.Winlostdate,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				m.leagueid,
				m.matchcode,
				m.isNeutral,
				m.sporttype
		END

		IF (@showNG = 1 OR @ShowVS = 1 OR @showVS2 = 1)
		BEGIN
			--exclude BA tickets
			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				bt.ProductCode,
				m.leagueid,
				SUM(b.Stake),
				SUM(b.Winlost),
				-SUM(b.winlost) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(b.playercomm) AS PlayerComm,
				'',
				m.matchcode,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.sporttype,
				'' AS ShowTime,
				SUM(b.betcount) betcount
			FROM #TempBetList b
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid 
				INNER JOIN @bettype bt ON b.bettype = bt.bettype  
			WHERE b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
			GROUP BY
				b.Winlostdate,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				bt.ProductCode,
				m.leagueid,
				m.matchcode,
				m.isNeutral,
				m.sporttype

			IF EXISTS (SELECT 1 FROM #TempBetList WHERE bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()))
			BEGIN 
				INSERT INTO @AgMatchWLDetails
				SELECT
					b.Winlostdate,
					r.EventTime,
					b.currency,
					o.EventID matchid,
					o.RacerID AS homeID,
					0 AS awayid,
					b.bettype,
					bt.ProductCode,
					r.leagueid,
					SUM(b.stake),
					SUM(b.winlost),
					-SUM(b.winlost) AS LicenseeWL,
					0 AS AmountDueToBA,
					0 AS CommBA,
					SUM(b.playercomm) AS PlayerComm,
					b.oddsid AS race,
					CONVERT(VARCHAR(50),o.RacerNum) AS matchcode,
					ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,
					r.sporttype,
					CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
					SUM(b.betcount) betcount
				FROM #TempBetList b
					INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @bettype bt ON b.bettype = bt.bettype  
				WHERE b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
				GROUP BY
					b.Winlostdate,
					r.EventTime,
					b.currency,
					o.EventID,
					o.RacerID,
					b.oddsid,
					b.bettype,
					bt.ProductCode,
					r.leagueid,
					o.RacerNum,
					r.sporttype
			END
		END
	END

	IF @_Date <= @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			TRUNCATE TABLE #TempBetList

			INSERT INTO #TempBetList
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				b.bettype,
				SUM(b.stake) AS Stake,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS awinlost,
				SUM(b.comm),
				b.oddsid,
				SUM(b.playercomm) AS PlayerComm,
				b.matchid,
				0 AS Liveawayscore,
				0 AS tpositiontaking,
				COUNT(1) betcount
			FROM dbo.bettrans14 b WITH(NOLOCK)
				INNER JOIN @TempAg AS a ON b.recommend = a.CustId AND b.currency = a.Currency
			WHERE b.winlostdate = @_Date
				AND b.statusID IN (111,112,113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND tpositiontaking = 0  
				AND (b.bettype < 31
					OR (b.Bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
					OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO
					OR b.Bettype = 38					 -- Single Match Parlay
				)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			GROUP BY
				b.Winlostdate,
				b.currency,
				b.oddsid,
				b.bettype,
				b.matchid

			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				'BA', --b.bettype,
				m.leagueid,
				SUM(b.Stake),
				SUM(b.Winlost),
				0 AS LicenseeWL,
				-SUM(b.Winlost + b.awinlost + b.comm) AS AmtDueToBA,
				SUM(b.comm) AS CommBA,
				SUM(b.playerComm) AS PlayerComm,
				'' AS race,
				m.matchcode,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.sporttype,
				'' AS showtime,
				SUM(b.betcount) betcount
			FROM #TempBetList b
				INNER JOIN dbo.match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
			GROUP BY
				b.Winlostdate,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				m.leagueid,
				m.matchcode,
				m.isNeutral,
				b.bettype,
				m.sporttype
		END

		--Get general data
		TRUNCATE TABLE #TempBetList

		INSERT INTO #TempBetList
		SELECT
			b.Winlostdate,
			NULL,
			b.currency,
			b.bettype,
			SUM(b.stake) AS Stake,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			SUM(b.awinlost) AS awinlost,
			SUM(b.comm) AS comm,
			b.oddsid,
			SUM(b.playercomm) AS playercomm,
			b.matchid,
			b.Liveawayscore,
			b.tpositiontaking,
			COUNT(1) betcount
		FROM dbo.bettrans14 b WITH(NOLOCK)
			INNER JOIN @TempAg  a ON b.recommend = a.CustId AND b.currency = a.Currency
		WHERE b.winlostdate = @_Date
			AND b.statusID IN (111, 112, 113)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
			AND b.matchid > 0
		GROUP BY
			b.Winlostdate,
			b.currency,
			b.bettype,
			b.oddsid,
			b.matchid,
			b.Liveawayscore,
			b.tpositiontaking

		IF @ShowSB = 1
		BEGIN
			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				'SB', --b.bettype,  
				m.leagueid,
				SUM(b.Stake),
				SUM(b.Winlost),
				-SUM(b.winlost) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(b.playercomm)  AS playercomm,
				'' AS race,
				m.matchcode,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.sporttype,
				'' AS showtime ,
				SUM(b.betcount) betcount
			FROM #TempBetList b
				INNER JOIN dbo.match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
			WHERE (b.bettype < 31 
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 AND 9399) -- E-Sports 2.0
					OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO
					OR b.Bettype = 38					 -- Single Match Parlay
				)
				AND b.tpositiontaking <> 0  
			GROUP BY
				b.Winlostdate,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				m.leagueid,
				m.matchcode,
				m.isNeutral,
				b.bettype,
				m.sporttype
		END  
  
		IF (@showNG = 1 OR @ShowVS = 1 OR @showVS2 = 1)
		BEGIN  
			INSERT INTO @AgMatchWLDetails
			SELECT
				b.Winlostdate,
				NULL,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				bt.ProductCode,
				m.leagueid,
				SUM(stake),
				SUM(winlost),
				-SUM(b.winlost) AS LicenseeWL,
				0 AS AmountDueToBA,
				0 AS CommBA,
				SUM(b.playercomm) AS playercomm,
				'' AS race,
				m.matchcode,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.sporttype,
				'' AS ShowTime ,
				SUM(b.betcount) betcount
			FROM #TempBetList b
				INNER JOIN dbo.match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid 
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
			WHERE b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
			GROUP BY
				b.Winlostdate,
				b.currency,
				m.matchid,
				m.homeid,
				m.awayid,
				b.bettype,
				m.leagueid,
				m.matchcode,
				m.isNeutral,
				b.bettype,
				bt.ProductCode,
				m.sporttype

			IF EXISTS (SELECT 1 FROM #TempBetList WHERE bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()))
			BEGIN 
				INSERT INTO @AgMatchWLDetails
				SELECT
					b.Winlostdate,
					r.EventTime,
					b.currency,
					o.EventID matchid,
					o.RacerID AS homeID,
					0 AS awayid,
					b.bettype,
					bt.ProductCode,
					r.leagueid,
					SUM(b.stake),
					SUM(b.winlost),
					-SUM(b.winlost) AS LicenseeWL,
					0 AS AmountDueToBA,
					0 AS CommBA,
					SUM(b.playercomm) AS PlayerComm,
					b.oddsid AS race,
					CONVERT(VARCHAR(50),o.RacerNum) AS matchcode,
					ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,
					r.sporttype,
					CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
					SUM(b.betcount) betcount
				FROM #TempBetList b
					INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @bettype bt ON b.bettype = bt.bettype  
				WHERE b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
				GROUP BY
					b.Winlostdate,
					o.EventID,
					b.currency,
					b.oddsid,
					o.RacerID,
					b.bettype,
					bt.ProductCode,
					r.leagueid,
					o.RacerNum,
					r.sporttype,
					r.EventTime
			END
		END
	END

	INSERT INTO @ExchangeDaily(ExchangeId, Rate)
	SELECT ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_Date,@_Date, @BaseCurrency, '')

	-- Result
	SELECT
		matchid,
		SUM(b.betcount) betcount,
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN 0 ELSE homeid END homeID,
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN 0 ELSE awayid END awayid,
		CASE WHEN ISNULL(b.KickoffTime,0) = 0 THEN 0 ELSE b.KickoffTime END KickoffTime,
		0 AS bettype,
		ProductName, --bettype,
		leagueid,  
		CAST(SUM(b.turnover			* e.Rate) AS MONEY) AS turnover,
		CAST(SUM(b.MemberWinLost	* e.Rate) AS MONEY) AS MemberWinLost,
		CAST(SUM(b.LicenseeWL		* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(b.CommBA			* e.Rate) AS MONEY) AS CommBA,
		CAST(SUM(b.PlayerComm		* e.Rate) AS MONEY) AS PlayerComm,
		CAST(SUM((b.AmtDueToBA)		* e.Rate) AS MONEY) AS AmtDuetoBA,
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN '' ELSE race END race,
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN '' ELSE matchcode END matchcode,
		b.isNeutral,
		b.sporttype,
		'' AS ShowTime
	FROM @AgMatchWLDetails b
		INNER JOIN @ExchangeDaily e ON b.currency = e.ExchangeId  
	GROUP BY
		b.matchid,
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN 0 ELSE homeid END,
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN 0 ELSE awayid END,
		CASE WHEN ISNULL(b.KickoffTime,0) = 0 THEN 0 ELSE b.KickoffTime END,
		b.ProductName, --bettype,  
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN '' ELSE matchcode END,
		b.leagueid,
		b.isNeutral,
		CASE WHEN b.sporttype IN (181,182,183,184,185) THEN '' ELSE race END,
		b.sporttype
	ORDER BY CASE ProductName 
				WHEN 'SB' THEN 0
				WHEN 'NG' THEN 1
				ELSE 2
			END

	DROP TABLE #TempBetList

	SET NOCOUNT OFF
END
GO

