set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Bettype]
	@MatchID			INT,
	@LicenseeID			INT, 
	@UserID				INT,
	@LicenseeType		VARCHAR(100)	= NULL,
	@CurrencyID			INT				= 0,
	@bettype			INT				= 0,
	@liveindicator		INT				= -1,
	@Langkey			VARCHAR(10)		= 'en-US',
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
	@ShowBA				BIT				= 0,
	@ShowLC				BIT				= 0,
	@ShowVS				BIT				= 0,
	@Date				SMALLDATETIME	= NULL
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

	Param's Explanation: 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @_Date AS SMALLDATETIME

	IF @Date IS NOT NULL
		SET @_Date = @Date

	SELECT currencyID,
		LicenseeID 
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)
	WHERE @CurrencyID = 0 OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID)

	DECLARE @TempAg AS TABLE (custid INT)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc
		INNER JOIN #currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	DECLARE @Fromdate DATETIME
	DECLARE @Todate DATETIME

	SELECT @bettype = ISNULL(@bettype, 0)

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

	DELETE @SportBettype 
	WHERE ProductID = 1 AND Bettype IN (901, 902, 903)

	CREATE TABLE #Data 
	(
		Sporttype		INT,
		Username		NVARCHAR(50),
		CustID			INT,
		Bettype			INT,
		LeagueID		INT,
		Transid			BIGINT,
		Matchcode		VARCHAR(50),
		HomeID			INT,
		AwayID			INT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		status			NVARCHAR(50),
		stake			MONEY,
		Winlost			MONEY,
		licenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		transdate		DATETIME,
		Winlostdate		DATETIME,
		betteam			VARCHAR(50),
		liveindicator	INT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		MatchID			INT,
		Betstatus		NVARCHAR(50),
		IsNeutral		BIT,
		oddstype		INT,
		betid			BIGINT,
		currency		SMALLINT,
		RefNO			BIGINT,
		showtime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		betcheck		NVARCHAR(50),
		transdesc		NVARCHAR(300)
	)

	IF EXISTS(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID = @MatchID
		UNION SELECT TOP 1 1 FROM VSOutright WITH(NOLOCK) WHERE EventID = @MatchID )
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS winlost,
				0 AS LicenseeWL ,
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
				AND (@bettype = 0 OR (@bettype <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @bettype))
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency)) 
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID)) 
				AND b.statusID IN (111, 112, 113) 
				AND b.tpositiontaking = 0 
				AND sbt.ProductID = 1 
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator=1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status, 
				b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
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
				AND (@bettype = 0 OR (@bettype <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @bettype)) 
				AND sbt.ProductID = 1 
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID<>0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0 
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator=1 AND b.Liveindicator = 1)) 
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowNG = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
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
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @matchid 
				AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
				AND sbt.ProductID = 3 
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowLC = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
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
				AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
				AND sbt.ProductID = 4 
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
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
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @matchid
				AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
				AND sbt.ProductID = 5 AND sbt.EventType = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		
			IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN 
				INSERT INTO #Data
				SELECT
					r.sporttype,
					b.username,
					b.custid,
					b.bettype,
					r.leagueID,
					b.transid,
					CONVERT (VARCHAR(50),o.RacerNum) matchcode,
					o.RacerID homeID,
					0 awayID,
					CONVERT(FLOAT, b.hdp1) AS hdp1, 
					CONVERT(FLOAT, b.hdp2) AS hdp2, 
					b.odds,
					b.status,
					b.stake,
					(b.winlost-actual_stake) winlost,
					- (b.winlost-b.actual_stake) AS LicenseeWL ,
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
					b.OddsType,
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
					AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
					AND sbt.[ProductID] = 5 
					AND sbt.EventType = 3 
					AND b.recommend IN (SELECT custid FROM @TempAg)
					AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
						OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
					AND b.statusID IN (111, 112, 113)
					AND ((@Liveindicator = -1) 
						OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
						OR (@Liveindicator = 1 AND b.Liveindicator = 1)) 
					AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
				ORDER BY
					b.status, 
					b.transid
			END
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
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) winlost,
				0 AS LicenseeWL ,
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
				AND (@bettype = 0 OR (@bettype <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @bettype))
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID = 1
				AND b.tpositiontaking = 0
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
				AND 1 = CASE @Liveindicator 
							WHEN 0 THEN CASE WHEN b.Liveindicator = 0 THEN 1 ELSE 0 END
							WHEN 1 THEN CASE WHEN b.Liveindicator = 1 THEN 1 ELSE 0 END
							ELSE 1 
							END
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
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
				AND (@bettype = 0 OR (@bettype <> 0 AND CASE WHEN ISNULL(ss.bettype,0) = 0 THEN b.bettype ELSE ss.Grouptypeid END = @bettype))
				AND sbt.ProductID = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency)) 
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@Liveindicator = -1)
					OR (@Liveindicator = 0 AND b.Liveindicator = 0)
					OR (@Liveindicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowNG = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
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
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @matchid
				AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
				AND sbt.ProductID = 3
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency)) 
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator = 1 AND b.Liveindicator = 1)) 
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowLC = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
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
				AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
				AND sbt.ProductID = 4
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		END

		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
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
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.matchid = @matchid
				AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1
				AND b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.statusID IN (111, 112, 113)
				AND ((@Liveindicator = -1) 
					OR (@Liveindicator = 0 AND b.Liveindicator = 0) 
					OR (@Liveindicator = 1 AND b.Liveindicator = 1))
				AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
			ORDER BY
				b.status,
				b.transid
		
			IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3)
			BEGIN 
				INSERT INTO #Data
				SELECT
					r.sporttype,
					b.username,
					b.custid,
					b.bettype,
					r.leagueID,
					b.transid,
					CONVERT (VARCHAR(50),o.RacerNum) matchcode,
					o.RacerID homeID,
					0 awayID,
					CONVERT(FLOAT, b.hdp1) AS hdp1,
					CONVERT(FLOAT, b.hdp2) AS hdp2,
					b.odds,
					b.status,
					b.stake,
					(b.winlost-actual_stake) winlost,
					- (b.winlost-b.actual_stake) AS LicenseeWL ,
					b.comm,
					b.playercomm,
					b.transdate,
					b.winlostdate,
					b.betteam,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					r.EventID matchid, 
					r.betstatus,
					ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
					b.OddsType,
					b.betid,
					b.currency,
					b.refno,
					CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
					'' AS betcheck,
					'' AS transdesc
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK) 
					INNER JOIN dbo.VSOutright14 AS o with (nolock) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE
					o.EventID = @matchid
					AND (@bettype = 0 OR (@bettype <> 0 AND b.bettype = @bettype))
					AND sbt.ProductID = 5 
					AND sbt.EventType = 3
					AND b.recommend IN (SELECT custid FROM @TempAg)
					AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
						OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
					AND b.statusID IN (111, 112, 113)
					AND ((@Liveindicator = -1)
						OR (@Liveindicator = 0 AND b.Liveindicator = 0)
						OR (@Liveindicator = 1 AND b.Liveindicator = 1))
					AND (@_Date IS NULL OR (@_Date IS NOT NULL AND b.winlostdate = @_Date))
				ORDER BY
					b.status, 
					b.transid
			END
		END
	END

	DECLARE @RowStart INT, 
		@RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, 
		@RowStart = @PageSize * @PageIndex + 1, 
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	SELECT @FromDate = CASE WHEN MIN(winlostdate) > @Today THEN @Today ELSE MIN(winlostdate) END,
		@Todate = CASE WHEN MAX(winlostdate) > @Today THEN @Today ELSE MAX(winlostdate) END
	FROM  #Data
 
	CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

	SELECT 
		@TotalRows = COUNT(transid),
		@SumWinlost=SUM(ISNULL(winlost,0)),
		@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
		@SumComm=SUM(ISNULL(comm,0)) ,
		@SumPlayerComm=SUM(ISNULL(playercomm,0)),
		--USD
		@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
		@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
		@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
		@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)),
		--EUR
		@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
		@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
		@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)),
		@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0)),
		--GBP
		@SumWinlostGBP=SUM(ISNULL(winlost*e.GBP,0)),
		@SumLicenseeWLGBP=SUM(ISNULL(LicenseeWL*e.GBP,0)),
		@SumCommGBP=SUM(ISNULL(comm*e.GBP,0)),
		@SumPlayerCommGBP=SUM(ISNULL(playercomm*e.GBP,0))
	FROM #Data AS b
		INNER JOIN #TempExchange AS e
		ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN  b.winlostdate ELSE @Today END)   AND e.exchangeid = b.currency

	SELECT A.* 
	FROM
	(
		SELECT  
			ROW_NUMBER() OVER(ORDER BY b.status, b.transid) AS RowNum,
			b.*,
			SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			stake		* e.USD AS stakeUSD,
			Winlost		* e.USD AS WinlostUSD,
			LicenseeWL	* e.USD AS LicenseeWLUSD,
			comm		* e.USD AS commUSD,
			playercomm	* e.USD AS PlayerCommUSD,
			stake		* e.EUR AS stakeEUR,
			Winlost		* e.EUR AS WinlostEUR,
			LicenseeWL	* e.EUR AS LicenseeWLEUR,
			comm		* e.EUR AS commEUR,
			playercomm	* e.EUR AS PlayerCommEUR,
			stake		* e.GBP AS stakeGBP,
			Winlost		* e.GBP AS WinlostGBP,
			LicenseeWL	* e.GBP AS LicenseeWLGBP,
			comm		* e.GBP AS commGBP,
			playercomm	* e.GBP AS PlayerCommGBP
		FROM #Data b
			INNER JOIN dbo.Customer AS c (NOLOCK) ON b.custid = c.custid
			INNER JOIN #TempExchange e
				ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DECLARE @BettransDetail TABLE (
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

	IF @ShowLC = 1
	BEGIN
		IF EXISTS(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID = @MatchID)
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
			FROM dbo.bettransg AS BG WITH (NOLOCK)
				INNER JOIN #Data AS B ON BG.refno = B.refno AND BG.custid = B.custid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			WHERE sbt.ProductID = 4
		END
		
		IF EXISTS(SELECT TOP 1 1 FROM Match14 WITH(NOLOCK) WHERE MatchID = @MatchID)
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
			FROM dbo.bettransg14 AS BG WITH (NOLOCK)
				INNER JOIN #Data AS B ON BG.refno = B.refno AND BG.custid = B.custid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			WHERE sbt.ProductID = 4
		END
	END

	IF @ShowVS = 1
	BEGIN 
		IF EXISTS(SELECT TOP 1 1 FROM Vsoutright WITH(NOLOCK) WHERE EventID = @MatchID)
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
			FROM dbo.bettransm AS BG WITH (NOLOCK)
				INNER JOIN #Data AS B ON BG.refno = B.refno AND BG.custid = B.custid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype=sbt.Bettype	
			WHERE sbt.ProductID = 5 AND sbt.EventType = 3
		END

		IF EXISTS(SELECT TOP 1 1 FROM Vsoutright14 WITH(NOLOCK) WHERE EventID = @MatchID)
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
			FROM dbo.bettransm14 AS BG WITH (NOLOCK)
				INNER JOIN #Data AS B ON BG.refno = B.refno AND BG.custid = B.custid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = B.winlostdate AND e.exchangeid = B.currency
				INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			WHERE sbt.ProductID = 5 AND sbt.EventType = 3
		END
	END

	SELECT * FROM @BettransDetail 
	ORDER BY RefNo, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #Data
	DROP TABLE #Currency 
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Bettype] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_MatchWL_Bettype] TO vnteam



