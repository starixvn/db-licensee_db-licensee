/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummary]
	@ProductCodes	VARCHAR(MAX) = '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Liveindicator	INT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
AS

/*
	Created: 20111031@Henry
	Task: Live Report Summary
	DB: DBEXT.bodb02

	Revisions:
		- 20111208@Jim: change bettype condition
		- 20120109@Henry: enhance performance + remove @LicenseeType + remove currency UUS
		- 20120214@Jim: change to use  table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		- 20120614@Jim: optimize code 
		- 20120726@Jim: add playercomm value 
		- 20120815@Henry: add Live casino
		- 20120831@Henry: add Virtual Sports
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130328@Scott: Support RNG Casino and Bingo
		- 20130514@Jim:  Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: support Virtual Tennis
		- 20140404@Florent: support Keno product
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150618@Patrick: #36263: Fix super balance isue for: AGC, GD & VG
		- 20150612@Jim: support MicroGaming 
		- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
		- 20151001@Jim: remove MicroGaming
		- 20151228@Bobby: Remove RNG Casino
		- 20151228@Bobby: #50469 - Remove RNG Casino - exclude OneRNG range bettype
		- 20160120@Victor: Fix bug missing bettrade original tickets [Redmine: #51053]
		- 20160218@Bobby: #52428 - Intergate RnG Casino product
		- 20160330@Percy: Support Voidbridge single wallet [Redmine: #55057]
		- 20160519@Jim: HotFix #57810
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20160804@Percy: Enhance Performance - using faster index on bettrans [RedmineID: #60770]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
		- 20170328@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170705@Harper: Hotfix for Cash Out [RedmineID: #79546]
		- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170721@Harper: Hotfix add AB and FW to LiveReport [RedmineID: #80350]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20170814@Harper: One RNG - Offer New Tablet Games [RedmineID: #78424]
		- 20171009@Sophia: Add ProductCode [RedmineID : #82797]
		- 20180205@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180418@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92318]
		- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181101@Amanda: Remove parameter @LicenseeId [Redmine: #103935]
		- 20181127@Paul: Add OPTION(RECOMPILE) [RedmineID: #105398]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190304@Amanda: Integrate PP Promotion Prize [RedmineID: #109471]
		- 20190516@Amanda: Remove hard code for product name [RedmineID: #113398]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
		- 20191121@Amanda: Exclude PP Promotion and Tournament Prize [RedmineID: #123804]
		- 20190312@Amanda: Add new bet types Single Match Parlay (ID: 38) [RedmineID: #108298]
		- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200508@Vickie: Add new bet types for E-Sports 2.0 [RedmineID: #132548]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200715@Louis: Add new bet types for Keno/Lottery/TableGame [RedmineID: #137625]		

	Param's Explanation:
		+ @IsLive : indicate that whether the report will get live data or not
				+ 0: Non - Live data only
				+ 1: Live data only
				+ 2: All

		+ @AgentList: xml structure
						<ROOT>
						<Agent AgentId="12345" Currency="3"/>  
						<Agent AgentId="12345" Currency="5"/>  
						</ROOT> 

	Example:
		DECLARE @DateFrom DATETIME
		DECLARE @DateTo DATETIME
		DECLARE @MoveBetsDay DATETIME
		SELECT @DateFrom = DATEADD(DAY, -15, GETDATE())
		SELECT @DateTo = GETDATE()
		SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)

		EXEC [Lrf_Rpt_LiveReportSummary] @CurrencyID = 0, @FromDate=@DateFrom, @ToDate=@DateTo, @MoveBetsDay = @MoveBetsDay, @ProductCode= NULL
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME,
			@FDate			SMALLDATETIME,
			@TDate			SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate	

	CREATE TABLE #tmpWinloss
	(
		winlostdate DATETIME,
		Currency	INT,
		ProductCode VARCHAR(20),
		TurnOver	MONEY,
		Winlost		MONEY,
		LicenseeWL	MONEY,
		Comm		MONEY,
		PlayerComm	MONEY,
		AmtDueTo3rd MONEY,
		Betcount	INT
	)

	DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT,@AgentList

		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH; 

	CREATE TABLE #LicenseeList(LicenseeID INT, Currency INT)

	CREATE CLUSTERED INDEX IX_LicenseeList_cl ON #LicenseeList(LicenseeID, Currency)

	INSERT INTO #LicenseeList(LicenseeID, Currency)
	SELECT DISTINCT LicenseeID, Currency
	FROM bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK)
	WHERE EXISTS (	SELECT 1
					FROM @TempAg t
					WHERE t.CustId = lc.CustID AND t.Currency = lc.Currency )

	IF @ProductCodes IS NULL
		SET @ProductCodes = ''

	CREATE TABLE #ProductCodes (ProductCode VARCHAR(10))

	INSERT INTO #ProductCodes (ProductCode)
	SELECT ISNULL(Val,'')
	FROM dbo.strSplit(@ProductCodes,',') 
	
	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		--BA
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'BA'))
		BEGIN
			;WITH CTE AS
			(
				SELECT transid
				FROM bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK)
					INNER JOIN @TempAg t ON BA.recommend = t.CustId
				UNION
				SELECT NULL
			)
			INSERT INTO #tmpWinloss
			SELECT
				b.winlostdate,
				t.currency,
				'BA' AS ProductCode,
				SUM(stake) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				0 AS LicenseeWL,
				SUM(comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.custid AND b.Currency = t.Currency 
				INNER JOIN CTE ON b.transid = CTE.TransID
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.statusID IN (111, 112, 113)
				AND (b.liveindicator = @Liveindicator OR @Liveindicator = 2)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY
				b.winlostdate,
				t.currency
			OPTION(RECOMPILE)
		END

		--SB
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'SB'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT
				b.winlostdate,
				t.currency,
				'SB' AS ProductCode,
				SUM(stake) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
				SUM(comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.custid AND b.Currency = t.Currency
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND (
					b.bettype <= 30
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
					OR (b.Bettype BETWEEN 9001 and 9399) -- E-Sports 2.0
					OR b.Bettype = 38					 -- Single Match Parlay
					)
				AND (b.bettype NOT IN (9,29))
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND (b.liveindicator = @Liveindicator OR @Liveindicator = 2)
			GROUP BY
				b.winlostdate,
				t.currency,
				b.bettype
		END

		--parlay for SB
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'SB'))
		BEGIN	
			INSERT INTO #tmpWinloss
			SELECT
				b.winlostdate,
				t.currency,
				'SB' AS ProductCode,
				SUM(stake) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
				SUM(comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.bettype IN (9,29)
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND (b.livehomescore = @Liveindicator OR @Liveindicator = 2)
			GROUP BY
				b.winlostdate,
				t.currency,
				b.bettype
		END

		-- Parlay for VS2
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'VS2'))
		BEGIN	
			INSERT INTO #tmpWinloss
			SELECT
				b.winlostdate,
				t.currency,
				'VS2' AS ProductCode,
				SUM(stake) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
				SUM(comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.bettype = 2799
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND (b.livehomescore = @Liveindicator OR @Liveindicator = 2)
			GROUP BY
				b.winlostdate,
				t.currency,
				b.bettype
		END

		--Others
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'NG', 'VS', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP', 'CC', 'SG', 'VRG', 'TG', 'I4D', 'SXG', 'SBC'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT
				b.winlostdate,
				t.currency,
				CASE 
					WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN 'NG'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN' -- Keno
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1099 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4296 THEN 'PP' -- PP -- exclude 4300, 4299, 4298, 4297
					WHEN b.bettype BETWEEN 1901 AND 1999 THEN 'CC' -- CC
					WHEN b.bettype BETWEEN 4301 AND 4600 THEN 'SG' -- SG
					WHEN b.bettype BETWEEN 4601 AND 4900 THEN 'VRG' -- VRG
					WHEN b.bettype BETWEEN 4901 AND 5000 THEN 'TG' -- TG
					WHEN b.bettype BETWEEN 5001 AND 5099 THEN 'I4D' -- I4D
					WHEN b.bettype BETWEEN 3101 AND 3199 THEN 'SXG' -- SXG
					WHEN b.bettype BETWEEN 1611 AND 1699 THEN 'SBC' -- SBC
					END AS ProductCode,
				SUM(stake) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
				SUM(comm) AS Comm,
				SUM(b.playercomm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) as AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.statusID IN (111, 112, 113)
				AND (
					b.bettype BETWEEN 81 AND 120
					OR b.bettype BETWEEN 8101 AND 8120 -- Number Game: Happy 5
					OR b.bettype BETWEEN 1201 AND 1299
					OR b.bettype BETWEEN 1501 AND 1599 -- Keno
					OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999) -- RNG CASINO
					OR b.bettype BETWEEN 4001 AND 4100 -- Voidbridge
					OR b.bettype BETWEEN 1011 AND 1020 -- FW
					OR b.bettype BETWEEN 2401 AND 2499 -- AB
					OR (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) -- BetRadar VS
					OR b.bettype BETWEEN 1021 AND 1099 -- LT
					OR b.bettype BETWEEN 4101 AND 4296 -- PP -- exclude 4300, 4299, 4298, 4297
					OR b.bettype BETWEEN 1901 AND 1999 -- CC
					OR b.bettype BETWEEN 4301 AND 4600 -- SG
					OR b.bettype BETWEEN 4601 AND 4900 -- VRG
					OR b.bettype BETWEEN 4901 AND 5000 -- TG
					OR b.bettype BETWEEN 5001 AND 5099 -- I4D
					OR b.bettype BETWEEN 3101 AND 3199 -- SXG
					OR b.bettype BETWEEN 1611 AND 1699 -- SBC
				)
				AND (b.liveindicator = @Liveindicator OR @Liveindicator = 2)
			GROUP BY
				b.winlostdate,
				t.currency,
				CASE 
					WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN 'NG'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN' -- Keno
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1099 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4296 THEN 'PP' -- PP -- exclude 4300, 4299, 4298, 4297
					WHEN b.bettype BETWEEN 1901 AND 1999 THEN 'CC' -- CC
					WHEN b.bettype BETWEEN 4301 AND 4600 THEN 'SG' -- SG
					WHEN b.bettype BETWEEN 4601 AND 4900 THEN 'VRG' -- VRG
					WHEN b.bettype BETWEEN 4901 AND 5000 THEN 'TG' -- TG
					WHEN b.bettype BETWEEN 5001 AND 5099 THEN 'I4D' -- I4D
					WHEN b.bettype BETWEEN 3101 AND 3199 THEN 'SXG' -- SXG
					WHEN b.bettype BETWEEN 1611 AND 1699 THEN 'SBC' -- SBC
				END
		END
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		-- BA
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'BA'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT
				b.rptdate,
				b.currencyID,
				'BA' AS ProductCode,
				SUM(b.turnover) turnover,
				SUM(b.winloss) winlost,
				0 AS LicenseeWL,
				SUM(b.CommissionA) Comm,
				SUM( b.CommissionP  ) PlayerComm,
				- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
				SUM(b.betcount) BetCount
			FROM
				bodb_licenseereport.dbo.rpt_Betting_BA b WITH ( NOLOCK )
				INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency
			WHERE
				b.rptDate BETWEEN @FDate AND @TempToDate
				AND b.status NOT IN (-1,103)
				AND
				(
					(@Liveindicator = 0 AND b.IsLive = 0)
					OR (@Liveindicator = 1 AND b.IsLive = 1)
					OR (@Liveindicator = 2)
				)
				AND b.bettype NOT IN (9,29,2799)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY
				b.rptdate,
				b.currencyID
		END

		-- parlay for BA
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'BA'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT
				b.rptdate,
				b.currencyID,
				'BA' AS ProductCode,
				SUM(b.turnover) turnover,
				SUM(b.winloss) winlost,
				0 AS LicenseeWL,
				SUM(b.CommissionA) Comm,
				SUM( b.CommissionP  ) PlayerComm,
				- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
				SUM(b.betcount) BetCount
			FROM
				bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )
				INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency
			WHERE
				b.rptDate BETWEEN @FDate AND @TempToDate
				AND b.status NOT IN (-1,103)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND
				(
					(@Liveindicator = 0 AND b.IsLive = 0)
					OR (@Liveindicator = 1 AND b.IsLive = 1)
					OR (@Liveindicator = 2)
				)
				AND b.isBA = 1
			GROUP BY 
				b.rptdate,
				b.currencyID
		END

		-- Others
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'NG', 'SB', 'VS', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP', 'CC', 'SG', 'VRG', 'TG', 'I4D', 'SXG', 'SBC'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT 
				b.rptDate,
				b.currencyID,
				CASE 
					WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN 'NG'
					WHEN (b.bettype <= 30 
							OR (b.bettype BETWEEN 121 AND 999) 
							OR (b.Bettype BETWEEN 1301 and 1399) 
							OR (b.Bettype BETWEEN 9001 and 9399) 
							OR b.Bettype = 38					 -- Single Match Parlay
						) 
						THEN 'SB'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN'
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN b.bettype BETWEEN 2701 AND 2829 THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1099 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4296 THEN 'PP' -- PP -- exclude 4300, 4299, 4298, 4297
					WHEN b.bettype BETWEEN 1901 AND 1999 THEN 'CC'
					WHEN b.bettype BETWEEN 4301 AND 4600 THEN 'SG' -- SG
					WHEN b.bettype BETWEEN 4601 AND 4900 THEN 'VRG'
					WHEN b.bettype BETWEEN 4901 AND 5000 THEN 'TG'
					WHEN b.bettype BETWEEN 5001 AND 5099 THEN 'I4D'
					WHEN b.bettype BETWEEN 3101 AND 3199 THEN 'SXG' -- SXG
					WHEN b.bettype BETWEEN 1611 AND 1699 THEN 'SBC'
				END AS ProductCode,
				SUM(b.turnover) turnover,
				SUM(b.winloss) winlost,
				- SUM(b.winloss) AS LicenseeWL,
				SUM(b.CommissionA) Comm,
				SUM( b.CommissionP) PlayerComm,
				- SUM(b.winloss + b.WinlossA + b.CommissionA) as AmountDueTo3rd,
				SUM(b.betcount) BetCount
			FROM
				bodb_licenseereport.dbo.rpt_Betting b WITH (NOLOCK)
				INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency
			WHERE
				b.rptDate BETWEEN @FDate AND @TempToDate
				AND b.status NOT IN (-1,103)
				AND
				(
					(@Liveindicator = 0 AND b.IsLive = 0)
					OR (@Liveindicator = 1 AND b.IsLive = 1)
					OR (@Liveindicator = 2)
				)
				AND b.CustomerCategory IN (-1, 1001, 1003)
				AND b.bettype NOT IN (9,29,2799,1700,1800,1900) 
				AND b.bettype NOT BETWEEN 2001 AND 2009 -- Exclude Microgamming (#44084)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND (b.bettype <= 30
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399
					OR b.Bettype BETWEEN 9001 and 9399
					OR b.Bettype = 38				   -- Single Match Parlay
					OR b.bettype BETWEEN 81 AND 120
					OR b.bettype BETWEEN 8101 AND 8120 -- Number Game: Happy 5
					OR b.bettype BETWEEN 1201 AND 1299
					OR b.bettype BETWEEN 1501 AND 1599 -- Keno
					OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999) -- RNG CASINO
					OR b.bettype BETWEEN 4001 AND 4100 -- Voidbridge
					OR b.bettype BETWEEN 1011 AND 1020 -- FW
					OR b.bettype BETWEEN 2401 AND 2499 -- AB
					OR b.bettype BETWEEN 2701 AND 2829 -- VS2
					OR b.bettype BETWEEN 1021 AND 1099 -- LT
					OR b.bettype BETWEEN 4101 AND 4296 -- PP -- exclude 4300, 4299, 4298, 4297
					OR b.bettype BETWEEN 1901 AND 1999 -- CC
					OR b.bettype BETWEEN 4301 AND 4600 -- SG
					OR b.bettype BETWEEN 4601 AND 4900 -- VRG
					OR b.bettype BETWEEN 4901 AND 5000 -- TG
					OR b.bettype BETWEEN 5001 AND 5099 -- I4D
					OR b.bettype BETWEEN 3101 AND 3199 -- SXG
					OR b.bettype BETWEEN 1611 AND 1699 -- SBC
					)
			GROUP BY
				b.rptDate,
				b.currencyID,
				CASE 
					WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN 'NG'
					WHEN b.bettype <= 30 
							OR (b.bettype BETWEEN 121 AND 999) 
							OR (b.Bettype BETWEEN 1301 and 1399) 
							OR (b.Bettype BETWEEN 9001 and 9399) 
							OR b.Bettype = 38					 -- Single Match Parlay
						THEN 'SB'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN'
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN b.bettype BETWEEN 2701 AND 2829 THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1099 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4296 THEN 'PP' -- exclude 4300, 4299, 4298, 4297
					WHEN b.bettype BETWEEN 1901 AND 1999 THEN 'CC'
					WHEN b.bettype BETWEEN 4301 AND 4600 THEN 'SG' -- SG
					WHEN b.bettype BETWEEN 4601 AND 4900 THEN 'VRG'
					WHEN b.bettype BETWEEN 4901 AND 5000 THEN 'TG'
					WHEN b.bettype BETWEEN 5001 AND 5099 THEN 'I4D'
					WHEN b.bettype BETWEEN 3101 AND 3199 THEN 'SXG' -- SXG
					WHEN b.bettype BETWEEN 1611 AND 1699 THEN 'SBC'
				END
		END

		-- parlay for SB
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'SB'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT 
				b.rptDate,
				b.currencyID,
				'SB' AS ProductCode,
				SUM(b.turnover) turnover,
				SUM(b.winloss) winlost,
				SUM(-1 * b.winloss) AS LicenseeWL,
				SUM(b.CommissionA) Comm,
				SUM(b.CommissionP) PlayerComm,
				- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
				SUM(b.betcount) BetCount
			FROM
				bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )
				INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency
			WHERE
				b.rptDate BETWEEN @FDate AND @TempToDate
				AND b.status NOT IN (-1,103)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.Bettype <> 2799
				AND
				(
					(@Liveindicator = 0 AND b.IsLive = 0)
					OR (@Liveindicator = 1 AND b.IsLive = 1)
					OR (@Liveindicator = 2)
				)
				AND b.isBA = 0
			GROUP BY
				b.rptDate,
				b.currencyID
		END

		-- parlay for VS2
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'VS2'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT
				b.rptDate,
				b.currencyID,
				'VS2' AS ProductCode,
				SUM(b.turnover) turnover,
				SUM(b.winloss) winlost,
				SUM(-1 * b.winloss) AS LicenseeWL,
				SUM(b.CommissionA) Comm,
				SUM( b.CommissionP  ) PlayerComm,
				- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
				SUM(b.betcount) BetCount
			FROM
				bodb_LicenseeReport.dbo.rpt_BettingParlay b WITH ( NOLOCK )
				INNER JOIN #LicenseeList l ON b.SiteID = l.LicenseeID AND b.CurrencyID = l.Currency
			WHERE
				b.rptDate BETWEEN @FDate AND @TempToDate
				AND b.status NOT IN (-1,103)
				AND b.Bettype = 2799
				AND
				(
					(@Liveindicator = 0 AND b.IsLive = 0)
					OR (@Liveindicator = 1 AND b.IsLive = 1)
					OR (@Liveindicator = 2)
				)
				AND b.isBA = 0
			GROUP BY
				b.rptDate,
				b.currencyID
		END
	END
	
	----Filter again by ProductCodes
	DELETE #tmpWinloss 
	WHERE ProductCode NOT IN (SELECT ProductCode FROM #ProductCodes)
	---------------------------------

	CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)

	SELECT FromDate, ToDate, ExchangeID, Rate
	INTO #TempExchange
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE e.ExchangeID = a.Currency)

	SELECT
		ProductCode,
		SUM(Betcount) AS Betcount,
		CAST(SUM(TurnOver		* e.Rate) AS MONEY) AS Turnover,
		CAST(SUM(Winlost		* e.Rate) AS MONEY) AS Winlost,
		CAST(SUM(LicenseeWL		* e.Rate) AS MONEY) AS LicenseeWL,
		CAST(SUM(Comm			* e.Rate) AS MONEY) AS Comm,
		CAST(SUM(playercomm		* e.Rate) AS MONEY) AS PlayerComm,
		CAST(SUM(AmtDueto3rd	* e.Rate) AS MONEY) AS AmtDueto3rd
	FROM
		#tmpWinloss b
		INNER JOIN #TempExchange e ON e.ExchangeID = b.currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
	WHERE b.ProductCode IS NOT NULL
	GROUP BY ProductCode
	ORDER BY ProductCode

	DROP TABLE #tmpWinloss
	DROP TABLE #TempExchange
	DROP TABLE #ProductCodes
	DROP TABLE #LicenseeList
END
GO