/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByLeague_Match_Currency]
	@AgentList		VARCHAR(MAX),
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@MatchId		INT,
	@EventType		TINYINT,
	@ProductList	VARCHAR(100)	= '',
	@BetTypeList	XML	= '',
	@StatusIdList	VARCHAR(50)		= '',
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20210916@Kos
	Task: LAP - Win Loss By League report - Match level - Separated by currencies
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
		- @Username: exact System ID or External ID
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

	-- Get sport/bettype matrix
	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductList, 'ALL') = 'ALL'  OR ',' + @ProductList + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2))

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

	SELECT @SportTypeCheck = NULL

	CREATE TABLE #SportBetType (BetType SMALLINT, ProductID INT, EventType TINYINT)
	CREATE CLUSTERED INDEX IX_SportBetType ON #SportBetType (BetType)

	INSERT INTO #SportBetType (BetType, ProductID, EventType)
	SELECT bm.Bettype, bm.ProductId, bm.EventType
	FROM bodb02.dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductList, @SportTypeCheck, @BettypeIdsCheck, @SBBACheck) AS bm
	WHERE @BettypeIdsCheck IS NULL OR EXISTS (SELECT 1 FROM #BetTypeSel bts WHERE bts.ProductId = bm.ProductId AND bts.Bettype = ISNULL(bm.GroupTypeId,bm.Bettype))
		AND BetType NOT IN (901, 902, 903, 904)
		AND BetType NOT BETWEEN 801 AND 806
		AND bm.EventType = @EventType

	DECLARE @Data TABLE (
		Currency	INT,
		WinLostDate	SMALLDATETIME,
		BetCount	BIGINT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY
	)

	DECLARE
		@MatchSportType	SMALLINT,
		@ParentId		INT

	DECLARE @_FromDate	SMALLDATETIME,
		@_ToDate		SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	DECLARE @Match TABLE (MatchId INT)

	IF @EventType = 1
	BEGIN
		SELECT
			@MatchSportType = sporttype,
			@ParentId = ParentID
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId AND eventdate > @MoveBetsDay

		IF @MatchSportType IS NULL
		BEGIN
			SELECT
				@MatchSportType = sporttype,
				@ParentId = ParentID
			FROM dbo.match14 WITH (NOLOCK)
			WHERE matchid = @MatchId
				AND eventdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		END

		IF @MatchSportType IS NULL
		BEGIN
			SELECT
				@MatchSportType = sporttype,
				@ParentId = ParentID
			FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
			WHERE matchid = @MatchId
		END

		IF @MatchSportType IS NOT NULL
		BEGIN
			IF @MatchSportType IN (50, 8) AND @ParentId IS NULL	-- Cricket, parent match
			BEGIN
				INSERT INTO @Match
				SELECT
					@MatchId
				UNION
				SELECT DISTINCT
					MatchId
				FROM dbo.match WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND eventdate BETWEEN @_FromDate AND @_ToDate
					AND ChildMatchType = 200
				UNION
				SELECT DISTINCT
					MatchId
				FROM dbo.match14 WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND eventdate BETWEEN @_FromDate AND @_ToDate
					AND ChildMatchType = 200
				UNION
				SELECT DISTINCT
					MatchId
				FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
				WHERE ParentID = @MatchId
					AND sporttype = @MatchSportType
					AND eventdate BETWEEN @_FromDate AND @_ToDate
					AND ChildMatchType = 200
			END
		END
	END
	
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
				Currency,
				WinLostDate,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				b.currency,
				b.winlostdate,
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
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.currency,
				b.winlostdate
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				Currency,
				WinLostDate,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				b.currency,
				b.winlostdate,
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
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.currency,
				b.winlostdate
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

		IF @CustId = -1		-- Licensee level
		BEGIN
			INSERT INTO @Data (
				Currency,
				WinLostDate,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				b.currency,
				b.winlostdate,
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
				b.winlostdate BETWEEN @_FromDate AND @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.currency,
				b.winlostdate
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				Currency,
				WinLostDate,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL
				)
			SELECT
				b.currency,
				b.winlostdate,
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
				b.winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.currency,
				b.winlostdate
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
		d.Currency,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL
	FROM @Data AS d
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
	GROUP BY d.Currency

	DROP TABLE IF EXISTS #BetTypeSel
	DROP TABLE IF EXISTS #SportBetType

END
GO
