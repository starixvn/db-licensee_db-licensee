/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByLeague_League]
	@AgentList		VARCHAR(MAX),
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(100)	= '',
	@ShowBA			BIT				= 0,
	@SportTypeList	VARCHAR(500)	= '',
	@BetTypeList	VARCHAR(MAX)	= '',
	@LeagueName		NVARCHAR(100)	= N'',
	@SearchLanguage	VARCHAR(10)		= 'en-US',
	@StatusIdList	VARCHAR(50)		= '',
	@BaseCurrency	VARCHAR(3)		= ''
AS

/*
	Created: 20210916@Kos
	Task: LAP - Win Loss By League report - League level
	DB: DBEXT.bodb02

	Revisions:
		- 20210916@Kos: New SP [RedmineID: #159939]
		- 20220106@Kos: Support search by username [RedmineID: #165926]
		- 20220513@Kos: Support Sports Lottery and Bitcoin [RedmineID: #160160]

	Param's Explanation:
		- @SportTypeList: sporttype list separated by ','
			+ 'All': all sport types
			+ -1: Saba Soccer (SportType = 1, LeagueGroupId IN (42, 74))
			+ -2: Saba Basketball (SportType = 2, LeagueGroupId IN (42))
			+ -3: Saba Cricket (SportType = 50, LeagueGroupId IN (42))
			+ -4: Saba Futsal (SportType = 1, LeagueGroupId IN (108))
			+ -5: Saba Soccer Pingoal (SportType = 1, LeagueGroupId IN (113))
			+ -6: Saba Basketball Pingoal (SportType = 2, LeagueGroupId IN (122))
		- @BetTypeList: bettype list separated by ','
			+ 'All': all bettypes
		- @SearchLanguage: search language
			+ en-US: English
			+ zh-CN: Chinese Simplified
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

	DECLARE @ShowSB	BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	-- Get sport/bettype matrix
	CREATE TABLE #SportBetType (BetType SMALLINT, ProductCode VARCHAR(10), EventType TINYINT)

	CREATE CLUSTERED INDEX IX_SportBetType ON #SportBetType (BetType)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 999)
		AND BetType NOT BETWEEN 801 AND 806
		AND (@BetTypeList = 'All'
			OR ',' + @BetTypeList + ',' LIKE '%,' + CAST(BetType AS VARCHAR(5)) + ',%'
			OR BetType IN (SELECT Bettype FROM dbo.f_GroupBettype() WHERE ',' + @BetTypeList + ',' LIKE '%,' + CAST(GroupTypeId AS VARCHAR(5)) + ',%'))

	IF @SportTypeList <> 'All'
	BEGIN
		IF ',' + @SportTypeList + ',' NOT LIKE '%,169,%'		-- Sports Lottery
		BEGIN
			DELETE FROM #SportBetType
			WHERE ProductCode = 'SLT'
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,175,%'		-- Bitcoin
		BEGIN
			DELETE FROM #SportBetType
			WHERE ProductCode = 'BTC'
		END

		DELETE FROM #SportBetType
		WHERE BetType = 29
	END

	IF @LeagueName <> ''
	BEGIN
		DELETE FROM #SportBetType
		WHERE ProductCode IN ('SLT', 'BTC')
			OR BetType = 29
	END

	DECLARE @_FromDate	SMALLDATETIME,
		@_ToDate		SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	-- Get league list
	CREATE TABLE #League (LeagueId INT PRIMARY KEY, SportType SMALLINT, LeagueGroupId SMALLINT)
	CREATE TABLE #TempLeague (LeagueId INT PRIMARY KEY)

	INSERT INTO #TempLeague
	SELECT DISTINCT leagueid
	FROM dbo.match WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM dbo.match14 WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM dbo.outright WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM dbo.outright14 WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM DBARC.bodb_Archive.dbo.outright_bk WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate

	INSERT INTO #League (
		LeagueId,
		SportType, 
		LeagueGroupId )
	SELECT
		l.leagueid,
		l.sporttype,
		l.LeagueGroupID
	FROM dbo.League AS l WITH (NOLOCK)
	WHERE (@SportTypeList = 'All'
			OR ',' + @SportTypeList + ',' LIKE '%,' + CAST(l.sporttype AS VARCHAR(5)) + ',%'
			OR (',' + @SportTypeList + ',' LIKE '%,-1,%'
				AND l.sporttype = 1
				AND l.LeagueGroupID IN (42, 74))
			OR (',' + @SportTypeList + ',' LIKE '%,-2,%'
				AND l.sporttype = 2
				AND l.LeagueGroupID IN (42))
			OR (',' + @SportTypeList + ',' LIKE '%,-3,%'
				AND l.sporttype = 50
				AND l.LeagueGroupID IN (42))
			OR (',' + @SportTypeList + ',' LIKE '%,-4,%'
				AND l.sporttype = 1
				AND l.LeagueGroupID IN (108))
			OR (',' + @SportTypeList + ',' LIKE '%,-5,%'
				AND l.sporttype = 1
				AND l.LeagueGroupID IN (113))
			OR (',' + @SportTypeList + ',' LIKE '%,-6,%'
				AND l.sporttype = 2
				AND l.LeagueGroupID IN (122)))
		AND (@LeagueName = '' OR CASE
									WHEN @SearchLanguage = 'zh-CN' THEN l.leaguenamecn
									ELSE l.leaguename
								END LIKE '%' + @LeagueName +'%')
		AND l.sporttype IN (SELECT SportType FROM dbo.SportBettypeMatrix WITH (NOLOCK) WHERE ProductID = 1)
		AND EXISTS (SELECT 1 FROM #TempLeague WHERE leagueid = l.leagueid)

	IF @SportTypeList <> 'All'
	BEGIN
		IF ',' + @SportTypeList + ',' NOT LIKE '%,1,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId NOT IN (42, 74, 108, 113)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,2,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 2 AND LeagueGroupId NOT IN (42, 122)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,50,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 50 AND LeagueGroupId NOT IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-1,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId IN (42, 74)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-2,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 2 AND LeagueGroupId IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-3,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 50 AND LeagueGroupId IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-4,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId IN (108)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-5,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId IN (113)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-6,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 2 AND LeagueGroupId IN (122)
		END
	END

	-- Insert League for Parlay
	IF @SportTypeList = 'All'
		AND @LeagueName = ''
		AND (@BetTypeList = 'All' OR ',' + @BetTypeList + ',' LIKE '%,29,%')
	BEGIN
		INSERT INTO #League (LeagueId, SportType, LeagueGroupId)
		SELECT -9, 0, 0
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 29)
	END

	-- Insert League for Sports Lottery, Bitcoin
	IF @LeagueName = ''
	BEGIN
		INSERT INTO #League (LeagueId, SportType, LeagueGroupId)
		SELECT -63, 169, 0
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE ProductCode = 'SLT')
		UNION ALL
		SELECT League3rdId, 175, 0
		FROM dbo.League3rd WITH (NOLOCK)
		WHERE SportType = 175
			AND EXISTS (SELECT 1 FROM #SportBetType WHERE ProductCode = 'BTC')
	END

	DECLARE @Data TABLE (
		LeagueId		INT,
		LeagueGroupId	SMALLINT,
		SportType		SMALLINT,
		WinLostDate		SMALLDATETIME,
		Currency		INT,
		BetCount		BIGINT,
		Turnover		MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		BAComm			MONEY
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

		IF @CustId = -1		-- Licensee level
		BEGIN
			-- Sportsbook (EventType = 1)
			INSERT INTO @Data (
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				l.LeagueId,
				l.LeagueGroupId,
				l.SportType,
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
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
				INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
				INNER JOIN #League AS l ON l.LeagueId = m.leagueid
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND sbt.ProductCode = 'SB'
				AND sbt.EventType = 1
				AND 1 = CASE
							WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
							WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
							ELSE 1
						END
			GROUP BY
				l.LeagueId,
				l.LeagueGroupId,
				l.SportType,
				b.winlostdate,
				b.currency

			-- Outright
			IF EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 10)
			BEGIN
				INSERT INTO @Data (
					LeagueId,
					LeagueGroupId,
					SportType,
					WinLostDate,
					Currency,
					BetCount,
					Turnover,
					WinLost,
					LicenseeWL,
					BAComm )
				SELECT
					l.LeagueId,
					l.LeagueGroupId,
					l.SportType,
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
					INNER JOIN #TempAg AS a ON a.CustId = b.recommend
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid
					INNER JOIN #League AS l ON l.LeagueId = o.leagueid
				WHERE
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
					AND b.bettype = 10
					AND 1 = CASE
								WHEN @ShowBA = 0 AND b.tpositiontaking = 0 THEN 0
								WHEN @ShowSB = 0 AND b.tpositiontaking <> 0 THEN 0
								ELSE 1
							END
				GROUP BY
					l.LeagueId,
					l.LeagueGroupId,
					l.SportType,
					b.winlostdate,
					b.currency
			END

			-- Parlay, Sports Lottery, Bitcoin
			INSERT INTO @Data (
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				CASE
					WHEN sbt.ProductCode = 'SB' THEN -9
					WHEN sbt.ProductCode = 'SLT' THEN -63
					WHEN sbt.ProductCode = 'BTC' THEN -69
					ELSE 0
				END AS LeagueId,
				0 AS LeagueGroupId,
				0 AS SportType,
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
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
				INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (sbt.ProductCode IN ('SLT', 'BTC')
					OR (sbt.ProductCode = 'SB' AND sbt.EventType = 0))
				AND 1 = CASE
							WHEN sbt.ProductCode = 'SB' AND @ShowBA = 0 AND b.tpositiontaking = 0 THEN 0
							WHEN sbt.ProductCode = 'SB' AND @ShowSB = 0 AND b.tpositiontaking <> 0 THEN 0
							ELSE 1
						END
			GROUP BY
				sbt.ProductCode,
				b.winlostdate,
				b.currency
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			-- Sportsbook (EventType = 1)
			INSERT INTO @Data (
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				l.LeagueId,
				l.LeagueGroupId,
				l.SportType,
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
				INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
				INNER JOIN #League AS l ON l.LeagueId = m.leagueid
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (sbt.ProductCode IN ('SLT', 'BTC')
					OR (sbt.ProductCode = 'SB' AND sbt.EventType = 0))
				AND 1 = CASE
							WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
							WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
							ELSE 1
						END
			GROUP BY
				l.LeagueId,
				l.LeagueGroupId,
				l.SportType,
				b.winlostdate,
				b.currency

			-- Outright
			IF EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 10)
			BEGIN
				INSERT INTO @Data (
					LeagueId,
					LeagueGroupId,
					SportType,
					WinLostDate,
					Currency,
					BetCount,
					Turnover,
					WinLost,
					LicenseeWL,
					BAComm )
				SELECT
					l.LeagueId,
					l.LeagueGroupId,
					l.SportType,
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
					INNER JOIN #League AS l ON l.LeagueId = o.leagueid
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
				GROUP BY
					l.LeagueId,
					l.LeagueGroupId,
					l.SportType,
					b.winlostdate,
					b.currency
			END

			-- Parlay, Sports Lottery, Bitcoin
			INSERT INTO @Data (
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				CASE
					WHEN sbt.ProductCode = 'SB' THEN -9
					WHEN sbt.ProductCode = 'SLT' THEN -63
					WHEN sbt.ProductCode = 'BTC' THEN -69
					ELSE 0
				END AS LeagueId,
				0 AS LeagueGroupId,
				0 AS SportType,
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
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.custid = @CustId
				AND (sbt.ProductCode IN ('SLT', 'BTC')
					OR (sbt.ProductCode = 'SB' AND sbt.EventType = 0))
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND 1 = CASE
							WHEN sbt.ProductCode = 'SB' AND @ShowBA = 0 AND b.tpositiontaking = 0 THEN 0
							WHEN sbt.ProductCode = 'SB' AND @ShowSB = 0 AND b.tpositiontaking <> 0 THEN 0
							ELSE 1
						END
			GROUP BY
				sbt.ProductCode,
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
				LeagueId,
				LeagueGroupId,
				SportType,
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
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							ELSE b.leagueid
						END AS LeagueId,
						l.LeagueGroupId,
						l.SportType,
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
						bodb_LicenseeReport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = b.recommend
						INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
						INNER JOIN #League AS l ON l.LeagueId = b.leagueid
					WHERE
						b.winlostdate = d.Date
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND 1 = CASE
									WHEN sbt.ProductCode = 'SB' AND @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
									WHEN sbt.ProductCode = 'SB' AND @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
									ELSE 1
								END
					GROUP BY
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							ELSE b.leagueid
						END,
						l.LeagueGroupId,
						l.SportType,
						b.winlostdate,
						b.currency
				) AS b
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				LeagueId,
				LeagueGroupId,
				SportType,
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
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							ELSE b.leagueid
						END AS LeagueId,
						l.LeagueGroupId,
						l.SportType,
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
						INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
						INNER JOIN #League AS l ON l.LeagueId = b.leagueid
					WHERE
						b.winlostdate = d.Date
						AND b.custid = @CustId
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND 1 = CASE
									WHEN sbt.ProductCode = 'SB' AND @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
									WHEN sbt.ProductCode = 'SB' AND @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
									ELSE 1
								END
					GROUP BY
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							ELSE b.leagueid
						END,
						l.LeagueGroupId,
						l.SportType,
						b.winlostdate,
						b.currency
				) AS b
		END

		DROP TABLE #Date
	END

	-- Get exchange rate
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
		FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, '') e
		WHERE EXISTS (SELECT 1 FROM #TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	-- Return result
	SELECT
		CASE
			WHEN d.SportType = 1 AND d.LeagueGroupId IN (42, 74) THEN -1
			WHEN d.SportType = 2 AND d.LeagueGroupId IN (42) THEN -2
			WHEN d.SportType = 50 AND d.LeagueGroupId IN (42) THEN -3
			WHEN d.SportType = 1 AND d.LeagueGroupId IN (108) THEN -4
			WHEN d.SportType = 1 AND d.LeagueGroupId IN (113) THEN -5
			WHEN d.SportType = 2 AND d.LeagueGroupId IN (122) THEN -6
			ELSE d.SportType
		END AS SportType,
		d.LeagueId,
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
		CASE
			WHEN d.SportType = 1 AND d.LeagueGroupId IN (42, 74) THEN -1
			WHEN d.SportType = 2 AND d.LeagueGroupId IN (42) THEN -2
			WHEN d.SportType = 50 AND d.LeagueGroupId IN (42) THEN -3
			WHEN d.SportType = 1 AND d.LeagueGroupId IN (108) THEN -4
			WHEN d.SportType = 1 AND d.LeagueGroupId IN (113) THEN -5
			WHEN d.SportType = 2 AND d.LeagueGroupId IN (122) THEN -6
			ELSE d.SportType
		END,
		d.LeagueId
	ORDER BY
		SportType ASC,
		d.LeagueId ASC

	DROP TABLE #TempAg
	DROP TABLE #SportBetType
	DROP TABLE #League
	DROP TABLE #TempLeague
END
GO
