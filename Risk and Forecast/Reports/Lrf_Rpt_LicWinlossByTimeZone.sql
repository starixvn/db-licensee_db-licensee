/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinlossByTimeZone]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@TimeZone		SMALLINT		= -4,
	@ProductList	VARCHAR(MAX)	= '',
	@CurrencyId		INT				= 0,
	@IncludeDraw	BIT				= 0,
	@ReportBy		TINYINT			= 1,
	@GroupBy		TINYINT			= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20171201@Sophia
	Date: 2012-01-09
	Task: Winloss Report for Licensee by Time Zone [Redmine: #84932]
	DB: DBEXT.bodb02

	Revisions:
		- 20171201@Sophia: initial version. Apply for Sportsbook first [redmine: #84932]
		- 20171226@Percy: Remove redundant code [RedmineID: #88704] 
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20190614@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190910@Amanda: Add bet types that support Half Won/ Half Lose [RedmineID: #118300]
		- 20190923@Amanda: Change the way to handle Half Won/ Half Lose bet types [RedmineID: #119879]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20220429@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20240311@Eddie: Change 'bodbLicenseeNet' to 'wsv_lap' account [RedmineID: #201098]

	Param's Explanation:
		+ @TimeZone: = -4: GMT-4
					= 8: GMT+8
		+ @ProductCodes: = @ProductCodes (multiple selection) ('SB', 'BA')
 		+ @MoveBetsDay: The day we move tickets to bettrans14
		+ @ReportBy: = 1: Summary
					= 2: Daily
					= 3: Monthly
		+ @GroupBy: = 1: Product
					= 2: Currency
		+ @IncludeDraw: = 0:
		+ @CurrencyId : = 0: All Currency
						= @CurrencyId (Single selection)
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12346" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)
	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId);

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
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #WinLoss (
		RptDateGMT		DATE,
		RptDate			DATE,
		CurrencyId		INT,
		ProductCode		VARCHAR(10),
		BetCount		BIGINT,
		Turnover		MONEY,
		LicenseeWL		MONEY,
		PlayerComm		MONEY,
		LicenseeComm	MONEY
	)

	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR(10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

	-- Get sportbettype matrix
	CREATE TABLE #BetTypeProduct (BetType INT PRIMARY KEY, ProductCode VARCHAR(10), EventType TINYINT)
	CREATE TABLE #SportTypeProduct (SportType INT PRIMARY KEY, ProductCode VARCHAR(10))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID) 

	-- Insert Bettype
	INSERT INTO #BetTypeProduct (BetType, ProductCode, EventType)		--- Don't have ProductCode IN (BA, BT, CO) because SportBettypeMatrix don't have ProductPrefix = 'BA'
	SELECT DISTINCT BetType, ProductPrefix, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE Bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
		AND Bettype NOT IN (SELECT BetType FROM @ExcludedBetType e WHERE e.ProductCode = ProductPrefix)

	-- Insert Sport Type
	INSERT INTO #SportTypeProduct (SportType, ProductCode)   --- Don't have ProductCode IN (BA, BT, CO)
	SELECT DISTINCT SportType, ProductCode
	FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)

	----------------- ######## Get data ########## ---------------
	DECLARE @FromDateLicWL2 SMALLDATETIME, @ToDateLicWL2 SMALLDATETIME, 
			@FromDateBettrans SMALLDATETIME, @ToDateBettrans SMALLDATETIME

	DECLARE @HWHLCutDate SMALLDATETIME = '2019-10-01' -- half won/ half lose cut date

	--------------## I: Begin :TimeZone = -4 ## -------------
	IF @TimeZone = -4  
	BEGIN
		---#I.1: Begin : Get data from rptLicWinloss2 table
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SELECT @FromDateLicWL2 = @FromDate 

			IF @ToDate > @MoveBetsDay
				SELECT @ToDateLicWL2 = @MoveBetsDay
			ELSE 
				SELECT @ToDateLicWL2 = @ToDate

			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA 
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					b.winlostdate,
					b.winlostdate,
					a.currency,
					'BA' AS ProductCode,
					SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.Turnover ELSE 0 END
						*
						CASE WHEN @IncludeDraw = 0 THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.statusID IN (114, 115) THEN 0.5
								ELSE 1 END
						ELSE 1 END) AS Turnover, 
					0 AS LicenseeWL,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
					INNER JOIN #TempAg AS a ON b.recommend = a.custID
				WHERE 
					b.winlostdate BETWEEN @FromDateLicWL2 AND @ToDateLicWL2
					AND b.roleid = 2
					AND b.statusID IN (111, 112, 113, 114, 115) --exclude REJECT bets
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.isBA = 1
				GROUP BY
					b.winlostdate,
					a.currency
			END

			IF EXISTS (SELECT 1 FROM #BetTypeProduct WHERE ProductCode = 'SB')	-- exclude BA , BT, CO
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					b.winlostdate,
					b.winlostdate,
					b.currency,
					'SB' AS ProductCode,
					SUM(b.betcount) AS BetCount,
					SUM(b.turnover) AS Turnover,
					SUM(b.winlost) AS LicenseeWL,
					SUM(b.PlayerComm) AS PlayerComm,
					SUM(b.comm) AS LicenseeComm
				FROM (
						SELECT
							b.winlostdate,
							a.currency,
							b.sporttype,
							SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
								*
								CASE WHEN @IncludeDraw = 0 THEN
									CASE
										WHEN b.statusID = 111 THEN 0
										WHEN b.statusID IN (114, 115) THEN 0.5
										ELSE 1 END
								ELSE 1 END) AS Turnover, 
							-SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost,
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END) AS PlayerComm,
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS Comm
						FROM bodb_licenseereport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
							INNER JOIN #TempAg AS a ON b.recommend = a.custID
						WHERE
							b.winlostdate BETWEEN @FromDateLicWL2 AND @ToDateLicWL2
							AND b.roleid = 2
							AND b.statusID IN (111, 112, 113, 114, 115) --exclude REJECT bets
							AND (b.bettype < 901 OR b.bettype > 904)
							AND (b.bettype < 911 OR b.bettype > 914)
							AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
							AND b.isBA = 0
						GROUP BY
							b.winlostdate,
							a.currency,
							b.sporttype
					) b
					INNER JOIN #SportTypeProduct AS p ON b.sporttype = p.sporttype
				GROUP BY
					b.winlostdate,
					b.currency
			END
		END
		---#I.1: End : Get data from rptLicWinloss2 table (Old data of SB GMT-4)

		---#I.2: Begin : Get data from Bettrans table after Movebetsday 
		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT @ToDateBettrans = @ToDate

			IF @Fromdate <= @MoveBetsDay
				SELECT @FromDateBettrans = DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SELECT @FromDateBettrans = @Fromdate
			
			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA Product
			BEGIN
				;WITH BA AS
				(
					SELECT DISTINCT transid
					FROM bodb_licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK)
						INNER JOIN #TempAg AS r ON BA.recommend = r.custID
				)
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					b.Winlostdate,
					b.Winlostdate,
					b.Currency,
					'BA' ProductCode,
					COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
						*
						CASE WHEN @IncludeDraw = 0 THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.winlostdate >= @HWHLCutDate
									AND b.statusID IN (112, 113)
									AND b.modds IN (-0.25, 0.25)
									AND b.bettype NOT IN (29, 38, 911, 912, 913, 914) THEN 0.5 -- exclude parlay, bet builder, cashout
								WHEN b.winlostdate < @HWHLCutDate
									AND (b.statusID = 112 OR b.statusID = 113)
									AND ABS(b.modds) = 0.25
									AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
								ELSE 1 END
						ELSE 1 END) AS Turnover, 
					0 AS LicenseeWL,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN #TempAg AS a ON a.CustID = b.recommend
					INNER JOIN BA WITH (NOLOCK) ON b.transid = BA.transid
				WHERE b.winlostdate BETWEEN @FromDateBettrans AND @ToDateBettrans
					AND b.statusID IN (111, 112, 113)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				GROUP BY
					b.winlostdate,
					b.recommend,
					b.currency
			END

			IF EXISTS (SELECT 1 FROM #BettypeProduct WHERE ProductCode = 'SB')  ---- SB exclude BA , BT, CO 
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					b.winlostdate,
					b.winlostdate,
					b.currency,
					'SB' AS ProductCode,
					COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
						*
						CASE WHEN @IncludeDraw = 0 THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.winlostdate >= @HWHLCutDate
									AND b.statusID IN (112, 113)
									AND b.modds IN (-0.25, 0.25)
									AND b.bettype NOT IN (29,38) THEN 0.5 -- exclude parlay, bet builder
								WHEN b.winlostdate < @HWHLCutDate
									AND (b.statusID = 112 OR b.statusID = 113)
									AND ABS(b.modds) = 0.25
									AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
								ELSE 1 END
						ELSE 1 END) AS Turnover,
					- SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END) AS PlayerComm,
					SUM(CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN #TempAg AS a ON b.recommend = a.custid
					INNER JOIN #BettypeProduct AS p ON p.bettype = b.bettype
				WHERE b.winlostdate BETWEEN @FromDateBettrans AND @ToDateBettrans
					AND b.statusID IN (111, 112, 113)
					AND b.matchID > 0
					AND (CASE WHEN p.ProductCode ='SB' THEN b.tpositiontaking ELSE 1 END <> 0 )  --- EXCLUDE BA
				GROUP BY
					b.winlostdate,
					b.currency
			END
		END
		---#I.2: End : Get data from Bettrans table after Movebetsday 
	END 
	---------## I: End :TimeZone = GMT-4 ## -------------

	---------## II: Begin :TimeZone <> GMT-4 ## -------------
	ELSE
	BEGIN
		---#II.1: Begin : Get data from rptLicWinlossGMT table
		BEGIN
			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					b.RptDateGMT,
					b.RptDate,
					a.currency,
					'BA' AS ProductCode,
					SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.Turnover ELSE 0 END
						*
						CASE WHEN @IncludeDraw = 0 THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.statusID IN (114, 115) THEN 0.5
								ELSE 1 END
						ELSE 1 END) AS Turnover,
					0 AS LicenseeWL,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM bodb_LicenseeReport.dbo.rptLicWinlossGMT AS b WITH (NOLOCK)
					INNER JOIN #TempAg AS a ON b.recommend = a.custID  
				WHERE 
					b.RptDateGMT BETWEEN @FromDate AND @ToDate
					AND b.TimeZone = @TimeZone
					AND b.RptDate <= @MoveBetsDay
					AND b.roleid = 2
					AND b.statusID IN (111, 112, 113, 114, 115) --exclude REJECT bets
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
					AND b.isBA = 1
				GROUP BY
					b.RptDateGMT,
					b.RptDate,
					a.currency
			END

			IF EXISTS (SELECT 1 FROM #BettypeProduct WHERE ProductCode = 'SB')     --- exclude BA , BT, CO
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					b.RptDateGMT,
					b.RptDate,
					b.currency,
					'SB' AS ProductCode,
					SUM (b.betcount) AS BetCount,
					SUM (b.turnover) AS Turnover,
					SUM (b.winlost) AS LicenseeWL,
					SUM(b.PlayerComm) AS PlayerComm,
					SUM(b.Comm) AS LicenseeComm
				FROM (
						SELECT
							b.RptDateGMT,
							b.RptDate,
							a.currency,
							b.sporttype,
							SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
								*
								CASE WHEN @IncludeDraw = 0 THEN
									CASE
										WHEN b.statusID = 111 THEN 0
										WHEN b.statusID IN (114, 115) THEN 0.5
										ELSE 1 END
								ELSE 1 END) AS Turnover, 
							-SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost, 
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS Comm
						FROM bodb_licenseereport.dbo.rptLicWinlossGMT AS b WITH (NOLOCK)
							INNER JOIN #TempAg AS a ON b.recommend = a.CustId
						WHERE 
							b.RptDateGMT BETWEEN @FromDate AND @ToDate
							AND b.TimeZone = @TimeZone
							AND b.RptDate <= @MoveBetsDay
							AND b.roleid = 2
							AND b.statusID IN (111, 112, 113, 114, 115) --exclude REJECT bets
							AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
							AND b.isBA = 0
						GROUP BY
							b.RptDateGMT,
							b.RptDate,
							a.Currency,
							b.Sporttype
					) b 
					INNER JOIN #SporttypeProduct AS p ON b.Sporttype = p.sporttype
				GROUP BY
					b.RptDateGMT,
					b.RptDate,
					b.Currency
			END
		END
		---#II.1: End : Get data from rptLicWinlossGMT table 

		---#II.2: Begin : Get data from Bettrans table 
		BEGIN
			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA Product
			BEGIN
				;WITH BA AS
				(
					SELECT DISTINCT transid
					FROM bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
						INNER JOIN #TempAg r ON BA.recommend = r.custID
				)
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))), 
					b.winlostdate,
					b.currency,
					'BA' ProductCode,
					COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
						*
						CASE WHEN @IncludeDraw = 0 THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN b.winlostdate >= @HWHLCutDate
									AND b.statusID IN (112, 113)
									AND b.modds IN (-0.25, 0.25)
									AND b.bettype NOT IN (29, 38, 911, 912, 913, 914) THEN 0.5 -- exclude parlay, bet builder, cashout
								WHEN b.winlostdate < @HWHLCutDate
									AND (b.statusID = 112 OR b.statusID = 113)
									AND ABS(b.modds) = 0.25
									AND b.bettype IN (1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
								ELSE 1 END
						ELSE 1 END) AS Turnover,
					0 AS LicenseeWL,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM dbo.bettrans AS b WITH (NOLOCK)
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.MatchId
					INNER JOIN #TempAg AS a ON a.CustID = b.recommend
					INNER JOIN BA WITH (NOLOCK) ON b.transid = BA.transid
				WHERE CONVERT(DATE, DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))) BETWEEN @FromDate AND @ToDate
					AND b.statusID IN (111, 112, 113)
					AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.winlostdate))),
					b.winlostdate,
					b.recommend,
					b.currency
			END

			INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
			SELECT
				CONVERT(DATE, DATEADD(HOUR, @TimeZone + 4, CASE
																WHEN p.ProductCode = 'SB' AND p.EventType = 1 THEN ISNULL(m.GlobalShowTime, b.winlostdate)
																WHEN p.ProductCode = 'SLT' THEN b.transdate
																WHEN p.ProductCode = 'BTC' THEN ISNULL(m3rd.StartTime, b.winlostdate)
																ELSE b.winlostdate
															END)),
				b.winlostdate,
				b.currency,
				'SB' AS ProductCode,
				COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
					*
					CASE WHEN @IncludeDraw = 0 THEN
						CASE
							WHEN b.statusID = 111 THEN 0
							WHEN b.winlostdate >= @HWHLCutDate
								AND b.statusID IN (112, 113)
								AND b.modds IN (-0.25, 0.25)
								AND b.bettype NOT IN (29, 38) THEN 0.5 -- exclude parlay, bet builder
							WHEN b.winlostdate < @HWHLCutDate
								AND (b.statusID = 112 OR b.statusID = 113)
								AND ABS(b.modds) = 0.25
								AND b.bettype IN(1,3,7,8,17,18,124,125,482,483,484,485) THEN 0.5
							ELSE 1 END
					ELSE 1 END) AS Turnover,
				- SUM(CASE WHEN RAND() + 1 > 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.playercomm ELSE 0 END) AS PlayerComm,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm 
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.recommend = a.custid
				INNER JOIN #BetTypeProduct AS p ON p.BetType = b.bettype
				LEFT JOIN dbo.match AS m WITH (NOLOCK)
					ON p.ProductCode = 'SB'
					AND p.EventType = 1
					AND m.MatchId = b.MatchId
				LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON p.ProductCode = 'BTC' AND m3rd.Match3rdId = b.MatchId
			WHERE CONVERT(DATE, DATEADD(HOUR, @TimeZone + 4, CASE
																WHEN p.ProductCode = 'SB' AND p.EventType = 1 THEN ISNULL(m.GlobalShowTime, b.winlostdate)
																WHEN p.ProductCode = 'SLT' THEN b.transdate
																WHEN p.ProductCode = 'BTC' THEN ISNULL(m3rd.StartTime, b.winlostdate)
																ELSE b.winlostdate
															END)) BETWEEN @FromDate AND @ToDate
				AND b.statusID IN (111, 112, 113)
				AND (CASE WHEN p.ProductCode = 'SB' THEN b.tpositiontaking ELSE 1 END <> 0 )  --- EXCLUDE BA
			GROUP BY
				CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, CASE
																WHEN p.ProductCode = 'SB' AND p.EventType = 1 THEN ISNULL(m.GlobalShowTime, b.winlostdate)
																WHEN p.ProductCode = 'SLT' THEN b.transdate
																WHEN p.ProductCode = 'BTC' THEN ISNULL(m3rd.StartTime, b.winlostdate)
																ELSE b.winlostdate
															END)),
				b.winlostdate,
				b.currency
		END
		---#II.2: End : Get data from Bettrans table
	END
	---------## II: End :TimeZone <> GMT-4 ## -------------
	----------#############################---------------
	 
	-- Get exchange rate
	CREATE TABLE #Exchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM #WinLoss)
	BEGIN
		DECLARE @MinDate SMALLDATETIME,
			@MaxDate SMALLDATETIME

		SELECT @MinDate = MIN(RptDate),
			@MaxDate = MAX(RptDate)
		FROM #WinLoss

		INSERT INTO #Exchange(FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @BaseCurrency, '')
	END

	-- Return result
	SELECT
		CASE
			WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(8), w.RptDateGMT, 112)	-- Daily
			WHEN @ReportBy = 3 THEN CONVERT(VARCHAR(6), w.RptDateGMT, 112)	-- Monthly
			ELSE ''
		END AS ReportBy,  --- Summary
		CASE
			WHEN @GroupBy = 1 THEN CONVERT(VARCHAR(8), w.ProductCode)
			WHEN @GroupBy = 2 THEN CONVERT(VARCHAR(6), w.CurrencyId)
			ELSE '0'
		END AS GroupBy,

		SUM(w.BetCount) AS BetCount,

		SUM(w.Turnover)		AS Turnover,
		SUM(w.PlayerComm)	AS PlayerComm,
		SUM(w.LicenseeWL)	AS LicenseeWL,
		SUM(w.LicenseeComm)	AS LicenseeComm,

		SUM(w.Turnover		* e.Rate) AS TurnoverBase,
		SUM(w.PlayerComm	* e.Rate) AS PlayerCommBase,
		SUM(w.LicenseeWL	* e.Rate) AS LicenseeWLBase,
		SUM(w.LicenseeComm	* e.Rate) AS LicenseeCommBase
	FROM #WinLoss AS w
		LEFT JOIN #Exchange AS e ON e.ExchangeID = w.CurrencyId AND w.RptDate BETWEEN e.FromDate AND e.ToDate
	GROUP BY
		CASE
			WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(8), w.RptDateGMT, 112)	-- Daily
			WHEN @ReportBy = 3 THEN CONVERT(VARCHAR(6), w.RptDateGMT, 112)	-- Monthly
			ELSE ''
		END,
		CASE
			WHEN @GroupBy = 1 THEN CONVERT(VARCHAR(8), w.ProductCode)
			WHEN @GroupBy = 2 THEN CONVERT(VARCHAR(6), w.CurrencyId)
			ELSE '0'
		END
	ORDER BY ReportBy ASC,
		GroupBy ASC

	DROP TABLE #WinLoss
	DROP TABLE #Exchange
END
GO
