/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByLeague_League_Currency]
	@AgentList		VARCHAR(MAX),
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@LeagueId		INT,
	@ProductList	VARCHAR(100)	= '',
	@ShowBA			BIT				= 0,
	@BetTypeList	VARCHAR(MAX)	= '',
	@StatusIdList	VARCHAR(50)		= '',
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20210916@Kos
	Task: LAP - Win Loss By League report - League level - Separated by currencies
	DB: DBEXT.bodb02

	Revisions:
		- 20210916@Kos: New SP [RedmineID: #159939]
		- 20220106@Kos: Support search by username [RedmineID: #165926]
		- 20220513@Kos: Support Sports Lottery and Bitcoin [RedmineID: #160160]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20241701@Evan: Update f_GroupBettype to Lrf_f_GroupBettype [RedmineID: #199523]

	Param's Explanation:
		- @BetTypeList: bettype list separated by ','
			+ 'All': all bettypes
		- @StatusIdList: status ID list separated by ','
		- @Username: exact System ID or External ID
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId)

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

	DECLARE @CustId INT = -1

	-- Get CustId in case of inputting Username
	IF @Username <> ''
	BEGIN
		SELECT @CustId = c.custid
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN #TempAg AS ta ON ta.CustId = c.recommend
		WHERE c.username = @Username

		IF @CustId = -1
		BEGIN
			SELECT @CustId = c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN #TempAg AS ta ON ta.CustId = c.recommend
			WHERE c.username2 LIKE + '%$' + @Username
		END

		IF @CustId = -1
		BEGIN
			SET @CustId = 0
		END
	END

	DECLARE @ShowSB BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	-- Get sport/bettype matrix
	CREATE TABLE #SportBetType (BetType SMALLINT, ProductCode VARCHAR(10), EventType TINYINT)

	CREATE CLUSTERED INDEX IX_SportBetType ON #SportBetType (BetType)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Insert Bettype
	INSERT INTO #SportBetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 999)
		AND BetType NOT BETWEEN 801 AND 806
		AND (@BetTypeList = 'All'
			OR ',' + @BetTypeList + ',' LIKE '%,' + CAST(BetType AS VARCHAR(5)) + ',%'
			OR BetType IN (SELECT Bettype FROM dbo.Lrf_f_GroupBettype() WHERE ',' + @BetTypeList + ',' LIKE '%,' + CAST(GroupTypeId AS VARCHAR(5)) + ',%'))

	-- Parlay
	IF @LeagueId = -9
		DELETE FROM #SportBetType
		WHERE BetType <> 29

	-- Sports Lottery
	IF @LeagueId = -63
		DELETE FROM #SportBetType
		WHERE ProductCode <> 'SLT'

	-- Bitcoin
	IF @LeagueId = -69
		DELETE FROM #SportBetType
		WHERE ProductCode <> 'BTC'

	DECLARE @Data TABLE (
		Currency	INT,
		WinLostDate	SMALLDATETIME,
		BetCount	BIGINT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY,
		BAComm		MONEY
	)

	DECLARE @_FromDate	SMALLDATETIME,
		@_ToDate		SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	-- bettrans range
	IF @_ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @_FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @_FromDate
							END

		IF @CustId = -1		-- Licensee level
		BEGIN
			IF @LeagueId > 0
			BEGIN
				-- Sportsbook (EventType = 1)
				INSERT INTO @Data (
					Currency,
					WinLostDate,
					BetCount,
					Turnover,
					WinLost,
					LicenseeWL,
					BAComm )
				SELECT
					b.currency,
					b.winlostdate,
					COUNT(1) AS BetCount,
					SUM(CASE
							WHEN b.statusID IN (112, 113)
								AND b.modds IN (-0.25, 0.25)
								AND b.bettype NOT IN (29, 38)
								THEN 0.5 * b.stake
							ELSE b.stake
						END) AS Turnover,
					SUM(b.winlost - b.actual_stake) AS WinLost,
					- SUM(CASE
							WHEN sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
							ELSE b.winlost - b.actual_stake
						END) AS LicenseeWL,
					SUM(CASE
							WHEN sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN b.comm
							ELSE 0
						END) AS BAComm
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN #TempAg AS a ON a.CustId = b.recommend
					INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
					AND sbt.EventType = 1
					AND 1 = CASE
								WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
								WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
								ELSE 1
							END
					AND m.leagueid = @LeagueId
				GROUP BY
					b.currency,
					b.winlostdate

				-- Outright
				IF EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 10)
				BEGIN
					INSERT INTO @Data (
						Currency,
						WinLostDate,
						BetCount,
						Turnover,
						WinLost,
						LicenseeWL,
						BAComm )
					SELECT
						b.currency,
						b.winlostdate,
						COUNT(1) AS BetCount,
						SUM(b.stake) AS Turnover,
						SUM(b.winlost - b.actual_stake) AS WinLost,
						- SUM(CASE
								WHEN b.tpositiontaking = 0 THEN 0
								ELSE b.winlost - b.actual_stake
							END) AS LicenseeWL,
						SUM(CASE
								WHEN b.tpositiontaking = 0 THEN b.comm
								ELSE 0
							END) AS BAComm
					FROM
						dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = b.recommend
						INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid
					WHERE
						b.winlostdate BETWEEN @TempFromDate AND @_ToDate
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND b.bettype = 10
						AND 1 = CASE
								WHEN @ShowBA = 0 AND b.tpositiontaking = 0 THEN 0
								WHEN @ShowSB = 0 AND b.tpositiontaking <> 0 THEN 0
								ELSE 1
							END
						AND o.leagueid = @LeagueId
					GROUP BY
						b.currency,
						b.winlostdate
				END
			END
			ELSE IF @LeagueId IN (-9, -63, -69)		-- Parlay, Sports Lottery, Bitcoin
			BEGIN
				INSERT INTO @Data (
					Currency,
					WinLostDate,
					BetCount,
					Turnover,
					WinLost,
					LicenseeWL,
					BAComm )
				SELECT
					b.currency,
					b.winlostdate,
					COUNT(1) AS BetCount,
					SUM(b.stake) AS Turnover,
					SUM(b.winlost - b.actual_stake) AS WinLost,
					- SUM(CASE
							WHEN b.tpositiontaking = 0 THEN 0
							ELSE b.winlost - b.actual_stake
						END) AS LicenseeWL,
					SUM(CASE
							WHEN b.tpositiontaking = 0 THEN b.comm
							ELSE 0
						END) AS BAComm
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN #TempAg AS a ON a.CustId = b.recommend
					INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
					AND 1 = CASE
								WHEN sbt.ProductCode = 'SB' AND @ShowBA = 0 AND b.tpositiontaking = 0 THEN 0
								WHEN sbt.ProductCode = 'SB' AND @ShowSB = 0 AND b.tpositiontaking <> 0 THEN 0
								ELSE 1
							END
				GROUP BY
					b.currency,
					b.winlostdate
			END
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			IF @LeagueId > 0
			BEGIN
				-- Sportsbook (EventType = 1)
				INSERT INTO @Data (
					Currency,
					WinLostDate,
					BetCount,
					Turnover,
					WinLost,
					LicenseeWL,
					BAComm )
				SELECT
					b.currency,
					b.winlostdate,
					COUNT(1) AS BetCount,
					SUM(CASE
							WHEN b.statusID IN (112, 113)
								AND b.modds IN (-0.25, 0.25)
								AND b.bettype NOT IN (29, 38)
								THEN 0.5 * b.stake
							ELSE b.stake
						END) AS Turnover,
					SUM(b.winlost - b.actual_stake) AS WinLost,
					- SUM(CASE
							WHEN sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
							ELSE b.winlost - b.actual_stake
						END) AS LicenseeWL,
					SUM(CASE
							WHEN sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN b.comm
							ELSE 0
						END) AS BAComm
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.custid = @CustId
					AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
					AND sbt.EventType = 1
					AND 1 = CASE
								WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
								WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
								ELSE 1
							END
					AND m.leagueid = @LeagueId
				GROUP BY
					b.currency,
					b.winlostdate

				-- Outright
				IF EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 10)
				BEGIN
					INSERT INTO @Data (
						Currency,
						WinLostDate,
						BetCount,
						Turnover,
						WinLost,
						LicenseeWL,
						BAComm )
					SELECT
						b.currency,
						b.winlostdate,
						COUNT(1) AS BetCount,
						SUM(b.stake) AS Turnover,
						SUM(b.winlost - b.actual_stake) AS WinLost,
						- SUM(CASE
								WHEN b.tpositiontaking = 0 THEN 0
								ELSE b.winlost - b.actual_stake
							END) AS LicenseeWL,
						SUM(CASE
								WHEN b.tpositiontaking = 0 THEN b.comm
								ELSE 0
							END) AS BAComm
					FROM
						dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid
					WHERE
						b.winlostdate BETWEEN @TempFromDate AND @_ToDate
						AND b.custid = @CustId
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND b.bettype = 10
						AND 1 = CASE
								WHEN @ShowBA = 0 AND b.tpositiontaking = 0 THEN 0
								WHEN @ShowSB = 0 AND b.tpositiontaking <> 0 THEN 0
								ELSE 1
							END
						AND o.leagueid = @LeagueId
					GROUP BY
						b.currency,
						b.winlostdate
				END
			END
			ELSE IF @LeagueId IN (-9, -63, -69)		-- Parlay, Sports Lottery, Bitcoin
			BEGIN
				INSERT INTO @Data (
					Currency,
					WinLostDate,
					BetCount,
					Turnover,
					WinLost,
					LicenseeWL,
					BAComm )
				SELECT
					b.currency,
					b.winlostdate,
					COUNT(1) AS BetCount,
					SUM(b.stake) AS Turnover,
					SUM(b.winlost - b.actual_stake) AS WinLost,
					- SUM(CASE
							WHEN b.tpositiontaking = 0 THEN 0
							ELSE b.winlost - b.actual_stake
						END) AS LicenseeWL,
					SUM(CASE
							WHEN b.tpositiontaking = 0 THEN b.comm
							ELSE 0
						END) AS BAComm
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.custid = @CustId
					AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
					AND 1 = CASE
								WHEN sbt.ProductCode = 'SB' AND @ShowBA = 0 AND b.tpositiontaking = 0 THEN 0
								WHEN sbt.ProductCode = 'SB' AND @ShowSB = 0 AND b.tpositiontaking <> 0 THEN 0
								ELSE 1
							END
				GROUP BY
					b.currency,
					b.winlostdate
			END
		END
	END

	-- bettrans14 & bettrans_bk range
	IF @_FromDate <= @MoveBetsDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @_ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @_ToDate
						END

		-- Add HalfWon status ID
		IF ',' + @StatusIdList + ',' LIKE '%,112,%'
			SET @StatusIdList = @StatusIdList + ',114'

		-- Add HalfLose status ID
		IF ',' + @StatusIdList + ',' LIKE '%,113,%'
			SET @StatusIdList = @StatusIdList + ',115'

		CREATE TABLE #Date (Date SMALLDATETIME PRIMARY KEY)

		INSERT INTO #Date
		SELECT [Date]
		FROM f_GetDateBetweenTwoDates (@_FromDate, @TempToDate)

		IF @CustId = -1		-- Licensee level
		BEGIN
			INSERT INTO @Data (
				Currency,
				WinLostDate,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT b.*
			FROM
				#Date AS d
				CROSS APPLY (
					SELECT
						b.currency,
						b.winlostdate,
						SUM(b.betcount) AS BetCount,
						SUM(CASE
								WHEN b.statusID IN (114, 115) THEN 0.5 * b.stake
								ELSE b.stake
							END) AS Turnover,
						SUM(b.winlost) AS WinLost,
						-SUM(CASE WHEN b.isBA = 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
						SUM(CASE WHEN b.isBA = 1 THEN b.comm ELSE 0 END) AS BAComm
					FROM
						bodb_licenseereport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = b.recommend
						INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
					WHERE
						b.winlostdate = d.Date
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND (b.leagueid = @LeagueId OR @LeagueId = -69)
						AND 1 = CASE
									WHEN sbt.ProductCode = 'SB' AND @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
									WHEN sbt.ProductCode = 'SB' AND @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
									ELSE 1
								END
					GROUP BY
						b.currency,
						b.winlostdate
				) AS b
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				Currency,
				WinLostDate,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT b.*
			FROM
				#Date AS d
				CROSS APPLY (
					SELECT
						b.currency,
						b.winlostdate,
						SUM(b.betcount) AS BetCount,
						SUM(CASE
								WHEN b.statusID IN (114, 115) THEN 0.5 * b.stake
								ELSE b.stake
							END) AS Turnover,
						SUM(b.winlost) AS WinLost,
						-SUM(CASE WHEN b.isBA = 0 THEN b.winlost ELSE 0 END) AS LicenseeWL,
						SUM(CASE WHEN b.isBA = 1 THEN b.comm ELSE 0 END) AS BAComm
					FROM
						bodb_licenseereport.dbo.rptCustomerMatch AS b WITH (NOLOCK)
						INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
					WHERE
						b.winlostdate = d.Date
						AND b.custid = @CustId
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND (b.leagueid = @LeagueId OR @LeagueId = -69)
						AND 1 = CASE
									WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
									WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
									ELSE 1
								END
					GROUP BY
						b.currency,
						b.winlostdate
				) AS b
		END

		DROP TABLE #Date
	END

	-- Get exchange rate
	DECLARE @MinDate	SMALLDATETIME,
		 @MaxDate		SMALLDATETIME

	SELECT
		@MinDate = MIN(WinLostDate),
		@MaxDate = MAX(WinLostDate)
	FROM @Data

	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT,
		USD			FLOAT,
		EUR			FLOAT,
		GBP			FLOAT,
		DefaultRate	FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM @Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @BaseCurrency, '') e
		WHERE EXISTS (SELECT 1 FROM #TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	-- Return result
	SELECT
		d.Currency,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(d.BAComm		* e.Rate) AS MONEY) AS BAComm
	FROM @Data AS d
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
	GROUP BY d.Currency
	ORDER BY d.Currency ASC

	DROP TABLE #TempAg
	DROP TABLE #SportBetType
END
GO
