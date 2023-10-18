/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExtraPayout_Mem_Detail]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@ProductList		VARCHAR(100)	= '',
	@PromotionTypeList	VARCHAR(500)	= '',
	@BaseCurrency		VARCHAR(12)		= ''
AS

/*
	Created: 20211208@Kos
	Task: LAP - Extra Payout WL report - Member level - Detail
	DB: DBACC.bodb02
	Revisions:
		- 20180711@Kos: Created [#Redmine: 153563]
		- 20220126@Kos: Integrate Spadegaming Jackpot [RedmineID: #167035]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20221122@Evan: Integrate Player Tips [RedmineID: #180590]
		- 20230208@Evan: Inteagrate SG promotion prize [RedmineID: #183497]
		- 20230626@Evan: Integrate MG-RNG (Promotion Game) [RedmineID: #189988]
		- 20231018@Evan: Enhance SPs + Integrate Saba Casino Royale Tournament Prize [redmine: #194505]

	Param's Explanation:
		+ @PromotionTypeList: promotion type list separated by ',' (Get PromotionTypeList from Lrf_f_SelPromotionType)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	-- Get PromotionTypeList
	DECLARE @tbPromotionTypeList TABLE (PromotionType SMALLINT, Bettype INT, ProductCode VARCHAR(10), SportType SMALLINT)
	INSERT INTO @tbPromotionTypeList (PromotionType, Bettype, ProductCode, SportType)
	SELECT a.PromotionType
		 , a.Bettype 
		 , a.ProductCode 
		 , a.SportType 
	FROM Lrf_f_SelPromotionType (@ProductList,@PromotionTypeList) AS a   
	WHERE a.PromotionType IN (SELECT value FROM STRING_SPLIT(@PromotionTypeList,','))

	-- Get sport/bettype matrix
	CREATE TABLE #SportBetType (BetType SMALLINT, ProductCode VARCHAR(10), EventType TINYINT, PromotionType SMALLINT, SportType SMALLINT)

	CREATE CLUSTERED INDEX IX_BetType ON #SportBetType (BetType)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBetType (BetType, ProductCode, EventType, PromotionType, SportType)
	SELECT DISTINCT a.BetType
				  , a.ProductPrefix
				  , a.EventType
				  , b.PromotionType
				  , b.SportType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest) a
		INNER JOIN @tbPromotionTypeList b ON b.ProductCode = a.ProductPrefix
			AND a.BetType = ISNULL(b.Bettype, a.BetType)

	DECLARE @Data TABLE (
		WinLostDate		SMALLDATETIME,
		RefNo			BIGINT,
		ProductCode		VARCHAR(10),
		PromotionType	SMALLINT,
		Turnover		MONEY,
		Amount			MONEY,
		SharingAmount	MONEY
	)

	DECLARE @TempToDate	SMALLDATETIME,
		@TempFromDate	SMALLDATETIME

	-- bettrans
	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @FromDate
							END

		-- bettrans
		INSERT INTO @Data (
			WinLostDate,
			RefNo,
			ProductCode,
			PromotionType,
			Turnover,
			Amount,
			SharingAmount)
		SELECT
			b.winlostdate,
			b.transid,
			sbt.ProductCode,
			sbt.PromotionType,
			CASE
				WHEN b.bettype IN (4297, 1698, 3898, 4599) THEN b.oddsspread
				ELSE b.stake
			END AS Turnover,
			(b.winlost - b.actual_stake) AS Amount,
			b.awinlost AS SharingAmount
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
			INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (111, 112, 113)
			AND 1 = CASE
						WHEN sbt.ProductCode IN ('SBC','VGA') AND b.matchid <> sbt.SportType THEN 0
						ELSE 1
					END
	END

	-- bettrans14
	IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @ToDate
						END

		SET @TempFromDate = CASE
								WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay
								ELSE @FromDate
							END

		INSERT INTO @Data (
			WinLostDate,
			RefNo,
			ProductCode,
			PromotionType,
			Turnover,
			Amount,
			SharingAmount)
		SELECT
			b.winlostdate,
			b.transid,
			sbt.ProductCode,
			sbt.PromotionType,
			CASE
				WHEN b.bettype IN (4297, 1698, 3898, 4599) THEN b.oddsspread
				ELSE b.stake
			END AS Turnover,
			(b.winlost - b.actual_stake) AS Amount,
			b.awinlost AS SharingAmount
		FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_memberStatement14)
			INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
			AND 1 = CASE
						WHEN sbt.ProductCode IN ('SBC','VGA') AND b.matchid <> sbt.SportType THEN 0
						ELSE 1
					END
	END

	-- bettrans_bk
	IF @FromDate <= @BalanceUpDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @ToDate >= DATEADD(dd, -1, @BalanceUpDay) THEN DATEADD(dd, -1, @BalanceUpDay)
							ELSE @ToDate
						END

		INSERT INTO @Data (
			WinLostDate,
			RefNo,
			ProductCode,
			PromotionType,
			Turnover,
			Amount,
			SharingAmount)
		SELECT
			b.winlostdate,
			b.transid,
			sbt.ProductCode,
			sbt.PromotionType,
			CASE
				WHEN b.bettype IN (4297, 1698, 3898, 4599) THEN b.oddsspread
				ELSE b.stake
			END AS Turnover,
			(b.winlost - b.actual_stake) AS Amount,
			b.awinlost AS SharingAmount
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
			INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
			AND 1 = CASE
						WHEN sbt.ProductCode IN ('SBC','VGA') AND b.matchid <> sbt.SportType THEN 0
						ELSE 1
					END
	END

	DECLARE @Currency	INT

	SELECT @Currency = currency
	FROM dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		Rate		FLOAT)

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @Data

	IF EXISTS (SELECT TOP(1) 1 FROM @Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, Rate)
		SELECT FromDate, ToDate, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') e
		WHERE e.ExchangeId = @Currency
	END

	-- Return result
	SELECT
		d.WinLostDate,
		d.RefNo,
		d.ProductCode,
		d.PromotionType,
		d.Turnover,
		d.Amount,
		d.SharingAmount,
		d.Turnover * ISNULL(e.Rate, 1) AS BasedTurnover,
		d.Amount * ISNULL(e.Rate, 1) AS BasedAmount,
		d.SharingAmount * ISNULL(e.Rate, 1) AS BasedSharingAmount
	FROM
		@Data AS d
		LEFT JOIN @ExchangeRate AS e ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
	ORDER BY d.WinLostDate ASC

	DROP TABLE #SportBetType
END
GO
