/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExtraPayout]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@ProductList		VARCHAR(1000)	= '',
	@PromotionTypeList	VARCHAR(500)	= '',
	@ReportType			TINYINT			= 1,
	@BaseCurrency		VARCHAR(12)		= ''
AS

/*
	Created: 20211016@Kos
	Task: LAP - Extra Payout WL report
	DB: DBEXT.bodb02

	Revisions:
		- 20211016@Kos: Created [RedmineID: #153563]
		- 20220126@Kos: Integrate Spadegaming Jackpot [RedmineID: #167035]
		- 20220223@Kos: Integrate Allbet Promotion [RedmineID: #167524]
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
		- 20240910@Kelvin: Integrate Odds Boost Voucher [RedmineID: #210613]
		- 20250213@Kelvin: Integrate ASKMESLOT [RedmineID: #217785]
		- 20250314@Kelvin: Integrate Saba Promotion - Number Game Lucky Draw Promotion [RedmineID: #219835]
		- 20250326@Kelvin: Add new Saba Promotion for Sportsbook - NBA event [RedmineID: #221485]
		- 20250320@Kelvin: Integrate HOTDOG [RedmineID: #219979]
		- 20250402@Kelvin: Integrate Microgaming Live product [RedmineID: #222437]
		- 20250311@Kelvin: Integrate Virtual Sports 7 - Kiron [RedmineID: #219083]
		- 20250421@Kelvin: Integrate RichGaming [RedmineID: #224191]
		- 20250519@Kelvin: Add new Saba Promotion - FIFA CWC Score Challenge [RedmineID: #227537]
		- 20250725@Kelvin: LAP - Integrate Playtech - Jackpot [RedmineID: #233781]
		- 20250801@Kelvin: LAP/MPA - Betradar VS2 - Integrate new VS Tournament [RedmineID: #234844]
		- 20250722@Kelvin: Enhancement to speed up integrate new casino product - Phase 2 [RedmineID: #232697]

	Param's Explanation:
		+ @PromotionTypeList: promotion type list separated by ','
			- 101: Sportsbook - Odds Boost Adjustment (BetType: 997)
			- 2101: Allbet - Promotion (BetType: 2499)
			- 2701: VS2 - VS Tournament (BetType: 2798)
			- 3201: PP - Tournament Prize (BetType: 4299)
			- 3202: PP - Promotion Prize (BetType: 4300)
			- 3203: PP - Jackpot Prize (BetType: 4298)
			- 3204: PP - Jackpot Contribution (BetType: 4297)
			- 3401: Arcadia Gaming - Bonus (BetType: 1906)
			- 3601: SG - Jackpot Prize (BetType: 4600)
			- 3602: SG - Jackpot Contribution (BetType: 4599)
			- 3603: SG - Promotion Prize (BetType: 4598)
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
			- 7301: MGRNG - Promotion Prize (BetType: 8695)
			- 7401: Player Tips (BetType: 8700)
			- 7901: Live22 - Promotion Prize (BetType: 7698)
			- 8701: FastSpin - Promotion Prize (BetType: 11295)
			- 8901: FACHAI - Promotion Prize (BetType: 11399)
			- 9501: HOTDOG - Promotion Prize (BetType: 11999)
			- 10001: Playtech  - Jackpot Contribution (BetType: 12998)
			- 10002: Playtech  - Jackpot Prize (BetType: 12999)
			- 10301: ASKMESLOT - Promotion Prize (BetType: 15199)
			- 10701: Microgaming Live - Promotion Prize (BetType: 13995)
			- 10801: RichGaming - Promotion Prize (BetType: 15899)

		+ @ReportType: 1: Daily, 2: Monthly
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId)

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

	-- Get member list
	CREATE TABLE #TempCust (CustId INT PRIMARY KEY)

	IF @Username <> ''
	BEGIN
		INSERT INTO #TempCust
		SELECT c.custid
		FROM dbo.Customer AS c WITH (NOLOCK, INDEX = IX_agent)
			INNER JOIN #TempAg AS ta ON ta.CustId = c.recommend
		WHERE c.roleid = 1
			AND (c.username2 LIKE '%$%' + @Username + '%'
				OR c.username LIKE '%' + @Username + '%')
		
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT ErrCode = 102,
				ErrMsg = N'Username was not found.'

			RETURN
		END
	END

	SELECT @ProductList = STRING_AGG(b.ProductPrefix, ',')
	FROM (
		SELECT DISTINCT ISNULL(b.ProductPrefix, a.Value) AS ProductPrefix
		FROM STRING_SPLIT(@ProductList, ',') a
			LEFT JOIN dbo.Lrf_f_GroupProduct() b ON a.Value = b.GroupProductPrefix
	) b

	-- Get sport/bettype matrix
	CREATE TABLE #SportBetType (BetType SMALLINT, ProductCode VARCHAR(10), SportType INT
								, PRIMARY KEY(BetType, SportType))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBetType (BetType, ProductCode, SportType)
	SELECT
		DISTINCT e.BetType, ISNULL(p.GroupProductPrefix, s.ProductPrefix), e.SportType
	FROM
		dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest) s
		INNER JOIN dbo.Lrf_f_Sel_PromotionExcludedBetType() e ON e.BetType = s.BetType
		LEFT JOIN dbo.Lrf_f_GroupProduct() p ON s.ProductID = p.ProductId
	WHERE 
		EXISTS (SELECT 1 FROM STRING_SPLIT(@PromotionTypeList,',') WHERE value = e.PromotionType)

	DECLARE @Data TABLE (
		ProductCode		VARCHAR(10),
		WinLostDate		SMALLDATETIME,
		Currency		INT,
		BetCount		BIGINT,
		Turnover		MONEY,
		Amount			MONEY,
		SharingAmount	MONEY
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	-- bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @FromDate
							END

		INSERT INTO @Data (
			ProductCode,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			Amount,
			SharingAmount )
		SELECT
			sbt.ProductCode,
			b.winlostdate,
			b.currency,
			COUNT(1) AS BetCount,
			SUM(CASE
					WHEN b.bettype IN (4297, 1698, 3898, 4599) THEN b.oddsspread
					ELSE b.stake
				END) AS Turnover,
			SUM(CASE 
					WHEN b.bettype IN (997) THEN b.oddsspread 
					ELSE (b.winlost - b.actual_stake) 
				END) AS Amount,
			SUM(CASE
					WHEN b.bettype IN (997) THEN 0
					ELSE b.awinlost
				END) AS SharingAmount
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype AND sbt.SportType = b.matchid
			LEFT JOIN #TempCust AS c ON c.CustId = b.custid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (111, 112, 113)
			AND (@Username = '' OR c.CustId IS NOT NULL)
		GROUP BY
			sbt.ProductCode,
			b.winlostdate,
			b.currency
	END

	-- bettrans14 & bettrans_bk range
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @ToDate
						END

		INSERT INTO @Data (
			ProductCode,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			Amount,
			SharingAmount )
		SELECT
			sbt.ProductCode,
			b.winlostdate,
			b.currency,
			SUM(b.BetCount) AS BetCount,
			SUM(CASE
					WHEN b.bettype IN (4297, 1698, 3898, 4599) THEN b.BuyBackAmt					
					ELSE b.turnover
				END) AS Turnover,
			SUM(CASE
					WHEN b.bettype IN (997) THEN b.BuyBackAmt
					ELSE b.winlost
				END) AS Amount,
			SUM(CASE
					WHEN b.bettype IN (997) THEN 0
					ELSE b.awinlost
				END) AS SharingAmount			
		FROM
			bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
			LEFT JOIN #TempCust AS c ON c.CustId = b.custid
		WHERE
			b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
			AND b.roleid = 1
			AND (@Username = '' OR c.CustId IS NOT NULL)
			AND 1 = CASE WHEN sbt.BetType = 997 THEN 1 -- BetType = 997 - rptLicWinloss2.SportType = 0, can't join with SportType
						 WHEN sbt.SportType = b.sporttype THEN 1
						 ELSE 0
					END
		GROUP BY
			sbt.ProductCode,
			b.winlostdate,
			b.currency
	END

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM @Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, Rate)
		SELECT FromDate, ToDate, ExchangeID, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') e
		WHERE EXISTS (SELECT 1 FROM #TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	-- Return result
	SELECT
		CASE
			WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), d.winlostdate, 112)
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), d.winlostdate, 112)
			ELSE '0'
		END AS ReportType,
		d.Currency,
		d.ProductCode,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover)		AS MONEY) AS Turnover,
		CAST(SUM(d.Amount)			AS MONEY) AS Amount,
		CAST(SUM(d.SharingAmount)	AS MONEY) AS SharingAmount,
		CAST(SUM(d.Turnover			* e.Rate) AS MONEY) AS BasedTurnover,
		CAST(SUM(d.Amount			* e.Rate) AS MONEY) AS BasedAmount,
		CAST(SUM(d.SharingAmount	* e.Rate) AS MONEY) AS BasedSharingAmount
	FROM @Data AS d
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
	GROUP BY
		CASE
			WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), d.winlostdate, 112)
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), d.winlostdate, 112)
			ELSE '0'
		END,
		d.Currency,
		d.ProductCode
	ORDER BY ReportType ASC

	DROP TABLE #TempAg
	DROP TABLE #SportBetType
	DROP TABLE #TempCust
END
GO
