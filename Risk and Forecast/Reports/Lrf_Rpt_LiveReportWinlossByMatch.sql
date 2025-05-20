/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportWinlossByMatch]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
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
		- 20240830@Lewis: BaseBallAIO - phase 2 [RedmineID: #209344]
		- 20241001@Kelvin: LAP - Integrate BetRadar Virtual Horses & Dogs Racing [RedmineID: #210808]
		- 20241024@Kelvin: LAP - Integrate Betby (VS6) [RedmineID: #212446]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]
		- 20250408@Kelvin: Upgrade ExchangeId Datatype [RedmineID: #222339]

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
	DECLARE @TempAg AS TABLE (CustId INT, Currency SMALLINT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (CustId, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency SMALLINT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;
		
	SELECT @ProductList = STRING_AGG(b.ProductPrefix, ',')
	FROM (
		SELECT DISTINCT ISNULL(b.ProductPrefix,a.Value) AS ProductPrefix
		FROM STRING_SPLIT(@ProductList, ',') a
			LEFT JOIN dbo.Lrf_f_GroupProduct() b ON a.Value = b.GroupProductPrefix
	) b

	-- Get bettype list
	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode, EventType)
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE EventType IN (1, 3, 5)
		AND BetType NOT IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME,
		@FDate				SMALLDATETIME,
		@TDate				SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate,
		@TDate = @ToDate

	CREATE TABLE #Data (
		WinLostDate		SMALLDATETIME,
		Currency		SMALLINT,
		Bettype			INT,
		EventType		TINYINT,
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,		
		VendorMatchId	VARCHAR(50),
		Distance        VARCHAR(50),
		BetCount		INT,
		TurnOver		MONEY,
		Winlost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY
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
			bt.EventType,
			CASE
				WHEN bt.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID				
				ELSE b.matchid
			END AS MatchId,
			CASE 
				WHEN bt.EventType = 1 THEN m.homeid
				WHEN bt.EventType = 5 THEN m3rd.HomeId 
				ELSE 0
			END,
			CASE 
				WHEN bt.EventType = 1 THEN m.awayid
				WHEN bt.EventType = 5 THEN m3rd.AwayId 
				ELSE 0 
			END,		
			CASE WHEN bt.EventType = 3 THEN r.VendorMatchId ELSE '' END,
			CASE WHEN bt.EventType = 3 THEN r.Distance ELSE '' END,
			COUNT(b.transid) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM(b.comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @BetType AS bt ON bt.bettype = b.bettype
			INNER JOIN @TempAg AS ag ON ag.CustId = b.recommend
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid
			LEFT JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = b.matchid
			LEFT JOIN dbo.Match3rd m3rd WITH(NOLOCK) ON m3rd.Match3rdId = b.matchid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)
			AND (CASE WHEN bt.EventType = 1 THEN m.sporttype
			          WHEN bt.EventType = 3 THEN r.SportType
					  WHEN bt.EventType = 5 THEN m3rd.SportType
				 END) = @SportId
			AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.liveindicator = 1)
				OR (@LiveIndicator = 2))
		GROUP BY
			b.winlostdate,
			b.currency,
			b.bettype,
			bt.EventType,
			CASE
				WHEN bt.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE b.matchid
			END,
			CASE 
				WHEN bt.EventType = 1 THEN m.homeid
				WHEN bt.EventType = 5 THEN m3rd.HomeId 
				ELSE 0
			END,
			CASE 
				WHEN bt.EventType = 1 THEN m.awayid
				WHEN bt.EventType = 5 THEN m3rd.AwayId 
				ELSE 0 
			END,		
			CASE WHEN bt.EventType = 3 THEN r.VendorMatchId ELSE '' END,
			CASE WHEN bt.EventType = 3 THEN r.Distance ELSE '' END

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
			bt.EventType,
			CASE
				WHEN bt.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE b.matchid
			END AS MatchId,
			CASE 
				WHEN bt.EventType = 1 THEN m.homeid
				WHEN bt.EventType = 5 THEN m3rd.HomeId 
				ELSE 0
			END,
			CASE 
				WHEN bt.EventType = 1 THEN m.awayid
				WHEN bt.EventType = 5 THEN m3rd.AwayId 
				ELSE 0 
			END,		
			CASE WHEN bt.EventType = 3 THEN r.VendorMatchId ELSE '' END,
			CASE WHEN bt.EventType = 3 THEN r.Distance ELSE '' END,
			COUNT(b.transid) AS BetCount,
			SUM(b.stake) AS Turnover,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM(b.comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @BetType AS bt ON bt.bettype = b.bettype
			INNER JOIN @TempAg AS ag ON ag.CustId = b.recommend
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.matchid
			LEFT JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = b.matchid
			LEFT JOIN dbo.Match3rd14 m3rd WITH(NOLOCK) ON m3rd.Match3rdId = b.matchid
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate
			AND b.statusID IN (111, 112, 113)
			AND (CASE WHEN bt.EventType = 1 THEN m.sporttype
			          WHEN bt.EventType = 3 THEN r.SportType
					  WHEN bt.EventType = 5 THEN m3rd.SportType
				 END) = @SportId
			AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.liveindicator = 1)
				OR (@LiveIndicator = 2))
		GROUP BY
			b.winlostdate,
			b.currency,
			b.bettype,
			bt.EventType,
			CASE
				WHEN bt.EventType = 1 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE b.matchid
			END,
			CASE 
				WHEN bt.EventType = 1 THEN m.homeid
				WHEN bt.EventType = 5 THEN m3rd.HomeId 
				ELSE 0
			END,
			CASE 
				WHEN bt.EventType = 1 THEN m.awayid
				WHEN bt.EventType = 5 THEN m3rd.AwayId 
				ELSE 0 
			END,		
			CASE WHEN bt.EventType = 3 THEN r.VendorMatchId ELSE '' END,
			CASE WHEN bt.EventType = 3 THEN r.Distance ELSE '' END
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
		b.EventType,
		b.homeid,
		b.awayid,
		b.VendorMatchId,
		b.Distance,
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
		b.EventType,
		b.homeid,
		b.awayid,
		b.VendorMatchId,
		b.Distance

	DROP TABLE #Data
END
GO
