set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Bettype]
	@MatchId			INT,
	@LicenseeId			INT,
	@UserId				INT,
	@LicenseeType		VARCHAR(100)	= NULL,
	@CurrencyId			INT				= 0,
	@BetType			INT				= 0,
	@LiveIndicator		INT				= -1,
	@LangKey			VARCHAR(10)		= 'en-US',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinlostUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinlostEUR		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinlostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT,
	@ShowSB				BIT				= 0,
	@ShowNG				BIT				= 0,
	@ShowLC				BIT				= 0,
	@ShowVS				BIT				= 0,
	@ShowBA				BIT				= 0,
	@Date				SMALLDATETIME	= NULL,
	@Sort				VARCHAR(100)		= 'TransId ASC'
AS

/*
	Created: 20101209@Henry
	Task: Betlist
	DB: DBEXT.bodb02
	Original:[Age_BetList_SelWinlossByBettypeMatch_Ag]
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110712@Henry: Add column LicenseeWL
		- 20110729@Henry: offer 3 new bettypes for Number Game
		- 20111208@Jim: Change condition bettype<31
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120726@Jim: add playercomm value
		- 20120817@Jim: add live casino
		- 20120918@Jim: add virtual sport
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121207@Henry: fix bug 1 match got 2 different winlostdate by add param @Date
		- 20130417@Jim: support base currency USD	
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130904@Jim: support Virtual Horse Racing 
		- 20140630@Hannah: offer BetRadar and Sporting Solution 
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141021@Florent: Apply for the change in Sporting Solution structure (#24478)
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20150406@Winnie: Apply matrix of sporttype & bettype & Add 60 bettype betradar
		- 20150609@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]

	Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @_Date SMALLDATETIME

	IF @Date IS NOT NULL
		SET @_Date = @Date

	SELECT currencyID,
		LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)
	WHERE @CurrencyId = 0
		OR (@CurrencyId <> 0 AND CurrencyID = @CurrencyId)

	DECLARE @TempAg AS TABLE (custid INT)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc
		INNER JOIN #currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	SELECT @BetType = ISNULL(@BetType, 0)

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

	DELETE @SportBettype
	WHERE ProductID = 1 AND Bettype IN (901, 902, 903)

	DELETE @SportBettype
	WHERE ProductID		= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowNG	= 0 THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC	= 0 THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS	= 0 THEN 5 END
		OR ProductID NOT IN (1, 3, 4, 5)
	-- end filer bettypes by sporttype

	CREATE TABLE #Data (
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			INT,
		LeagueId		INT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		MatchId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		OddsType		INT,
		BetId			BIGINT,
		Currency		SMALLINT,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	IF EXISTS(SELECT TOP 1 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchID
		UNION SELECT TOP 1 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchID )
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake) AS winlost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking = 0
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake) AS winlost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Number Game, Live Casino, Virtual Sports (EventType = 1)
		IF @ShowNG = 1 OR @ShowLC = 1 OR @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				ISNULL(m.showtime,'') AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID IN (3, 4, 5)
				AND sbt.EventType = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1) 
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				r.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				r.leagueID,
				b.transid,
				CONVERT (VARCHAR(50),o.RacerNum) AS matchcode,
				o.RacerID AS homeID,
				0 AS awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				o.EventID matchid,
				r.betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				o.EventID = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END
	END
	ELSE
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake) AS winlost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking = 0
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
				AND 1 = CASE @LiveIndicator
							WHEN 0 THEN CASE WHEN b.Liveindicator = 0 THEN 1 ELSE 0 END
							WHEN 1 THEN CASE WHEN b.Liveindicator = 1 THEN 1 ELSE 0 END
							ELSE 1
						END
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake) AS winlost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.matchid = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @BetType))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency)) 
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Number Game, Live Casino, Virtual Sports (EventType = 1)
		IF @ShowNG = 1 OR @ShowLC = 1 OR @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid, 
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.OddsType,
				b.betid,
				b.currency,
				b.refno,
				ISNULL(m.showtime,'') AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID IN (3, 4, 5)
				AND sbt.EventType = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency)) 
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1) 
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				r.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				r.leagueID,
				b.transid,
				CONVERT (VARCHAR(50),o.RacerNum) matchcode,
				o.RacerID AS homeID,
				0 AS awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				r.EventID AS matchid,
				r.betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				o.EventID = @matchid
				AND (@BetType = 0
					OR (@BetType <> 0 AND b.bettype = @BetType))
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = -1)
					OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
					OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL
					OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
		END
	END

	DECLARE @RowStart INT,
		@RowEnd INT
	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @Fromdate DATETIME
	DECLARE @Todate DATETIME

	SELECT @FromDate = CASE WHEN MIN(winlostdate) > @Today THEN @Today ELSE MIN(winlostdate) END,
		@Todate = CASE WHEN MAX(winlostdate) > @Today THEN @Today ELSE MAX(winlostdate) END
	FROM #Data
 
	CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

	SELECT
		@TotalRows			= COUNT(b.TransId),
		@SumWinlost			= SUM(ISNULL(b.WinLost, 0)),
		@SumLicenseeWL		= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm			= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm		= SUM(ISNULL(b.PlayerComm, 0)),
		-- USD
		@SumWinlostUSD		= SUM(ISNULL(b.WinLost		* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm			* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(b.PlayerComm	* e.USD, 0)),
		-- EUR
		@SumWinlostEUR		= SUM(ISNULL(b.WinLost		* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm			* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm	* e.EUR, 0)),
		-- GBP
		@SumWinlostGBP		= SUM(ISNULL(b.WinLost		* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm			* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm	* e.GBP, 0))
	FROM #Data AS b
		INNER JOIN #TempExchange AS e
		ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency

	UPDATE #Data
	SET Nickname = SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2))
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid

	CREATE TABLE #PagingData (
		RowNum			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			INT,
		LeagueId		INT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		MatchId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		OddsType		INT,
		BetId			BIGINT,
		Currency		SMALLINT,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	-- Exchange rate is different for each day => Stake order may be different from StakeUSD order
	DECLARE @SortExp VARCHAR(200)

	IF @Sort LIKE '%USD%' OR @Sort LIKE '%EUR%' OR @Sort LIKE '%GBP%'
	BEGIN
		DECLARE @CharIndex INT

		SELECT @CharIndex = CHARINDEX( ' ', @Sort, 1)
		SELECT @SortExp = SUBSTRING (@Sort, 1, @CharIndex - 4) + ' * e.' 
			+ SUBSTRING(@Sort, @CharIndex - 3, 4) + SUBSTRING(@Sort, @CharIndex + 1, LEN(@Sort))
	END
	ELSE
	BEGIN
		SET @SortExp = @Sort
	END

	IF @SortExp NOT LIKE '%TransId%'
	BEGIN
		SELECT @SortExp = @SortExp + ', TransId ASC'
	END

	DECLARE @Sql NVARCHAR(1000)

	SET @Sql = 
		'DECLARE @TempToday SMALLDATETIME 
		SET @TempToday = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
		
		INSERT INTO #PagingData
		SELECT A.*
		FROM
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY ' + @SortExp + ') AS RowNum,
				b.* 
			FROM #Data AS b
				INNER JOIN #TempExchange AS e
					ON e.exchangeid = b.Currency
						AND e.ExchangeDate = (CASE WHEN b.WinLostDate <= @TempToday THEN b.WinLostDate ELSE @TempToday END)
		) A
		WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+ ' ORDER BY A.RowNum'

	EXEC sp_executesql @sql

	DROP TABLE #Data

	SELECT
		b.*,
		b.Stake			* e.USD AS StakeUSD,
		b.WinLost		* e.USD AS WinLostUSD,
		b.LicenseeWL	* e.USD AS LicenseeWLUSD,
		b.Comm			* e.USD AS CommUSD,
		b.PlayerComm	* e.USD AS PlayerCommUSD,
		b.Stake			* e.EUR AS StakeEUR,
		b.WinLost		* e.EUR AS WinLostEUR,
		b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
		b.Comm			* e.EUR AS CommEUR,
		b.PlayerComm	* e.EUR AS PlayerCommEUR,
		b.Stake			* e.GBP AS StakeGBP,
		b.WinLost		* e.GBP AS WinLostGBP,
		b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
		b.Comm			* e.GBP AS CommGBP,
		b.PlayerComm	* e.GBP AS PlayerCommGBP
	FROM #PagingData AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.exchangeid = b.Currency
	ORDER BY b.RowNum

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		StakeEUR		MONEY,
		StakeUSD		MONEY,
		StakeGBP		MONEY
	)

	IF @ShowLC = 1
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchID)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN #PagingData AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			WHERE sbt.ProductID = 4
		END

		IF EXISTS (SELECT TOP 1 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchID)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN #PagingData AS B ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			WHERE sbt.ProductID = 4
		END
	END

	IF @ShowVS = 1
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.VSOutright WITH (NOLOCK) WHERE EventID = @MatchID)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransm AS bg WITH (NOLOCK)
				INNER JOIN #PagingData AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			WHERE sbt.ProductID = 5 AND sbt.EventType = 3
		END

		IF EXISTS (SELECT TOP 1 1 FROM dbo.VSOutright14 WITH (NOLOCK) WHERE EventID = @MatchID)
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransm14 AS bg WITH (NOLOCK)
				INNER JOIN #PagingData AS b ON bg.refno = b.RefNo AND bg.custid = b.CustId
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			WHERE sbt.ProductID = 5 AND sbt.EventType = 3
		END
	END

	SELECT * FROM @BettransDetail
	ORDER BY RefNo, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #PagingData
	DROP TABLE #Currency
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Bettype] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_MatchWL_Bettype] TO vnteam



