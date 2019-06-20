/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_ColossusBetsWinloss] 
	@FromDate				SMALLDATETIME
	, @ToDate				SMALLDATETIME
	, @MoveBetsDay			SMALLDATETIME
	, @ReportType			TINYINT = 1
	, @AgentList			VARCHAR(MAX)
	, @TicketType			INT = -1
	, @BaseCurrency			VARCHAR(3) = ''
	, @DefaultBaseCurrency	VARCHAR(3) = ''
AS
	
/*  
	Created: Jim
	Date: 2016-09-16
    Task : Colossus Bets report [RedminID : #63785]
    DB: DBEXT.bodb02  
    Revisions:  
		- 20161121@Sophia: Correct fomular CashOutAmount,WinPrizeAmount value [RedmineID : #67473]
		- 20161205@Jim:  Report should include only WLD tickets [RedminID : #68316]
		- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20180305@Harper: Implement CB free play ticket [RedmineID: #90768]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180809@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]
		- 20190617@Amanda: Add Base currency param [RedmineID: #112531]

	Param's Explanation:  
	   - @excludeTest: remove currency UUS
	   - @ReportType : 1 Daily, 2 Monthly
	   - @TicketType : -1: ALL, 0: Money Play, 1: Free Play, 
*/
/*
 exec Lrf_Rpt_ColossusBetsWinloss 
 @LicenseeID=1
,@CurrencyID=0
,@FromDate='2016-04-01 00:00:00'
,@ToDate='2016-09-30 00:00:00'
, @MoveBetsDay ='2016-09-01 00:00:00'
,@excludeTest=0
,@UserId=10
*/
SET NOCOUNT ON

BEGIN
	---Section 1 : DECLARE VARIABLE
	DECLARE @_FromDate	SMALLDATETIME
		, @_ToDate		SMALLDATETIME
		, @TempFromDate SMALLDATETIME
		, @TempToDate	SMALLDATETIME

	DECLARE @tempAg AS TABLE (
		custID		INT
		, currency	INT
	)

	CREATE TABLE #tmpRawData (
		rptDate			DATETIME
		, CurrencyID	INT
		, TurnOver		MONEY
		, TotalTrans	INT
		, WinningPrize	MONEY
		, CashOutAmt	MONEY
		, CashInAmt		MONEY
		, CommAmt		MONEY
		, GrandAmt		MONEY
	)
	
	CREATE TABLE #TempExchange(FromDate DATETIME, ToDate DATETIME, ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)

	---Section 2 : INIT VARIABLE
	SELECT @_FromDate = @FromDate
		, @_ToDate = @ToDate

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @tempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	---Section 2 :RETRIEVE RAW DATA
	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate

		DECLARE @tmpGrandAmt AS TABLE (
			Refno BIGINT
			,rptDate DATETIME
			, CustID INT
			, GrandAmt MONEY
			)

		INSERT INTO @tmpGrandAmt (
			Refno
			,rptDate
			, CustID
			, GrandAmt
			)
		SELECT Refno
			, winlostdate
			, CustID
			, SUM(WinAmount) AS GrandAmt
		FROM DBACC.bodb02.dbo.PayoutTrans p WITH (NOLOCK)
		WHERE productId = 204
			AND p.winlostdate BETWEEN @TempFromDate	AND @_ToDate
		GROUP BY CustID
			, winlostdate
			,Refno

		DECLARE @tmpBettrans AS TABLE (
			refno			BIGINT
			, winlostdate	DATETIME
			, Currency		INT
			, TurnOver		MONEY
			, TotalTrans	INT
			, Winlost		MONEY
			, Actual_stake	MONEY
			, STATUS		NVARCHAR(20)
			, GrandAmt		MONEY
			)

		INSERT INTO @tmpBettrans (
			refno
			, winlostdate
			, Currency
			, TurnOver
			, TotalTrans
			, Winlost
			, Actual_stake
			, STATUS
			, GrandAmt
			)
		SELECT b.refno
			, b.winlostdate
			, b.Currency
			, SUM(ABS(b.Stake)) TurnOver
			, COUNT(DISTINCT b.refno) TotalTrans
			, b.Winlost
			, b.Actual_stake
			, b.STATUS
			, SUM(a.GrandAmt) AS GrandAmt
		FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN @tempAg t
			ON b.recommend = t.CustID
				AND b.Currency = t.Currency
		LEFT JOIN @tmpGrandAmt a
			ON b.CustID = a.CustID
				AND b.winlostdate = a.rptDate
				AND b.transid = a.refno
		WHERE b.bettype = 18000
			AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID IN (111,112,113)	
			AND (@TicketType = -1 OR ISNULL(b.currency2, 0) = @TicketType)
		GROUP BY b.refno
			, b.winlostdate
			, b.Currency
			, b.Winlost
			, b.Actual_stake
			, b.STATUS

		INSERT INTO #tmpRawData (
			rptDate
			, CurrencyID
			, TurnOver
			, TotalTrans
			, WinningPrize
			, CashOutAmt
			, CashInAmt
			, CommAmt
			, GrandAmt
			)
		SELECT b.winlostdate AS rptDate
			, b.Currency
			, 0 TurnOver
			, COUNT(DISTINCT b.refno) TotalTrans
			, SUM(CASE 
					WHEN (b.winlost - b.actual_stake ) < 0 AND b.status  = 'WON' 
						THEN 0
					ELSE CASE 
							WHEN bm.bettype IN (
									18004
									, 18005
									, 18006
									)
								THEN bm.Winlost - bm.stake
							ELSE 0
							END
					END) AS WinningPrize
			, SUM(CASE 
					WHEN (b.winlost - b.actual_stake ) < 0 AND b.status  = 'WON'
						THEN 0
					ELSE CASE 
							WHEN bm.bettype = 18002
								THEN bm.winlost - bm.stake
							ELSE 0
							END
					END) AS CashOutAmt
			, SUM(CASE 
					WHEN bm.bettype = 18002
						THEN bm.acomm
					ELSE 0
					END) AS CashInAmt
			, SUM(CASE 
					WHEN bm.bettype = 18001
						THEN bm.acomm
					ELSE 0
					END) CommAmt
			, 0 AS GrandAmt
		FROM @tmpBettrans b
		INNER JOIN dbo.bettransm bm WITH (NOLOCK)
			ON b.refno = bm.refno
		WHERE bm.bettype BETWEEN 18001
				AND 18006
			AND bm.statusID IN (111,112,113)		
		GROUP BY b.Currency
			, b.winlostdate;

		WITH cte_TO
		AS (
			SELECT Currency
				, winlostdate
				, SUM(TurnOver) TurnOver
				,SUM(GrandAmt) GrandAmt
			FROM @tmpBettrans
			GROUP BY Currency
				, winlostdate
			)
		UPDATE d
		SET TurnOver = s.TurnOver
			,GrandAmt = s.GrandAmt
		FROM #tmpRawData d
		INNER JOIN cte_TO s
			ON d.CurrencyID = s.Currency
				AND d.rptDate = s.Winlostdate
	END

	IF @_FromDate <= @MoveBetsDay
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate

		DECLARE @tmpCust AS TABLE (CustID INT)

		INSERT INTO @tmpCust (CustID)
		SELECT c.CustID
		FROM Customer c WITH (NOLOCK)
		INNER JOIN @tempAg t
			ON c.recommend = t.CustID AND c.roleid = 1

		INSERT INTO #tmpRawData (
			rptDate
			, CurrencyID
			, TurnOver
			, TotalTrans
			, WinningPrize
			, CashOutAmt
			, CashInAmt
			, CommAmt
			, GrandAmt
			)
		SELECT b.rptDate
			, b.CurrencyId
			, SUM(b.TurnOver)
			, SUM(b.TotalTrans)
			, SUM(b.WinningPrize)
			, SUM(b.CashOutAmt)
			, SUM(b.CashInShare) AS CashInAmt
			, SUM(b.CommAmt)
			, SUM(b.GrandAmt)
		FROM bodb_licenseeReport.dbo.rpt_BettingColossusBets b WITH (NOLOCK)
		INNER JOIN @tmpCust c
			ON b.CustID = c.CustID
		WHERE rptDate BETWEEN @_FromDate AND @TempToDate
			AND b.statusID IN (111,112,113)	
			AND (@TicketType = -1 OR ISNULL(b.TicketType, 0) = @TicketType)
		GROUP BY b.rptDate
			, b.CustID
			, b.CurrencyId
	END

	----

	IF EXISTS (SELECT TOP (1) 1 FROM #tmpRawData)
	BEGIN
		INSERT INTO #TempExchange(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, @DefaultRate) e
		WHERE EXISTS (SELECT 1 FROM @tempAg a WHERE e.ExchangeID = a.Currency)
	END

	SELECT CASE 
			WHEN @ReportType = 1
				THEN CONVERT(VARCHAR(8), t.rptDate, 112)
			WHEN @ReportType = 2
				THEN CONVERT(VARCHAR(6), t.rptDate, 112)
			ELSE '0'
			END ReportType
		, CurrencyID
		, SUM(TotalTrans) TotalTrans
		
		, CAST(SUM(TurnOver * e.Rate) AS MONEY)		AS TurnOver
		, CAST(SUM(WinningPrize * e.Rate) AS MONEY) AS WinningPrize
		, CAST(SUM(CashOutAmt * e.Rate) AS MONEY)	AS CashOutAmt
		, CAST(SUM(CashInAmt * e.Rate) AS MONEY)	AS CashInAmt
		, CAST(SUM(CommAmt * e.Rate) AS MONEY)		AS CommAmt
		, CAST(SUM(GrandAmt * e.Rate) AS MONEY)		AS GrandAmt
		---USD
		, CAST(SUM(TurnOver * e.USD) AS MONEY)		AS TurnOverUSD
		, CAST(SUM(WinningPrize * e.USD) AS MONEY)	AS WinningPrizeUSD
		, CAST(SUM(CashOutAmt * e.USD) AS MONEY)	AS CashOutAmtUSD
		, CAST(SUM(CashInAmt * e.USD) AS MONEY)		AS CashInAmtUSD
		, CAST(SUM(CommAmt * e.USD) AS MONEY)		AS CommAmtUSD
		, CAST(SUM(GrandAmt * e.USD) AS MONEY)		AS GrandAmtUSD
		---EUR
		, CAST(SUM(TurnOver * e.EUR) AS MONEY)		AS TurnOverEUR
		, CAST(SUM(WinningPrize * e.EUR) AS MONEY)	AS WinningPrizeEUR
		, CAST(SUM(CashOutAmt * e.EUR) AS MONEY)	AS CashOutAmtEUR
		, CAST(SUM(CashInAmt * e.EUR) AS MONEY)		AS CashInAmtEUR
		, CAST(SUM(CommAmt * e.EUR) AS MONEY)		AS CommAmtEUR
		, CAST(SUM(GrandAmt * e.EUR) AS MONEY)		AS GrandAmtEUR
		---GBP
		, CAST(SUM(TurnOver * e.GBP) AS MONEY)		AS TurnOverGBP
		, CAST(SUM(WinningPrize * e.GBP) AS MONEY)	AS WinningPrizeGBP
		, CAST(SUM(CashOutAmt * e.GBP) AS MONEY)	AS CashOutAmtGBP
		, CAST(SUM(CashInAmt * e.GBP) AS MONEY)		AS CashInAmtGBP
		, CAST(SUM(CommAmt * e.GBP) AS MONEY)		AS CommAmtGBP
		, CAST(SUM(GrandAmt * e.GBP) AS MONEY)		AS GrandAmtGBP
		---Base Currency
		, CAST(SUM(TurnOver * e.DefaultRate) AS MONEY)		AS TurnOverBase
		, CAST(SUM(WinningPrize * e.DefaultRate) AS MONEY)	AS WinningPrizeBase
		, CAST(SUM(CashOutAmt * e.DefaultRate) AS MONEY)	AS CashOutAmtBase
		, CAST(SUM(CashInAmt * e.DefaultRate) AS MONEY)		AS CashInAmtBase
		, CAST(SUM(CommAmt * e.DefaultRate) AS MONEY)		AS CommAmtBase
		, CAST(SUM(GrandAmt * e.DefaultRate) AS MONEY)		AS GrandAmtBase
	FROM #tmpRawData t
	INNER JOIN #TempExchange e
		ON t.rptDate BETWEEN e.FromDate AND e.ToDate
			AND t.CurrencyId = e.ExchangeID
	GROUP BY CASE 
			WHEN @ReportType = 1
				THEN CONVERT(VARCHAR(8), t.rptDate, 112)
			WHEN @ReportType = 2
				THEN CONVERT(VARCHAR(6), t.rptDate, 112)
			ELSE '0'
			END
		, CurrencyID
	ORDER BY CASE 
			WHEN @ReportType = 1
				THEN CONVERT(VARCHAR(8), t.rptDate, 112)
			WHEN @ReportType = 2
				THEN CONVERT(VARCHAR(6), t.rptDate, 112)
			ELSE '0'
			END

	DROP TABLE #tmpRawData
	DROP TABLE #TempExchange		
END

GO
