/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByLeague_Match]
	@AgentList		VARCHAR(MAX),
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@LeagueId		INT,
	@ProductList	VARCHAR(100)	= '',
	@ShowBA			BIT				= 0,
	@BetTypeList	VARCHAR(MAX)	= '',
	@StatusIdList	VARCHAR(50)		= '',
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20210916@Kos
	Task: LAP - Win Loss By League report - Match level
	DB: DBEXT.bodb02

	Revisions:
		- 20210916@Kos: New SP [RedmineID: #159939]
		- 20220106@Kos: Support search by username [RedmineID: #165926]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20241701@Evan: Update f_GroupBettype to Lrf_f_GroupBettype [RedmineID: #199523]

	Param's Explanation:
		- @BetTypeList: bettype list separated by ','
			+ 'All': all bettypes
		- @StatusIdList: status ID list separated by ','
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	DECLARE @TempAg TABLE (CustId INT PRIMARY KEY, Currency INT)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (CustId, Currency)
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
			INNER JOIN @TempAg AS ta ON ta.CustId = c.recommend
		WHERE c.username = @Username

		IF @CustId = -1
		BEGIN
			SELECT @CustId = c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN @TempAg AS ta ON ta.CustId = c.recommend
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
	DECLARE @SportBetType TABLE (BetType SMALLINT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Insert Bettype
	INSERT INTO @SportBetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 999)
		AND BetType NOT BETWEEN 801 AND 806
		AND (@BetTypeList = 'All'
			OR ',' + @BetTypeList + ',' LIKE '%,' + CAST(BetType AS VARCHAR(5)) + ',%'
			OR BetType IN (SELECT Bettype FROM dbo.Lrf_f_GroupBettype() WHERE ',' + @BetTypeList + ',' LIKE '%,' + CAST(GroupTypeId AS VARCHAR(5)) + ',%'))

	DECLARE @Data TABLE (
		MatchId		INT,
		EventType	TINYINT,
		HomeId		INT,
		AwayId		INT,
		IsNeutral	BIT,
		WinLostDate	SMALLDATETIME,
		Currency	INT,
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
			-- Sportsbook (EventType = 1)
			INSERT INTO @Data (
				MatchId,
				EventType,
				HomeId,
				AwayId,
				IsNeutral,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				CASE
					WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
					ELSE b.matchid
				END AS MatchId,
				1 AS EventType,
				m.homeid,
				m.awayid,
				m.IsNeutral,
				b.winlostdate,
				b.currency,
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
				INNER JOIN @TempAg AS a ON a.CustId = b.recommend
				INNER JOIN @SportBetType AS sbt ON sbt.BetType = b.bettype
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
				CASE
					WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
					ELSE b.matchid
				END,
				m.homeid,
				m.awayid,
				m.IsNeutral,
				b.winlostdate,
				b.currency

			-- Outright
			INSERT INTO @Data (
				MatchId,
				EventType,
				HomeId,
				AwayId,
				IsNeutral,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				b.matchid,
				2 AS EventType,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS IsNeutral,
				b.winlostdate,
				b.currency,
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
				INNER JOIN @TempAg AS a ON a.CustId = b.recommend
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
				b.matchid,
				o.teamid,
				b.winlostdate,
				b.currency
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			-- Sportsbook (EventType = 1)
			INSERT INTO @Data (
				MatchId,
				EventType,
				HomeId,
				AwayId,
				IsNeutral,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				CASE
					WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
					ELSE b.matchid
				END AS MatchId,
				1 AS EventType,
				m.homeid,
				m.awayid,
				m.IsNeutral,
				b.winlostdate,
				b.currency,
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
				INNER JOIN @SportBetType AS sbt ON sbt.BetType = b.bettype
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
				CASE
					WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
					ELSE b.matchid
				END,
				m.homeid,
				m.awayid,
				m.IsNeutral,
				b.winlostdate,
				b.currency

			-- Outright
			INSERT INTO @Data (
				MatchId,
				EventType,
				HomeId,
				AwayId,
				IsNeutral,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				b.matchid,
				2 AS EventType,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS IsNeutral,
				b.winlostdate,
				b.currency,
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
				b.matchid,
				o.teamid,
				b.winlostdate,
				b.currency
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
				MatchId,
				EventType,
				WinLostDate,
				Currency,
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
						b.matchid,
						sbt.EventType,
						b.winlostdate,
						b.currency,
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
						INNER JOIN @TempAg AS a ON a.CustId = b.recommend
						INNER JOIN @SportBetType AS sbt ON sbt.BetType = b.bettype
					WHERE
						b.winlostdate = d.Date
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND b.leagueid = @LeagueId
						AND 1 = CASE
									WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
									WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
									ELSE 1
								END
					GROUP BY
						b.matchid,
						sbt.EventType,
						b.winlostdate,
						b.currency
				) AS b
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				MatchId,
				EventType,
				WinLostDate,
				Currency,
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
						b.matchid,
						sbt.EventType,
						b.winlostdate,
						b.currency,
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
						INNER JOIN @SportBetType AS sbt ON sbt.BetType = b.bettype
					WHERE
						b.winlostdate = d.Date
						AND b.custid = @CustId
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND b.leagueid = @LeagueId
						AND 1 = CASE
									WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
									WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
									ELSE 1
								END
					GROUP BY
						b.matchid,
						sbt.EventType,
						b.winlostdate,
						b.currency
				) AS b
		END

		DROP TABLE #Date

		-- bettrans14 range
		IF EXISTS (SELECT 1 FROM @Data WHERE WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay)
		BEGIN
			UPDATE b
			SET b.MatchId = CASE
								WHEN b.EventType = 1 AND m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
								ELSE b.matchid
							END,
				b.HomeId = CASE
								WHEN b.EventType = 1 THEN m.homeid
								WHEN b.EventType = 2 THEN o.teamid
								ELSE 0
							END,
				b.AwayId = CASE
								WHEN b.EventType = 1 THEN m.awayid
								ELSE 0
							END,
				b.IsNeutral = CASE
								WHEN b.EventType = 1 THEN m.IsNeutral
								ELSE 0
							END
			FROM @Data AS b
				LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND b.EventType = 1
				LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId AND b.EventType = 2
			WHERE b.WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		END

		-- bettrans_bk range
		IF EXISTS (SELECT 1 FROM @Data WHERE WinLostDate < @BalanceUpDay)
		BEGIN
			UPDATE b
			SET b.MatchId = CASE
								WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
								ELSE b.matchid
							END,
				b.HomeId = m.homeid,
				b.AwayId = m.awayid,
				b.IsNeutral = m.IsNeutral
			FROM @Data AS b
				INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
			WHERE b.WinLostDate < @BalanceUpDay
				AND b.EventType = 1
				AND m.leagueid = @LeagueId

			UPDATE b
			SET b.HomeId = o.teamid,
				b.AwayId = 0,
				b.IsNeutral = 0
			FROM @Data AS b
				INNER JOIN DBARC.bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
			WHERE b.WinLostDate < @BalanceUpDay
				AND b.EventType = 2
				AND o.leagueid = @LeagueId
		END
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
		WHERE EXISTS (SELECT 1 FROM @TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	-- Return result
	SELECT
		d.MatchId,
		d.EventType,
		d.HomeId,
		d.AwayId,
		d.IsNeutral,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(d.BAComm		* e.Rate) AS MONEY) AS BAComm
	FROM @Data AS d
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
	GROUP BY
		d.MatchId,
		d.EventType,
		d.HomeId,
		d.AwayId,
		d.IsNeutral
	ORDER BY d.MatchId ASC
END
GO
