/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_GetLicenseeWLByPlatform]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@BaseCurrency	VARCHAR(3) = ''
AS

/*
	Created: 20170119@Joseph
	Task: Dashboard API
	DB: DBEXT.bodb02

	Revisions:
		- 20170119@Joseph: Copy from Lrf_Rpt_PlatformWinloss [RedmineID: #70616]
		- 20170323@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]
		- 20170802@Sophia: Add new Flatfrom [redmine: #80687]
		- 20170814@Alex  : Restrict permission by currency  [RedmineID: #80855]
		- 20171020@Harper: LRF - Add "New Asia" in platform list [RedmineID: #85203]
		- 20181113@Joseph: New betfrom Mobile App (o) [RedmineID: #104587]
		- 20181212@Joseph: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181211@Joseph: New betfrom Mobile China View (c) [RedmineID: #106088]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190903@Amanda: Remove platform y,s and add platform t [RedmineID: #119010]
		- 20191115@Merlin: Get data by AgentList instead of LicenseeID and CurrentcyList[RedmineID: #123651]
		- 20191219@Amanda: Add platform v [RedmineID: #125553]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20191226@Vickie: Add platform 0 and change ID platform v[RedmineID: #125824]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20210330@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210407@Kos: Split data of God Of Fortune in rptLicWinloss2 [RedmineID: #152908]
		- 20210518@Mark: Support multiple selection on Platform filter [Redmine: #153102]
*/

/*
	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[Lrf_GetLicenseeWLByPlatform]
			@FromDate = '11-11-2019',
			@ToDate = '11-15-2019',
			@AgentList = N'<ROOT><Agent AgentId="14551801" Currency="45"/><Agent AgentId="14554801" Currency="45"/><Agent AgentId="836224" Currency="2"/><Agent AgentId="860386" Currency="2"/><Agent AgentId="2812961" Currency="2"/></ROOT>'

	SELECT	'Return Value' = @return_value
*/

BEGIN
	SET NOCOUNT ON;

	IF DATEDIFF(MONTH,@FromDate,@ToDate) > 0
		RETURN;

	CREATE TABLE #WinLoss (
		WinLostDate		SMALLDATETIME,
		Currency		INT,
		PlatformType	TINYINT,
		LicenseeWL		MONEY
	);

	DECLARE @TempFromDate SMALLDATETIME,
			@TempToDate SMALLDATETIME, 
			@FDate SMALLDATETIME,
			@TDate SMALLDATETIME;
	
	DECLARE @DocHandler INT

	CREATE TABLE #TempAg (CustId INT, Currency INT);

	CREATE CLUSTERED INDEX ix_tempAg_cl ON #TempAg (Currency, CustId);
	
	--to Deal WITH Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate;

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

	CREATE TABLE #PlatformList (BetFrom NVARCHAR(1), PlatformType TINYINT);

	INSERT INTO #PlatformList (BetFrom, PlatformType)
	SELECT betfrom, PlatformType
	FROM Lrf_f_BetFromType_Sel('All')

	CREATE TABLE #Exchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT);

	INSERT INTO #Exchange (FromDate, ToDate, ExchangeID, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') ex
	WHERE EXISTS (SELECT 1 FROM #TempAg c WHERE ex.ExchangeID = c.Currency)

	DECLARE @MoveBetsDay SMALLDATETIME;

	DECLARE @MoveBetTable AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME);

	INSERT INTO @MoveBetTable (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay;

	SELECT TOP(1) @MoveBetsDay = MoveBetsDay
	FROM @MoveBetTable;

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
			LicenseeWL)
		SELECT
			b.winlostdate,
			tma.currency,
			pl.PlatformType,
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #tempAg AS tma ON tma.CustID = b.recommend AND b.currency = tma.currency
			INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
		WHERE b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype < 31
				OR (b.bettype BETWEEN 121 AND 999)
				OR (b.Bettype BETWEEN 1301 AND 1399) --new tennis's bettypes
				OR (b.Bettype BETWEEN 9001 AND 9399) --E-Sports 2.0
				OR (b.Bettype BETWEEN 9400 AND 9699) -- Cricket AIO
				OR b.Bettype = 38					 -- Single Match Parlay
			)
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
			AND b.tpositiontaking <> 0
		GROUP BY
			b.winlostdate,
			tma.currency,
			pl.PlatformType;
	END

	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay;
		ELSE
			SET @TempToDate = @TDate;

		INSERT INTO #WinLoss (Winlostdate, Currency, PlatformType, LicenseeWL)
		SELECT
			b.winlostdate,
			b.currency,
			pl.PlatformType,
			- SUM(b.winlost) AS LicenseeWL
		FROM bodb_licenseereport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
			INNER JOIN #tempAg AS ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			INNER JOIN #PlatformList AS pl ON pl.betfrom = b.betfrom
		WHERE b.winlostdate BETWEEN @FDate AND @TempToDate
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.sporttype = 0		-- Sportsbook
			AND b.bettype IN (0, -29)
			AND (b.isBA = 0 OR b.isBA IS NULL)
		GROUP BY
			b.currency,
			b.winlostdate,
			pl.PlatformType;
	END

	SELECT
		w.PlatformType,
		SUM(LicenseeWL * e.Rate) AS LicenseeWL
	FROM #WinLoss AS w
		INNER JOIN #Exchange AS e ON w.Currency = e.exchangeid AND w.Winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY w.PlatformType
	ORDER BY w.PlatformType;

	DROP TABLE #Exchange;
	DROP TABLE #WinLoss;
	DROP TABLE #tempAg;
END
GO
