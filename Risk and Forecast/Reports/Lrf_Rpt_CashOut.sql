/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_CashOut]
	@AgentList				VARCHAR(MAX),
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@ReportType				TINYINT		= 1,
	@SportTypeList			VARCHAR(500)	= 'All',
	@BaseCurrency			VARCHAR(12)		= '',
	@DefaultBaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20211217@Kos
	Task: LAP - Cash Out Win Loss report for new model
	DB: DBEXT.bodb02

	Revisions:
		- 20211217@Kos: New SP [RedmineID: #165160]
		- 20220222@Kos: Hotfix - show agent data [RedmineID: #168905]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20221214@Evan: Cash Out WL - Separate Soccer & Basketball [RedmineID: #179083]

	Param's Explanation:
		+ @ReportType: 1: Daily, 2: Monthly
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Invalid Parameter.'

		RETURN
	END CATCH;

	DECLARE
		@_FromDate	SMALLDATETIME,
		@_ToDate	SMALLDATETIME

	DECLARE @CutoffDate SMALLDATETIME;

	SELECT @CutoffDate = CutoffDate
	FROM dbo.Lrf_f_GetCutoffDate()
	WHERE TypeName = 'CashOut'

	SELECT @_FromDate = @FromDate, @_ToDate = @ToDate

	-- Get sport type list
	DECLARE @SportType TABLE (SportType INT PRIMARY KEY)

	IF @SportTypeList = 'All'
	BEGIN
		INSERT INTO @SportType (SportType)
		SELECT DISTINCT SportType
		FROM dbo.SportBettypeMatrix WITH(NOLOCK)
		WHERE ProductID = 1
	END
    ELSE 
	BEGIN
		INSERT INTO @SportType (SportType)
		SELECT value
		FROM STRING_SPLIT(@SportTypeList, ',') 
	END

	-- Get league list
	CREATE TABLE #League (LeagueId INT, SportType SMALLINT)
	CREATE CLUSTERED INDEX IX_LeagueId ON #League (LeagueId)
	
	CREATE TABLE #TempLeague (LeagueId INT)
	CREATE CLUSTERED INDEX IX_LeagueId ON #TempLeague (LeagueId)

	INSERT INTO #TempLeague
	SELECT DISTINCT leagueid
	FROM dbo.match WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM dbo.match14 WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate

	INSERT INTO #League (
		LeagueId,
		SportType )
	SELECT
		l.leagueid,
		l.sporttype
	FROM dbo.League AS l WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM @SportType WHERE SportType = l.sporttype) 
		AND EXISTS (SELECT 1 FROM #TempLeague WHERE leagueid = l.leagueid)	

	-- Get bettype list
	CREATE TABLE #BetType (BetType SMALLINT, ProductCode VARCHAR(10), EventType TINYINT)
	CREATE CLUSTERED INDEX IX_BetType ON #BetType (BetType)

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #BetType (BetType)
	SELECT DISTINCT BetType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', 'SB', 1)
	WHERE BetType NOT IN (9, 29, 10, 914, 901, 902, 903, 904)

	DECLARE @Data TABLE (
		WinLostDate	SMALLDATETIME,
		Currency	INT,
		BetCount	BIGINT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY,
		PlayerComm	MONEY,
		BAComm		MONEY,
		AmtDueToBA	MONEY
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	-- bettrans range
	IF @_ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @_FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @_FromDate
							END

		INSERT INTO @Data (
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			LicenseeWL,
			PlayerComm,
			BAComm,
			AmtDueToBA )
		SELECT
			b.winlostdate,
			b.currency,
			COUNT(1) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(CASE WHEN b.tpositiontaking <> 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
			SUM(b.playerComm) AS PlayerComm,
			SUM(CASE WHEN b.tpositiontaking = 0 THEN b.comm ELSE 0 END) AS BAComm,
			-SUM(CASE
					WHEN b.tpositiontaking = 0 THEN b.winlost - b.actual_stake + b.awinlost + b.comm
					ELSE 0
				END) AS AmtDueToBA
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN #BetType AS bt ON bt.bettype = b.bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
			INNER JOIN #League AS l ON l.LeagueId = m.leagueid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID IN (111, 112, 113)
			AND b.betdaqid = -2
		GROUP BY
			b.winlostdate,
			b.currency
	END
 
	-- bettrans14 & bettrans_bk range
	IF @_FromDate <= @MoveBetsDay
	BEGIN
		DECLARE @TempDateCutoff SMALLDATETIME; 

		SET @TempToDate = CASE
							WHEN @_ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @_ToDate
						END

		IF @_FromDate < @CutoffDate
		BEGIN
			SET @TempDateCutoff = CASE
							WHEN @TempToDate > @CutoffDate THEN @TempToDate
							ELSE @CutoffDate
						END

			INSERT INTO @Data (
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				PlayerComm,
				BAComm,
				AmtDueToBA )
			SELECT
				b.winlostdate,
				b.currency,
				SUM(b.betcount) AS BetCount,
				SUM(b.turnover) AS Turnover,
				SUM(b.winlost) AS WinLost,
				-SUM(CASE WHEN b.isBA = 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
				SUM(b.playercomm) AS PlayerComm,
				SUM(CASE WHEN b.isBA = 1 THEN b.comm ELSE 0 END) AS BAComm,
				-SUM(CASE WHEN b.isBA = 1 THEN b.winlost + b.awinlost + b.comm ELSE 0 END) AS AmountDueToBA
			FROM
				bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
				INNER JOIN @SportType AS s ON s.SportType = b.sporttype
			WHERE
				b.winlostdate BETWEEN @_FromDate AND @TempDateCutoff
				AND b.statusID <> 101	--exclude REJECT
				AND b.bettype NOT IN (901, 902, 903, 904, 914, 9, 29, 10)
				AND b.TicketType = 1
				AND b.roleid = 1
			GROUP BY
				b.winlostdate,
				b.currency

		END

		IF @TempToDate >= @CutoffDate
		BEGIN 
			INSERT INTO @Data (
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				PlayerComm,
				BAComm,
				AmtDueToBA )
			SELECT
				b.winlostdate,
				b.currency,
				SUM(b.betcount) AS BetCount,
				SUM(b.stake) AS Turnover,
				SUM(b.winlost) AS WinLost,
				-SUM(CASE WHEN b.isBA = 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
				SUM(b.playercomm) AS PlayerComm,
				SUM(CASE WHEN b.isBA = 1 THEN b.comm ELSE 0 END) AS BAComm,
				-SUM(CASE WHEN b.isBA = 1 THEN b.winlost + b.awinlost + b.comm ELSE 0 END) AS AmountDueToBA
			FROM
				bodb_LicenseeReport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
				INNER JOIN #League AS l ON l.LeagueId = b.leagueid
			WHERE 
				b.winlostdate BETWEEN @CutoffDate AND @TempToDate
				AND b.statusID <> 101	--exclude REJECT
				AND b.bettype NOT IN (901, 902, 903, 904, 914, 9, 29, 10)
				AND b.TicketType = 1 
			GROUP BY
				b.winlostdate,
				b.currency
		END
			
	END
	
	DELETE FROM @Data WHERE BetCount = 0

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM @Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, Rate)
		SELECT FromDate, ToDate, ExchangeID, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, '') e
		WHERE EXISTS (SELECT 1 FROM #TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	SELECT
		CASE
			WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), d.WinLostDate, 112)
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), d.WinLostDate, 112)
			ELSE '0'
		END ReportType,
		d.Currency,
		SUM(d.BetCount) AS Betcount,
		CAST(SUM(d.Turnover)	AS MONEY) AS Turnover,
		CAST(SUM(d.WinLost)		AS MONEY) AS WinLost,
		CAST(SUM(d.LicenseeWL)	AS MONEY) AS LicenseeWL,
		CAST(SUM(d.PlayerComm)	AS MONEY) AS PlayerComm,
		CAST(SUM(d.BAComm)		AS MONEY) AS BAComm,
		CAST(SUM(d.AmtDueToBA)	AS MONEY) AS AmtDuetoBA,
		CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS BasedTurnover,
		CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS BasedWinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS BasedLicenseeWL,
		CAST(SUM(d.PlayerComm	* e.Rate) AS MONEY) AS BasedPlayerComm,
		CAST(SUM(d.BAComm		* e.Rate) AS MONEY) AS BasedBAComm,
		CAST(SUM(d.AmtDueToBA	* e.Rate) AS MONEY) AS BasedAmtDuetoBA
	FROM @Data AS d
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.currency = e.ExchangeId
	GROUP BY
		CASE
			WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), d.WinLostDate, 112)
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), d.WinLostDate, 112)
			ELSE '0'
		END,
		d.Currency
	ORDER BY ReportType ASC

	DROP TABLE #TempAg
	DROP TABLE #BetType
	DROP TABLE #TempLeague
	DROP TABLE #League
END
GO