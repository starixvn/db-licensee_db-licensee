USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_ColossusBetsWinloss_Detail] @LicenseeID INT
	, @Currency INT = 0
	, @UserID INT
	, @FromDate SMALLDATETIME
	, @ToDate SMALLDATETIME
	, @MoveBetsDay SMALLDATETIME
	, @CurrencyID INT = 0
	, @excludeTest BIT = 0
	, @ReportType TINYINT = 1
AS
/*  Created: Jim
	Date: 2016-09-16
    Task : Colossus Bets report [RedminID : #63785]
    DB: DBEXT.bodb02  
    Revisions:  
		-  
	Param's Explanation:  
	   - @excludeTest: remove currency UUS
	   - @ReportType : 1 Daily, 2 Monthly
*/
/*
 exec Lrf_Rpt_ColossusBetsWinloss_detail 
 @LicenseeID=1
,@CurrencyID=6
,@FromDate='20160919'
,@ToDate='20160919'
, @MoveBetsDay ='2016-09-01 00:00:00'
,@excludeTest=0
,@UserId=10

*/
SET NOCOUNT ON

BEGIN
	---Section 1 : DECLARE VARIABLE
	DECLARE @_FromDate SMALLDATETIME
		, @_ToDate SMALLDATETIME
		, @TempFromDate SMALLDATETIME
		, @TempToDate SMALLDATETIME
		, @VNDCurrencyName VARCHAR(20)
	DECLARE @tempAg AS TABLE (
		custID INT
		, currency INT
		)
	DECLARE @tmpRawData AS TABLE (
		rptDate DATETIME
		, CustID INT
		, CurrencyID INT
		, TurnOver MONEY
		, TotalTrans INT
		, WinningPrize MONEY
		, CashOutAmt MONEY
		, CashInAmt MONEY
		, CommAmt MONEY
		, GrandAmt MONEY
		)

	---Section 2 : INIT VARIABLE
	SELECT @_FromDate = @FromDate
		, @_ToDate = @ToDate

	SELECT @VNDCurrencyName = currency
	FROM dbo.Exchange WITH (NOLOCK)
	WHERE ExchangeId = 51

	SELECT currencyID
		, LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1) -- System is default=1 (LRF)
	WHERE (
			@CurrencyID = 0
			OR (
				@CurrencyID <> 0
				AND CurrencyID = @CurrencyID
				)
			)

	INSERT INTO @tempAg (
		custID
		, currency
		)
	SELECT DISTINCT lc.custID
		, lc.currency
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
	INNER JOIN #Currency c
		ON lc.LicenseeID = c.LicenseeID
			AND lc.Currency = c.CurrencyID
	WHERE (
			@excludeTest = 0
			OR (
				@excludeTest = 1
				AND Currency <> 20
				)
			)

	---Section 2 :RETRIEVE RAW DATA
	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate

		DECLARE @tmpGrandAmt AS TABLE (
			rptDate DATETIME
			, CustID INT
			, GrandAmt MONEY
			)

		INSERT INTO @tmpGrandAmt (
			rptDate
			, CustID
			, GrandAmt
			)
		SELECT winlostdate
			, CustID
			, SUM(WinAmount) AS GrandAmt
		FROM DBACC.bodb02.dbo.PayoutTrans p WITH (NOLOCK)
		WHERE productId = 204
			AND p.winlostdate BETWEEN @TempFromDate
				AND @_ToDate
		GROUP BY CustID
			, winlostdate

		DECLARE @tmpBettrans AS TABLE (
			CustID INT
			, refno BIGINT
			, winlostdate DATETIME
			, Currency INT
			, TurnOver MONEY
			, TotalTrans INT
			, Winlost MONEY
			, STATUS NVARCHAR(20)
			, GrandAmt MONEY
			)

		INSERT INTO @tmpBettrans (
			CustID
			, refno
			, winlostdate
			, Currency
			, TurnOver
			, TotalTrans
			, Winlost
			, STATUS
			, GrandAmt
			)
		SELECT b.CustID
			, b.refno
			, b.winlostdate
			, b.Currency
			, SUM(ABS(b.Stake)) TurnOver
			, COUNT(DISTINCT b.refno) TotalTrans
			, b.Winlost
			, b.STATUS
			, SUM(a.GrandAmt) AS GrandAmt
		FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN @tempAg t
			ON b.recommend = t.CustID
				AND b.Currency = t.Currency
		LEFT JOIN @tmpGrandAmt a
			ON b.CustID = a.CustID
				AND b.winlostdate = a.rptDate
		WHERE b.bettype = 18000
			AND b.winlostdate BETWEEN @TempFromDate
				AND @_ToDate
		GROUP BY b.CustID
			, b.refno
			, b.winlostdate
			, b.Currency
			, b.Winlost
			, b.STATUS

		INSERT INTO @tmpRawData (
			rptDate
			, CustID
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
			, b.CustID
			, b.Currency
			, 0 TurnOver
			, COUNT(DISTINCT b.refno) TotalTrans
			, SUM(CASE 
					WHEN b.winlost = 0
						THEN 0
					ELSE CASE 
							WHEN bm.bettype IN (
									18004
									, 18005
									, 18006
									)
								AND b.STATUS = 'WON'
								THEN bm.Winlost - bm.stake
							ELSE 0
							END
					END) AS WinningPrize
			, SUM(CASE 
					WHEN b.winlost = 0
						THEN 0
					ELSE CASE 
							WHEN bm.bettype = 18002
								AND b.STATUS = 'WON'
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
			, SUM(b.GrandAmt) AS GrandAmt
		FROM @tmpBettrans b
		INNER JOIN dbo.bettransm bm WITH (NOLOCK)
			ON b.refno = bm.refno
		WHERE bm.bettype BETWEEN 18001
				AND 18006
		GROUP BY b.CustID
			, b.Currency
			, b.winlostdate;

		WITH cte_TO
		AS (
			SELECT CustID
				, Currency
				, winlostdate
				, SUM(TurnOver) TurnOver
			FROM @tmpBettrans
			GROUP BY CustID
				, Currency
				, winlostdate
			)
		UPDATE d
		SET TurnOver = s.TurnOver
		FROM @tmpRawData d
		INNER JOIN cte_TO s
			ON d.CurrencyID = s.Currency
				AND d.rptDate = s.Winlostdate
				AND d.CustID = s.CustID
	END

	IF @_FromDate <= @MoveBetsDay
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate

		DECLARE @tmpCust AS TABLE (CustID INT)

		INSERT INTO @tmpCust (CustID)
		SELECT lci.CustID
		FROM DBLIC.bodb_licensee.dbo.LicenseeCustInfo lci WITH (NOLOCK)
		INNER JOIN @tempAg t
			ON lci.recommend = t.CustID

		INSERT INTO @tmpRawData (
			rptDate
			, CustID
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
			, b.CustID
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
		WHERE rptDate BETWEEN @_FromDate
				AND @TempToDate
		GROUP BY b.rptDate
			, b.CustID
			, b.CurrencyId
	END

	----
	DROP TABLE #currency

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@_FromDate, @_ToDate)
	WHERE exchangeid IN (
			SELECT DISTINCT CurrencyID
			FROM @tmpRawData
			)

	SELECT t.CustID
		, CASE 
			WHEN @ReportType = 1
				THEN CONVERT(VARCHAR(8), t.rptDate, 112)
			WHEN @ReportType = 2
				THEN CONVERT(VARCHAR(6), t.rptDate, 112)
			ELSE '0'
			END ReportType
		, c.username SystemId
		, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS ExternalID
		, CurrencyID
		, CASE 
			WHEN CurrencyID = 51
				THEN @VNDCurrencyName
			WHEN CurrencyID = 70
				THEN 'MKK'
			ELSE e.Code
			END AS currencyName
		, SUM(TurnOver) TurnOver
		, SUM(TotalTrans) TotalTrans
		, SUM(WinningPrize) WinningPrize
		, SUM(CashOutAmt) CashOutAmt
		, SUM(CashInAmt) CashInAmt
		, SUM(CommAmt) CommAmt
		, SUM(GrandAmt) GrandAmt
		---USD
		, CAST(SUM(TurnOver * e.USD) AS MONEY) TurnOverUSD
		, CAST(SUM(WinningPrize * e.USD) AS MONEY) WinningPrizeUSD
		, CAST(SUM(CashOutAmt * e.USD) AS MONEY) CashOutAmtUSD
		, CAST(SUM(CashInAmt * e.USD) AS MONEY) CashInAmtUSD
		, CAST(SUM(CommAmt * e.USD) AS MONEY) CommAmtUSD
		, CAST(SUM(GrandAmt * e.USD) AS MONEY) GrandAmtUSD
		---EUR
		, CAST(SUM(TurnOver * e.EUR) AS MONEY) TurnOverEUR
		, CAST(SUM(WinningPrize * e.EUR) AS MONEY) WinningPrizeEUR
		, CAST(SUM(CashOutAmt * e.EUR) AS MONEY) CashOutAmtEUR
		, CAST(SUM(CashInAmt * e.EUR) AS MONEY) CashInAmtEUR
		, CAST(SUM(CommAmt * e.EUR) AS MONEY) CommAmtEUR
		, CAST(SUM(GrandAmt * e.EUR) AS MONEY) GrandAmtEUR
		---GBP
		, CAST(SUM(TurnOver * e.GBP) AS MONEY) TurnOverGBP
		, CAST(SUM(WinningPrize * e.GBP) AS MONEY) WinningPrizeGBP
		, CAST(SUM(CashOutAmt * e.GBP) AS MONEY) CashOutAmtGBP
		, CAST(SUM(CashInAmt * e.GBP) AS MONEY) CashInAmtGBP
		, CAST(SUM(CommAmt * e.GBP) AS MONEY) CommAmtGBP
		, CAST(SUM(GrandAmt * e.GBP) AS MONEY) GrandAmtGBP
	FROM @tmpRawData t
	INNER JOIN #TempExchange e
		ON t.rptDate = e.ExchangeDate
			AND t.CurrencyId = e.ExchangeID
	INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK)
		ON t.custid = c.custid
	GROUP BY t.CustID
		, CASE 
			WHEN @ReportType = 1
				THEN CONVERT(VARCHAR(8), t.rptDate, 112)
			WHEN @ReportType = 2
				THEN CONVERT(VARCHAR(6), t.rptDate, 112)
			ELSE '0'
			END
		, CurrencyID
		, c.username
		, c.username2
		, CASE 
			WHEN CurrencyID = 51
				THEN @VNDCurrencyName
			WHEN CurrencyID = 70
				THEN 'MKK'
			ELSE e.Code
			END

	DROP TABLE #TempExchange
END
GO

GRANT EXECUTE
	ON [dbo].[Lrf_Rpt_ColossusBetsWinloss_Detail]
	TO [bodbLicenseeNet]
GO

GRANT VIEW DEFINITION
	ON [dbo].[Lrf_Rpt_ColossusBetsWinloss_Detail]
	TO [vnteam]
