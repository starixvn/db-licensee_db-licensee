USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinLossByDate_Mem]    Script Date: 9/24/2015 4:49:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinLossByDate_Mem]
	@LicenseeID			INT,
	@UserID				INT,
	@CustID				INT,
	@CurrencyID			INT				= 0,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@Langkey			VARCHAR(20)		= 'en-US',
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumBetEffective	MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinlostUSD		MONEY			= 0 OUTPUT,
	@SumBetEffectiveUSD	MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD 	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinlostEUR		MONEY			= 0 OUTPUT,
	@SumBetEffectiveEUR	MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinlostGBP		MONEY			= 0 OUTPUT,
	@SumBetEffectiveGBP	MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT,
	@ShowSB				BIT				= 0,
	@ShowRB				BIT				= 0,
	@ShowNG				BIT				= 0,
	@ShowBA				BIT				= 0,
	@ShowLC				BIT				= 0,
	@ShowVS				BIT				= 0,
	@ShowCS				BIT				= 0,	-- RNG Casino
	@ShowBG				BIT				= 0,
	@ShowKN				BIT				= 0,
	@ShowMGCLC			BIT				= 0,	-- Microgaming Live Casino
	@ShowMGCRNG			BIT				= 0,	-- Microgaming RNG Casino
	@ShowAGC			BIT				= 0,
	@ShowBT				BIT				= 0		-- Bet Trade
AS

/*
	Created: 20101209@Henry
	Task : Bet List Win-loss By Date
	DB: DBEXT/bodb02
	Original: [Age_BetList_SelWinLossByDate_Mem]

	Revisions:
		- 20110214@Jacob: Add column discount in the result SET
		- 20110303@Henry: suppport based currency
		- 20110318@Henry: Change server DB052 to DB06 (support bet list old)	
		- 20110408@Amy: Change function to get Odds value AND odds type
						Get data for Number Game
		- 20110513@Henry: change bettype to new range
		- 20110523@Henry: remove @ShowCasino, @ShowP2P, @ShowFI, @ShowBI
		- 20110712@Henry: Add column LicenseeWL	
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mixed Parlay
		- 20111208@Jim: change condition bettype<31
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120614@Jim: optimize code 
		- 20120711@Jim: get value for hdp1, hdp2 
		- 20120726@Jim: add playercomm value 
		- 20120817@Jim: add live casino 
		- 20120913@Jim: add virtual sport
		- 20130123@Daniel: Change link server alias
		- 20130225@Jim: support RNG Casino, Bingo 
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20130903@Jim: support Virtual Horse Racing
		- 20131101@Victor: enhance performance
		- 20140326@Jim: offer Keno
		- 20140630@Hannah: offer BetRadar and Sporting Solution 
		- 20140819@Jim: add more output @SumBetEffective  
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141128@Jim: add more input param @CurrencyID   
		- 20150128@Winnie: Add base currency GBP
		- 20150406@Winnie: Apply sporttype, bettype matrix and add 60 bettypes betradar 
		- 20150406@Winnie: fix bug
		- 20150604@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150828@Edward: Fixed Odds value of ticket 901, 902 is displayed incorrectly
		- 20150915@Kos: Support Microgaming RNG Game
		- 20150922@Kos: Support AG Casino
		- 20151029@Kos: Change ProductId/SportType of Microgaming RNG Game
*/

BEGIN
	SET NOCOUNT ON

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 5

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype WHERE ProductID = 1 AND Bettype IN (901, 902, 903)
	END

	DELETE sbt
	FROM @SportBettype sbt
	WHERE ProductID		= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowRB	= 0		THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG	= 0		THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC	= 0		THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS	= 0		THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS	= 0		THEN 6 END
		OR ProductID	= CASE WHEN @ShowBG	= 0		THEN 7 END
		OR ProductID	= CASE WHEN @ShowKN	= 0		THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC = 0	THEN 11 END
		OR ProductID	= CASE WHEN @ShowMGCLC = 0	THEN 13 END
		OR ProductID	= CASE WHEN @ShowMGCRNG = 0	THEN 17 END
		OR (ProductID 	> 8 AND ProductID NOT IN (11, 13, 17)) -- not suport for LIC system

	DECLARE @UserName		NVARCHAR(20)
		, @Recommend		INT
		, @BetEffectiveDate SMALLDATETIME

	SELECT CurrencyID
		, LicenseeID
	INTO #Currency
	FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @userID 
		AND LicenseeID = @LicenseeID 
		AND SystemID = 1
		AND isActive = 1

	SELECT @BetEffectiveDate = '2014-09-01'

	SELECT @UserName = UserName, 
		@Recommend = Recommend 
	FROM custinfo c WITH(NOLOCK) 
		INNER JOIN #Currency cy ON c.Currency = cy.CurrencyID
	WHERE CustID = @CustID
	----------------------------------------
	DROP TABLE #currency
	-----------------------------------------
	CREATE TABLE #BetListByDateMem (
		Sporttype		SMALLINT,
		Username		NVARCHAR(20), 
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			SMALLINT,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		OddsType		TINYINT,
		Odds			SMALLMONEY, 
		modds			SMALLMONEY, 
		Stake			MONEY, 
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		BetEffective	MONEY,
		licenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(15),
		LeagueID		INT,
		MatchID			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		HomeID			INT,
		AwayID			INT,
		Betstatus		NVARCHAR(50),
		isNeutral		BIT,
		currency		SMALLINT,
		showtime		NVARCHAR(50) -- table - shoe - hand of Live Casino
		,betcheck		NVARCHAR(50)
	)

	CREATE TABLE  #TempBetList (
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			INT,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		OddsType		TINYINT,
		Odds			SMALLMONEY, 
		modds			SMALLMONEY, 
		Stake			MONEY, 
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,	
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		comm			MONEY,
		playercomm 		MONEY,
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(50),
		currency		INT,
		MatchID			INT,
		betcheck		NVARCHAR(50)
	)

	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		--general BA tickets
		INSERT INTO #TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			ABS(b.winlost-actual_stake),
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,		
			b.currency,
			b.MatchID
			,b.betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid = @custid AND
			b.ruben = 1 AND
			b.bettype NOT IN (901,902,903) 

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				#TempBetList b
				INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL ,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				#TempBetList b
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				#TempBetList b
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.matchid > 0 
				AND b.custid = @custid 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype NOT IN (901, 902, 903) 
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,  
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,NULL AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Mix Parlay + Combination Mix Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)	
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29) 
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 
		END

		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.OddsType,
				ob.Odds,
				b.modds,
				ob.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				ABS(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm  ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,	
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK)	ON b.refno = ob.transid
				INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.matchid > 0 
				AND b.custid = @custid 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype IN (901, 902, 903) 
				AND b.ruben = 1
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,	
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				b.awinlost,
				b.comm,
				b.playercomm ,	
				0 AS LiveIndicator , 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 2 
				AND b.ruben = 1
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CASE WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime,
				NULL AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (3, 4) 
				AND b.ruben = 1 
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,	
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral	, 
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1
				AND b.ruben = 1 

			UNION ALL 

			SELECT
				r.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID matchid,	
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,	
				o.RacerID HomeID,
				0 AwayID, 		
				r.Betstatus,
				CONVERT(BIT,0) AS IsNeutral	,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS  ShowTime
				,NULL AS betcheck	
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.ruben = 1 
		END

		-- RNG Casino, Bingo. Microgaming Live Casino
		IF @ShowCS = 1 OR @ShowBG = 1 OR @ShowMGCLC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 7 THEN 252
					WHEN sbt.ProductID = 13 THEN 203
				END AS Sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN b.Betteam
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				ABS(b.winlost - b.actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (6, 7, 13) 
				AND b.ruben = 1 
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				202 Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				ChoiceId betteam,
				b.status,
				b.refno,
				b.Transdate,	
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				GameId AS MatchID,	
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral	,
				b.currency,
				'' AS  ShowTime 
				,NULL AS betcheck	
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 8 
				AND b.ruben = 1 
		END

		-- Microgaming RNG Casino
		IF @ShowMGCRNG = 1
		BEGIN
			-- Microgaming RNG Casino (up to yesterday settled ticket)
			INSERT INTO #BetListByDateMem
			SELECT
				205 AS Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS oddstype,
				0 AS Odds,
				0 AS modds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				ABS(b.winlost - b.actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS Liveindicator,
				0 AS Livehomescore,
				0 AS Liveawayscore,
				b.IP,
				0 AS LeagueID,
				0 AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.winlostdate <> DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- not today
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 17 
				AND b.ruben = 1

			IF @todate >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO #BetListByDateMem
				SELECT
					205 AS Sporttype,
					@Username, 
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS oddstype,
					0 AS Odds,
					0 AS modds,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
					END AS Status,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(brng.winlost - brng.actual_stake) AS Winlost,
					ABS(SUM(brng.winlost - brng.actual_stake)) AS BetEffective,
					SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
					SUM(brng.comm) AS comm,
					SUM(brng.playercomm) AS playercomm,
					0 AS Liveindicator,
					0 AS Livehomescore,
					0 AS Liveawayscore,
					b.IP,
					0 AS LeagueID,
					0 AS MatchID,
					'' AS MatchCode,
					'' AS Race,
					0 AS HomeID,
					0 AS AwayID,
					0 AS Betstatus,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS showtime,
					'' AS betcheck
				FROM
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE
					b.winlostdate = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
					AND b.custid = @custid 
					AND (@currencyID = 0 OR b.currency = @currencyID) 
					AND sbt.ProductID = 17
					AND brng.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.IP,
					b.currency
			END
		END

		-- AG Casino
		IF @ShowAGC = 1
		BEGIN
			-- AG Casino (up to yesterday settled ticket)
			INSERT INTO #BetListByDateMem
			SELECT
				250 AS Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS oddstype,
				0 AS Odds,
				0 AS modds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				ABS(b.winlost - b.actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS Liveindicator,
				0 AS Livehomescore,
				0 AS Liveawayscore,
				b.IP,
				0 AS LeagueID,
				0 AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.winlostdate <> DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- not today
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 11
				AND b.ruben = 1

			IF @todate >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO #BetListByDateMem
				SELECT
					250 AS Sporttype,
					@Username, 
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS oddstype,
					0 AS Odds,
					0 AS modds,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
					END AS Status,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(blc.winlost - blc.actual_stake) AS Winlost,
					ABS(SUM(blc.winlost - blc.actual_stake)) AS BetEffective,
					SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
					SUM(blc.comm) AS comm,
					SUM(blc.playercomm) AS playercomm,
					0 AS Liveindicator,
					0 AS Livehomescore,
					0 AS Liveawayscore,
					b.IP,
					0 AS LeagueID,
					0 AS MatchID,
					'' AS MatchCode,
					'' AS Race,
					0 AS HomeID,
					0 AS AwayID,
					0 AS Betstatus,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS showtime,
					'' AS betcheck
				FROM
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE
					b.winlostdate = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
					AND b.custid = @custid 
					AND (@currencyID = 0 OR b.currency = @currencyID) 
					AND sbt.ProductID = 11
					AND blc.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.IP,
					b.currency
			END
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @ToDate
	
		IF @BalanceUpDay < @FromDate 
			SELECT @BalanceUpDay=@FromDate

		DELETE FROM #TempBetList
		
		--general BA tickets
		INSERT INTO #TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2, 
			b.Oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			ABS(b.winlost-actual_stake),
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,
			b.currency,
			b.matchid
			,b.betcheck
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.recommend = @Recommend AND
			b.custid = @custid AND
			b.ruben = 1 AND
			b.bettype NOT IN (901,902,903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				#TempBetList b
				INNER JOIN dbo.MATCH14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1
		
			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL ,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				#TempBetList b
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay +  Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,  
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				#TempBetList b
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN	
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND b.matchid > 0 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype NOT IN (901,902,903) 
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,  
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race	
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)	
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29) 
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList)

			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,	
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime
				,NULL AS betcheck 
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList)
		END	

		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				b.Oddstype,
				ob.odds,
				b.modds,
				ob.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				ABS(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK)	ON b.refno = ob.transid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND b.matchid > 0 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype IN (901,902,903) 
				AND b.ruben = 1
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				b.awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 2 
				AND b.ruben = 1
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN	
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CASE WHEN sbt.ProductID=4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (3, 4)
				AND b.ruben = 1
		END

		-- Virtual Sport
		IF @ShowVS = 1
		BEGIN	
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1
				AND b.ruben = 1
			
			UNION ALL 
			SELECT
				r.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID matchid,	
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,	
				o.RacerID HomeID,
				0 AwayID, 		
				r.Betstatus,
				CONVERT(BIT,0) AS IsNeutral	,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS ShowTime 	
				,NULL AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3
				AND b.ruben = 1
		END

		-- RNG Casino, Bingo, AG Casino, Microgaming Live Casino, Microgaming RNG Casino
		IF @ShowCS = 1 OR @ShowBG = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1
		BEGIN	
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 7 THEN 252
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 13 THEN 203
					WHEN sbt.ProductID = 17 THEN 205
				END AS Sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN CONVERT(FLOAT, b.hdp1)
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN CONVERT(FLOAT, b.hdp2)
					ELSE 0
				END AS hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN b.Betteam
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake) AS WinLost,
				ABS(b.winlost - actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (6, 7, 11, 13, 17) 
				AND b.ruben = 1
		END

		-- Keno
		IF @ShowKN = 1 
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				202 Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				ChoiceID betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm  ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				GameId AS MatchID,	
				'' AS MatchCode,
				'' AS Race,	
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral	,
				b.currency,
				''  AS ShowTime 
				,NULL AS betcheck	
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 8 
				AND b.ruben = 1
		END
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate

		DELETE FROM #TempBetList
		
		--general BA tickets
		INSERT INTO #TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.Oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost - actual_stake),
			ABS(b.winlost - actual_stake),
			0 AS LicenseeWL,
			CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
			b.playercomm ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,
			b.currency,
			b.matchid
			,b.betcheck
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @fromdate AND @TempToDate 
			AND b.recommend = @Recommend
			AND b.custid = @custid 
			AND b.ruben = 1 
			AND b.bettype NOT IN (901, 902, 903) 

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck
			FROM
				#TempBetList b
				INNER JOIN bodb_archive.dbo.MATCH_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1
		
			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				#TempBetList b
				INNER JOIN bodb_archive.dbo.Outright_BK AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				#TempBetList b
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND b.ruben = 1 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype NOT IN (901, 902, 903) 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,NULL AS betcheck 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (0,9,29) --should not remove 0 in Archive
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList)

			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.orid, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.teamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid 
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend
				AND b.ruben = 1 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.ruben = 1 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 
		END
	
		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.Oddstype,
				ob.odds,
				b.modds,
				ob.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				ABS(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,b.betcheck
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN bodb_archive.dbo.bettrans_bk AS ob WITH (NOLOCK)	ON b.refno = ob.transid
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND b.ruben = 1 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype IN (901, 902, 903)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				b.awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.orid, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.teamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid 
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND b.ruben = 1 
				AND sbt.ProductID = 2 
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CASE WHEN sbt.ProductID=4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
				,NULL AS betcheck
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend 
				AND sbt.ProductID IN (3, 4)
				AND b.ruben = 1
		END
	
		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral	,
				b.currency,
				'' AS ShowTime 
				,NULL AS betcheck
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1
				AND b.ruben = 1
			
			UNION ALL 

			SELECT
				r.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID matchid,	
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,	
				o.RacerID HomeID,
				0 AwayID,
				r.Betstatus,
				CONVERT(BIT,0) AS IsNeutral	,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS ShowTime
				,NULL AS betcheck 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK,INDEX(IX_custid))
				INNER JOIN bodb_Archive.dbo.VSOutright_bk o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3
				AND b.ruben = 1
		END

		-- RNG Casino, Bingo, Microgaming Live Casino, Microgaming RNG Casino, AG Casino
		IF @ShowCS = 1 OR @ShowBG = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 7 THEN 252
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 13 THEN 203
					WHEN sbt.ProductID = 17 THEN 205
				END AS Sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN CONVERT(FLOAT, b.hdp1)
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN CONVERT(FLOAT, b.hdp2)
					ELSE 0
				END AS hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN b.Betteam
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake) AS WinLost,
				ABS(b.winlost - actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID IN (6, 7) THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend 
				AND sbt.ProductID IN (6, 7, 11, 13, 17)
				AND sbt.EventType = 0 
				AND b.ruben = 1
		END

		-- Show Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				202 Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				ChoiceID Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				GameId AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,NULL AS betcheck 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend 
				AND sbt.ProductID = 8 
				AND sbt.EventType = 0 
				AND b.ruben = 1
		END
	END

	IF @ShowBT = 1
	BEGIN
		UPDATE betList
		SET betList.comm = CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
		FROM #BetListByDateMem AS betList
			INNER JOIN #BetListByDateMem AS commBetList ON betList.RefNO = commBetList.RefNO
		WHERE betList.Sporttype = 1 
			AND betList.Bettype IN (901, 902)
			AND commBetList.Bettype = 903

		DELETE #BetListByDateMem WHERE Sporttype = 1 AND Bettype = 903
	END

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, 
		@RowStart = @PageSize * @PageIndex + 1, 
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	CREATE NONCLUSTERED INDEX IDX_Index_betlist ON #BetListByDateMem (Currency)

	IF @CurrencyID <> 0
	BEGIN 
		DELETE #BetListByDateMem
		WHERE Currency <> @CurrencyID
	END

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #BetListByDateMem)

	UPDATE #BetListByDateMem 
	SET BetEffective = 0
	WHERE winlostdate < @BetEffectiveDate
		OR status NOT IN ('LOSE','WON')


	SELECT 
		@TotalRows = COUNT(transid),
		@SumWinlost = SUM(ISNULL(winlost,0)),
		@SumBetEffective = SUM(ISNULL(BetEffective,0)),
		@SumLicenseeWL = SUM(ISNULL(licenseeWL,0)),
		@SumComm = SUM(ISNULL(comm,0)) ,
		@SumPlayerComm = SUM(ISNULL(playercomm,0)),
		--USD
		@SumWinlostUSD = SUM(ISNULL(winlost*e.USD,0)),
		@SumBetEffectiveUSD = SUM(ISNULL(BetEffective*e.USD,0)),
		@SumLicenseeWLUSD = SUM(ISNULL(LicenseeWL*e.USD,0)),
		@SumCommUSD = SUM(ISNULL(comm*e.USD,0)) ,
		@SumPlayerCommUSD = SUM(ISNULL(playercomm*e.USD,0)),
		--EUR
		@SumWinlostEUR = SUM(ISNULL(winlost*e.EUR,0)),
		@SumBetEffectiveEUR = SUM(ISNULL(BetEffective*e.EUR,0)),
		@SumLicenseeWLEUR = SUM(ISNULL(LicenseeWL*e.EUR,0)),
		@SumCommEUR = SUM(ISNULL(comm*e.EUR,0)) ,
		@SumPlayerCommEUR = SUM(ISNULL(playercomm*e.EUR,0)),
		--GBP
		@SumWinlostGBP = SUM(ISNULL(winlost*e.GBP,0)),
		@SumBetEffectiveGBP = SUM(ISNULL(BetEffective*e.GBP,0)),
		@SumLicenseeWLGBP = SUM(ISNULL(LicenseeWL*e.GBP,0)),
		@SumCommGBP = SUM(ISNULL(comm*e.GBP,0)) ,
		@SumPlayerCommGBP = SUM(ISNULL(playercomm*e.GBP,0))
	FROM #BetListByDateMem b
		INNER JOIN #TempExchange e 
		ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency

	SELECT A.* 
	FROM
	(
		SELECT  
			ROW_NUMBER() over(ORDER BY b.TransID) AS RowNum,
			b.*,
			--USD
			Stake*e.USD StakeUSD,
			Actual_Stake*e.USD Actual_StakeUSD,
			Winlost*e.USD WinlostUSD,
			BetEffective*e.USD BetEffectiveUSD,
			licenseeWL*e.USD licenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			--EUR
			Stake*e.EUR StakeEUR,
			Actual_Stake*e.EUR Actual_StakeEUR,
			Winlost*e.EUR WinlostEUR,
			BetEffective*e.EUR BetEffectiveEUR,
			licenseeWL*e.EUR licenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR PlayerCommEUR,
			--GBP
			Stake*e.GBP StakeGBP,
			Actual_Stake*e.GBP Actual_StakeGBP,
			Winlost*e.GBP WinlostGBP,
			BetEffective*e.GBP BetEffectiveGBP,
			licenseeWL*e.GBP licenseeWLGBP,
			comm*e.GBP commGBP,
			playercomm*e.GBP PlayerCommGBP
		FROM #BetListByDateMem b
			INNER JOIN #TempExchange e
			ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DECLARE @BettransDetail TABLE(  
		refno			BIGINT,  
		odds			SMALLMONEY,  
		stake			MONEY,
		status			NVARCHAR(10),  
		apositiontaking	SMALLMONEY,  
		bettype			SMALLINT,
		Betteam			NVARCHAR(10),
		stakeEUR		MONEY,
		stakeUSD		MONEY,
		stakeGBP		MONEY
	)

	-- Racing
	IF @ShowRB = 1
	BEGIN
		IF @Todate > @MoveBetsDay 
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake * e.EUR,
				BM.stake * e.USD,
				BM.stake * e.GBP
			FROM bettransm BM WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BM.refno = B.transid
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON Bm.bettype = sbt.bettype
			WHERE sbt.ProductID = 2 AND sbt.EventType = 2
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake * e.EUR,
				BM.stake * e.USD,	
				BM.stake * e.GBP
			FROM bettransm14 BM WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BM.refno = B.transid
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON Bm.bettype = sbt.bettype
			WHERE sbt.ProductID = 2 AND sbt.EventType = 2
		END

		IF @FromDate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake * e.EUR,	
				BM.stake * e.USD,
				BM.stake * e.GBP
			FROM bodb_archive.dbo.bettransm BM WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BM.refno = B.transid
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON Bm.bettype = sbt.bettype
			WHERE sbt.ProductID = 2 AND sbt.EventType = 2
		END
	END

	-- Live Casino
	IF @ShowLC = 1
	BEGIN
		IF @Todate > @MoveBetsDay 
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.betteam,
				BG.stake * e.EUR,
				BG.stake * e.USD,
				BG.stake * e.GBP
			FROM bettransg BG WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BG.refno = B.refno AND BG.CustID = @CustID
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON BG.bettype = sbt.bettype
			WHERE sbt.ProductID = 4
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.betteam,
				BG.stake * e.EUR,	
				BG.stake * e.USD,
				BG.stake * e.GBP
			FROM bettransg14 BG WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BG.refno = B.refno AND BG.CustID = @CustID 
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON BG.bettype = sbt.bettype
			WHERE sbt.ProductID = 4
		END

		IF @FromDate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.betteam,
				BG.stake * e.EUR,
				BG.stake * e.USD,	
				BG.stake * e.GBP
			FROM bodb_archive.dbo.bettransg BG WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BG.refno = B.refno AND BG.CustID = @CustID
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON BG.bettype = sbt.bettype
			WHERE sbt.ProductID = 4
		END
	END

	-- Virtual Sports
	IF @ShowVS = 1
	BEGIN 
		IF @Todate > @MoveBetsDay 
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.Betteam,
				BG.stake * e.EUR,
				BG.stake * e.USD,
				BG.stake * e.GBP
			FROM bettransm BG WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BG.refno = B.refno
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON BG.bettype = sbt.bettype
			WHERE sbt.ProductID = 5 AND sbt.EventType = 3
		END

		IF @FromDate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.Betteam,
				BG.stake * e.EUR,
				BG.stake * e.USD,
				BG.stake * e.GBP
			FROM bettransm14 BG WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BG.refno = B.refno
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON BG.bettype=sbt.bettype
			WHERE sbt.ProductID = 5 AND sbt.EventType = 3
		END

		IF @FromDate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BM.refno, 
				BM.odds, 
				BM.stake,
				BM.status, 
				BM.apositiontaking, 
				BM.bettype,
				BM.betteam,
				BM.stake*e.EUR,	
				BM.stake*e.USD,
				BM.stake*e.GBP
			FROM bodb_archive.dbo.bettransm BM WITH (NOLOCK)
				INNER JOIN #BetListByDateMem B ON BM.refno = B.refno
				INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype sbt ON Bm.bettype = sbt.bettype
			WHERE sbt.ProductID = 5 AND sbt.EventType = 3
		END
	END

	SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype 

	DROP TABLE #TempExchange
	DROP TABLE #BetListByDateMem
	DROP TABLE #TempBetList
END

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinLossByDate_Mem] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinLossByDate_Mem] TO [vnteam] AS [dbo]