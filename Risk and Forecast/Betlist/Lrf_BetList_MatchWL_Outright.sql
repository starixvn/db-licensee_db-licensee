
USE bodb02
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Outright]
	@LicenseeId			INT,
	@UserId				INT,
	@LicenseeType		VARCHAR(100)	= NULL,
	@CurrencyId			INT				= 0,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@ShowBA				BIT				= 0,
	@ShowSB				BIT				= 0,
	@ExcludeReject		BIT				= 0,
	@Langkey			VARCHAR(10)		= 'en-US',
	@MoveBetsDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 0,
	@Sort				VARCHAR(100)	= 'TransId ASC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinLostUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinLostEUR		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinLostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT
AS

/*
	Created: Henry@20101210
	Task: Get bet tickets for outright, horse racing
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelWinlossOutright_Ag]
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110506@Henry: fix bug do not have data if only parameter @CustID --> change to param: @LicenseeID, @LicenseeType, @CurrencyName to get the list of agents
		- 20110712@Henry: Add column LicenseeWL
		- 20111121@Jacob: Add 3 parameters: @ShowBA & @Show SB & @ExcludeReject
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120726@Jim: add player comm value
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20150406@Winnie: Apply spottype bettype matrix
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]

	Example:

	declare @p12 int
	set @p12=7
	declare @p13 money
	set @p13=0
	declare @p14 money
	set @p14=0
	declare @p15 money
	set @p15=0
	declare @p16 money
	set @p16=0
	declare @p17 money
	set @p17=0
	declare @p18 money
	set @p18=0
	declare @p19 money
	set @p19=0
	declare @p20 money
	set @p20=0
	declare @p21 money
	set @p21=0

	DECLARE @DateFrom DATETIME
	DECLARE @DateTo DATETIME
	DECLARE @MoveBetsDay DATETIME
	SELECT @DateFrom = DATEADD(DAY, -15, GETDATE())
	SELECT @DateTo = GETDATE()
	SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)


	exec Lrf_BetList_SelWinlossOutright @LicenseeID=4,@LicenseeType=default,@CurrencyName=default,@FromDate=@DateFrom,@ToDate=@DateTo,@ShowBA=1,@ShowSB=0,@Language=default,@MoveBetsDay=@MoveBetsDay,@PageSize=1000,@PageIndex=1,@TotalRows=@p12 output,@SumWinlost=@p13 output,@SumLicenseeWL=@p14 output,@SumComm=@p15 output,@SumWinlostUSD=@p16 output,@SumLicenseeWLUSD=@p17 output,@SumCommUSD=@p18 output,@SumWinlostEUR=@p19 output,@SumLicenseeWLEUR=@p20 output,@SumCommEUR=@p21 output
	select @p12, @p13, @p14, @p15, @p16, @p17, @p18, @p19, @p20, @p21
*/

BEGIN
	SET NOCOUNT ON

	SELECT currencyID,
		LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)-- System is default=1 (LRF)
	WHERE @CurrencyId = 0
		OR (@CurrencyId <> 0 AND CurrencyID = @CurrencyId)

	DECLARE @TempAg AS TABLE (custid INT)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc
		INNER JOIN #Currency AS c ON lc.LicenseeID=c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID INT, BetType INT, EventType INT)

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4, @ProductID = 1

	CREATE TABLE #Data (
		SportType		INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
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
		BetTeam			NVARCHAR(50),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT, 
		Ip				VARCHAR(30),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		IsBA			INT
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamid,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake),
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueid,
				b.matchid,
				b.ip,
				NULL,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				1 AS isBA
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.currency = @CurrencyID))
				AND b.winlostdate >= @FromDate
				AND b.winlostdate <= @ToDate
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.ruben = 1
				AND b.tpositiontaking = 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103)))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamid,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake),
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueid,
				b.matchid,
				b.ip,
				NULL,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				0 AS IsBA
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.currency = @CurrencyID))
				AND b.winlostdate >= @FromDate
				AND b.winlostdate <= @ToDate
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.ruben = 1
				AND b.tpositiontaking <> 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103))) 
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamid,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake),
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueid,
				b.matchid,
				b.ip,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				1 AS IsBA
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.Winlostdate >= @FromDate
				AND b.Winlostdate <= @ToDate
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.Ruben = 1
				AND b.tpositiontaking = 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103)))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamid,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost - actual_stake),
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueid,
				b.matchid, 
				b.ip,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				0 AS IsBA
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE
				b.recommend IN (SELECT custid FROM @TempAg)
				AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
				AND b.winlostdate >= @FromDate
				AND b.winlostdate <= @ToDate
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.ruben = 1
				AND b.tpositiontaking <> 0
				AND (@ExcludeReject = 0
					OR (@ExcludeReject = 1 AND b.statusID NOT IN (101, 102, 103))) 
		END
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #Data (Currency)

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

	SELECT
		@TotalRows			= COUNT(b.TransId),
		@SumWinlost			= SUM(ISNULL(b.WinLost, 0)),
		@SumLicenseeWL		= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm			= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm		= SUM(ISNULL(b.PlayerComm,0)),
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
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency

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
		BetType			SMALLINT,
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
		BetTeam			NVARCHAR(50),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT, 
		Ip				VARCHAR(30),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		IsBA			INT
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
		'INSERT INTO #PagingData
		SELECT A.*
		FROM
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY ' + @SortExp + ') AS RowNum,
				b.* 
			FROM #Data AS b
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.Currency AND e.ExchangeDate = b.WinLostDate
		) A
		WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+ ' ORDER BY A.RowNum'

	EXEC sp_executesql @sql

	DROP TABLE #Data

	SELECT
		b.*,
		-- USD
		b.Stake			* e.USD AS StakeUSD,
		b.WinLost		* e.USD AS WinLostUSD,
		b.LicenseeWL	* e.USD AS LicenseeWLUSD,
		b.Comm			* e.USD AS CommUSD,
		b.PlayerComm	* e.USD AS PlayerCommUSD,
		-- EUR
		b.Stake			* e.EUR AS StakeEUR,
		b.WinLost		* e.EUR AS WinLostEUR,
		b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
		b.Comm			* e.EUR AS CommEUR,
		b.PlayerComm	* e.EUR AS PlayerCommEUR,
		-- GBP
		b.Stake			* e.GBP AS StakeGBP,
		b.WinLost		* e.GBP AS WinLostGBP,
		b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
		b.Comm			* e.GBP AS CommGBP,
		b.PlayerComm	* e.GBP AS PlayerCommGBP
	FROM #PagingData AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	DROP TABLE #PagingData
	DROP TABLE #TempExchange
	DROP TABLE #currency
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Outright] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_MatchWL_Outright] TO [VNTeam] 

