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
	@BetTypeList	XML	= '',
	@StatusIdList	VARCHAR(50)		= '',
	@BaseCurrency	VARCHAR(12)		= '',
	@SportType		SMALLINT = NULL
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
		- 20240910@Kelvin: Integrate Odds Boost Voucher [RedmineID: #210613]
		- 20240830@Lewis: BaseBallAIO - phase 2 [RedmineID: #209344]
		- 20250217@Kelvin: Win Loss By League - Support Virtual Sports [RedmineID: #217407]

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

	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductList, 'ALL') = 'ALL'  OR ',' + @ProductList + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2))

	-- Get sport/bettype matrix
	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

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

	SELECT @SportTypeCheck = CAST(@SportType AS VARCHAR(10))

	CREATE TABLE #SportBetType (BetType SMALLINT, ProductID INT, EventType TINYINT)
	CREATE CLUSTERED INDEX IX_SportBetType ON #SportBetType (BetType)

	INSERT INTO #SportBetType (BetType, ProductID, EventType)
	SELECT bm.Bettype, bm.ProductId, bm.EventType
	FROM bodb02.dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductList, @SportTypeCheck, @BettypeIdsCheck, @SBBACheck) AS bm
	WHERE @BettypeIdsCheck IS NULL OR EXISTS (SELECT 1 FROM #BetTypeSel bts WHERE bts.ProductId = bm.ProductId AND bts.Bettype = ISNULL(bm.GroupTypeId,bm.Bettype))
		AND BetType NOT IN (901, 902, 903, 904)
		AND BetType NOT BETWEEN 801 AND 806

	DECLARE @Data TABLE (
		MatchId			INT,
		EventType		TINYINT,
		HomeId			INT,
		AwayId			INT,
		IsNeutral		BIT,
		VendorMatchId	VARCHAR(50),
		Distance		VARCHAR(50),
		WinLostDate		SMALLDATETIME,
		Currency		INT,
		BetCount		BIGINT,
		Turnover		MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY
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
			INSERT INTO @Data (
				MatchId,
				EventType,
				HomeId,
				AwayId,
				IsNeutral,
				VendorMatchId,
				Distance,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				ext.MatchId,
				sbt.EventType,
				ext.HomeId,
				ext.AwayId,
				ext.IsNeutral,
				ext.VendorMatchId,
				ext.Distance,
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
				INNER JOIN @TempAg AS a ON a.CustId = b.recommend
				INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.matchid
				LEFT JOIN dbo.outright o WITH(NOLOCK) ON o.orid = b.matchid
				LEFT JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON r.EventID = b.matchid
				OUTER APPLY
				(
					SELECT 
						CASE WHEN sbt.EventType = 1 THEN ISNULL(m.leagueid,-1)
							 WHEN sbt.EventType = 2 THEN ISNULL(o.leagueid,-1)
							 WHEN sbt.EventType = 3 THEN ISNULL(r.leagueid,-1)
							 WHEN sbt.EventType = 5 THEN ISNULL(m3rd.League3rdId,-1)
							 ELSE -1
						END AS LeagueId,
						CASE WHEN sbt.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID
							ELSE b.matchid
						END AS MatchId,
						CASE WHEN sbt.EventType = 1 THEN m.homeid
							 WHEN sbt.EventType = 2 THEN o.teamid
							 WHEN sbt.EventType = 5 THEN m3rd.HomeId
							 ELSE 0
						END AS HomeId,
						CASE WHEN sbt.EventType = 1 THEN m.awayid
							 WHEN sbt.EventType = 5 THEN m3rd.AwayId
							 ELSE 0
						END AS AwayId,
						IIF(sbt.EventType = 1, m.IsNeutral, 0) AS IsNeutral,
						IIF(sbt.EventType = 3, r.VendorMatchId, '') AS VendorMatchId,
						IIF(sbt.EventType = 3, r.Distance, '') AS Distance
				) ext
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND ext.LeagueId = @LeagueId
			GROUP BY
				ext.MatchId,
				sbt.EventType,
				ext.HomeId,
				ext.AwayId,
				ext.IsNeutral,
				ext.VendorMatchId,
				ext.Distance,
				b.winlostdate,
				b.currency
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				MatchId,
				EventType,
				HomeId,
				AwayId,
				IsNeutral,
				VendorMatchId,
				Distance,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				ext.MatchId,
				sbt.EventType,
				ext.HomeId,
				ext.AwayId,
				ext.IsNeutral,
				ext.VendorMatchId,
				ext.Distance,
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
				INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.matchid
				LEFT JOIN dbo.outright o WITH(NOLOCK) ON o.orid = b.matchid
				LEFT JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON r.EventID = b.matchid
				OUTER APPLY
				(
					SELECT 
						CASE WHEN sbt.EventType = 1 THEN ISNULL(m.leagueid,-1)
							 WHEN sbt.EventType = 2 THEN ISNULL(o.leagueid,-1)
							 WHEN sbt.EventType = 3 THEN ISNULL(r.leagueid,-1)
							 WHEN sbt.EventType = 5 THEN ISNULL(m3rd.League3rdId,-1)
							 ELSE -1
						END AS LeagueId,
						CASE WHEN sbt.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID
							ELSE b.matchid
						END AS MatchId,
						CASE WHEN sbt.EventType = 1 THEN m.homeid
							 WHEN sbt.EventType = 2 THEN o.teamid
							 WHEN sbt.EventType = 5 THEN m3rd.HomeId
							 ELSE 0
						END AS HomeId,
						CASE WHEN sbt.EventType = 1 THEN m.awayid
							 WHEN sbt.EventType = 5 THEN m3rd.AwayId
							 ELSE 0
						END AS AwayId,
						IIF(sbt.EventType = 1, m.IsNeutral, 0) AS IsNeutral,
						IIF(sbt.EventType = 3, r.VendorMatchId, '') AS VendorMatchId,
						IIF(sbt.EventType = 3, r.Distance, '') AS Distance
				) ext
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND ext.LeagueId = @LeagueId
			GROUP BY
				ext.MatchId,
				sbt.EventType,
				ext.HomeId,
				ext.AwayId,
				ext.IsNeutral,
				ext.VendorMatchId,
				ext.Distance,
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
				LicenseeWL
				)
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
						-SUM(b.winlost) AS LicenseeWL
					FROM
						bodb_licenseereport.dbo.rptCustomerMatch AS b WITH (NOLOCK)
						INNER JOIN @TempAg AS a ON a.CustId = b.recommend
						INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
					WHERE
						b.winlostdate = d.Date
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND b.leagueid = @LeagueId
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
				LicenseeWL
				)
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
						-SUM(b.winlost) AS LicenseeWL
					FROM
						bodb_licenseereport.dbo.rptCustomerMatch AS b WITH (NOLOCK)
							INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
					WHERE
						b.winlostdate = d.Date
						AND b.custid = @CustId
						AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
						AND b.leagueid = @LeagueId
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
			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 1)
			BEGIN
				UPDATE b
				SET b.MatchId = CASE
									WHEN b.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID
									ELSE b.matchid
								END,
					b.HomeId = m.homeid,
					b.AwayId = m.awayid,
					b.IsNeutral= m.IsNeutral,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				WHERE b.WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
					AND b.EventType = 1
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 2)
			BEGIN
				UPDATE b
				SET b.HomeId = o.teamid,
					b.AwayId = 0,
					b.IsNeutral= 0,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
				WHERE b.WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
					AND b.EventType = 2
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 3)
			BEGIN
				UPDATE b
				SET b.HomeId = 0,
					b.AwayId = 0,
					b.IsNeutral= 0,
					b.VendorMatchId = r.VendorMatchId,
					b.Distance = r.Distance
				FROM @Data AS b
					INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = b.MatchId
				WHERE b.WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
					AND b.EventType = 3
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 5)
			BEGIN
				UPDATE b
				SET b.HomeId = m3rd.HomeId,
					b.AwayId = m3rd.AwayId,
					b.IsNeutral= 0,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId
				WHERE b.WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
					AND b.EventType = 5
			END
		END

		-- bettrans_bk range
		IF EXISTS (SELECT 1 FROM @Data WHERE WinLostDate < @BalanceUpDay)
		BEGIN
			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 1)
			BEGIN
				UPDATE b
				SET b.MatchId = CASE
									WHEN b.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID
									ELSE b.matchid
								END,
					b.HomeId = m.homeid,
					b.AwayId = m.awayid,
					b.IsNeutral= m.IsNeutral,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				WHERE b.WinLostDate < @BalanceUpDay
					AND b.EventType = 1
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 2)
			BEGIN
				UPDATE b
				SET b.HomeId = o.teamid,
					b.AwayId = 0,
					b.IsNeutral= 0,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN DBARC.bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
				WHERE b.WinLostDate < @BalanceUpDay
					AND b.EventType = 2
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 3)
			BEGIN
				UPDATE b
				SET b.HomeId = 0,
					b.AwayId = 0,
					b.IsNeutral= 0,
					b.VendorMatchId = r.VendorMatchId,
					b.Distance = r.Distance
				FROM @Data AS b
					INNER JOIN DBARC.bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = b.MatchId
				WHERE b.WinLostDate < @BalanceUpDay
					AND b.EventType = 3
			END

			IF EXISTS(SELECT TOP(1) 1 FROM @Data WHERE EventType = 5)
			BEGIN
				UPDATE b
				SET b.HomeId = m3rd.HomeId,
					b.AwayId = m3rd.AwayId,
					b.IsNeutral= 0,
					b.VendorMatchId = '',
					b.Distance = ''
				FROM @Data AS b
					INNER JOIN DBARC.bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON m3rd.Match3rdId = b.MatchId
				WHERE b.WinLostDate < @BalanceUpDay
					AND b.EventType = 5
			END
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
		d.VendorMatchId,
		d.Distance,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL
	FROM @Data AS d
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
	GROUP BY
		d.MatchId,
		d.EventType,
		d.HomeId,
		d.AwayId,
		d.IsNeutral,
		d.VendorMatchId,
		d.Distance
	ORDER BY d.MatchId ASC

	DROP TABLE IF EXISTS #BetTypeSel
	DROP TABLE IF EXISTS #SportBetType

END
GO
