/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_GodOfFortuneWinloss_Detail]
	@AgentList				VARCHAR(MAX),
	@CustId					INT				= 0,	-- AgentId
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@DrawFilter				SMALLINT		= 1,
	@BaseCurrency			VARCHAR(12)		= '',
	@ConvertToBaseCurrency	BIT				= 1
AS

/*
	Created: 20210408@Kos
	Task: LAP - God of Fortune Winloss Report - Detail
	DB: DBEXT.bodb02

	Revisions:
		- 20210408@Kos: God of Fortune WL report [RedmineID: #152900]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

	Param's Explanation:
		+ @ReportType:
			- 1: Daily
			- 2: Monthly
		+ @DrawFilter:
			- 1: Normal
			- 2: No Draw
			- 3: No Draw for Turnover only
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
		WHERE @CustId = 0 OR AgentId = @CustId

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #Data (
		CustId		INT,
		WinLostDate	SMALLDATETIME,
		Currency	INT,
		BetCount	BIGINT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY,
		Discount	MONEY
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @FromDate
							END

		INSERT INTO #Data (
			CustId,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			LicenseeWL,
			Discount )
		SELECT
			b.custid,
			b.winlostdate,
			b.currency,
			SUM(CASE
					WHEN @DrawFilter = 2 AND b.statusID = 111 THEN 0
					ELSE 1
				END) AS BetCount,
			SUM(CASE
					WHEN @DrawFilter IN (2, 3) AND b.statusID = 111 THEN 0
					ELSE b.stake
				END) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM(b.stake - b.actual_stake) AS Discount
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS a ON a.CustId = b.recommend
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.bettype = 29
			AND b.oddsspread = 1
			AND b.statusID IN (111, 112, 113)
		GROUP BY
			b.custid,
			b.winlostdate,
			b.currency
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @ToDate
						END

		INSERT INTO #Data (
			CustId,
			WinLostDate,
			Currency,
			BetCount,
			Turnover,
			WinLost,
			LicenseeWL,
			Discount )
		SELECT
			b.custid,
			b.winlostdate,
			b.Currency,
			SUM(CASE
					WHEN @DrawFilter = 2 AND b.statusID = 111 THEN 0
					ELSE b.BetCount
				END) AS BetCount,
			SUM(CASE
					WHEN @DrawFilter IN (2, 3) AND b.statusID = 111 THEN 0
					ELSE b.turnover
				END) AS Turnover,
			SUM(b.winlost) AS WinLost,
			-SUM(b.winlost) AS LicenseeWL,
			SUM(b.turnover - b.BuyBackAmt) AS Discount
		FROM
			bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS ag ON b.recommend = ag.custID AND ag.currency = b.Currency
		WHERE
			b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.sporttype = 0
			AND b.bettype = -29
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
		GROUP BY
			b.custid,
			b.winlostdate,
			b.currency
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

	IF EXISTS (SELECT TOP(1) 1 FROM #Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT
			e.FromDate,
			e.ToDate,
			e.ExchangeId,
			e.USD,
			e.EUR,
			e.GBP,
			e.Rate,
			CASE
				WHEN @ConvertToBaseCurrency = 1 THEN e.DefaultRate
				ELSE 1
			END AS DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, @BaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM @TempAg AS a WHERE e.ExchangeID = a.Currency)
	END

	-- Member rows
	SELECT
		d.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		d.Currency,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.DefaultRate)	AS MONEY)	AS Turnover,
		CAST(SUM(d.WinLost		* e.DefaultRate)	AS MONEY)	AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.DefaultRate)	AS MONEY)	AS LicenseeWL,
		CAST(SUM(d.Discount		* e.DefaultRate)	AS MONEY)	AS Discount
	FROM
		#Data AS d
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = d.CustId
		INNER JOIN @ExchangeRate AS e ON d.winlostdate BETWEEN e.FromDate AND e.ToDate AND d.currency = e.ExchangeId
	GROUP BY
		d.CustId,
		c.username,
		c.username2,
		d.Currency

	-- Total Currency rows
	SELECT
		d.Currency,
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.Rate)	AS MONEY)	AS Turnover,
		CAST(SUM(d.WinLost		* e.Rate)	AS MONEY)	AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate)	AS MONEY)	AS LicenseeWL,
		CAST(SUM(d.Discount		* e.Rate)	AS MONEY)	AS Discount
	FROM
		#Data AS d
		INNER JOIN @ExchangeRate AS e ON d.winlostdate BETWEEN e.FromDate AND e.ToDate AND d.currency = e.ExchangeId
	GROUP BY
		d.Currency

	-- Total row
	SELECT
		SUM(d.BetCount) AS BetCount,
		CAST(SUM(d.Turnover		* e.Rate)	AS MONEY)	AS Turnover,
		CAST(SUM(d.WinLost		* e.Rate)	AS MONEY)	AS WinLost,
		CAST(SUM(d.LicenseeWL	* e.Rate)	AS MONEY)	AS LicenseeWL,
		CAST(SUM(d.Discount		* e.Rate)	AS MONEY)	AS Discount
	FROM
		#Data AS d
		INNER JOIN @ExchangeRate AS e ON d.WinLostDate BETWEEN e.FromDate AND e.ToDate AND d.Currency = e.ExchangeId

	DROP TABLE #Data
END
GO