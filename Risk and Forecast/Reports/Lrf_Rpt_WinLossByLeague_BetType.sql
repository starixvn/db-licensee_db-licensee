/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByLeague_BetType]
	@AgentList		VARCHAR(MAX),
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@MatchId		INT,
	@EventType		TINYINT,
	@ProductList	VARCHAR(100)	= '',
	@ShowBA			BIT				= 0,
	@BetTypeList	VARCHAR(MAX)	= '',
	@StatusIdList	VARCHAR(50)		= '',
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20210916@Kos
	Task: LAP - Win Loss By League report - BetType level
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

	DECLARE @ShowSB BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	-- Get sport/bettype matrix
	DECLARE @SportBetType TABLE (BetType SMALLINT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 999, 997)
		AND BetType NOT BETWEEN 801 AND 806
		AND (@BetTypeList = 'All'
			OR ',' + @BetTypeList + ',' LIKE '%,' + CAST(BetType AS VARCHAR(5)) + ',%')
			OR BetType IN (SELECT Bettype FROM dbo.Lrf_f_GroupBettype() WHERE ',' + @BetTypeList + ',' LIKE '%,' + CAST(GroupTypeId AS VARCHAR(5)) + ',%')
		AND EventType = @EventType

	DECLARE @Data TABLE (
		BetType		INT,
		WinLostDate	SMALLDATETIME,
		Currency	INT,
		BetCount	BIGINT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY,
		BAComm		MONEY
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
				BetType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				b.bettype,
				b.winlostdate,
				b.currency,
				COUNT(1) AS BetCount,
				SUM(CASE
						WHEN sbt.ProductCode = 'SB' AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29, 38)
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
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND 1 = CASE
							WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
							WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
							ELSE 1
						END
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.bettype,
				b.winlostdate,
				b.currency
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				BetType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				b.bettype,
				b.winlostdate,
				b.currency,
				COUNT(1) AS BetCount,
				SUM(CASE
						WHEN sbt.ProductCode = 'SB' AND b.statusID IN (112, 113) AND b.modds IN (-0.25, 0.25) AND b.bettype NOT IN (29, 38)
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
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @_ToDate
				AND b.custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND 1 = CASE
							WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
							WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
							ELSE 1
						END
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.bettype,
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

		IF @CustId = -1		-- Licensee level
		BEGIN
			INSERT INTO @Data (
				BetType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				b.bettype,
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
				INNER JOIN @TempAg AS a ON a.CustId = b.recommend
				INNER JOIN @SportBetType AS sbt ON sbt.BetType = b.bettype
			WHERE
				b.winlostdate BETWEEN @_FromDate AND @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND 1 = CASE
							WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
							WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
							ELSE 1
						END
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.bettype,
				b.winlostdate,
				b.currency
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				BetType,
				WinLostDate,
				Currency,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL,
				BAComm )
			SELECT
				b.bettype,
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
				b.winlostdate BETWEEN @_FromDate AND @TempToDate
				AND b.custid = @CustId
				AND ',' + @StatusIdList + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND 1 = CASE
							WHEN @ShowBA = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 1 THEN 0
							WHEN @ShowSB = 0 AND sbt.ProductCode = 'SB' AND b.isBA = 0 THEN 0
							ELSE 1
						END
				AND (b.matchid = @MatchId
					OR b.matchid IN (SELECT MatchId FROM @Match))
			GROUP BY
				b.bettype,
				b.winlostdate,
				b.currency
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
		CASE
			WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
			ELSE d.BetType
		END AS BetType,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(d.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(d.BAComm		* e.Rate) AS MONEY) AS BAComm
	FROM @Data AS d
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
		LEFT JOIN dbo.Lrf_f_GroupBettype() AS ss ON ss.bettype = d.BetType
	GROUP BY CASE
				WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
				ELSE d.BetType
			END
	ORDER BY BetType ASC
END
GO
