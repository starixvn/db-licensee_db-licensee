/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummary]	
	@LicenseeID		INT,
	@ProductCodes	VARCHAR(MAX) = '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Liveindicator	INT = 1,
	@AgentList		VARCHAR(MAX)
AS 
/*
Created: 20111031@Henry
Task : Live Report Summary
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
	- 20180418@Amanda: LAP - Update VB bet type range and integrate PP [RedmineID: #92381]

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

EXEC [Lrf_Rpt_LiveReportSummary] @LicenseeId = 1, @CurrencyID = 0, @FromDate=@DateFrom, @ToDate=@DateTo, @MoveBetsDay = @MoveBetsDay, @ProductCode= NULL

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
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH; 

	CREATE TABLE #LicenseeList(LicenseeID INT, Currency INT)

	CREATE CLUSTERED INDEX IX_LicenseeList_cl ON #LicenseeList(LicenseeID, Currency)

	INSERT INTO #LicenseeList(LicenseeID, Currency)
	SELECT DISTINCT LicenseeID, Currency
	FROM bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK)
	WHERE EXISTS(
			SELECT 1
			FROM @TempAg t
			WHERE t.CustId = lc.CustID
				AND t.Currency = lc.Currency
		)
	
	IF @ProductCodes IS NULL
		SET @ProductCodes = ''
		
	CREATE TABLE #ProductCodes (ProductCode VARCHAR(10))

	INSERT INTO #ProductCodes (ProductCode)
	SELECT	ISNULL(Val,'') 	
	FROM	dbo.strSplit(@ProductCodes,',')  
	
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
				SELECT transid FROM bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK)
					INNER JOIN @TempAg t ON BA.recommend = t.CustId
				UNION SELECT NULL
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
		END

		--RB
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'RB'))
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT
				b.winlostdate,
				t.currency,
				'RB' AS ProductCode,
				SUM(CASE WHEN b.bettype IN (33, 43)	AND liveawayscore = 0 THEN stake / 2 ELSE stake	END) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				SUM(b.awinlost) AS LicenseeWL,
				SUM(comm) AS Comm,
				SUM(playercomm) AS PlayerComm,
				- SUM((b.winlost - b.actual_stake + awinlost + comm)) AmountDueTo3rd,
				COUNT(b.transid) BetCount
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND b.bettype BETWEEN 31 AND 33
				AND b.statusID IN (111, 112, 113)
				AND (b.liveindicator = @Liveindicator OR @Liveindicator = 2)
			GROUP BY
				b.winlostdate,
				t.currency,
				b.bettype
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
					b.bettype < 31
					OR (b.bettype BETWEEN 121 AND 999)
					OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
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
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode  IN ('', 'NG', 'RB', 'VS', 'BG', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP'))			
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT
				b.winlostdate,
				t.currency,
				CASE 
					WHEN b.bettype BETWEEN 81 AND 120 THEN 'NG'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype = 73	THEN 'BG'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN' -- Keno
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1049 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4300 THEN 'PP' -- PP
					END AS ProductCode,
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
				AND b.bettype NOT IN (31, 32, 33)
				AND b.statusID IN (111, 112, 113)
				AND (
					b.bettype BETWEEN 81 AND 120
					OR b.bettype BETWEEN 1201 AND 1299
					OR b.bettype IN (73) -- BINGO
					OR b.bettype BETWEEN 1501 AND 1599 -- Keno
					OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999) -- RNG CASINO
					OR b.bettype BETWEEN 4001 AND 4100 -- Voidbridge
					OR b.bettype BETWEEN 1011 AND 1020 -- FW
					OR b.bettype BETWEEN 2401 AND 2499 -- AB
					OR (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) -- BetRadar VS
					OR b.bettype BETWEEN 1021 AND 1049 -- LT
					OR b.bettype BETWEEN 4101 AND 4300 -- PP
				)
				AND (b.liveindicator = @Liveindicator OR @Liveindicator = 2)
			GROUP BY
				b.winlostdate,
				t.currency,
				CASE 
					WHEN b.bettype BETWEEN 81 AND 120 THEN 'NG'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype = 73	THEN 'BG'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN' -- Keno
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN (b.bettype BETWEEN 2701 AND 2798) OR (b.bettype BETWEEN 2800 AND 2829) THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1049 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4300 THEN 'PP' -- PP
				END
			END
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate

		---- BA		
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

		----Others
		IF EXISTS (SELECT 1 FROM #ProductCodes WHERE ProductCode IN ('', 'NG', 'SB', 'RB', 'VS', 'BG', 'KN', 'CS', 'VB', 'FW', 'AB', 'VS2', 'LT', 'PP')	)
		BEGIN
			INSERT INTO #tmpWinloss
			SELECT 
				b.rptDate,
				b.currencyID,
				CASE 
					WHEN b.bettype BETWEEN 81 AND 120 THEN 'NG'
					WHEN (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399)) THEN 'SB'
					WHEN b.bettype BETWEEN 31 AND 33 THEN 'RB'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype = 73	THEN 'BG'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN'
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN b.bettype BETWEEN 2701 AND 2829 THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1049 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4300 THEN 'PP' -- PP
				END AS ProductCode,
				SUM(b.turnover * CASE WHEN b.bettype = 33 AND b.status IN (114, 115) THEN 0.5 ELSE 1 END) turnover,
				SUM(b.winloss) winlost,
				SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.WinlossA ELSE -1 * b.winloss END) AS LicenseeWL,
				SUM(b.CommissionA) Comm,
				SUM( b.CommissionP) PlayerComm,
				- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,
				SUM(b.betcount) BetCount
			FROM
				bodb_licenseereport.dbo.rpt_Betting b WITH ( NOLOCK )
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
				AND (b.bettype <= 33
					OR b.bettype BETWEEN 121 AND 999
					OR b.Bettype BETWEEN 1301 and 1399 
					OR b.bettype BETWEEN 81 AND 120
					OR b.bettype BETWEEN 1201 AND 1299
					OR b.bettype IN (73) -- BINGO
					OR b.bettype BETWEEN 1501 AND 1599 -- Keno
					OR (b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999) -- RNG CASINO
					OR b.bettype BETWEEN 4001 AND 4100 -- Voidbridge
					OR b.bettype BETWEEN 1011 AND 1020 -- FW
					OR b.bettype BETWEEN 2401 AND 2499 -- AB
					OR b.bettype BETWEEN 2701 AND 2829 -- VS2
					OR b.bettype BETWEEN 1021 AND 1049 -- LT
					OR b.bettype BETWEEN 4101 AND 4300 -- PP
					)
			GROUP BY
				b.rptDate,
				b.currencyID,
				CASE 
					WHEN b.bettype BETWEEN 81 AND 120 THEN 'NG'
					WHEN (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999) OR (b.Bettype BETWEEN 1301 and 1399)) THEN 'SB'
					WHEN b.bettype BETWEEN 31 AND 33 THEN 'RB'
					WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
					WHEN b.bettype = 73	THEN 'BG'
					WHEN b.bettype BETWEEN 1501 AND 1599 THEN 'KN'
					WHEN b.bettype = 71 OR b.bettype BETWEEN 2101 AND 2399 OR b.bettype BETWEEN 2901 AND 2999 THEN 'CS' -- RNG CASINO
					WHEN b.bettype BETWEEN 4001 AND 4100 THEN 'VB' -- Voidbridge
					WHEN b.bettype BETWEEN 1011 AND 1020 THEN 'FW' -- Fishing World
					WHEN b.bettype BETWEEN 2401 AND 2499 THEN 'AB' -- AllBet
					WHEN b.bettype BETWEEN 2701 AND 2829 THEN 'VS2'
					WHEN b.bettype BETWEEN 1021 AND 1049 THEN 'LT'
					WHEN b.bettype BETWEEN 4101 AND 4300 THEN 'PP'
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
	WHERE  ProductCode NOT IN (SELECT ProductCode FROM #ProductCodes)
	---------------------------------

	CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	--WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss)

	SELECT
		ProductCode,
		CASE ProductCode
			WHEN 'BA' THEN 'BA'
			WHEN 'RB' THEN 'Racing'
			WHEN 'NG' THEN 'Number Game'
			WHEN 'VS' THEN 'Virtual Sports'
			WHEN 'BG' THEN 'Bingo'
			WHEN 'KN' THEN 'Keno'
			WHEN 'CS' THEN 'RNG Casino'
			WHEN 'VB' THEN 'Voidbridge'
			WHEN 'FW' THEN 'Fishing World'
			WHEN 'AB' THEN 'AllBet'
			WHEN 'VS2' THEN 'Virtual Sports 2'
			WHEN 'LT' THEN 'Lottery'
			WHEN 'PP' THEN 'PP'
			ELSE 'Sportsbook'
			END AS ProductName,
		SUM(TurnOver) AS Turnover,
		SUM(Winlost) AS Winlost,
		SUM(LicenseeWL) AS LicenseeWL,
		SUM(Comm) AS Comm,
		SUM(playercomm) AS PlayerComm,
		SUM(AmtDueto3rd) AS AmtDueto3rd,
		SUM(Betcount) AS Betcount,
		--BaseEUR  
		CAST(SUM(TurnOver * e.EUR) AS MONEY) AS TurnoverEUR,
		CAST(SUM(Winlost * e.EUR) AS MONEY) AS WinlostEUR,
		CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR,
		CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,
		CAST(SUM(playercomm * e.EUR) AS MONEY) AS PlayerCommEUR,
		CAST(SUM(AmtDueto3rd * e.EUR) AS MONEY) AS AmtDueto3rdEUR,
		-- BaseUSD
		CAST(SUM(TurnOver * e.USD) AS MONEY) AS TurnoverUSD,
		CAST(SUM(Winlost * e.USD) AS MONEY) AS WinlostUSD,
		CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD,
		CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD,
		CAST(SUM(playercomm * e.USD) AS MONEY) AS PlayerCommUSD,
		CAST(SUM(AmtDueto3rd * e.USD) AS MONEY) AS AmtDueto3rdUSD,
		-- BaseGBP
		CAST(SUM(TurnOver * e.GBP) AS MONEY) AS TurnoverGBP,
		CAST(SUM(Winlost * e.GBP) AS MONEY) AS WinlostGBP,
		CAST(SUM(LicenseeWL * e.GBP) AS MONEY) AS LicenseeWLGBP,
		CAST(SUM(Comm * e.GBP) AS MONEY) AS CommGBP,
		CAST(SUM(playercomm * e.GBP) AS MONEY) AS PlayerCommGBP,
		CAST(SUM(AmtDueto3rd * e.GBP) AS MONEY) AS AmtDueto3rdGBP		
	FROM
		#tmpWinloss b
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
	WHERE b.ProductCode IS NOT NULL
	GROUP BY ProductCode
	ORDER BY ProductName

	DROP TABLE #tmpWinloss
	DROP TABLE #TempExchange
	DROP TABLE #ProductCodes
	DROP TABLE #LicenseeList

END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportSummary] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportSummary] TO [vnteam]