/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportWinlossByMatch]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@ShowBA			BIT				= 0,
	@SportId		INT				= 0,
	@LiveIndicator	INT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20111031@
	Task: Live Report Summary by Sport
	DB: DBEXT.bodb02

	Revisions:
		- 20120110@Henry: remove @LicenseeType + enhance performance + remove currency UUS
		- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120726@Jim: add player commission value 
		- 20120820@Jim : add live casino
		- 20120830@Henry: split column for clearer + Add Virtual Sports
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20130618@Jim:  Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS 
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150612@Jim: support MicroGaming
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20151001@Jim: remove MicroGaming
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180808@Amanda: Remove bet type related to Racing [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20220211@Kos: Integrate Cricket AIO phase 2 [RedmineID: #168034]
					- Remove input params @showSB, @ShowVS, @showVS2
					- Add input param @ProductList VARCHAR(500)
					- Don't return BetType, ShowTime, AmountDueTo3rd column anymore
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20241701@Evan: Merge VS1, VS2, VS3 as VS only [RedmineID: #199523]

	Param's Explanation:
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
		+ @SportId: Not includes mixparlay, outright, numbergame, horseracing
		+ @LiveIndicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (CustId, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	DECLARE @ShowSB	BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'
		
	SELECT @ProductList = STRING_AGG(b.ProductPrefix, ',')
	FROM (
		SELECT DISTINCT ISNULL(b.ProductPrefix,p.ProductPrefix) AS ProductPrefix
		FROM STRING_SPLIT(@ProductList, ',') a
			INNER JOIN dbo.Products p WITH (NOLOCK) ON a.Value = p.ProductPrefix
			LEFT JOIN dbo.Lrf_f_GroupProduct() b ON p.ProductID = b.GroupProductId
	) b

	-- Get bettype list
	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE EventType = 1
		AND BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME,
		@FDate				SMALLDATETIME,
		@TDate				SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate,
		@TDate = @ToDate

	CREATE TABLE #Data (
		WinLostDate	SMALLDATETIME,
		Currency	TINYINT,
		Bettype		INT,
		MatchId		INT,
		HomeId		INT,
		AwayId		INT,
		BetCount	INT,
		TurnOver	MONEY,
		Winlost		MONEY,
		LicenseeWL	MONEY,
		Comm		MONEY,
		PlayerComm	MONEY
	)

	-- bettrans range
	IF @TDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @FDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @FDate
							END

		INSERT INTO #Data
		SELECT
			b.winlostdate,
			b.currency,
			b.bettype,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END AS MatchId,
			m.homeid,
			m.awayid,
			COUNT(b.transid) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
					ELSE b.winlost - b.actual_stake
				END) AS LicenseeWL,
			SUM(b.comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @BetType AS bt ON bt.bettype = b.bettype
			INNER JOIN @TempAg AS ag ON ag.CustId = b.recommend
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)
			AND m.sporttype = @SportId
			AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.liveindicator = 1)
				OR (@LiveIndicator = 2))
			AND CASE
					WHEN @ShowBA = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
					WHEN @ShowSB = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
					ELSE 1
				END <> 0
		GROUP BY
			b.winlostdate,
			b.currency,
			b.bettype,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END,
			m.homeid,
			m.awayid
	END

	-- bettrans14 range
	IF @FDate <= @MoveBetsDay 
	BEGIN
		SET @TempToDate = CASE
							WHEN @TDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @TDate
						END

		INSERT INTO #Data
		SELECT
			b.winlostdate,
			b.currency,
			b.bettype,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END AS MatchId,
			m.homeid,
			m.awayid,
			COUNT(b.transid) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
					ELSE b.winlost - b.actual_stake
				END) AS LicenseeWL,
			SUM(b.comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @BetType AS bt ON bt.bettype = b.bettype
			INNER JOIN @TempAg AS ag ON ag.CustId = b.recommend
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.matchid
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
			AND m.sporttype = @SportId
			AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.liveindicator = 1)
				OR (@LiveIndicator = 2))
			AND CASE
					WHEN @ShowBA = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
					WHEN @ShowSB = 0 AND bt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
					ELSE 1
				END <> 0
		GROUP BY
			b.winlostdate,
			b.currency,
			b.bettype,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END,
			m.homeid,
			m.awayid
	END

	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM #Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') e
		WHERE EXISTS (SELECT 1 FROM #Data AS a WHERE e.ExchangeID = a.Currency)
	END

	SELECT
		b.matchid,
		b.homeid,
		b.awayid,
		SUM(b.BetCount) AS BetCount,
		CAST(SUM(b.TurnOver		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(b.Winlost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(b.LicenseeWL	* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(b.Comm			* e.Rate) AS MONEY) AS Comm,
		CAST(SUM(b.PlayerComm	* e.Rate) AS MONEY) AS PlayerComm
	FROM #Data AS b WITH (NOLOCK)
		INNER JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FromDate AND e.ToDate AND e.ExchangeId = b.Currency
	GROUP BY
		b.matchid,
		b.homeid,
		b.awayid

	DROP TABLE #Data
END
GO
