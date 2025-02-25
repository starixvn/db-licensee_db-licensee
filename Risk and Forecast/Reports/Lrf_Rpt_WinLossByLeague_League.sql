/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByLeague_League]
	@AgentList		VARCHAR(MAX),
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(100)	= '',
	@SportTypeList	VARCHAR(500)	= '',
	@BetTypeList	VARCHAR(MAX)	= '',
	@LeagueName		NVARCHAR(100)	= N'',
	@SearchLanguage	VARCHAR(10)		= 'en-US',
	@StatusIdList	VARCHAR(50)		= '',
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20210916@Kos
	Task: LAP - Win Loss By League report - League level
	DB: DBEXT.bodb02

	Revisions:
		- 20210916@Kos: New SP [RedmineID: #159939]
		- 20220106@Kos: Support search by username [RedmineID: #165926]
		- 20220513@Kos: Support Sports Lottery and Bitcoin [RedmineID: #160160]
		- 20220616@Kos: Fix issue duplicate LeagueId [RedmineID: #171991]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20221207@Evan: Support Saba E-Sports PinGoal [RedmineID: #181224]
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]
		- 20230708@Evan: Support CN3, INDO & THAI language on LAP [RedmineID: #187132]
		- 20241701@Evan: Update f_GroupBettype to Lrf_f_GroupBettype [RedmineID: #199523]
		- 20240304@Evan: Integrate Saba Ice Hockey [RedmineID: #201283]
		- 20240508@Bobby: Integrate Saba Kabaddi [RedmineID: #203612]
		- 20240910@Kelvin: Integrate Odds Boost Voucher [RedmineID: #210613]
		- 20250217@Kelvin: Win Loss By League - Support Virtual Sports [RedmineID: #217407]

	Param's Explanation:
		- @SportTypeList: sporttype list separated by ','
			+ 'All': all sport types
			+ -1: Saba Soccer (SportType = 1, LeagueGroupId IN (42, 74))
			+ -2: Saba Basketball (SportType = 2, LeagueGroupId IN (42))
			+ -3: Saba Cricket (SportType = 50, LeagueGroupId IN (42))
			+ -4: Saba Futsal (SportType = 1, LeagueGroupId IN (108))
			+ -5: Saba Soccer Pingoal (SportType = 1, LeagueGroupId IN (113))
			+ -6: Saba Basketball Pingoal (SportType = 2, LeagueGroupId IN (122))
			+ -7: Saba E-Sports Pingoal (SportType = 43, LeagueGroupId IN (151))
			+ -8: Saba Virtual Tennis (SportType = 5, LeagueGroupId IN (42))
			+ -9: Saba Ice Hockey (SportType = 4, LeagueGroupId IN (42))
			+ -10: Saba Kabaddi (SportType = 47, LeagueGroupId IN (42))

		- @BetTypeList: bettype list separated by ','
			+ 'All': all bettypes
		- @SearchLanguage: search language
			+ en-US: English
			+ zh-CN: Chinese Simplified
			+ vi-VN: CN3 (Vietnamese)
			+ th-TH: Thailand
		- @StatusIdList: status ID list separated by ','
		- @Username: exact System ID or External ID
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @sql VARCHAR(MAX)= ''

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME
	SELECT @BalanceUpDay = BalanceUpDay FROM @MBBU

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

	-- Get sport/bettype matrix
	CREATE TABLE #SportBetType (BetType SMALLINT, ProductID INT, ProductCode VARCHAR(10), EventType TINYINT, GroupProductCode VARCHAR(10))

	CREATE CLUSTERED INDEX IX_SportBetType ON #SportBetType (BetType)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBetType (BetType, ProductID, ProductCode, EventType, GroupProductCode)
	SELECT DISTINCT s.BetType, s.ProductID, s.ProductPrefix, s.EventType, ISNULL(lf.GroupProductPrefix,IIF(s.ProductId IN (63,69),'SB',s.ProductPrefix)) AS GroupProductCode
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest) s
		LEFT JOIN dbo.Lrf_f_GroupProduct() lf ON s.ProductId = lf.ProductId
	WHERE BetType NOT IN (901, 902, 903, 904, 999, 997)
		AND BetType NOT BETWEEN 801 AND 806
		AND (@BetTypeList = 'All'
			OR ',' + @BetTypeList + ',' LIKE '%,' + CAST(BetType AS VARCHAR(5)) + ',%'
			OR BetType IN (SELECT Bettype FROM dbo.Lrf_f_GroupBettype() WHERE ',' + @BetTypeList + ',' LIKE '%,' + CAST(GroupTypeId AS VARCHAR(5)) + ',%'))
	
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
		WHERE BetType IN (29, 2799, 10449, 11099) -- parlay
	END

	IF @LeagueName <> ''
	BEGIN
		DELETE FROM #SportBetType
		WHERE ProductCode IN ('SLT', 'BTC')
			OR BetType IN (29, 2799, 10449, 11099) -- parlay
	END

	DECLARE @_FromDate	SMALLDATETIME,
		@_ToDate		SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	DECLARE @CutoffDate SMALLDATETIME;

	SELECT @CutoffDate = CutoffDate
	FROM dbo.Lrf_f_GetCutOffDate()
	WHERE TypeName = 'SabaTennis'
	
	-- Get league list
	CREATE TABLE #League (LeagueId INT, EventType INT, SportType SMALLINT, LeagueGroupId SMALLINT)
	CREATE TABLE #TempLeague (LeagueId INT, EventType INT)
	CREATE TABLE #TempLeague3rd (LeagueId INT, EventType INT)

	CREATE CLUSTERED INDEX IX_LeagueId ON #League (LeagueId, EventType)
	CREATE CLUSTERED INDEX IX_LeagueId ON #TempLeague (LeagueId)
	CREATE CLUSTERED INDEX IX_LeagueId ON #TempLeague3rd (LeagueId)

	IF EXISTS (SELECT TOP 1 1 FROM #SportBetType WHERE EventType = 1)
	BEGIN
		IF @ToDate > @MoveBetsDay
			INSERT INTO #TempLeague (LeagueId, EventType)
			SELECT DISTINCT leagueid, 1
			FROM dbo.match WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate

		IF @FromDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR @ToDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR (@FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay)
			INSERT INTO #TempLeague (LeagueId, EventType)
			SELECT DISTINCT leagueid, 1
			FROM dbo.match14 WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate

		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT @Sql = '
			SELECT leagueid, 1 AS EventType
			FROM OPENQUERY(DBARC,
			''
			SELECT DISTINCT leagueid
			FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
			WHERE eventdate BETWEEN ''''' + CONVERT(VARCHAR, @_FromDate, 101) + '''''  AND ''''' + CONVERT(VARCHAR, @_ToDate, 101) + '''''
			'')'
			INSERT INTO #TempLeague (LeagueId, EventType)
			EXEC (@sql)
		END
	END

	IF EXISTS (SELECT TOP 1 1 FROM #SportBetType WHERE EventType = 2)
	BEGIN
		IF @ToDate > @MoveBetsDay
			INSERT INTO #TempLeague (LeagueId, EventType)
			SELECT DISTINCT leagueid, 2
			FROM dbo.outright WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR @ToDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR (@FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay)
			INSERT INTO #TempLeague (LeagueId, EventType)
			SELECT DISTINCT leagueid, 2
			FROM dbo.outright14 WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT @Sql = '
			SELECT leagueid, 2 AS EventType
			FROM OPENQUERY(DBARC,
			''
			SELECT DISTINCT leagueid
			FROM bodb_Archive.dbo.outright_bk WITH (NOLOCK)
			WHERE eventdate BETWEEN ''''' + CONVERT(VARCHAR, @_FromDate, 101) + '''''  AND ''''' + CONVERT(VARCHAR, @_ToDate, 101) + '''''
			'')'
			INSERT INTO #TempLeague (LeagueId, EventType)
			EXEC (@sql)
		END
	END

	IF EXISTS (SELECT TOP 1 1 FROM #SportBetType WHERE EventType = 3)
	BEGIN
		IF @ToDate > @MoveBetsDay
			INSERT INTO #TempLeague3rd (LeagueId, EventType)
			SELECT DISTINCT r.LeagueID, 3
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR @ToDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR (@FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay)
			INSERT INTO #TempLeague3rd (LeagueId, EventType)
			SELECT DISTINCT r.LeagueID, 3
			FROM dbo.VSOutright14 AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT @Sql = '
			SELECT leagueid, 3 AS EventType
			FROM OPENQUERY(DBARC,
			''
			SELECT DISTINCT r.LeagueID
			FROM DBARC.bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK)
				INNER JOIN DBARC.bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.eventdate BETWEEN ''''' + CONVERT(VARCHAR, @_FromDate, 101) + '''''  AND ''''' + CONVERT(VARCHAR, @_ToDate, 101) + '''''
			'')'
			INSERT INTO #TempLeague3rd (LeagueId, EventType)
			EXEC (@sql)
		END
	END

	IF EXISTS (SELECT TOP 1 1 FROM #SportBetType WHERE EventType = 5)
	BEGIN
		IF @ToDate > @MoveBetsDay
			INSERT INTO #TempLeague3rd (LeagueId, EventType)
			SELECT DISTINCT League3rdId, 5
			FROM dbo.match3rd WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR @ToDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR (@FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay)
			INSERT INTO #TempLeague3rd (LeagueId, EventType)
			SELECT DISTINCT League3rdId, 5
			FROM dbo.match3rd14 WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT @Sql = '
			SELECT League3rdId, 5 AS EventType
			FROM OPENQUERY(DBARC,
			''
			SELECT DISTINCT League3rdId
			FROM DBARC.bodb_Archive.dbo.match3rd_bk WITH (NOLOCK)
			WHERE eventdate BETWEEN ''''' + CONVERT(VARCHAR, @_FromDate, 101) + '''''  AND ''''' + CONVERT(VARCHAR, @_ToDate, 101) + '''''
			'')'
			INSERT INTO #TempLeague3rd (LeagueId, EventType)
			EXEC (@sql)
		END
	END

	;WITH CTE_SportTypeList AS
	(
		SELECT DISTINCT SportType
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE ProductID IN (SELECT DISTINCT ProductID FROM #SportBetType)
	)
	INSERT INTO #League (
		LeagueId,
		EventType,
		SportType,
		LeagueGroupId
		)
	SELECT
		l.leagueid,
		tmp.EventType,
		l.sporttype,
		l.LeagueGroupID
	FROM dbo.League AS l WITH (NOLOCK)
	INNER JOIN #TempLeague tmp ON tmp.LeagueId = l.leagueid
	INNER JOIN CTE_SportTypeList s ON s.SportType = l.SportType
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
				AND l.LeagueGroupID IN (122))
			OR (',' + @SportTypeList + ',' LIKE '%,-7,%'
				AND l.sporttype = 43
				AND l.LeagueGroupID IN (151))
			OR (',' + @SportTypeList + ',' LIKE '%,-8,%'
				AND l.sporttype = 5
				AND l.LeagueGroupID IN (42))
			OR (',' + @SportTypeList + ',' LIKE '%,-9,%'
				AND l.sporttype = 4
				AND l.LeagueGroupID IN (42))
			OR (',' + @SportTypeList + ',' LIKE '%,-10,%'
				AND l.sporttype = 47
				AND l.LeagueGroupID IN (42))
		)
		AND (@LeagueName = '' OR CASE
									WHEN @SearchLanguage = 'zh-CN' AND ISNULL(l.leaguenamecn,'') <> '' THEN l.leaguenamecn
									WHEN @SearchLanguage = 'vi-VN' AND ISNULL(l.leaguenameVN,'') <> '' THEN l.leaguenameVN
									WHEN @SearchLanguage = 'th-TH' AND ISNULL(l.leaguenameth,'') <> '' THEN l.leaguenameth
									ELSE l.leaguename
								END LIKE '%' + @LeagueName +'%')

	;WITH CTE_SportTypeList AS
	(
		SELECT DISTINCT SportType
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE ProductID IN (SELECT DISTINCT ProductID FROM #SportBetType)
	)
	INSERT INTO #League (
		LeagueId,
		SportType,
		LeagueGroupId,
		EventType)
	SELECT
		l.League3rdId,
		l.SportType,
		0 as LeagueGroupId,
		tmp.EventType
	FROM dbo.League3rd AS l WITH (NOLOCK)
	INNER JOIN #TempLeague3rd tmp ON tmp.LeagueId = l.League3rdId
	INNER JOIN CTE_SportTypeList s ON s.SportType = l.SportType
	WHERE (@SportTypeList = 'All' OR ',' + @SportTypeList + ',' LIKE '%,' + CAST(l.sporttype AS VARCHAR(5)) + ',%')
		AND (@LeagueName = '' OR CASE
									WHEN @SearchLanguage = 'zh-CN' AND ISNULL(l.LeagueNameSC,'') <> '' THEN l.LeagueNameSC
									WHEN @SearchLanguage = 'vi-VN' AND ISNULL(l.leaguenameVN,'') <> '' THEN l.leaguenameVN
									WHEN @SearchLanguage = 'th-TH' AND ISNULL(l.leaguenameth,'') <> '' THEN l.leaguenameth
									ELSE l.leaguename
								END LIKE '%' + @LeagueName +'%')

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

		IF ',' + @SportTypeList + ',' NOT LIKE '%,43,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 43 AND LeagueGroupId NOT IN (151)
		END
		
		IF ',' + @SportTypeList + ',' NOT LIKE '%,5,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 5 AND LeagueGroupId NOT IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,4,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 4 AND LeagueGroupId NOT IN (42)
		END

		--Saba Kabaddi
		IF ',' + @SportTypeList + ',' NOT LIKE '%,47,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 47 AND LeagueGroupId NOT IN (42)
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

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-7,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 43 AND LeagueGroupId IN (151)
		END
		IF ',' + @SportTypeList + ',' NOT LIKE '%,-8,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 5 AND LeagueGroupId IN (42)
				AND 1 = CASE
							WHEN @CutoffDate > @_FromDate AND  ',' + @SportTypeList + ',' LIKE '%,5,%' THEN 0
							ELSE 1 
						END
		END
		IF ',' + @SportTypeList + ',' NOT LIKE '%,-9,%'
		BEGIN	
			DELETE FROM #League
			WHERE SportType = 4 AND LeagueGroupId IN (42)
		END

		--Saba Kabaddi
		IF ',' + @SportTypeList + ',' NOT LIKE '%,-10,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 47 AND LeagueGroupId IN (42)
		END
	END
	
	-- Insert League for Parlay
	IF @SportTypeList = 'All'
		AND @LeagueName = ''
		AND (@BetTypeList = 'All'	OR ',' + @BetTypeList + ',' LIKE '%,29,%'
									OR ',' + @BetTypeList + ',' LIKE '%,2799,%'
									OR ',' + @BetTypeList + ',' LIKE '%,10449,%'
									OR ',' + @BetTypeList + ',' LIKE '%,11099,%')
	BEGIN
		INSERT INTO #League (LeagueId, SportType, LeagueGroupId, EventType)
		SELECT -9, 0, 0, 0
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 29)
		UNION
		SELECT -2799, 0, 0, 0
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 2799)
		UNION
		SELECT -10449, 0, 0, 0
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 10449)
		UNION
		SELECT -11099, 0, 0, 0
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 11099)
	END

	-- Insert League for Sports Lottery, Bitcoin
	IF @LeagueName = ''
	BEGIN
		INSERT INTO #League (LeagueId, SportType, LeagueGroupId, EventType)
		SELECT -63, 169, 0, 0
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE ProductCode = 'SLT')
		UNION ALL
		SELECT League3rdId, 175, 0, 5
		FROM dbo.League3rd WITH (NOLOCK)
		WHERE SportType = 175
			AND EXISTS (SELECT 1 FROM #SportBetType WHERE ProductCode = 'BTC')
	END

	DECLARE @Data TABLE (
		GroupProductCode	VARCHAR(10),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		SportType			SMALLINT,
		WinLostDate			SMALLDATETIME,
		Currency			INT,
		BetCount			BIGINT,
		Turnover			MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY
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
			INSERT INTO @Data (
				GroupProductCode,
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				sbt.GroupProductCode,
				ext.LeagueId,
				ext.LeagueGroupId,
				ext.SportType,
				b.winlostdate,
				b.currency,
				COUNT(1) AS BetCount,
				SUM(CASE
						WHEN b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29, 38)
							THEN 0.5 * b.stake
						ELSE b.stake
					END) AS Turnover,
				SUM(b.winlost - b.actual_stake) AS WinLost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a
					ON a.CustId = b.recommend
				INNER JOIN #SportBetType AS sbt 
					ON sbt.BetType = b.bettype
				LEFT JOIN dbo.match AS m WITH (NOLOCK) 
					ON m.MatchId = b.matchid
				LEFT JOIN #League AS l 
					ON l.LeagueId = m.leagueid AND l.EventType = sbt.EventType
				LEFT JOIN dbo.outright o WITH(NOLOCK) 
					ON o.orid = b.matchid
				LEFT JOIN #League AS lo 
					ON lo.LeagueId = o.leagueid AND lo.EventType = sbt.EventType
				LEFT JOIN dbo.VSRaceInfo r WITH(NOLOCK) 
					ON r.EventID = b.matchid
				LEFT JOIN #League AS lr 
					ON lr.LeagueId = r.LeagueID AND lr.EventType = sbt.EventType
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK)
					ON m3rd.Match3rdId = b.matchid
				LEFT JOIN #League AS l3rd 
					ON l3rd.LeagueId = m3rd.League3rdId AND l3rd.EventType = sbt.EventType
				OUTER APPLY
				(
					SELECT 
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN -9 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
									WHEN sbt.ProductCode = 'SLT' THEN -63 --Sports Lottery
									ELSE -1
								END
							WHEN sbt.EventType = 1 THEN ISNULL(l.LeagueId, -1)
							WHEN sbt.EventType = 2 THEN ISNULL(lo.LeagueId, -1)
							WHEN sbt.EventType = 3 THEN ISNULL(lr.LeagueID, -1)
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductCode = 'BTC', -69, ISNULL(l3rd.LeagueId, -1))
						END AS LeagueId,
						CASE WHEN sbt.ProductCode = 'SB' AND sbt.EventType = 1 THEN l.LeagueGroupId
							 WHEN sbt.ProductCode = 'SB' AND sbt.EventType = 2 THEN lo.LeagueGroupId
							 ELSE 0
						END AS LeagueGroupId,
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN 0 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN 0 --parlay VS
									WHEN sbt.ProductCode = 'SLT' THEN 0 --Sports Lottery
									ELSE -1
								END
							WHEN sbt.EventType = 1 THEN ISNULL(l.SportType, -1)
							WHEN sbt.EventType = 2 THEN ISNULL(lo.SportType, -1)
							WHEN sbt.EventType = 3 THEN ISNULL(lr.SportType, -1)
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductCode = 'BTC', 0, ISNULL(l3rd.SportType, -1))
						END AS SportType
				) ext
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND ext.LeagueId <> -1
			GROUP BY
				sbt.GroupProductCode,
				ext.LeagueId,
				ext.LeagueGroupId,
				ext.SportType,
				b.winlostdate,
				b.currency
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				GroupProductCode,
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				sbt.GroupProductCode,
				ext.LeagueId,
				ext.LeagueGroupId,
				ext.SportType,
				b.winlostdate,
				b.currency,
				COUNT(1) AS BetCount,
				SUM(CASE
						WHEN sbt.ProductCode = 'SB' AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29, 38)
							THEN 0.5 * b.stake
						ELSE b.stake
					END) AS Turnover,
				SUM(b.winlost - b.actual_stake) AS WinLost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #SportBetType AS sbt 
					ON sbt.BetType = b.bettype
				LEFT JOIN dbo.match AS m WITH (NOLOCK) 
					ON m.MatchId = b.matchid
				LEFT JOIN #League AS l 
					ON l.LeagueId = m.leagueid AND l.EventType = sbt.EventType
				LEFT JOIN dbo.outright o WITH(NOLOCK) 
					ON o.orid = b.matchid
				LEFT JOIN #League AS lo 
					ON lo.LeagueId = o.leagueid AND lo.EventType = sbt.EventType
				LEFT JOIN dbo.VSRaceInfo r WITH(NOLOCK) 
					ON r.EventID = b.matchid
				LEFT JOIN #League AS lr 
					ON lr.LeagueId = r.LeagueID AND lr.EventType = sbt.EventType
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK)
					ON m3rd.Match3rdId = b.matchid
				LEFT JOIN #League AS l3rd 
					ON l3rd.LeagueId = m3rd.League3rdId AND l3rd.EventType = sbt.EventType
				OUTER APPLY
				(
					SELECT 
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN -9 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
									WHEN sbt.ProductCode = 'SLT' THEN -63 --Sports Lottery
									ELSE -1
								END
							WHEN sbt.EventType = 1 THEN ISNULL(l.LeagueId, -1)
							WHEN sbt.EventType = 2 THEN ISNULL(lo.LeagueId, -1)
							WHEN sbt.EventType = 3 THEN ISNULL(lr.LeagueID, -1)
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductCode = 'BTC', -69, ISNULL(l3rd.LeagueId, -1))
						END AS LeagueId,
						CASE WHEN sbt.ProductCode = 'SB' AND sbt.EventType = 1 THEN l.LeagueGroupId
							 WHEN sbt.ProductCode = 'SB' AND sbt.EventType = 2 THEN lo.LeagueGroupId
							 ELSE 0
						END AS LeagueGroupId,
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN 0 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN 0 --parlay VS
									WHEN sbt.ProductCode = 'SLT' THEN 0 --Sports Lottery
									ELSE -1
								END
							WHEN sbt.EventType = 1 THEN ISNULL(l.SportType, -1)
							WHEN sbt.EventType = 2 THEN ISNULL(lo.SportType, -1)
							WHEN sbt.EventType = 3 THEN ISNULL(lr.SportType, -1)
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductCode = 'BTC', 0, ISNULL(l3rd.SportType, -1))
						END AS SportType
				) ext
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND ext.LeagueId <> -1
			GROUP BY
				sbt.GroupProductCode,
				ext.LeagueId,
				ext.LeagueGroupId,
				ext.SportType,
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
				GroupProductCode,
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT b.*
			FROM
				#Date AS d
				CROSS APPLY (
					SELECT
						sbt.GroupProductCode,
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
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
						-SUM(b.winlost) AS LicenseeWL
					FROM
						bodb_LicenseeReport.dbo.rptCustomerMatch AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = b.recommend
						INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
						INNER JOIN #League AS l ON l.LeagueId = b.leagueid AND l.EventType = sbt.EventType
					WHERE
						b.winlostdate = d.Date
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
					GROUP BY
						sbt.GroupProductCode,
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
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
				GroupProductCode,
				LeagueId,
				LeagueGroupId,
				SportType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT b.*
			FROM
				#Date AS d
				CROSS APPLY (
					SELECT
						sbt.GroupProductCode,
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
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
						-SUM(b.winlost) AS LicenseeWL
					FROM
						bodb_LicenseeReport.dbo.rptCustomerMatch AS b WITH (NOLOCK)
						INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
						INNER JOIN #League AS l ON l.LeagueId = b.leagueid AND l.EventType = sbt.EventType
					WHERE
						b.winlostdate = d.Date
						AND b.custid = @CustId
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
					GROUP BY
						sbt.GroupProductCode,
						CASE
							WHEN sbt.ProductCode = 'BTC' THEN -69
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
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
		GroupProductCode ,SportType, LeagueId, BetCount, Turnover, WinLost, LicenseeWL
	FROM 
		(SELECT 
			d.GroupProductCode,
			CASE
				WHEN d.SportType = 1 AND d.LeagueGroupId IN (42, 74) THEN -1
				WHEN d.SportType = 2 AND d.LeagueGroupId IN (42) THEN -2
				WHEN d.SportType = 50 AND d.LeagueGroupId IN (42) THEN -3
				WHEN d.SportType = 1 AND d.LeagueGroupId IN (108) THEN -4
				WHEN d.SportType = 1 AND d.LeagueGroupId IN (113) THEN -5
				WHEN d.SportType = 2 AND d.LeagueGroupId IN (122) THEN -6
				WHEN d.SportType = 43 AND d.LeagueGroupId IN (151) THEN -7
				WHEN d.SportType = 5 AND d.LeagueGroupId IN (42) AND d.WinLostDate >= @CutoffDate THEN -8
				WHEN d.SportType = 4 AND d.LeagueGroupId IN (42) THEN -9
				WHEN d.SportType = 47 AND d.LeagueGroupId IN (42) THEN -10
				ELSE d.SportType
			END AS SportType,
			d.LeagueId,
			SUM(d.BetCount) AS BetCount,
			CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS Turnover,
			CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS WinLost,
			CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL
			FROM @Data AS d
			INNER JOIN @ExchangeRate AS e
				ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
					AND d.Currency = e.ExchangeId
			GROUP BY
			d.GroupProductCode,
			CASE
				WHEN d.SportType = 1 AND d.LeagueGroupId IN (42, 74) THEN -1
				WHEN d.SportType = 2 AND d.LeagueGroupId IN (42) THEN -2
				WHEN d.SportType = 50 AND d.LeagueGroupId IN (42) THEN -3
				WHEN d.SportType = 1 AND d.LeagueGroupId IN (108) THEN -4
				WHEN d.SportType = 1 AND d.LeagueGroupId IN (113) THEN -5
				WHEN d.SportType = 2 AND d.LeagueGroupId IN (122) THEN -6
				WHEN d.SportType = 43 AND d.LeagueGroupId IN (151) THEN -7
				WHEN d.SportType = 5 AND d.LeagueGroupId IN (42) AND d.WinLostDate >= @CutoffDate THEN -8
				WHEN d.SportType = 4 AND d.LeagueGroupId IN (42) THEN -9
				WHEN d.SportType = 47 AND d.LeagueGroupId IN (42) THEN -10
				ELSE d.SportType
			END,
			d.LeagueId
		) a
	WHERE 
		@SportTypeList = 'All' OR ',' + @SportTypeList + ',' LIKE '%,' + CAST(SportType AS VARCHAR(5)) + ',%'
	ORDER BY
		GroupProductCode ASC,
		SportType ASC,
		LeagueId ASC

	DROP TABLE #TempAg
	DROP TABLE #SportBetType
	DROP TABLE #League
	DROP TABLE #TempLeague
	DROP TABLE #TempLeague3rd
END
GO
