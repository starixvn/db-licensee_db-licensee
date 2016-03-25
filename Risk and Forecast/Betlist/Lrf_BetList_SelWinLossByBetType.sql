USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinLossByBetType]    Script Date: 3/8/2016 2:31:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinLossByBetType]
	@LicenseeId			INT,
	@UserId				INT,
	@LicenseeType		VARCHAR(100)	= NULL,
	@CurrencyId			INT				= 0,
	@BetType			INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumWinlostUSD		MONEY			= 0 OUTPUT,
	@SumWinlostEUR		MONEY			= 0 OUTPUT,
	@SumWinlostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20160229
	Task : Get bet list of Win Loss By Bet Type report
	DB: DBEXT.bodb02
	Original:
	Revisions:

	Parameters:
*/

BEGIN
	SET NOCOUNT ON

	-- Sport Bet Type matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 5

	DELETE FROM @SportBettype
	WHERE ProductID NOT IN (1, 2, 3, 4, 5, 8)
		OR (ProductID = 1 AND Bettype IN (901, 902, 903))

	-- Licensee type
	SELECT CurrencyId,
		LicenseeId
	INTO #Currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)	-- System is default=1 (LRF)
	WHERE @CurrencyId = 0 OR CurrencyID = @CurrencyId

	DECLARE @TempAg AS TABLE (CustId INT)

	INSERT INTO @TempAg (CustId)
	SELECT DISTINCT CustId
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) AS lc
		INNER JOIN #Currency AS c ON lc.LicenseeID = c.LicenseeId AND lc.Currency = c.CurrencyId
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	-- Create temp table
	CREATE TABLE #AllData (
		TransId		BIGINT,
		RefNo		BIGINT,
		Currency		SMALLINT,
		WinLostDate		DATETIME,
		WinLost		MONEY,
		LicenseeWL	MONEY,
		Comm		MONEY,
		PlayerComm	MONEY,
		WhTicket	TINYINT
	)

	CREATE TABLE #TempData (
		TransId		BIGINT,
		RefNo		BIGINT,
		WhTicket	TINYINT
	)

	CREATE TABLE #Data (
		TransId			BIGINT,
		RefNo			BIGINT,
		BetId			BIGINT,
		CustId			INT,
		Username		NVARCHAR(50),
		SportType		INT,
		BetType			INT,
		Currency		SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		MatchCode		VARCHAR(50),
		IsNeutral		BIT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		BetTeam			NVARCHAR(10),
		Odds			MONEY,
		OddsType		TINYINT,
		Modds			MONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		ShowTime		NVARCHAR(50),
		Status			NVARCHAR(10),
		BetStatus		NVARCHAR(50),
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Race			VARCHAR(20),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	DECLARE @TempFromDate DATETIME,
		@TempToDate DATETIME

	-- Bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @CurrencyId = 0
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType)
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					1 AS WhTicket
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = CIX_recommend_matchid_bettype)
					INNER JOIN #Currency AS c ON b.currency = c.currencyId
					LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.Grouptypeid END = @bettype
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
			ELSE
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					1 AS WhTicket
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = CIX_recommend_matchid_bettype)
					INNER JOIN #Currency AS c ON b.currency = c.currencyId
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.bettype = @bettype
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
		END
		ELSE	-- @CurrencyId <> 0
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType)
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					1 AS WhTicket
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = CIX_recommend_matchid_bettype)
					LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.Grouptypeid END = @bettype
					AND b.Currency = @CurrencyId
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
			ELSE
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					1 AS WhTicket
				FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = CIX_recommend_matchid_bettype)
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.bettype = @bettype
					AND b.Currency = @CurrencyId
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
		END
	END

	-- Bettrans14 range
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @BalanceUpDay < @FromDate
			SELECT @BalanceUpDay = @FromDate

		IF @CurrencyId = 0
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType)
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = bettrans143)
					INNER JOIN #Currency AS c ON b.currency = c.currencyId
					LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
					AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.Grouptypeid END = @bettype
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
			ELSE
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = bettrans143)
					INNER JOIN #Currency AS c ON b.currency = c.currencyId
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
					AND b.bettype = @bettype
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
		END
		ELSE	-- @CurrencyId <> 0
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType)
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = bettrans143)
					LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
					AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.Grouptypeid END = @bettype
					AND b.currency = @CurrencyId
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
			ELSE
			BEGIN
				INSERT INTO #AllData
				SELECT
					b.transid,
					b.refno,
					b.currency,
					b.winlostdate,
					(b.winlost - b.actual_stake) AS WinLost,
					-(b.winlost - b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					2 AS WhTicket
				FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = bettrans143)
				WHERE b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
					AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
					AND b.bettype = @bettype
					AND b.currency = @CurrencyId
					AND b.statusID NOT IN (101, 102, 103)
					AND b.ruben = 1
			END
		END
	END

	DECLARE @RowStart	INT,
		@RowEnd			INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	-- Get exchange rate
	SELECT * 
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE ExchangeId IN (SELECT DISTINCT CurrencyId FROM #Currency)

	-- Get total values
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
	FROM #AllData AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency

	-- Get paging data
	INSERT INTO #TempData
	SELECT
		tmp.TransId,
		tmp.RefNo,
		tmp.WhTicket
	FROM (
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.transid) AS RowNum,
				b.*
			FROM #AllData AS b
		) AS tmp
	WHERE tmp.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #AllData

	-- Get ticket detail
	IF EXISTS (SELECT 1 FROM #TempData WHERE WhTicket = 1)
	BEGIN
		-- Sportsbook
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				b.matchid,
				m.matchcode,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
		END

		-- Outright
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 2 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				l.sporttype,
				b.bettype,
				b.currency,
				o.leagueid,
				b.matchid,
				o.matchcode,
				CONVERT(BIT, 0) AS IsNeutral,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				o.groupmatch AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
		END

		-- Mix Parlay & System Parlay
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 0 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.BetID, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				0 AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
		END

		-- Number Game, Live Casino, Virtual Sports (EventType = 1)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (3, 4, 5) AND EventType = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.BetID, 0) AS BetId,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				m.matchid,
				m.matchcode,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				CASE
					WHEN sbt.ProductId IN (3, 5) THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductId = 5 THEN b.hdp2
					ELSE 0
				END AS Hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				ISNULL(m.showtime,'') AS ShowTime,
				b.status,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
		END

		-- Horse Racing (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 2 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				l.sporttype,
				b.bettype,
				b.currency,
				o.leagueid,
				b.matchid,
				o.matchcode,
				CONVERT(BIT, 0) AS IsNeutral,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				o.groupmatch AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
		END

		-- Virtual Sports (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 5 AND EventType = 3 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				r.sporttype,
				b.bettype,
				b.currency,
				r.LeagueID,
				b.matchid,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				CONVERT(BIT, 0) AS IsNeutral,
				o.RacerID AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				CONVERT(VARCHAR(20), b.oddsid) AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
		END

		-- Keno
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 8 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				202 AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				fnc.GameId AS MatchId,
				'' AS MatchCode,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				fnc.ChoiceId AS BetTeam,
				b.odds,
				b.oddstype,
				0 AS Modds,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype) AS fnc
			WHERE td.WhTicket = 1
		END
	END

	IF EXISTS (SELECT 1 FROM #TempData WHERE WhTicket = 2)
	BEGIN
		-- Sportsbook
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				b.matchid,
				m.matchcode,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
		END

		-- Outright
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 2 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				l.sporttype,
				b.bettype,
				b.currency,
				o.leagueid,
				b.matchid,
				o.matchcode,
				CONVERT(BIT, 0) AS IsNeutral,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				o.groupmatch AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
		END

		-- Mix Parlay & System Parlay
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 0 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.BetID, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				0 AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
		END

		-- Number Game, Live Casino, Virtual Sports (EventType = 1)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (3, 4, 5) AND EventType = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.BetID, 0) AS BetId,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				m.matchid,
				m.matchcode,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				CASE
					WHEN sbt.ProductId IN (3, 5) THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductId = 5 THEN b.hdp2
					ELSE 0
				END AS Hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				ISNULL(m.showtime,'') AS ShowTime,
				b.status,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
		END

		-- Horse Racing (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 2 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				l.sporttype,
				b.bettype,
				b.currency,
				o.leagueid,
				b.matchid,
				o.matchcode,
				CONVERT(BIT, 0) AS IsNeutral,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				o.groupmatch AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
		END

		-- Virtual Sports (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 5 AND EventType = 3 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				r.sporttype,
				b.bettype,
				b.currency,
				r.LeagueID,
				b.matchid,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				CONVERT(BIT, 0) AS IsNeutral,
				o.RacerID AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				CONVERT(VARCHAR(20), b.oddsid) AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
		END

		-- Keno
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 8 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				202 AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				fnc.GameId AS MatchId,
				'' AS MatchCode,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				fnc.ChoiceId AS BetTeam,
				b.odds,
				b.oddstype,
				0 AS Modds,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				'' AS ShowTime,
				b.status,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				'' AS TransDesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype) AS fnc
			WHERE td.WhTicket = 2
		END
	END

	SELECT
		b.*,
		SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS Nickname,
		Stake		* e.USD AS StakeUSD,
		WinLost		* e.USD AS WinLostUSD,
		LicenseeWL	* e.USD AS LicenseeWLUSD,
		Comm		* e.USD AS CommUSD,
		PlayerComm	* e.USD AS PlayerCommUSD,
		Stake		* e.EUR AS StakeEUR,
		WinLost		* e.EUR AS WinLostEUR,
		LicenseeWL	* e.EUR AS LicenseeWLEUR,
		Comm		* e.EUR AS CommEUR,
		PlayerComm	* e.EUR AS PlayerCommEUR,
		Stake		* e.GBP AS StakeGBP,
		WinLost		* e.GBP AS WinLostGBP,
		LicenseeWL	* e.GBP AS LicenseeWLGBP,
		Comm		* e.GBP AS CommGBP,
		PlayerComm	* e.GBP AS PlayerCommGBP
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c (NOLOCK) ON b.custid = c.custid
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
	ORDER BY b.TransId

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		Apositiontaking	SMALLMONEY,
		Bettype			SMALLINT,
		Betteam			NVARCHAR(10),
		StakeEUR		MONEY,
		StakeUSD		MONEY,
		StakeGBP		MONEY
	)

	IF EXISTS (	SELECT 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 4 )
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
			INNER JOIN #Data AS b ON bg.refno = b.refno AND bg.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
		WHERE sbt.ProductId = 4

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
			INNER JOIN #Data AS b ON bg.refno = b.refno AND bg.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
		WHERE sbt.ProductId = 4
	END
	
	IF EXISTS (	SELECT 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
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
			INNER JOIN #Data AS b ON bg.refno = b.refno AND bg.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
		WHERE sbt.ProductId = 5 AND sbt.EventType = 3

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
			INNER JOIN #Data AS b ON bg.refno = b.refno AND bg.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
		WHERE sbt.ProductId = 5 AND sbt.EventType = 3
	END

	SELECT * FROM @BettransDetail 
	ORDER BY RefNo, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #Data
	DROP TABLE #TempData
	DROP TABLE #Currency
END



GRANT	VIEW DEFINITION	ON	Lrf_BetList_SelWinLossByBetType	TO	vnteam
GRANT	EXECUTE	ON	Lrf_BetList_SelWinLossByBetType	TO	bodbLicenseeNet

/*
declare @p10 int
declare @p11 money
declare @p12 money
declare @p13 money
declare @p14 money
declare @p15 money
declare @p16 money
declare @p17 money
declare @p18 money
declare @p19 money
declare @p20 money
declare @p21 money
declare @p22 money
declare @p23 money
declare @p24 money
declare @p25 money
declare @p26 money
exec Lrf_BetList_SelWinLossByBetType @licenseeid=1,@userid=68,@CurrencyID=0,@LicenseeType=NULL,@bettype=9,
@PageSize=2147483646,@PageIndex=1,@totalrows=@p10 output,@SumWinlost=@p11 output,@SumLicenseeWL=@p12 output,
@SumComm=@p13 output,@SumPlayerComm=@p14 output,@SumWinlostUSD=@p15 output,@SumLicenseeWLUSD=@p16 output,@SumCommUSD=@p17 output,
@SumPlayerCommUSD=@p18 output,@SumWinlostEUR=@p19 output,@SumLicenseeWLEUR=@p20 output,@SumCommEUR=@p21 output,
@SumPlayerCommEUR=@p22 output,@SumWinlostGBP=@p23 output,@SumLicenseeWLGBP=@p24 output,@SumCommGBP=@p25 output,
@SumPlayerCommGBP=@p26 output,@FromDate='2016-02-24 00:00:00',@ToDate='2016-02-28 00:00:00',
@MoveBetsDay='2016-02-21 00:00:00',@BalanceUpDay='2016-02-20 00:00:00'
select @p10, @p11, @p12, @p13, @p14, @p15, @p16, @p17, @p18, @p19, @p20, @p21, @p22, @p23, @p24, @p25, @p26
*/