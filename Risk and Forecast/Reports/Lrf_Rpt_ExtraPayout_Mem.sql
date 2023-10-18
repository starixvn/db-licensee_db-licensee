/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExtraPayout_Mem]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@ProductList		VARCHAR(100)	= '',
	@PromotionTypeList	VARCHAR(500)	= '',
	@BaseCurrency		VARCHAR(12)		= ''
AS

/*
	Created: 20211016@Kos
	Task: LAP - Extra Payout WL report - Member level
	DB: DBEXT.bodb02

	Revisions:
		- 20211016@Kos: Created [RedmineID: #153563]
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
		CustId			INT,
		ProductCode		VARCHAR(10),
		PromotionType	SMALLINT,
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
			CustId,
			ProductCode,
			PromotionType,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			Amount,
			SharingAmount )
		SELECT
			b.custid,
			sbt.ProductCode,
			sbt.PromotionType,
			b.winlostdate,
			b.currency,
			COUNT(1) AS BetCount,
			SUM(CASE
					WHEN b.bettype IN (4297, 1698, 3898, 4599) THEN b.oddsspread
					ELSE b.stake
				END) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS Amount,
			SUM(b.awinlost) AS SharingAmount
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype
			LEFT JOIN #TempCust AS c ON c.CustId = b.custid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (111, 112, 113)
			AND 1 = CASE
						WHEN sbt.ProductCode IN ('SBC','VGA') AND b.matchid <> sbt.SportType THEN 0
						ELSE 1
					END
			AND (@Username = '' OR c.CustId IS NOT NULL)
		GROUP BY
			b.custid,
			sbt.ProductCode,
			sbt.PromotionType,
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
			CustId,
			ProductCode,
			PromotionType,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			Amount,
			SharingAmount )
		SELECT
			b.custid,
			sbt.ProductCode,
			sbt.PromotionType,
			b.winlostdate,
			b.currency,
			SUM(b.BetCount) AS BetCount,
			SUM(CASE
					WHEN b.bettype IN (4297, 1698, 3898, 4599) THEN b.BuyBackAmt
					ELSE b.turnover
				END) AS Turnover,
			SUM(b.winlost) AS Amount,
			SUM(b.awinlost) AS SharingAmount
		FROM
			bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN #SportBetType AS sbt ON sbt.BetType = b.bettype AND b.sporttype = ISNULL(sbt.SportType,b.SportType)
			LEFT JOIN #TempCust AS c ON c.CustId = b.custid
		WHERE
			b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
			AND b.roleid = 1
			AND (@Username = '' OR c.CustId IS NOT NULL)
		GROUP BY
			b.custid,
			sbt.ProductCode,
			sbt.PromotionType,
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
		d.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		d.Currency,
		d.ProductCode,
		d.PromotionType,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover)		AS MONEY) AS Turnover,
		CAST(SUM(d.Amount)			AS MONEY) AS Amount,
		CAST(SUM(d.SharingAmount)	AS MONEY) AS SharingAmount,
		CAST(SUM(d.Turnover			* e.Rate) AS MONEY) AS BasedTurnover,
		CAST(SUM(d.Amount			* e.Rate) AS MONEY) AS BasedAmount,
		CAST(SUM(d.SharingAmount	* e.Rate) AS MONEY) AS BasedSharingAmount
	FROM @Data AS d
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = d.CustId
		INNER JOIN @ExchangeRate AS e
			ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND d.Currency = e.ExchangeId
	GROUP BY
		d.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)),
		d.Currency,
		d.ProductCode,
		d.PromotionType
	ORDER BY c.username ASC

	DROP TABLE #TempAg
	DROP TABLE #SportBetType
	DROP TABLE #TempCust
END
GO
