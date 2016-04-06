USE [bodb02]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinloss_Mem]
	@LicenseeID			INT,
	@UserID				INT,
	@CustID				INT,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@ShowSB				BIT			= 0,
	@ShowRB				BIT			= 0,
	@ShowNG				BIT			= 0,
	@ShowBA				BIT			= 0,
	@ShowLC				BIT			= 0,
	@ShowVS				BIT			= 0,
	@ShowCS				BIT			= 0,	-- RNG Casino
	@ShowBG				BIT			= 0,	-- Bingo 
	@ShowKN				BIT			= 0,	-- Keno
	@ShowMGCLC			BIT			= 0,	-- Microgaming Live Casino
	@ShowMGCRNG			BIT			= 0,	-- Microgaming RNG Casino
	@ShowAGC			BIT			= 0,	-- AG Casino
	@ShowVB				BIT			= 0,	-- Voidbridge
	@ShowBT				BIT			= 0,	-- Bet Trade
	@PageSize			INT			= 1000,
	@PageIndex			INT			= 1,
	@TotalRows			INT			= 0 OUTPUT,
	@SumWinlost			MONEY		= 0 OUTPUT,
	@SumWinlostUSD		MONEY		= 0 OUTPUT,
	@SumWinlostEUR		MONEY		= 0 OUTPUT,
	@SumWinlostGBP		MONEY		= 0 OUTPUT,
	@SumLicenseeWL		MONEY		= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY		= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY		= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY		= 0 OUTPUT,
	@SumComm			MONEY		= 0 OUTPUT,
	@SumCommUSD			MONEY		= 0 OUTPUT,
	@SumCommEUR			MONEY		= 0 OUTPUT,
	@SumCommGBP			MONEY		= 0 OUTPUT,
	@SumPlayerComm		MONEY		= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY		= 0 OUTPUT,
	@SumPLayerCommEUR	MONEY		= 0 OUTPUT,
	@SumPLayerCommGBP	MONEY		= 0 OUTPUT,
	@drawfilter			SMALLINT	= 1,
	@Langkey			VARCHAR(10) = 'en-US',
	@currencyID			INT			= 0 
AS

/*
	Created: Henry
	Date: 2012-01-09
	Task : Betlist for Licensee Winloss Report
	DB: DBACC.bodb02

	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay 
		- 20120529@Henry: enhance performance
		- 20120703@Henry: add value to column hdp1, hdp2 for Number Game
		- 20120717@Jim: add paging filter
		- 20120723@Jim: add playercomm value 
		- 20120816@Henry: add ShowLiveCasino 
		- 20120911@Jim : add virtual sport
		- 20130123@Daniel: Change link server alias
		- 20130204@Jim: support RNG Casino and Bingo product
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20130809@Jim: offer Virtual Horse Racing
		- 20140307@Hannah: offer Keno
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141128@winnie: change currency keenocean	
		- 20150124@winnie: Add base currency GBP
		- 20150406@Winnie: Add 60 bettypes Betradar & Apply matrix of sporttype & bettype 
		- 20150515@Winnie: fix bug
		- 20150604@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150828@Edward: Fixed Odds value of ticket 901, 902 is displayed incorrectly
		- 20150914@Kos: Support Microgaming RNG Casino
		- 20150922@Kos: Support AG Casino
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151224@Jim: Fix bug [Redmine: #49885]
		- 20151225@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160405@Kos: Support Voidbridge [#Redmine: 54925]

	Param's Explanation:
		+ @drawfilter: 'No Draw' filter is supportted
			- 1: Normal
			- 2: No Draw
			- 3: No Draw for Turnover only
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @fdate DATETIME, @tdate DATETIME
	SELECT @fdate = @FromDate, @tdate = @ToDate

	DECLARE @BetListByDateMem AS TABLE(
		Sporttype		INT,
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			INT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		LicenseeWL		MONEY,
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
		virtualrate		FLOAT,
		isShowOTExRate	BIT,
		currency		INT,
		showtime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		betcheck		NVARCHAR(50),
		transdesc		NVARCHAR(300)
	)

	DECLARE @TempBetList AS TABLE (
		TransID			BIGINT,
		BetID			BIGINT,
		Bettype			INT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Betteam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNO			BIGINT,
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Winlost			MONEY,
		LicenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(50),
		currency		INT,
		MatchID			INT,
		betcheck		NVARCHAR(50),
		transdesc		NVARCHAR(300)
	)

	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME

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
	WHERE (ProductID	= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END AND Bettype NOT IN (901, 902, 903))
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
		OR ProductID	= CASE WHEN @ShowVB = 0		THEN 22 END
		OR (ProductID 	> 8 AND ProductID NOT IN (11, 13, 17, 22))
			-- not suport for LIC system

	IF @tdate > @MoveBetsDay
	BEGIN
		IF @fdate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @fdate

		-- Get BA Tickets
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			0,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate AND
			b.custid = @custid AND (@currencyID = 0 OR b.currency = @currencyID ) AND
			b.statusID IN (111, 112, 113) AND
			b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				b.modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList b
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE b.matchid IN (9, 29) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,	
				ISNULL(b.BetID, 0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm ,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29) 
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END
	
		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(ob.bettype,0) AS BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.OddsType,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake),
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.bettype IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0
				AND b.statusID IN (111, 112, 113)
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID IN (3, 4)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID )
				AND sbt.ProductID = 5
				AND sbt.EventType = 1
				AND b.statusID IN (111, 112, 113)

			UNION ALL

			SELECT 
				r.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Bingo, Microgaming Live Casino
		IF @ShowCS = 1 OR @ShowBG = 1 OR @ShowMGCLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 7 THEN 252
					WHEN sbt.ProductID = 13 THEN 203
				END AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				ISNULL(b.oddstype, 0),
				b.Odds,
				b.stake,
				b.actual_stake, 
				ISNULL(b.betteam,0),
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake) ,
				b.comm ,
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
				0,
				0,
				b.currency,
				'' AS showtime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID )
				AND (sbt.ProductID IN (7, 13) 
					OR (sbt.ProductID = 6 AND sbt.SubProduct = ''))
				AND b.statusID IN (111, 112, 113)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.virtualrate,
				ISNUMERIC(m.programID),
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 2 
				AND b.statusID IN (111, 112, 113)
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				202 AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				ChoiceId AS betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm ,
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
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 8 
				AND b.statusID IN (111, 112, 113)
		END

		-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge
		IF @ShowCS = 1 OR @ShowMGCRNG = 1  OR @ShowVB = 1
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN b.matchid
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 22 THEN 212
				END AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS oddstype,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID IN (6, 22) THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND (sbt.ProductID IN (17 , 22)
					OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
				AND b.statusID IN (111, 112, 113)

			IF @tdate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)				-- yesterday
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO @BetListByDateMem
				SELECT
					CASE
						WHEN sbt.ProductID = 6 THEN b.matchid
						WHEN sbt.ProductID = 17 THEN 205
						WHEN sbt.ProductID = 22 THEN 212
					END AS Sporttype,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS oddstype,
					0 AS Odds,
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
					0,
					0,
					b.currency,
					'' AS showtime,
					'' AS betcheck,
					CASE
						WHEN sbt.ProductID IN (6, 22) THEN b.transdesc
						ELSE ''
					END AS transdesc
				FROM
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @tdate
					AND b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
						AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
					AND b.custid = @custid 
					AND (@currencyID = 0 OR b.currency = @currencyID) 
					AND (sbt.ProductID IN (17 , 22)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND brng.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.IP,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END

		-- AG Casino
		IF @ShowAGC = 1
		BEGIN
			-- AG Casino (up to yesterday settled ticket)
			INSERT INTO @BetListByDateMem
			SELECT
				250 AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS oddstype,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 11 
				AND b.statusID IN (111, 112, 113)

			IF @tdate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)				-- yesterday
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO @BetListByDateMem
				SELECT
					250 AS Sporttype,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS oddstype,
					0 AS Odds,
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
					0,
					0,
					b.currency,
					'' AS showtime,
					'' AS betcheck,
					'' AS transdesc
				FROM
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @tdate
					AND b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
						AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
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

	IF @fdate <= @MoveBetsDay
	BEGIN
		IF @tdate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @tdate
	
		IF @BalanceUpDay < @fdate 
			SELECT @BalanceUpDay = @fdate

		-- BA Tickets
		DELETE FROM @TempBetList
		
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			0,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.custid = @custid AND (@currencyID = 0 OR b.currency = @currencyID ) AND
			b.statusID IN (111, 112, 113) AND
			b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.matchid IN (9, 29)
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0 
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.BetID, 0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm ,
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
				CONVERT(BIT,0) AS isNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END
	
		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.Oddstype,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake),
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans14 AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND b.bettype IN (901, 902, 903) 
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0 
				AND b.statusID IN (111, 112, 113)
		END
	
		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID IN (3, 4)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1 
				AND b.statusID IN (111, 112, 113)

			UNION ALL

			SELECT 
				r.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20), r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Bingo, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, Voidbridge
		IF @ShowCS = 1 OR @ShowBG = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1 OR @ShowVB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 7 THEN 252
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 13 THEN 203
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 22 THEN 212
				END AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					WHEN sbt.ProductID = 7 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					WHEN sbt.ProductID = 7 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					WHEN sbt.ProductID = 7 THEN b.modds
					ELSE 0
				END AS modds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					WHEN sbt.ProductID = 7 THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					WHEN sbt.ProductID = 7 THEN b.Odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN ISNULL(b.betteam, '')
					WHEN sbt.ProductID = 7 THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake),
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
					WHEN sbt.ProductID = 7 THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID = 22 THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID IN (6, 7, 11, 13, 17, 22)
				AND b.statusID IN (111, 112, 113)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.virtualrate,
				ISNUMERIC(m.programID),
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 2 
				AND b.statusID IN (111, 112, 113)
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				202 AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2,
				b.modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				ChoiceID AS betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 8 
				AND b.statusID IN (111, 112, 113)
		END
	END

	IF @fdate < @BalanceUpDay
	BEGIN
		IF @tdate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @tdate

		DELETE FROM @TempBetList

		-- BA Tickets
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			0,
			b.comm,
			b.playercomm,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate 
			AND b.custid = @custid 
			AND (@currencyID = 0 OR b.currency = @currencyID) 
			AND b.ruben = 1 
			AND b.status NOT IN ('VOID','REJECT','REFUND') 
			AND b.bettype NOT IN (901, 902, 903)
	
		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				@TempBetList b
				INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1
			
			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2
			
			-- Mix Parlay + System parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND') 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.BetID, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT','REFUND') 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (0, 9, 29) --should NOT remove 0 IN archive
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END
	
		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.Oddstype,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake),
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.bettrans_bk AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND') 
				AND b.bettype IN (901, 902, 903) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '') 
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID IN (3, 4)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END

		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
			UNION ALL
			SELECT 
				r.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Bingo, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, Voidbridge
		IF @ShowCS = 1 OR @ShowBG = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1 OR @ShowVB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 7 THEN 252
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 13 THEN 203
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 22 THEN 212
				END AS Sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					WHEN sbt.ProductID = 7 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					WHEN sbt.ProductID = 7 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					WHEN sbt.ProductID = 7 THEN b.modds
					ELSE 0
				END AS modds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					WHEN sbt.ProductID = 7 THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					WHEN sbt.ProductID = 7 THEN b.Odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN ISNULL(b.betteam, '')
					WHEN sbt.ProductID = 7 THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake),
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
					WHEN sbt.ProductID = 7 THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID = 22 THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID IN (6, 7, 11, 13, 17, 22)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END

		-- Racebook
		IF @ShowRB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,	
				b.winlostdate,
				(b.winlost-actual_stake),
				awinlost,
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
				b.virtualrate,
				ISNUMERIC(m.programID),
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID','REJECT','REFUND') 
				AND sbt.ProductID = 2
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				202 AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				ChoiceID AS betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 8 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END
	END

	IF @ShowBT = 1
	BEGIN
		UPDATE betList
		SET betList.comm = CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
		FROM @BetListByDateMem AS betList
			INNER JOIN @BetListByDateMem AS commBetList ON betList.RefNO = commBetList.RefNO
		WHERE betList.Sporttype = 1 
			AND betList.Bettype IN (901, 902)
			AND commBetList.Bettype = 903

		DELETE @BetListByDateMem WHERE Sporttype = 1 AND Bettype = 903
	END

	--@currency
	SELECT CurrencyID
		,LicenseeID
	INTO #Currency
	FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @userID 
		AND LicenseeID = @LicenseeID 
		AND SystemID = 1
		AND isActive = 1
	
	--DECLARE	@currency INT 
	--SELECT	@currency = currency 
	--FROM custinfo c (NOLOCK) 
	--INNER JOIN 	#currency cy ON c.currency=cy.currencyID
	--WHERE custid = @custid

	--FROM  OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
	---------------------------------------
	--DROP TABLE #currency
	---------------------------------------

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE exchangeid IN 
	(
		SELECT DISTINCT lc.Currency
		FROM OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
			INNER JOIN #currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID 
	)
	---------------------------------------
	DROP TABLE #currency
	---------------------------------------

	--exclude draw for no draw option (2)
	DELETE FROM @BetListByDateMem
	WHERE @drawfilter = 2 AND status = 'DRAW' AND ABS(modds) <> 0.25

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, 
		@RowStart = @PageSize * @PageIndex + 1, 
		@RowEnd = @RowStart + @PageSize - 1

	SELECT 
		@TotalRows = COUNT(transid),
		@SumWinlost = SUM(ISNULL(winlost, 0)),
		@SumLicenseeWL = SUM(ISNULL(LicenseeWL, 0)),
		@SumComm = SUM(ISNULL(comm, 0)),
		@SumPlayerComm = SUM(ISNULL(playercomm, 0)),
		--USD
		@SumWinlostUSD = SUM(ISNULL(winlost * e.USD, 0)),
		@SumLicenseeWLUSD = SUM(ISNULL(LicenseeWL * e.USD, 0)),
		@SumCommUSD = SUM(ISNULL(comm * e.USD, 0)) ,
		@SumPlayerCommUSD = SUM(ISNULL(playercomm * e.USD, 0)),
		--EUR
		@SumWinlostEUR = SUM(ISNULL(winlost * e.EUR, 0)),
		@SumLicenseeWLEUR = SUM(ISNULL(LicenseeWL * e.EUR, 0)),
		@SumCommEUR = SUM(ISNULL(comm * e.EUR, 0)),
		@SumPlayerCommEUR = SUM(ISNULL(playercomm * e.EUR, 0)),
		--GBP
		@SumWinlostGBP = SUM(ISNULL(winlost * e.GBP, 0)),
		@SumLicenseeWLGBP = SUM(ISNULL(LicenseeWL * e.GBP, 0)),
		@SumCommGBP = SUM(ISNULL(comm * e.GBP, 0)),
		@SumPlayerCommGBP = SUM(ISNULL(playercomm * e.GBP, 0))
	FROM @BetListByDateMem b
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency

	SELECT A.*
	FROM
		(
		SELECT	ROW_NUMBER() OVER (ORDER BY TransID) AS RowNum,
			d.* , 
			--BASE RM
			d.stake * e.MYR			AS StakeMYR,
			d.actual_stake * e.MYR	AS actual_stakeMYR,
			d.winlost * e.MYR		AS WinlostMYR,
			d.LicenseeWL * e.MYR	AS LicenseeWLMYR,
			d.comm * e.MYR			AS commMYR,
			d.playercomm * e.MYR	AS playercommMYR,
			--BASEUSD
			d.stake * e.USD			AS StakeUSD,
			d.actual_stake * e.USD	AS actual_stakeUSD,
			d.winlost * e.USD		AS WinlostUSD,
			d.LicenseeWL * e.USD	AS LicenseeWLUSD,
			d.comm * e.USD			AS commUSD,
			d.playercomm * e.USD 	AS playercommUSD,
			--BASEEUR
			d.stake * e.EUR			AS StakeEUR,
			d.actual_stake * e.EUR	AS actual_stakeEUR,
			d.winlost * e.EUR		AS WinlostEUR,
			d.LicenseeWL * e.EUR	AS LicenseeWLEUR,
			d.comm * e.EUR			AS commEUR,
			d.playercomm * e.EUR	AS playercommEUR,
			--BASEGBP
			d.stake * e.GBP			AS StakeGBP,
			d.actual_stake * e.GBP	AS actual_stakeGBP,
			d.winlost * e.GBP		AS WinlostGBP,
			d.LicenseeWL * e.GBP	AS LicenseeWLGBP,
			d.comm * e.GBP			AS commGBP,
			d.playercomm * e.GBP	AS playercommGBP
		FROM @BetListByDateMem d
			INNER JOIN #TempExchange e
				ON e.ExchangeDate =  d.winlostdate AND e.exchangeid = d.currency
		) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DECLARE @BettransDetail TABLE(
		refno			BIGINT,
		odds			MONEY,
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
		IF @tdate > @MoveBetsDay 
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.Betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bm.refno = B.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bm.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 2
		END
		
		IF @fdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.Betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bm.refno = B.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bm.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 2
		END

		IF @fdate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.Betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bm.refno = B.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bm.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 2
		END
	END

	-- Virtual Sports
	IF @ShowVS = 1
	BEGIN 
		IF @tdate > @MoveBetsDay 
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.Betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bm.refno = B.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bm.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 5
		END

		IF @fdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.Betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bm.refno = B.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bm.Bettype=sbt.Bettype
			WHERE sbt.ProductID = 5
		END

		IF @fdate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.Betteam,
				bm.stake * e.EUR,
				bm.stake * e.USD,
				bm.stake * e.GBP
			FROM bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bm.refno = B.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bm.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 5
		END
	END 

	-- Live Casino
	IF @ShowLC = 1
	BEGIN
		IF @tdate > @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.Betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bg.refno = B.refno AND bg.custid = @CustID
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bg.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 4
		END

		IF @fdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.Betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bg.refno = B.refno AND bg.custid = @CustID
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bg.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 4
		END

		IF @fdate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.Betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM bodb_archive.dbo.bettransG AS bg WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS B ON bg.refno = B.refno AND bg.custid = @CustID
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON bg.Bettype=sbt.Bettype
			WHERE sbt.ProductID = 4
		END
	END

	SELECT * FROM @BettransDetail 
	ORDER BY RefNo,Bettype

	DROP TABLE #TempExchange
	/*
		[Lrf_BetList_SelWinloss_Mem]
		@CustID			=1265745,
		@FromDate		='2012-09-01',
		@ToDate			='2012-09-10',
		@MoveBetsDay	='2012-09-03',
		@BalanceUpDay	='2012-09-05',
		@ShowSB			 = 1,
		@ShowRB			 = 1,
		@ShowNG			 = 1,
		@ShowBA			 = 1,
		@ShowLC			 = 1,
		@ShowVS			 = 1,
		@ShowCS			 = 1,
		@ShowBG			 = 1,
		@ShowMGCLC		 = 1,
		@ShowMGCRNG		 = 1,
		@ShowAGC		 = 1,
		@ShowVB			 = 1
	*/
END 



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinloss_Mem] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinloss_Mem] TO [vnteam] 