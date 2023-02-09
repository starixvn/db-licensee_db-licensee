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

	Param's Explanation:
		+ @PromotionTypeList: promotion type list separated by ','
			- 2101: Allbet - Promotion (BetType: 2499)
			- 3201: PP - Tournament Prize (BetType: 4299)
			- 3202: PP - Promotion Prize (BetType: 4300)
			- 3203: PP - Jackpot Prize (BetType: 4298)
			- 3204: PP - Jackpot Contribution (BetType: 4297)
			- 3401: Arcadia Gaming - Bonus (BetType: 1906)
			- 3601: SG - Jackpot Prize (BetType: 4600)
			- 3602: SG - Jackpot Contribution (BetType: 4599)
			- 3701: Saba Lucky Spin (BetType: 17000)
			- 3702: Saba Lucky Spot (BetType: 17001)
			- 3703: Non - Cash Prize (BetType: 17002)
			- 3704: Saba Loyalty Points Exchange (BetType: 17003)
			- 3705: Saba Red Envelope (BetType: 17004)
			- 3901: SA Gaming - Tip (BetType: 3007)
			- 4201: Saba.club - Free Bets (SportType: 150)
			- 4202: Saba.club - Jackpot Prize (BetType: 1699)
			- 4203: Saba.club - Jackpot Contribution (BetType: 1698)
			- 4501: AE Sexy - Lucky Draw (BetType: 3150)
			- 6601: Vgaming - Free Bets (SportType: 173)
			- 6602: Vgaming - Jackpot Prize (BetType: 3899)
			- 6603: Vgaming - Jackpot Contribution (BetType: 3898)
			- 7401: Player Tips (BetType: 8700)
			- 3603: SG - Promotion Prize (BetType: 4598)
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

	-- Get sport/bettype matrix
	CREATE TABLE #SportBetType (BetType SMALLINT, ProductCode VARCHAR(10), EventType TINYINT)

	CREATE CLUSTERED INDEX IX_BetType ON #SportBetType (BetType)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE 1 = CASE
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,2101,%' AND BetType = 2499 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3201,%' AND BetType = 4299 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3202,%' AND BetType = 4300 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3203,%' AND BetType = 4298 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3204,%' AND BetType = 4297 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3401,%' AND BetType = 1906 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3601,%' AND BetType = 4600 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3602,%' AND BetType = 4599 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3603,%' AND BetType = 4598 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3701,%' AND BetType = 17000 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3702,%' AND BetType = 17001 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3703,%' AND BetType = 17002 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3704,%' AND BetType = 17003 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3705,%' AND BetType = 17004 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3901,%' AND BetType = 3007 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4201,%' AND ProductPrefix = 'SBC' AND BetType NOT IN (1698, 1699) THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4202,%' AND BetType = 1699 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4203,%' AND BetType = 1698 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4501,%' AND BetType = 3150 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,6601,%' AND ProductPrefix = 'VGA' AND BetType NOT IN (3899, 3898) THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,6602,%' AND BetType = 3899 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,6603,%' AND BetType = 3898 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,7401,%' AND BetType = 8700 THEN 1
				ELSE 0
			END

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
			CASE
				WHEN b.bettype = 2499 THEN 2101
				WHEN b.bettype = 4299 THEN 3201
				WHEN b.bettype = 4300 THEN 3202
				WHEN b.bettype = 4298 THEN 3203
				WHEN b.bettype = 4297 THEN 3204
				WHEN b.bettype = 1906 THEN 3401
				WHEN b.bettype = 4600 THEN 3601
				WHEN b.bettype = 4599 THEN 3602
				WHEN b.bettype = 4598 THEN 3603
				WHEN b.bettype = 17000 THEN 3701
				WHEN b.bettype = 17001 THEN 3702
				WHEN b.bettype = 17002 THEN 3703
				WHEN b.bettype = 17003 THEN 3704
				WHEN b.bettype = 17004 THEN 3705
				WHEN b.bettype = 3007 THEN 3901
				WHEN sbt.ProductCode = 'SBC' AND b.matchid = 150 THEN 4201
				WHEN b.bettype = 1699 THEN 4202
				WHEN b.bettype = 1698 THEN 4203
				WHEN b.bettype = 3150 THEN 4501
				WHEN sbt.ProductCode = 'VGA' AND b.matchid = 173 THEN 6601
				WHEN b.bettype = 3899 THEN 6602
				WHEN b.bettype = 3898 THEN 6603
				WHEN b.bettype = 8700 THEN 7401
				ELSE 0
			END AS PromotionType,
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
						WHEN sbt.ProductCode = 'SBC' AND b.bettype NOT IN (1698, 1699) AND b.matchid <> 150 THEN 0
						WHEN sbt.ProductCode = 'VGA' AND b.bettype NOT IN (3898, 3899) AND b.matchid <> 173 THEN 0
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
			CASE
				WHEN b.bettype = 2499 THEN 2101
				WHEN b.bettype = 4299 THEN 3201
				WHEN b.bettype = 4300 THEN 3202
				WHEN b.bettype = 4298 THEN 3203
				WHEN b.bettype = 4297 THEN 3204
				WHEN b.bettype = 1906 THEN 3401
				WHEN b.bettype = 4600 THEN 3601
				WHEN b.bettype = 4599 THEN 3602
				WHEN b.bettype = 4598 THEN 3603
				WHEN b.bettype = 17000 THEN 3701
				WHEN b.bettype = 17001 THEN 3702
				WHEN b.bettype = 17002 THEN 3703
				WHEN b.bettype = 17003 THEN 3704
				WHEN b.bettype = 17004 THEN 3705
				WHEN b.bettype = 3007 THEN 3901
				WHEN sbt.ProductCode = 'SBC' AND b.matchid = 150 THEN 4201
				WHEN b.bettype = 1699 THEN 4202
				WHEN b.bettype = 1698 THEN 4203
				WHEN b.bettype = 3150 THEN 4501
				WHEN sbt.ProductCode = 'VGA' AND b.matchid = 173 THEN 6601
				WHEN b.bettype = 3899 THEN 6602
				WHEN b.bettype = 3898 THEN 6603
				WHEN b.bettype = 8700 THEN 7401
				ELSE 0
			END AS PromotionType,
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
						WHEN sbt.ProductCode = 'SBC' AND b.bettype NOT IN (1698, 1699) AND b.matchid <> 150 THEN 0
						WHEN sbt.ProductCode = 'VGA' AND b.bettype NOT IN (3898, 3899) AND b.matchid <> 173 THEN 0
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
			CASE
				WHEN b.bettype = 2499 THEN 2101
				WHEN b.bettype = 4299 THEN 3201
				WHEN b.bettype = 4300 THEN 3202
				WHEN b.bettype = 4298 THEN 3203
				WHEN b.bettype = 4297 THEN 3204
				WHEN b.bettype = 1906 THEN 3401
				WHEN b.bettype = 4600 THEN 3601
				WHEN b.bettype = 4599 THEN 3602
				WHEN b.bettype = 4598 THEN 3603
				WHEN b.bettype = 17000 THEN 3701
				WHEN b.bettype = 17001 THEN 3702
				WHEN b.bettype = 17002 THEN 3703
				WHEN b.bettype = 17003 THEN 3704
				WHEN b.bettype = 17004 THEN 3705
				WHEN b.bettype = 3007 THEN 3901
				WHEN sbt.ProductCode = 'SBC' AND b.matchid = 150 THEN 4201
				WHEN b.bettype = 1699 THEN 4202
				WHEN b.bettype = 1698 THEN 4203
				WHEN b.bettype = 3150 THEN 4501
				WHEN sbt.ProductCode = 'VGA' AND b.matchid = 173 THEN 6601
				WHEN b.bettype = 3899 THEN 6602
				WHEN b.bettype = 3898 THEN 6603
				WHEN b.bettype = 8700 THEN 7401
				ELSE 0
			END AS PromotionType,
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
						WHEN sbt.ProductCode = 'SBC' AND b.bettype NOT IN (1698, 1699) AND b.matchid <> 150 THEN 0
						WHEN sbt.ProductCode = 'VGA' AND b.bettype NOT IN (3898, 3899) AND b.matchid <> 173 THEN 0
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
