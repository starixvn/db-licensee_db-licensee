 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Racing]
	@LicenseeId			INT,
	@UserId				INT,
	@LicenseeType		VARCHAR(100)	= NULL,
	@CurrencyId			INT				= 0,
	@BetType			INT,
	@LeagueId			INT,
	@RaceNo				VARCHAR(50),
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				VARCHAR(30)		= 'TransId DESC',
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
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT
AS

/*
	Created: Henry@20101210
	Task : Betlist HR
	DB: DBEXT.bodb02
	Original: Age_BetList_SelWinlossHR_Ag
	Revisions:
		- 20110214@Jacob: Add column discount in the result SET
		- 20110216@Jacob: Add column nickname in the result SET
		- 20110303@Henry: suppport based currency
		- 20110506@Henry: fix bug do not have data if only parameter @CustID --> change to param: @LicenseeID, @LicenseeType, @CurrencyName to get the list of agents
		- 20110721@Henry: Add Licensee WL
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120726@Jim: add playercomm value 
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20141111@Winnie: Change from LicenseeCust to f_SelLicenseeCust 
		- 20150128@Winnie: Add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY, sportstype from TINYINT to SMALLINT [Redmine: #48660]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg AS TABLE (custid INT)

	CREATE TABLE #Data (
		SportType		SMALLINT,
		Username		NVARCHAR(50),
		NickName		NVARCHAR(50),
		BetType			SMALLINT,
		Transid			BIGINT,
		Race			VARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(25),
		APositionTaking	SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(30),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT
	)

	SELECT currencyID,
		LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)
	WHERE @CurrencyID = 0
		OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc
		INNER JOIN #Currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO #Data
		SELECT
			l.sporttype,
			b.username,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS Nickname,
			b.bettype,
			b.transid,
			m.groupmatch AS Race,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - actual_stake),
			b.awinlost,
			b.comm,
			b.playercomm,
			b.adiscount,
			b.transdate,
			'',
			b.apositiontaking,
			0,
			b.livehomescore,
			b.liveawayscore,
			l.leagueid,
			b.matchid,
			b.ip,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.custid
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND b.currency = @CurrencyID))
			AND b.winlostdate >= @FromDate
			AND b.winlostdate <= @ToDate
			AND l.leagueid = @LeagueId
			AND m.groupmatch = @RaceNo
			AND b.bettype= @Bettype
			AND b.ruben = 1
	END
  
	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO #Data
		SELECT
			l.sporttype,
			b.username,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
			b.bettype,
			b.transid,
			m.groupmatch AS Race,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			modds,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - actual_stake),
			b.awinlost,
			b.comm,
			b.playercomm,
			b.adiscount,
			b.transdate,
			'',
			b.apositiontaking,
			0,
			b.livehomescore,
			b.liveawayscore,
			l.leagueid,
			b.matchid,
			b.ip,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			b.winlostdate,
			b.currency
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			INNER JOIN dbo.customer AS c WITH(NOLOCK) ON c.custid = b.custid
		WHERE
			b.recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND b.currency = @CurrencyID))
			AND b.winlostdate >= @FromDate
			AND b.winlostdate <= @ToDate
			AND l.leagueid = @LeagueId
			AND m.groupmatch = @RaceNo
			AND b.bettype = @Bettype
			AND b.ruben = 1
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
		@TotalRows			= COUNT(b.Transid),
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
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	CREATE TABLE #PagingData (
		RowNum			INT,
		SportType		SMALLINT,
		Username		NVARCHAR(50),
		NickName		NVARCHAR(50),
		BetType			SMALLINT,
		Transid			BIGINT,
		Race			VARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(25),
		APositionTaking	SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(30),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT
	)

	DECLARE @Sql NVARCHAR(500)

	SET @Sql = 
		'INSERT INTO #PagingData
		SELECT A.*
		FROM
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY ' + @Sort + ') AS RowNum,
				b.* 
			FROM #Data AS b
		) A 
		WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+ ' ORDER BY A.RowNum'

	EXEC sp_executesql @Sql

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
		INNER JOIN  #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency

	-- Get data from bettransm for bettype 33,43
	IF @BetType IN (33, 43)
	BEGIN
		DECLARE @Bettransm TABLE (
			RefNo			BIGINT,
			FinalOdds		MONEY,
			Odds			MONEY,
			Status			NVARCHAR(10),
			APositionTaking	SMALLMONEY,
			BetType			SMALLINT
		)

		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT
				bm.refno,
				bm.finalodds,
				bm.odds,
				bm.status,
				bm.apositiontaking,
				bm.bettype
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.refno = b.transid
			WHERE b.Bettype = @Bettype
		END

		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				bm.refno,
				bm.finalodds,
				bm.odds,
				bm.status,
				bm.apositiontaking,
				bm.bettype
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.refno = b.transid
			WHERE b.Bettype = @Bettype
		END

		SELECT * FROM @Bettransm
		ORDER BY RefNo, Bettype
	END
	
	DROP TABLE #TempExchange
	DROP TABLE #PagingData
	DROP TABLE #Currency
END
  

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Racing] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_MatchWL_Racing] TO [vnteam]

