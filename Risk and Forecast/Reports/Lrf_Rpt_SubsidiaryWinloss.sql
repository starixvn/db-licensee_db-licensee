/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_SubsidiaryWinloss]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(1000),
	@IncludeRaw		BIT,
	@BaseCurrency	VARCHAR(3)
AS

/*
	Created: 20170829@Sophia
	Task: Subsidiary Performance report [Redmine: #76246]
	DB: DBEXT.bodb02

	Revisions:
		- 20170829@Sophia: Initial SP [Redmine: #76246]
		- 20171226@Harper: Return more column for report [RedmineID: #88398]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20180905@Amanda: Add new params [Redmine: #95177]
		- 20181228@Joseph: Remove vnteam [RedmineID: #103698]
		- 20190620@Amanda: Centralize function to get exchange rate [Redmine: #112531]
		- 20200707@Kos: Support all products [Redmine: #136568]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200924@Louis: Control BA status for subsidiary [RedmineID: #142038]

	Param's Explanation:
		+ @MoveBetsDay: The day we move tickets to bettrans14
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Subsidiary
	(
		WinLostDate	SMALLDATETIME,
		Recommend	INT,
		Currency	INT,
		ProductCode	VARCHAR(10),
		BetCount	INT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY
	)
	CREATE TABLE #BettypeProduct (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))
	CREATE TABLE #SporttypeProduct (SportType SMALLINT, ProductCode VARCHAR(10))

	CREATE TABLE #Exchange (
		ExFromDate	SMALLDATETIME,
		ExToDate	SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME

	SELECT @FDate = @FromDate,
		@TDate = @ToDate

	-- Get AgentList
	BEGIN 
		DECLARE @tempAg TABLE (CustId INT, Currency INT)

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
				ErrMsg = N'Parameter invalid.'

			RETURN
		END CATCH;
	END

	-- Get SportBettypeMatrix
	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @ShowBA BIT = 0,
		@ShowSB BIT = 0

	SELECT @ShowBA = CASE WHEN ',' + @ProductList + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END
	SELECT @ShowSB = CASE WHEN ',' + @ProductList + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	-- Insert Bettype
	INSERT INTO #BettypeProduct (BetType, ProductCode)		-- Don't have ProductCode IN (BT, CO)
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 911, 912, 913, 914, 4299, 4300, 17000, 17001, 17002, 4298, 4297)		-- Exclude PP Promotion Prize, Saba Promotion Prize

	-- Insert Sport Type
	INSERT INTO #SporttypeProduct (SportType, ProductCode )		-- Don't have ProductCode IN (BT, CO)
	SELECT DISTINCT SportType, ProductCode
	FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
	-----End Get SportBettypeMatrix

	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TDate = @ToDate

		IF @FromDate <= @MoveBetsDay
			SET @FDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @FDate = @FromDate
		
		IF EXISTS (SELECT TOP(1) 1 FROM #BettypeProduct)	-- exclude BT, CO
		BEGIN
			INSERT INTO #Subsidiary (
				WinLostDate,
				Recommend,
				Currency,
				ProductCode,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL)
			SELECT
				b.winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 'BA'
					ELSE p.ProductCode
				END AS ProductCode,
				COUNT(b.transid) AS BetCount,
				SUM(b.stake) AS Turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				- SUM(CASE
						WHEN p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
						ELSE b.winlost - b.actual_stake
					END) AS LicenseeWL
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS a ON b.recommend = a.custid 
				INNER JOIN #BettypeProduct AS p ON p.bettype = b.bettype
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.statusID IN (112, 113)
					OR (@IncludeRaw = 1 AND b.statusID = 111))
				AND b.matchid > 0
				AND (CASE
						WHEN @ShowBA = 0 AND p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
						WHEN @ShowSB = 0 AND p.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
						ELSE 1
					END <> 0)
			GROUP BY
				b.winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 'BA'
					ELSE p.ProductCode
				END
		END
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @FDate = @FromDate

		IF @ToDate >= @MoveBetsDay
			SET @TDate = @MoveBetsDay
		ELSE
			SET @TDate = @ToDate

		IF EXISTS (SELECT TOP(1) 1 FROM #BettypeProduct)		-- exclude BT, CO
		BEGIN
			INSERT INTO #Subsidiary (
				WinLostDate,
				Recommend,
				Currency,
				ProductCode,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL)
			SELECT
				b.winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.isBA = 1 THEN 'BA'
					ELSE p.ProductCode
				END AS ProductCode,
				SUM(b.BetCount) AS BetCount,
				SUM(b.turnover) AS Turnover,
				SUM(b.winlost) AS Winlost,
				- SUM(CASE
						WHEN p.ProductCode = 'SB' AND b.isBA = 1 THEN 0
						ELSE b.winlost
					END) AS LicenseeWL
			FROM bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
				INNER JOIN #SporttypeProduct AS p ON b.sporttype = p.sporttype
				INNER JOIN @TempAg AS a ON b.recommend = a.custid
			WHERE
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.bettype NOT IN (4299, 4300, 17000, 17001, 17002, 4298, 4297)		-- Exclude PP Promotion Prize, Saba Promotion Prize
				AND b.roleid = 1
				AND (b.statusID IN (112, 113, 114, 115)
					OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
				AND (b.isBA = 0 OR (b.isBA = 1 AND @ShowBA = 1))
				AND (CASE
						WHEN @ShowBA = 0 AND p.ProductCode = 'SB' AND b.isBA = 1 THEN 0
						WHEN @ShowSB = 0 AND p.ProductCode = 'SB' AND b.isBA = 0 THEN 0
						ELSE 1
					END <> 0)
			GROUP BY
				b.Winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.isBA = 1 THEN 'BA'
					ELSE p.ProductCode
				END
		END
	END

	;WITH Currency_CTE (CurrencyID) AS (
											SELECT DISTINCT currency
											FROM @tempAg
										)
	INSERT INTO #Exchange (
		ExFromDate,
		ExToDate,
		ExchangeId,
		Rate)
	SELECT
		e.FromDate,
		e.ToDate,
		e.ExchangeID,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') e
		INNER JOIN Currency_CTE c ON e.ExchangeId = c.CurrencyID

	SELECT
		s.Recommend,
		s.Currency,
		s.ProductCode,
		SUM(s.BetCount)		AS BetCount,
		SUM(s.Turnover)		AS Turnover,
		SUM(s.WinLost)		AS Winlost,
		SUM(s.LicenseeWL)	AS LicenseeWL,
		SUM(s.Turnover		* e.Rate)	AS TurnoverBase,
		SUM(s.WinLost		* e.Rate)	AS WinlostBase,
		SUM(s.LicenseeWL	* e.Rate)	AS LicenseeWLBase
	FROM
		#Subsidiary AS s
		INNER JOIN #Exchange AS e ON s.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND s.currency = e.ExchangeId
	GROUP BY
		s.recommend,
		s.currency,
		s.ProductCode

	DROP TABLE #Subsidiary
	DROP TABLE #Exchange
	DROP TABLE #BettypeProduct
	DROP TABLE #SporttypeProduct
END
GO
