/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByLeague_League]
	@AgentList		VARCHAR(MAX),
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(100)	= '',
	@SportTypeList	VARCHAR(500)	= '',
	@BetTypeList	XML = '',
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
			-2	 :SABA Soccer	{"Sporttype":1, "LeagueGroupID": [42,74]}
			-3	 :SABA Futsal	{"Sporttype":1, "LeagueGroupID": [108]}
			-4	 :SABA Soccer PinGoal	{"Sporttype":1, "LeagueGroupID": [113]}
			-5	 :SABA Basketball	{"Sporttype":2, "LeagueGroupID": [42]}
			-6	 :SABA Basketball PinGoal	{"Sporttype":2, "LeagueGroupID": [122]}
			-7	 :SABA ESports PinGoal	{"Sporttype":43, "LeagueGroupID": [151]}
			-8	 :SABA Cricket	{"Sporttype":50, "LeagueGroupID": [42]}
			-9	 :SABA Tennis	{"Sporttype":5, "LeagueGroupID": [42]}
			-10	 :SABA Ice Hockey	{"Sporttype":4, "LeagueGroupID": [42]}
			-11	 :SABA Kabaddi	{"Sporttype":47, "LeagueGroupID": [42]}

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
	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductList, 'ALL') = 'ALL'  OR ',' + @ProductList + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2))

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #SabaSporttype (SabaSportType INT, SportType INT, LeagueGroupID INT, SportOrder INT, CutOffDate SMALLDATETIME);

	INSERT INTO #SabaSporttype (SabaSportType, SportType, LeagueGroupID, SportOrder, CutOffDate)
	SELECT saba.SabaSportType, t.SportType, t.LeagueGroupID, saba.SportOrder, saba.CutOffDate
	FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
	OUTER APPLY
	(
		SELECT Sporttype, LeagueGroupID
		FROM OPENJSON(saba.SporttypeRef)
		WITH (Sporttype INT '$.Sporttype', 
			LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
		)
		OUTER APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID INT '$')
	) AS t
	WHERE saba.IsShowUI = 1


	CREATE TABLE #BetTypeSel (ProductCode VARCHAR(10), Bettype INT, ProductId INT);
	--Bettype selection
	;WITH BettypeSel AS (
		SELECT t.c.value('@pc', 'VARCHAR(10)') AS ProductCode
			,t.c.value('@bt', 'VARCHAR(MAX)') AS Bettype
		FROM @BetTypeList.nodes('/ROOT/Bettype') AS t(c)
		)
	INSERT INTO #BetTypeSel(ProductCode, Bettype)
	SELECT a.ProductCode, b.value
	FROM BettypeSel a
	CROSS APPLY (
		SELECT value FROM STRING_SPLIT (a.Bettype,',') 
	) b;

	UPDATE a
	SET a.ProductId = IIF(a.ProductCode = 'VS', 5, t.ProductId)
	FROM #BetTypeSel a
		CROSS APPLY (
			SELECT TOP 1 p.ProductID AS ProductID
			FROM SportBettypeMatrix p WITH (NOLOCK)
			WHERE p.BetType = a.Bettype
		) AS t

	DECLARE @BettypeIdsCheck VARCHAR(MAX)
			,@SportTypeCheck VARCHAR(500)

	--Bettype, SportType filtering
	SELECT @BettypeIdsCheck = STRING_AGG(CAST(BetType AS VARCHAR(MAX)), ',')
	FROM (SELECT DISTINCT bettype FROM #BetTypeSel) a

	SELECT @SportTypeCheck = IIF(@SportTypeList='ALL', NULL, @SportTypeList)

	CREATE TABLE #SportBetType (BetType SMALLINT, ProductID INT, EventType TINYINT, GroupProductCode VARCHAR(10))
	CREATE CLUSTERED INDEX IX_SportBetType ON #SportBetType (BetType)

	INSERT INTO #SportBetType (BetType, ProductID, EventType, GroupProductCode)
	SELECT bm.Bettype, bm.ProductId, bm.EventType
		,CASE WHEN bm.ProductId IN (63, 69) THEN 'SB' ELSE p.ProductPrefix END AS GroupProductCode
	FROM bodb02.dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductList, @SportTypeCheck, @BettypeIdsCheck, @SBBACheck) AS bm
		INNER JOIN bodb02.dbo.Products AS p WITH(NOLOCK) ON p.ProductID = bm.ProductId
	WHERE @BettypeIdsCheck IS NULL OR EXISTS (SELECT 1 FROM #BetTypeSel bts WHERE bts.ProductId = bm.ProductId AND bts.Bettype = ISNULL(bm.GroupTypeId,bm.Bettype))
		AND BetType NOT IN (901, 902, 903, 904)
		AND BetType NOT BETWEEN 801 AND 806

	IF @SportTypeCheck IS NOT NULL
	BEGIN
		DELETE FROM #SportBetType 
		WHERE BetType IN (29, 2799, 10449, 11099)
	END

	IF @LeagueName <> ''
	BEGIN
		DELETE FROM #SportBetType
		WHERE BetType IN (29, 2799, 10449, 11099)
			OR ProductID IN (63, 69) --SLT, BTC
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

	CREATE CLUSTERED INDEX IX_LeagueId ON #League (LeagueId, EventType)
	CREATE CLUSTERED INDEX IX_LeagueId ON #TempLeague (LeagueId, EventType)

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
			INSERT INTO #TempLeague (LeagueId, EventType)
			SELECT DISTINCT r.LeagueID, 3
			FROM dbo.VSOutright AS o WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE o.EventDate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR @ToDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR (@FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay)
			INSERT INTO #TempLeague (LeagueId, EventType)
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
			INSERT INTO #TempLeague (LeagueId, EventType)
			EXEC (@sql)
		END
	END

	IF EXISTS (SELECT TOP 1 1 FROM #SportBetType WHERE EventType = 5)
	BEGIN
		IF @ToDate > @MoveBetsDay
			INSERT INTO #TempLeague (LeagueId, EventType)
			SELECT DISTINCT League3rdId, 5
			FROM dbo.match3rd WITH (NOLOCK) WHERE eventdate BETWEEN @_FromDate AND @_ToDate
		
		IF @FromDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR @ToDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			OR (@FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay)
			INSERT INTO #TempLeague (LeagueId, EventType)
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
			INSERT INTO #TempLeague (LeagueId, EventType)
			EXEC (@sql)
		END
	END

	;WITH CTE_SportTypeList AS
	(
		SELECT DISTINCT SportType
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE BetType IN (SELECT BetType FROM #SportBetType)
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
	INNER JOIN #TempLeague tmp ON tmp.LeagueId = l.leagueid AND tmp.EventType IN (1,2)
	INNER JOIN CTE_SportTypeList s ON s.SportType = l.sporttype
	WHERE (@LeagueName = '' OR CASE
									WHEN @SearchLanguage = 'zh-CN' AND ISNULL(l.leaguenamecn,'') <> '' THEN l.leaguenamecn
									WHEN @SearchLanguage = 'vi-VN' AND ISNULL(l.leaguenameVN,'') <> '' THEN l.leaguenameVN
									WHEN @SearchLanguage = 'th-TH' AND ISNULL(l.leaguenameth,'') <> '' THEN l.leaguenameth
									ELSE l.leaguename
								END LIKE '%' + @LeagueName +'%')
	
	;WITH CTE_SportTypeList AS
	(
		SELECT DISTINCT SportType
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE BetType IN (SELECT BetType FROM #SportBetType)
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
	INNER JOIN #TempLeague tmp ON tmp.LeagueId = l.League3rdId AND tmp.EventType IN (3,5)
	WHERE (@LeagueName = '' OR CASE
									WHEN @SearchLanguage = 'zh-CN' AND ISNULL(l.LeagueNameSC,'') <> '' THEN l.LeagueNameSC
									WHEN @SearchLanguage = 'vi-VN' AND ISNULL(l.leaguenameVN,'') <> '' THEN l.leaguenameVN
									WHEN @SearchLanguage = 'th-TH' AND ISNULL(l.leaguenameth,'') <> '' THEN l.leaguenameth
									ELSE l.leaguename
								END LIKE '%' + @LeagueName +'%')
	
	IF @SportTypeCheck IS NOT NULL
	BEGIN
		DELETE l
		FROM #League l
		INNER JOIN #SabaSporttype saba ON saba.SportType = l.SportType AND saba.LeagueGroupID = l.LeagueGroupId
		WHERE l.EventType IN (1,2)
			AND ',' + @SportTypeCheck + ',' NOT LIKE '%,' + CAST(saba.SabaSportType AS varchar(10)) + ',%'
	END

	IF @LeagueName = ''
	BEGIN
		IF @SportTypeCheck IS NULL
		BEGIN
			-- Insert League for Parlay
			INSERT INTO #League (LeagueId, SportType, LeagueGroupId, EventType)
			SELECT -9, 0, 0, 0
			WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = 29)
			UNION
			SELECT -t.BetType, 0, 0, 0
			FROM (VALUES (2799),(10449),(11099)) t(BetType)
			WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE BetType = t.BetType)
		END

		-- Insert League for Sports Lottery, Bitcoin
		INSERT INTO #League (LeagueId, SportType, LeagueGroupId, EventType)
		SELECT -63, 169, 0, 0 -- Sports Lottery
		WHERE EXISTS (SELECT 1 FROM #SportBetType WHERE ProductID = 63)
		UNION ALL
		SELECT League3rdId, 175, 0, 5 -- Bitcoin
		FROM dbo.League3rd WITH (NOLOCK)
		WHERE SportType = 175
			AND EXISTS (SELECT 1 FROM #SportBetType WHERE ProductID = 69)
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
						WHEN sbt.ProductID = 1 AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29, 38)
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
				LEFT JOIN #SabaSporttype saba
					ON sbt.ProductID = 1 AND saba.Sporttype = l.Sporttype AND saba.LeagueGroupID = l.LeagueGroupID
				OUTER APPLY
				(
					SELECT 
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN -9 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
									WHEN sbt.ProductID = 63 THEN -63 --Sports Lottery
									ELSE -1
								END
							WHEN sbt.EventType = 1 THEN ISNULL(l.LeagueId, -1)
							WHEN sbt.EventType = 2 THEN ISNULL(lo.LeagueId, -1)
							WHEN sbt.EventType = 3 THEN ISNULL(lr.LeagueID, -1)
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductID = 69, -69, ISNULL(l3rd.LeagueId, -1))
							ELSE - 1
						END AS LeagueId,
						CASE WHEN sbt.ProductID = 1 AND sbt.EventType = 1 THEN l.LeagueGroupId
							 WHEN sbt.ProductID = 1 AND sbt.EventType = 2 THEN lo.LeagueGroupId
							 ELSE 0
						END AS LeagueGroupId,
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN 0 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN 0 --parlay VS
									WHEN sbt.ProductID = 63 THEN 0 --Sports Lottery
									ELSE NULL
								END
							WHEN sbt.EventType = 1 THEN ISNULL(saba.SabaSportType,l.SportType)
							WHEN sbt.EventType = 2 THEN lo.SportType
							WHEN sbt.EventType = 3 THEN lr.SportType
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductID = 69, 0, l3rd.SportType)
							ELSE NULL
						END AS SportType
				) ext
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (ext.SportType IS NOT NULL AND (@SportTypeCheck IS NULL OR  ',' + @SportTypeCheck + ',' LIKE '%,' + CAST(ext.SportType AS VARCHAR(10)) + ',%'))
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
						WHEN sbt.ProductID = 1 AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29, 38)
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
				LEFT JOIN #SabaSporttype saba
					ON sbt.ProductID = 1 AND saba.Sporttype = l.Sporttype AND saba.LeagueGroupID = l.LeagueGroupID
				OUTER APPLY
				(
					SELECT 
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN -9 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
									WHEN sbt.ProductID = 63 THEN -63 --Sports Lottery
									ELSE -1
								END
							WHEN sbt.EventType = 1 THEN ISNULL(l.LeagueId, -1)
							WHEN sbt.EventType = 2 THEN ISNULL(lo.LeagueId, -1)
							WHEN sbt.EventType = 3 THEN ISNULL(lr.LeagueID, -1)
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductID = 69, -69, ISNULL(l3rd.LeagueId, -1))
							ELSE - 1
						END AS LeagueId,
						CASE WHEN sbt.ProductID = 1 AND sbt.EventType = 1 THEN l.LeagueGroupId
							 WHEN sbt.ProductID = 1 AND sbt.EventType = 2 THEN lo.LeagueGroupId
							 ELSE 0
						END AS LeagueGroupId,
						CASE WHEN sbt.EventType = 0 THEN
								CASE
									WHEN b.bettype = 29 THEN 0 --parlay SB
									WHEN b.bettype IN (2799, 10449, 11099) THEN 0 --parlay VS
									WHEN sbt.ProductID = 63 THEN 0 --Sports Lottery
									ELSE NULL
								END
							WHEN sbt.EventType = 1 THEN ISNULL(saba.SabaSportType,l.SportType)
							WHEN sbt.EventType = 2 THEN lo.SportType
							WHEN sbt.EventType = 3 THEN lr.SportType
							WHEN sbt.EventType = 5 THEN IIF(sbt.ProductID = 69, 0, l3rd.SportType)
							ELSE NULL
						END AS SportType
				) ext
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (ext.SportType IS NOT NULL AND (@SportTypeCheck IS NULL OR  ',' + @SportTypeCheck + ',' LIKE '%,' + CAST(ext.SportType AS VARCHAR(10)) + ',%'))
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
							WHEN sbt.ProductID = 69 THEN -69 --BTC
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
							ELSE b.leagueid
						END AS LeagueId,
						l.LeagueGroupId,
						ISNULL(saba.SportType, l.SportType) AS SportType,
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
						LEFT JOIN #SabaSporttype saba ON sbt.ProductID =1 AND saba.Sporttype = l.Sporttype AND saba.LeagueGroupID = l.LeagueGroupId AND b.winlostdate >= ISNULL(saba.CutOffDate,b.winlostdate)
					WHERE
						b.winlostdate = d.Date
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND (l.SportType IS NOT NULL AND (@SportTypeCheck IS NULL OR  ',' + @SportTypeCheck + ',' LIKE '%,' + CAST(ISNULL(saba.SabaSportType, l.Sporttype) AS VARCHAR(10)) + ',%'))
					GROUP BY
						sbt.GroupProductCode,
						CASE
							WHEN sbt.ProductID = 69 THEN -69 --BTC
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
							ELSE b.leagueid
						END,
						l.LeagueGroupId,
						ISNULL(saba.SportType, l.SportType),
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
							WHEN sbt.ProductID = 69 THEN -69 --BTC
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
							ELSE b.leagueid
						END AS LeagueId,
						l.LeagueGroupId,
						ISNULL(saba.SportType, l.SportType) AS SportType,
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
						LEFT JOIN #SabaSporttype saba ON sbt.ProductID =1 AND saba.Sporttype = l.Sporttype AND saba.LeagueGroupID = l.LeagueGroupId AND b.winlostdate >= ISNULL(saba.CutOffDate,b.winlostdate)
					WHERE
						b.winlostdate = d.Date
						AND b.custid = @CustId
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND (l.SportType IS NOT NULL AND (@SportTypeCheck IS NULL OR  ',' + @SportTypeCheck + ',' LIKE '%,' + CAST(ISNULL(saba.SabaSportType, l.Sporttype) AS VARCHAR(10)) + ',%'))
					GROUP BY
						sbt.GroupProductCode,
						CASE
							WHEN sbt.ProductID = 69 THEN -69 --BTC
							WHEN b.bettype IN (2799, 10449, 11099) THEN -5 --parlay VS
							ELSE b.leagueid
						END,
						l.LeagueGroupId,
						ISNULL(saba.SportType, l.SportType),
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
			d.SportType,
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
			d.SportType,
			d.LeagueId
		) a
	ORDER BY
		GroupProductCode ASC,
		SportType ASC,
		LeagueId ASC

	DROP TABLE IF EXISTS #TempAg
	DROP TABLE IF EXISTS #SportBetType
	DROP TABLE IF EXISTS #League
	DROP TABLE IF EXISTS #TempLeague
	DROP TABLE IF EXISTS #BetTypeSel
	DROP TABLE IF EXISTS #SabaSporttype
END
GO
