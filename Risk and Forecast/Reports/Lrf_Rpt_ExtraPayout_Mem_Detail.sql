/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExtraPayout_Mem_Detail]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@ProductList		VARCHAR(1000)	= '',
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
		- 20231018@Evan: Integrate Saba Casino Royale Tournament Prize [redmine: #194505]
		- 20231018@Evan: Integrate Saba Reward Risk-free Rebate [redmine: #196881]
		- 20231213@Evan: Integrate Live22 Promotion [RedmineID: #197702]
		- 20240416@Evan: Integrate Saba Coins [RedmineID: #202281]
		- 20240701@Kelvin: Integrate Integrate FastSpin [RedmineID: #207099]
		- 20240725@Kelvin: Vgaming - Integrate Promotion Prize [RedmineID: #208144]
		- 20240827@Lewis: FA CHAI - Integrate Promotion Prize [RedmineID: #209881]
		- 20250213@Kelvin: Integrate ASKMESLOT [RedmineID: #217785]
		- 20250314@Kelvin: Integrate Saba Promotion - Number Game Lucky Draw Promotion [RedmineID: #219835]
		- 20250326@Kelvin: Add new Saba Promotion for Sportsbook - NBA event [RedmineID: #221485]
		- 20250320@Kelvin: Integrate HOTDOG [RedmineID: #219979]
		- 20250402@Kelvin: Integrate Microgaming Live product [RedmineID: #222437]
		- 20250311@Kelvin: Integrate Virtual Sports 7 - Kiron [RedmineID: #219083]
		- 20250421@Kelvin: Integrate RichGaming [RedmineID: #224191]
		- 20250519@Kelvin: Add new Saba Promotion - FIFA CWC Score Challenge [RedmineID: #227537]

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
			- 3706: Casino Royale Tournament (BetType: 17006)
			- 3707: Saba Reward Risk-free Rebate (BetType: 17007)
			- 3708: Saba Coins Cash Exchange (BetType: 17008)
			- 3709: Promotion Jackpot Prize (BetType: 17009)
			- 3710: Promotion Cash Prize (BetType: 17010)
			- 3711: Number Game Lucky Draw Promotion (BetType: 17031)
			- 3712: NBA Playoffs Lottery (BetType: 17011)
			- 3713: Balance Adjustment (BetType: 17012)
			- 3714: FIFA CWC Score Challenge (BetType: 17013)
			- 3901: SA Gaming - Tip (BetType: 3007)
			- 4201: Saba.club - Free Bets (SportType: 150)
			- 4202: Saba.club - Jackpot Prize (BetType: 1699)
			- 4203: Saba.club - Jackpot Contribution (BetType: 1698)
			- 4501: AE Sexy - Lucky Draw (BetType: 3150)
			- 6601: Vgaming - Free Bets (SportType: 173)
			- 6602: Vgaming - Jackpot Prize (BetType: 3899)
			- 6603: Vgaming - Jackpot Contribution (BetType: 3898)
			- 6604: Vgaming - Promotion Prize (BetType: 3897)
			- 7401: Player Tips (BetType: 8700)
			- 3603: SG - Promotion Prize (BetType: 4598)
			- 7301: MGRNG - Promotion Prize (BetType: 8695)
			- 7901: Live22 - Promotion Prize (BetType: 7698)
			- 8701: FastSpin - Promotion Prize (BetType: 11295)
			- 8901: FACHAI - Promotion Prize (BetType: 11399)
			- 10301: ASKMESLOT - Promotion Prize (BetType: 15199)
			- 9501: HOTDOG - Promotion Prize (BetType: 11999)
			- 10701: Microgaming Live - Promotion Prize (BetType: 13995)
			- 10801: RichGaming - Promotion Prize (BetType: 15899)
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
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3706,%' AND BetType = 17006 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3707,%' AND BetType = 17007 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3708,%' AND BetType = 17008 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3709,%' AND BetType = 17009 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3710,%' AND BetType = 17010 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3711,%' AND BetType = 17031 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3712,%' AND BetType = 17011 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3713,%' AND BetType = 17012 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3714,%' AND BetType = 17013 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,3901,%' AND BetType = 3007 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4201,%' AND ProductPrefix = 'SBC' AND BetType NOT IN (1698, 1699) THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4202,%' AND BetType = 1699 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4203,%' AND BetType = 1698 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,4501,%' AND BetType = 3150 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,6601,%' AND ProductPrefix = 'VGA' AND BetType NOT IN (3899, 3898, 3897) THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,6602,%' AND BetType = 3899 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,6603,%' AND BetType = 3898 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,6604,%' AND BetType = 3897 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,7401,%' AND BetType = 8700 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,7301,%' AND BetType = 8695 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,7901,%' AND BetType = 7698 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,8701,%' AND BetType = 11295 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,8901,%' AND BetType = 11399 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,10301,%' AND BetType = 15199 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,9501,%' AND BetType = 11999 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,10701,%' AND BetType = 13995 THEN 1
				WHEN ',' + @PromotionTypeList + ',' LIKE '%,10801,%' AND BetType = 15899 THEN 1
				ELSE 0
			END

	DECLARE @Data TABLE (
		WinLostDate		SMALLDATETIME,
		RefNo			BIGINT,
		BetID			BIGINT,
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
			BetID,
			ProductCode,
			PromotionType,
			Turnover,
			Amount,
			SharingAmount)
		SELECT
			b.winlostdate,
			b.transid,
			CASE WHEN b.bettype = 17007 THEN b.refno ELSE NULL END AS BetID,
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
				WHEN b.bettype = 17006 THEN 3706
				WHEN b.bettype = 17007 THEN 3707
				WHEN b.bettype = 17008 THEN 3708
				WHEN b.bettype = 17009 THEN 3709
				WHEN b.bettype = 17010 THEN 3710
				WHEN b.bettype = 17031 THEN 3711
				WHEN b.bettype = 17011 THEN 3712
				WHEN b.bettype = 17012 THEN 3713
				WHEN b.bettype = 17013 THEN 3714
				WHEN b.bettype = 3007 THEN 3901
				WHEN sbt.ProductCode = 'SBC' AND b.matchid = 150 THEN 4201
				WHEN b.bettype = 1699 THEN 4202
				WHEN b.bettype = 1698 THEN 4203
				WHEN b.bettype = 3150 THEN 4501
				WHEN sbt.ProductCode = 'VGA' AND b.matchid = 173 THEN 6601
				WHEN b.bettype = 3899 THEN 6602
				WHEN b.bettype = 3898 THEN 6603
				WHEN b.bettype = 3897 THEN 6604
				WHEN b.bettype = 8700 THEN 7401
				WHEN b.bettype = 8695 THEN 7301
				WHEN b.bettype = 7698 THEN 7901
				WHEN b.bettype = 11295 THEN 8701
				WHEN b.bettype = 11399 THEN 8901
				WHEN b.bettype = 15199 THEN 10301
				WHEN b.bettype = 11999 THEN 9501
				WHEN b.bettype = 13995 THEN 10701
				WHEN b.bettype = 15899 THEN 10801
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
						WHEN sbt.ProductCode = 'VGA' AND b.bettype NOT IN (3898, 3899, 3897) AND b.matchid <> 173 THEN 0
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
			BetID,
			ProductCode,
			PromotionType,
			Turnover,
			Amount,
			SharingAmount)
		SELECT
			b.winlostdate,
			b.transid,
			CASE WHEN b.bettype = 17007 THEN b.refno ELSE -1 END AS BetID,
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
				WHEN b.bettype = 17006 THEN 3706
				WHEN b.bettype = 17007 THEN 3707
				WHEN b.bettype = 17008 THEN 3708
				WHEN b.bettype = 17009 THEN 3709
				WHEN b.bettype = 17010 THEN 3710
				WHEN b.bettype = 17031 THEN 3711
				WHEN b.bettype = 17011 THEN 3712
				WHEN b.bettype = 17012 THEN 3713
				WHEN b.bettype = 17013 THEN 3714
				WHEN b.bettype = 3007 THEN 3901
				WHEN sbt.ProductCode = 'SBC' AND b.matchid = 150 THEN 4201
				WHEN b.bettype = 1699 THEN 4202
				WHEN b.bettype = 1698 THEN 4203
				WHEN b.bettype = 3150 THEN 4501
				WHEN sbt.ProductCode = 'VGA' AND b.matchid = 173 THEN 6601
				WHEN b.bettype = 3899 THEN 6602
				WHEN b.bettype = 3898 THEN 6603
				WHEN b.bettype = 3897 THEN 6604
				WHEN b.bettype = 8700 THEN 7401
				WHEN b.bettype = 8695 THEN 7301
				WHEN b.bettype = 7698 THEN 7901
				WHEN b.bettype = 11295 THEN 8701
				WHEN b.bettype = 11399 THEN 8901
				WHEN b.bettype = 15199 THEN 10301
				WHEN b.bettype = 11999 THEN 9501
				WHEN b.bettype = 13995 THEN 10701
				WHEN b.bettype = 15899 THEN 10801
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
						WHEN sbt.ProductCode = 'VGA' AND b.bettype NOT IN (3898, 3899, 3897) AND b.matchid <> 173 THEN 0
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
			BetID,
			ProductCode,
			PromotionType,
			Turnover,
			Amount,
			SharingAmount)
		SELECT
			b.winlostdate,
			b.transid,
			CASE WHEN b.bettype = 17007 THEN b.refno ELSE -1 END AS BetID,
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
				WHEN b.bettype = 17006 THEN 3706
				WHEN b.bettype = 17007 THEN 3707
				WHEN b.bettype = 17008 THEN 3708
				WHEN b.bettype = 17009 THEN 3709
				WHEN b.bettype = 17010 THEN 3710
				WHEN b.bettype = 17031 THEN 3711
				WHEN b.bettype = 17011 THEN 3712
				WHEN b.bettype = 17012 THEN 3713
				WHEN b.bettype = 17013 THEN 3714
				WHEN b.bettype = 3007 THEN 3901
				WHEN sbt.ProductCode = 'SBC' AND b.matchid = 150 THEN 4201
				WHEN b.bettype = 1699 THEN 4202
				WHEN b.bettype = 1698 THEN 4203
				WHEN b.bettype = 3150 THEN 4501
				WHEN sbt.ProductCode = 'VGA' AND b.matchid = 173 THEN 6601
				WHEN b.bettype = 3899 THEN 6602
				WHEN b.bettype = 3898 THEN 6603
				WHEN b.bettype = 3897 THEN 6604
				WHEN b.bettype = 8700 THEN 7401
				WHEN b.bettype = 8695 THEN 7301
				WHEN b.bettype = 7698 THEN 7901
				WHEN b.bettype = 11295 THEN 8701
				WHEN b.bettype = 11399 THEN 8901
				WHEN b.bettype = 15199 THEN 10301
				WHEN b.bettype = 11999 THEN 9501
				WHEN b.bettype = 13995 THEN 10701
				WHEN b.bettype = 15899 THEN 10801
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
						WHEN sbt.ProductCode = 'VGA' AND b.bettype NOT IN (3898, 3899, 3897) AND b.matchid <> 173 THEN 0
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
		ISNULL(CONVERT(VARCHAR(20), d.BetID),'-') BetID,
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