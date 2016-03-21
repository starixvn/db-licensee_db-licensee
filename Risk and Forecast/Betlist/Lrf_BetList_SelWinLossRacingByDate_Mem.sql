USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinLossByDate_Mem]    Script Date: 9/24/2015 4:49:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinLossRacingByDate_Mem]
	@LicenseeId			INT,
	@UserId				INT,
	@CustId				INT,
	@CurrencyId			INT				= 0,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@LangKey			VARCHAR(20)		= 'en-US',
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@PageIndex			INT				= 1,
	@PageSize			INT				= 1000,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumWinlostUSD		MONEY			= 0 OUTPUT,
	@SumWinlostEUR		MONEY			= 0 OUTPUT,
	@SumWinlostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD 	MONEY			= 0 OUTPUT,
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
	Created: 20160311@Kos
	Task: Bet List for Racing Commission report
	DB: DBACC.bodb02
	Original: [Lrf_BetList_SelWinLossByDate_Mem]

	Revisions:
	Sample call:
		DECLARE @p11 INT
		DECLARE @p12 MONEY
		DECLARE @p13 MONEY
		DECLARE @p14 MONEY
		DECLARE @p15 MONEY
		DECLARE @p16 MONEY
		DECLARE @p17 MONEY
		DECLARE @p18 MONEY
		DECLARE @p19 MONEY
		DECLARE @p20 MONEY
		DECLARE @p21 MONEY
		DECLARE @p22 MONEY
		DECLARE @p23 MONEY
		DECLARE @p24 MONEY
		DECLARE @p25 MONEY
		DECLARE @p26 MONEY
		DECLARE @p27 MONEY

		EXEC Lrf_BetList_SelWinLossRacingByDate_Mem @licenseeid=1,@userid=68,@CustID=1368168,@CurrencyId=0,
		@FromDate='2016-03-01 00:00:00',@ToDate='2016-03-11 00:00:00',@MoveBetsDay='2016-02-28 00:00:00',
		@BalanceUpDay='2016-02-27 00:00:00',@PageSize=2147483646,@PageIndex=1,@totalrows=@p11 OUTPUT,@SumWinlost=@p12 OUTPUT,
		@SumLicenseeWL=@p13 OUTPUT,@SumComm=@p14 OUTPUT,@SumPlayerComm=@p15 OUTPUT,@SumWinlostUSD=@p16 OUTPUT,
		@SumLicenseeWLUSD=@p17 OUTPUT,@SumCommUSD=@p18 OUTPUT,@SumPlayerCommUSD=@p19 OUTPUT,@SumWinlostEUR=@p20 OUTPUT,
		@SumLicenseeWLEUR=@p21 OUTPUT,@SumCommEUR=@p22 OUTPUT,@SumPlayerCommEUR=@p23 OUTPUT,@SumWinlostGBP=@p24 OUTPUT,
		@SumLicenseeWLGBP=@p25 OUTPUT,@SumCommGBP=@p26 OUTPUT,@SumPlayerCommGBP=@p27 OUTPUT
		select @p11, @p12, @p13, @p14, @p15, @p16, @p17, @p18, @p19, @p20, @p21, @p22, @p23, @p24, @p25, @p26, @p27
*/

BEGIN
	SET NOCOUNT ON

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4, @ProductId = 2

	DECLARE @UserName	NVARCHAR(20)
		, @Recommend	INT

	SELECT CurrencyId
		, LicenseeId
	INTO #Currency
	FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @UserId
		AND LicenseeID = @LicenseeId
		AND SystemID = 1
		AND isActive = 1

	SELECT @UserName = UserName,
		@Recommend = Recommend
	FROM dbo.custinfo AS c WITH (NOLOCK)
		INNER JOIN #Currency AS cy ON c.Currency = cy.CurrencyId
	WHERE CustID = @CustId

	DROP TABLE #Currency

	CREATE TABLE #Data (
		TransId			BIGINT,
		RefNo			BIGINT,
		BetId			BIGINT,
		Username		NVARCHAR(20),
		SportType		SMALLINT,
		BetType			SMALLINT,
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
		Race			NVARCHAR(20),
		Ip				NVARCHAR(15),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		-- Horse Racing
		INSERT INTO #Data
		SELECT
			b.transid,
			b.refno,
			ISNULL(b.betid, 0) AS BetId,
			@Username,
			l.sporttype,
			b.bettype,
			b.currency,
			m.leagueid,
			m.orid AS MatchId,
			m.matchcode,
			CONVERT(BIT,0) AS IsNeutral,
			m.teamid AS HomeId,
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
			(b.winlost - actual_stake) AS WinLost,
			b.awinlost AS LicenseeWL,
			b.comm,
			b.playercomm,
			m.groupmatch AS Race,
			b.ip,
			'' AS BetCheck,
			'' AS TransDesc
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate
			AND b.recommend = @Recommend
			AND b.custid = @CustId
			AND b.ruben = 1
			AND (@CurrencyId = 0 OR b.currency = @CurrencyId)
			AND sbt.ProductId = 2
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @BalanceUpDay < @FromDate
			SELECT @BalanceUpDay = @FromDate

		-- Horse Racing
		INSERT INTO #Data
		SELECT
			b.transid,
			b.refno,
			ISNULL(b.betid, 0) AS BetId,
			@Username,
			l.sporttype,
			b.bettype,
			b.currency,
			m.leagueid,
			m.orid AS MatchId,
			m.matchcode,
			CONVERT(BIT,0) AS IsNeutral,
			m.teamid AS HomeId,
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
			(b.winlost - actual_stake) AS WinLost,
			b.awinlost AS LicenseeWL,
			b.comm,
			b.playercomm,
			m.groupmatch AS Race,
			b.ip,
			'' AS BetCheck,
			'' AS TransDesc
		FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
			INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
			AND b.recommend = @Recommend
			AND b.custid = @CustId 
			AND b.ruben = 1
			AND (@CurrencyId = 0 OR b.currency = @CurrencyId)
			AND sbt.ProductId = 2 
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate

		-- Horse Racing
		INSERT INTO #Data
		SELECT
			b.transid,
			b.refno,
			ISNULL(b.betid, 0) AS BetId,
			@Username,
			l.sporttype,
			b.bettype,
			b.currency,
			m.leagueid,
			m.orid AS MatchId,
			m.matchcode,
			CONVERT(BIT,0) AS IsNeutral,
			m.teamid AS HomeId,
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
			(b.winlost - actual_stake) AS WinLost,
			b.awinlost AS LicenseeWL,
			b.comm,
			b.playercomm,
			m.groupmatch AS Race,
			b.ip,
			'' AS BetCheck,
			'' AS TransDesc
		FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN bodb_archive.dbo.outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid 
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
		WHERE b.winlostdate BETWEEN @fromdate AND @TempToDate
			AND b.custid = @CustId
			AND b.recommend = @Recommend
			AND b.ruben = 1
			AND (@CurrencyId = 0 OR b.currency = @CurrencyId)
			AND sbt.ProductId = 2
	END

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE ExchangeId IN (SELECT DISTINCT Currency FROM #Data)

	SELECT
		@TotalRows			= COUNT(transid),
		@SumWinlost			= SUM(ISNULL(WinLost, 0)),
		@SumLicenseeWL		= SUM(ISNULL(LicenseeWL, 0)),
		@SumComm			= SUM(ISNULL(Comm, 0)),
		@SumPlayerComm		= SUM(ISNULL(PlayerComm, 0)),
		--USD
		@SumWinlostUSD		= SUM(ISNULL(WinLost	* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(Comm		* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(PlayerComm	* e.USD, 0)),
		--EUR
		@SumWinlostEUR		= SUM(ISNULL(WinLost	* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(comm		* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(PlayerComm	* e.EUR, 0)),
		--GBP
		@SumWinlostGBP		= SUM(ISNULL(WinLost	* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(Comm		* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(PlayerComm	* e.GBP, 0))
	FROM #Data AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.ExchangeId = b.Currency

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT A.* 
	FROM
	(
		SELECT
			ROW_NUMBER() OVER(ORDER BY b.TransId) AS RowNum,
			b.*,
			--USD
			b.Stake			* e.USD AS StakeUSD,
			b.Actual_Stake	* e.USD AS Actual_StakeUSD,
			b.WinLost		* e.USD AS WinLostUSD,
			b.LicenseeWL	* e.USD AS LicenseeWLUSD,
			b.Comm			* e.USD AS CommUSD,
			b.PlayerComm	* e.USD AS PlayerCommUSD,
			--EUR
			b.Stake			* e.EUR AS StakeEUR,
			b.Actual_Stake	* e.EUR AS Actual_StakeEUR,
			b.WinLost		* e.EUR AS WinLostEUR,
			b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
			b.Comm			* e.EUR AS CommEUR,
			b.PlayerComm	* e.EUR AS PlayerCommEUR,
			--GBP
			b.Stake			* e.GBP AS StakeGBP,
			b.Actual_Stake	* e.GBP AS Actual_StakeGBP,
			b.WinLost		* e.GBP AS WinLostGBP,
			b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
			b.Comm			* e.GBP AS CommGBP,
			b.PlayerComm	* e.GBP AS PlayerCommGBP
		FROM #Data AS b
			INNER JOIN #TempExchange AS e
				ON e.ExchangeDate = (CASE WHEN b.WinLostDate <= @Today THEN b.WinLostDate ELSE @Today END) AND e.ExchangeId = b.Currency
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

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

	-- Racing
	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.bettype
		WHERE sbt.ProductId = 2 AND sbt.EventType = 2
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.bettype
		WHERE sbt.ProductId = 2 AND sbt.EventType = 2
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.bettype
		WHERE sbt.ProductId = 2 AND sbt.EventType = 2
	END

	SELECT * FROM @BettransDetail
	ORDER BY RefNo, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #Data
END






GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinLossRacingByDate_Mem] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinLossRacingByDate_Mem] TO [vnteam] AS [dbo]