/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_GetLicenseeTurnoverByPlatform]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(100),
	@BaseCurrency	VARCHAR(12) = ''
AS

/*
	Created: 20170207@Paul
	DB: DBEXT.bodb02
	Original: Lrf_Rpt_PlatformWinloss

	Revisions:
		- 20170207@Paul: Create new [RedmineID: #70616]
		- 20170323@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]
		- 20170802@Sophia: Add new Flatfrom [redmine: #80687]
		- 20170814@Alex  : Restrict permission by currency [RedmineID: #80855]
		- 20171020@Harper: LRF - Add "New Asia" in platform list [RedmineID: #85203]
		- 20181113@Joseph: New betfrom Mobile App (o) [RedmineID: #104587]
		- 20181212@Joseph: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181211@Joseph: New betfrom Mobile China View (c) [RedmineID: #106088]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190903@Amanda: Remove platform y,s and add platform t [RedmineID: #119010]
		- 20191115@Merlin: Get data by AgentList instead of LicenseeID and CurrentcyList [RedmineID: #123651]
		- 20191219@Amanda: Add platform v [RedmineID: #125553]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20191226@Vickie: Add platform 0 and change ID platform v [RedmineID: #125824]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20210330@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210407@Kos: Split data of God Of Fortune in rptLicWinloss2 [RedmineID: #152908]
		- 20210518@Mark: Support multiple selection on Platform filter [Redmine: #153102]
		- 20210622@Mark: Change on MoveBet - Add param MoveBetsDay [RedmineID: #154866]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
					- Add new input param @ProductList VARCHAR(100)
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		
	Param explanation:
		- @ProductList: SB and all products grouped under SB (SB,SLT,...)
*/

BEGIN
	SET NOCOUNT ON;

	IF DATEDIFF(MONTH, @FromDate, @ToDate) > 0
		RETURN;

	-- Get agent list
	DECLARE @DocHandler INT

	CREATE TABLE #TempAg (CustId INT, Currency INT);

	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId);

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	-- Get sport type list
	DECLARE @SportType TABLE (SportType INT PRIMARY KEY, ProductCode VARCHAR(10))

	INSERT INTO @SportType (SportType, ProductCode)
	SELECT DISTINCT SportType, ProductCode
	FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)

	-- Get bettype list
	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode)
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904)

	-- Get platform list
	CREATE TABLE #PlatformList (betfrom NVARCHAR(1) PRIMARY KEY, PlatformType TINYINT);

	INSERT INTO #PlatformList (betfrom, PlatformType)
	SELECT betfrom, PlatformType
	FROM Lrf_f_BetFromType_Sel('All')

	CREATE TABLE #WinLoss (
		WinLostDate		SMALLDATETIME,
		Currency		INT,
		PlatformType	TINYINT,
		Turnover		MONEY
	);

	DECLARE @TempFromDate SMALLDATETIME,
			@TempToDate SMALLDATETIME,
			@FDate SMALLDATETIME,
			@TDate SMALLDATETIME;

	--to Deal WITH Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate;

	-- bettrans range
	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay);
		ELSE
			SET @TempFromDate = @FDate;

		INSERT INTO #WinLoss (
			WinLostDate,
			Currency,
			PlatformType,
			Turnover)
		SELECT
			b.winlostdate,
			tma.currency,
			pl.PlatformType,
			SUM(b.stake) AS Turnover
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS tma ON tma.CustID = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
			INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
		WHERE b.statusID IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.tpositiontaking <> 0
		GROUP BY
			b.winlostdate,
			tma.currency,
			pl.PlatformType;
	END

	-- bettrans14 range
	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay;
		ELSE
			SET @TempToDate = @TDate;

		INSERT INTO #WinLoss (
			WinLostDate,
			Currency,
			PlatformType,
			Turnover)
		SELECT
			b.winlostdate,
			b.currency,
			pl.PlatformType,
			SUM(b.turnover) AS Turnover
		FROM bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS ag ON ag.CustId = b.recommend
			INNER JOIN @SportType AS s ON s.SportType = b.sporttype
			INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
		WHERE b.winlostdate BETWEEN @FDate AND @TempToDate
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype IN (0, -29)
			AND (b.isBA = 0 OR b.isBA IS NULL)
		GROUP BY
			b.currency,
			b.winlostdate,
			pl.PlatformType
	END

	-- Get exchange rate
	CREATE TABLE #Exchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT);

	INSERT INTO #Exchange (
		FromDate,
		ToDate,
		ExchangeId,
		Rate)
	SELECT
		ex.FromDate,
		ex.ToDate,
		ex.ExchangeId,
		ex.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') ex
	WHERE EXISTS (SELECT 1 FROM #TempAg AS c WHERE ex.ExchangeID = c.Currency);

	-- Return result
	SELECT
		w.PlatformType,
		SUM(w.Turnover * e.Rate) AS Turnover
	FROM #WinLoss AS w
		INNER JOIN #Exchange AS e ON w.Currency = e.exchangeid AND w.Winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY w.PlatformType
	ORDER BY w.PlatformType;

	DROP TABLE #Exchange
	DROP TABLE #WinLoss
	DROP TABLE #TempAg
END
GO
