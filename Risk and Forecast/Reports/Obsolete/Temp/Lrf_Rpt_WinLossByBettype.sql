/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLossByBettype]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20101201@Jacob
	Task : Report WinLoss
	DB: DB052.bodb02
	Original: Age_Rpt_WinLossByBettype_Ag
	Revisions:
		- 20101201@Jacob: Copy code from Age_Rpt_WinLossByBettype_Ag, remove redundant column
		- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency
		- 20110513@Henry: change bettype to new range
		- 20110616@Henry: Suport filter BA tickets  + add column commission
		- 20110707@Henry: show Comm, Amt Due to for each 3rd party product: BA, Racing
		- 20110802@Henry: Offer 3 new bettypes for Number Game
		- 20111028@Jim: change bettype condition
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily   
		- 20120731@Jim: add Player Comm value 
		- 20120815@Jim: add live casino
		- 20120906@Jim: add virtual sport
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20121225@Henry: enhance performance
		- 20130402@Jim: add support for base currency USD
		- 20130426@Scott: Doesn't support RNG casino and Bingo (bettype : 71,73)
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
		- 20140404@Florent: offer Keno products
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20150415@Jim: change to use f_GroupBettype instead of LRF_view_bettype_SS
		- 20150612@Jim: support MicroGaming
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
		- 20151001@Jim: remove MicroGaming
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20160721@Percy: Enhance Performance - using index srecommend on bettrans [RedmineID: #60770]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180423@Harper: Fix bug group VS2: BasketBall - Virual Soccer [RedmineID: #93844]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20200331@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200715@Louis: Add new bet types for Keno/Lottery/TableGame [RedmineID: #137625]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]
		- 20210330@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210830@Kos: Support subsidiary view [RedmineID: #159576]
		- 20220224@Hogan: Integrate Virtual Sports 3 (Leap Gaming)[RedmineID: #145337]
		- 20220317@Kos: Integrate Cricket phase 2 [RedmineID: #168034]
		- 20210818@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

	Param's Explanation:
		+ @AgentList: XML structure
				<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
				</ROOT>
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
		SELECT ErrCode = 100
				,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #AgWinLoss (
		BetType			INT,
		LiveIndicator	BIT,
		WinLostDate		SMALLDATETIME,
		currency		INT,
		Turnover		MONEY,
		MemberWinLost	MONEY,
		LicenseeWL		MONEY,
		AmtDueToBA		MONEY,
		CommBA			MONEY,
		PlayerComm		MONEY
	)

	DECLARE @RowStart INT
		, @RowEnd INT
		, @TotalRows INT
		, @Today SMALLDATETIME

	SELECT @PageIndex = @PageIndex - 1
		, @RowStart = @PageSize * @PageIndex + 1
		, @RowEnd = @RowStart + @PageSize - 1
		, @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME
	DECLARE @FDate DATETIME
	DECLARE @TDate DATETIME

	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate
		, @TDate = @ToDate

	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

	-- Get sport/bettype matrix
	DECLARE @ProductList VARCHAR(100) = 'SB,NG,VS,VS2,KN,LT,TG,I4D,SLT,BTC'

	DECLARE @BetType TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @BetType (BetType, ProductCode)
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (SELECT BetType FROM @ExcludedBetType AS e WHERE e.ProductCode = ProductPrefix)
		AND BetType NOT IN (71, 73, 901, 902, 903, 904, 911, 912, 913, 914)

	IF @Tdate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		INSERT INTO #AgWinLoss
		SELECT b.bettype
			, CASE
				WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator
			, b.winlostdate
			, b.currency
			, SUM(b.stake)
			, SUM(b.winlost - b.actual_stake) AS MemberWinLost
			, - SUM(CASE
					WHEN ISNULL(BA.transid, 0) = 0 THEN (b.winlost - b.actual_stake)
					ELSE 0
					END) AS LicenseeWL
			, - SUM(CASE
						WHEN ISNULL(BA.transid, 0) <> 0 THEN (b.winlost - b.actual_stake + b.awinlost + b.comm)
						ELSE 0
					END) AS AmountDueToBA
			, SUM(CASE
					WHEN ISNULL(BA.transid, 0) <> 0 THEN comm
					ELSE 0
				END) AS CommBA
			, SUM(b.playercomm) AS PlayerComm
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS ta ON ta.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid	 
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)
		GROUP BY b.bettype
			, CASE
				WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator
				ELSE 0
			END
			,b.winlostdate
			,b.currency
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		IF @BalanceUpDay < @FDate
			SELECT @BalanceUpDay = @FDate

		INSERT INTO #AgWinLoss
		SELECT b.bettype
			, CASE
				WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator
				ELSE 0
			END AS liveindicator
			, b.winlostdate
			, b.currency
			, SUM(b.stake)
			, SUM(b.winlost - b.actual_stake)
			, - SUM(CASE 
					WHEN ISNULL(BA.transid, 0) = 0 THEN (b.winlost - b.actual_stake)
					ELSE 0
				END) AS LicenseeWL
			, - SUM(CASE
						WHEN ISNULL(BA.transid, 0) <> 0 THEN (b.winlost - b.actual_stake + b.awinlost + b.comm)
						ELSE 0
					END) AS AmountDueToBA
			, SUM(CASE
					WHEN ISNULL(BA.transid, 0) <> 0 THEN comm
					ELSE 0
				END) AS CommBA
			, SUM(b.playercomm) AS PlayerComm
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS ta ON ta.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.BetType = b.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
			AND b.statusID IN (111, 112, 113)
		GROUP BY
			b.bettype
			, CASE
				WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator
				ELSE 0
			END
			, b.winlostdate
			, b.currency
	END

	-- Calculate total value
	SELECT @TotalRows = COUNT(DISTINCT BetType)
	FROM #AgWinLoss

	-- Get exchange rate
	DECLARE @Exchange TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT
	)

	INSERT INTO @Exchange (
		FromDate,
		ToDate,
		ExchangeId,
		Rate )
	SELECT
		FromDate,
		ToDate,
		ExchangeId,
		Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT Currency FROM #TempAg AS a WHERE a.Currency = e.ExchangeId)

	-- Return result
	SELECT wl.*
	FROM (
		SELECT CASE WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.grouptypeId
					WHEN ISNULL(vs.Bettype, 0) <> 0 THEN vs.GroupTypeId 
					ELSE b.bettype
				END bettype
			, b.liveindicator
			, CAST(SUM(b.TurnOver		* e.Rate) AS MONEY)	AS TurnOver
			, CAST(SUM(b.MemberWinLost	* e.Rate) AS MONEY)	AS MemberWinLost
			, CAST(SUM(b.LicenseeWL		* e.Rate) AS MONEY)	AS LicenseeWL
			, CAST(SUM(b.CommBA			* e.Rate) AS MONEY)	AS CommBA
			, CAST(SUM(b.PlayerComm		* e.Rate) AS MONEY)	AS PlayerComm
			, CAST(SUM(b.AmtDueToBA		* e.Rate) AS MONEY)	AS AmtDuetoBA
			, ROW_NUMBER() OVER (ORDER BY CASE
											WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.grouptypeId
											WHEN ISNULL(vs.Bettype, 0) <> 0 THEN vs.GroupTypeId 
											ELSE b.bettype
										END
								) AS RowNum
		FROM #AgWinLoss AS b
			LEFT JOIN @Exchange AS e ON b.currency = e.ExchangeId AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			LEFT JOIN dbo.f_GroupBetType3rd() AS vs ON b.bettype = vs.Bettype
		GROUP BY
			CASE
				WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.grouptypeId
				WHEN ISNULL(vs.Bettype, 0) <> 0 THEN vs.GroupTypeId
				ELSE b.bettype
			END,
			b.liveindicator
		) wl
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #AgWinLoss
END
GO
