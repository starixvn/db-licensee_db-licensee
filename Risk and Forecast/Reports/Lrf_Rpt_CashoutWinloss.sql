USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_CashoutWinloss]
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ReportType		TINYINT,
	@AgentList		VARCHAR(MAX)
AS
/*
	Created: 20170330@Harper
	Description: LRF - Implement Cash Out [#71727]
	DB: DBEXT.bodb02 
	Revisions: 

	Param's Explanation:  

	exec Lrf_Rpt_CashoutWinloss @fromdate='2017-04-24 00:00:00',@todate='2017-04-24 00:00:00',@ReportType = 1,@AgentList=N'<ROOT><Agent AgentId="791088" Currency="3"/><Agent AgentId="860379" Currency="6"/><Agent AgentId="2428981" Currency="6"/><Agent AgentId="2812696" Currency="6"/><Agent AgentId="3575140" Currency="6"/><Agent AgentId="4362999" Currency="6"/></ROOT>',@MoveBetsDay='2017-04-20 00:00:00' 
 
*/

SET NOCOUNT ON
BEGIN
	
	DECLARE @FDate SMALLDATETIME,
			@TDate SMALLDATETIME,
			@TempFromDate SMALLDATETIME,
			@TempToDate SMALLDATETIME,
			@VNDCurrencyName VARCHAR(20)

	SELECT @FDate = @FromDate,
		   @TDate = @ToDate
	
	SELECT @VNDCurrencyName = currency
	FROM dbo.Exchange WITH (NOLOCK)
	WHERE ExchangeId = 51	

	DECLARE @DocHandler INT
	DECLARE @tempAg AS TABLE (custID INT, currency INT)

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #Exchange(ExchangeID INT, ExchageDate SMALLDATETIME, Code VARCHAR(5), USD FLOAT, EUR FLOAT, GBP FLOAT)

	INSERT INTO #Exchange(ExchangeID, ExchageDate, Code, USD, EUR, GBP)
	SELECT ExchangeId, exchangedate, Code, USD, EUR, GBP	
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)	

	CREATE TABLE #CashoutCust (CustId INT PRIMARY KEY)

	INSERT INTO #CashoutCust(CustId)
	SELECT CustId FROM bodb02.dbo.f_GetCashoutCustList('ALL', 14) -- Cashout

	CREATE TABLE #TempData (
				rptDate		SMALLDATETIME,
				CurrencyID	INT,
				Bettype		INT, 
				Transid		BIGINT, 
				Refno		BIGINT, 
				Actual_stake MONEY, 
				winlost		MONEY, 
				awinlost	MONEY, 
				transid2	INT,
				CustID		INT,
				CashoutComm	MONEY, 
				TicketPayout MONEY
	)

	DECLARE @Result AS TABLE (
				rptDate			SMALLDATETIME,
				CurrencyID		INT,
				CashoutTime		INT,
				CashoutTicket	INT,
				CashoutValue	MONEY,
				BuyBackAmountSB MONEY,
				BuyBackAmountBA MONEY,
				BuyBackAmount	MONEY,
				TicketPayout	MONEY,
				CashoutComm		MONEY,
				AmountDue_TicketPayout	MONEY,
				AmountDue_Comm			MONEY,
				AmountDue_Total			MONEY
	)

	-- 
	IF @TDate > @MoveBetsDay
	BEGIN
		SELECT @TempFromDate = CASE WHEN @FDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FDate END

		INSERT INTO #TempData ( rptDate ,CurrencyID ,Bettype ,Transid ,Refno ,Actual_stake ,winlost ,awinlost ,transid2)			
		SELECT b.winlostdate, b.currency, b.bettype, b.transid, b.refno, b.actual_stake, b.winlost, b.awinlost, b.transid2
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg ag ON b.recommend = ag.custID AND b.currency = ag.currency
		WHERE b.bettype IN (911, 913)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)

		UPDATE t
		SET CashoutComm = c.awinlost
		FROM #TempData t
			INNER JOIN (
							SELECT c.awinlost, c.Refno 
							FROM #TempData c 
							WHERE c.Bettype = 913
						) c ON t.Transid = c.Refno
		WHERE t.Bettype = 911

		;WITH ticketPayout AS (
								SELECT b.refno, b.winlost AS ticketPayout
								FROM dbo.bettrans b WITH (NOLOCK)		
									INNER JOIN #CashoutCust ctc ON b.CustId = ctc.CustId							
								WHERE b.bettype NOT IN (911, 912, 913, 914)									
									AND b.winlostdate BETWEEN @TempFromDate AND @TDate										
							)
		UPDATE t
		SET t.TicketPayout = ISNULL(p.ticketPayout, 0)
		FROM #TempData t
			INNER JOIN ticketPayout p ON p.refno = t.Transid

		INSERT INTO @Result
		        ( rptDate ,
		          CurrencyID ,
		          CashoutTime ,
		          CashoutTicket ,
		          CashoutValue ,
		          BuyBackAmountSB ,
		          BuyBackAmountBA 
		        )		
		SELECT b.rptDate,
				b.CurrencyID,				
				COUNT (*) AS CashoutTime,
				COUNT(DISTINCT (b.refno)) AS CashoutTicket,
				SUM(b.actual_stake) AS CashoutValue,
				SUM(CASE WHEN b.transid2 = 0 THEN b.winlost ELSE 0 END) AS BuyBackAmountSB,
				SUM(CASE WHEN b.transid2 = 1 THEN b.winlost ELSE 0 END) AS BuyBackAmountBA
		FROM #TempData b
		WHERE b.bettype = 911			
		GROUP BY b.rptDate, b.CurrencyID	
		
	END	

	IF @FDate <= @MoveBetsDay
	BEGIN
		SELECT @TempToDate = CASE WHEN @TDate >= @MoveBetsDay THEN @MoveBetsDay ELSE @TDate END
		
		INSERT INTO @Result
		        ( rptDate ,
		          CurrencyID ,
		          CashoutTime ,
		          CashoutTicket ,
		          CashoutValue ,
		          BuyBackAmountSB ,
		          BuyBackAmountBA ,
				  CashoutComm,
				  TicketPayout
		        )		
		SELECT b.winlostdate, b.Currency
			, SUM(b.NumOfCashoutTrans)
			, SUM(b.NumOfCashoutTicket)
			, SUM(b.CashoutAmount)
			, SUM(b.BuyBackAmt)
			, SUM(b.BABuyBackAmt)
			, SUM(b.CashoutComm)
			, SUM(b.TicketPayout)
		FROM bodb_LicenseeReport.dbo.rptLicCashoutSummary b WITH (NOLOCK)
			INNER JOIN @tempAg ag ON b.Recommend = ag.custID AND b.Currency = ag.currency
		WHERE b.winlostdate BETWEEN @FDate AND @TempToDate
			AND b.RoleID = 1 AND b.ProductID = 25			
		GROUP BY b.winlostdate, b.Currency	
	END

	-- Select Result
	SELECT 
		CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), r.rptDate, 112)
				WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), r.rptDate, 112)
				ELSE '0'
		END AS ReportType
		, r.CurrencyID
		, CASE WHEN r.CurrencyID = 51 THEN @VNDCurrencyName
				WHEN r.CurrencyID = 70 THEN 'MKK'
				ELSE e.Code
		END AS CurrencyName
		, SUM(r.CashoutTime) AS CashoutTime
		, SUM(r.CashoutTicket) AS CashoutTicket
		, SUM(r.CashoutValue) AS CashoutValue
		, SUM(r.BuyBackAmountSB) AS BuyBackAmountSB
		, SUM(r.BuyBackAmountBA) AS BuyBackAmountBA
		, SUM(r.BuyBackAmountSB + r.BuyBackAmountBA) AS BuyBackAmount
		, SUM(r.TicketPayout) AS TicketPayout
		, SUM(r.CashoutComm) AS CashoutComm
		, SUM(r.TicketPayout) AS AmountDue_TicketPayout
		, SUM(r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) AS AmountDue_Comm
		, SUM(r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) AS Amount_Total
		--- USD		
		, CAST(SUM(r.CashoutValue * e.USD) AS MONEY) AS CashoutValueUSD
		, CAST(SUM(r.BuyBackAmountSB * e.USD) AS MONEY) AS BuyBackAmountSBUSD
		, CAST(SUM(r.BuyBackAmountBA * e.USD) AS MONEY) AS BuyBackAmountBAUSD
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.USD) AS MONEY) AS BuyBackAmountUSD
		, CAST(SUM(r.TicketPayout * e.USD) AS MONEY) AS TicketPayoutUSD
		, CAST(SUM(r.CashoutComm * e.USD) AS MONEY) AS CashoutCommUSD
		, CAST(SUM(r.TicketPayout * e.USD) AS MONEY) AS AmountDue_TicketPayoutUSD
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.USD) AS MONEY) AS AmountDue_CommUSD
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.USD) AS MONEY) AS Amount_TotalUSD
		--- EUR		
		, CAST(SUM(r.CashoutValue * e.EUR) AS MONEY) AS CashoutValueEUR
		, CAST(SUM(r.BuyBackAmountSB * e.EUR) AS MONEY) AS BuyBackAmountSBEUR
		, CAST(SUM(r.BuyBackAmountBA * e.EUR) AS MONEY) AS BuyBackAmountBAEUR
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.EUR) AS MONEY) AS BuyBackAmountEUR
		, CAST(SUM(r.TicketPayout * e.EUR) AS MONEY) AS TicketPayoutEUR
		, CAST(SUM(r.CashoutComm * e.EUR) AS MONEY) AS CashoutCommEUR
		, CAST(SUM(r.TicketPayout * e.EUR) AS MONEY) AS AmountDue_TicketPayoutEUR
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.EUR) AS MONEY) AS AmountDue_CommEUR
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.EUR) AS MONEY) AS Amount_TotalEUR
		--- GBP		
		, CAST(SUM(r.CashoutValue * e.GBP) AS MONEY) AS CashoutValueGBP
		, CAST(SUM(r.BuyBackAmountSB * e.GBP) AS MONEY) AS BuyBackAmountSBGBP
		, CAST(SUM(r.BuyBackAmountBA * e.GBP) AS MONEY) AS BuyBackAmountBAGBP
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.GBP) AS MONEY) AS BuyBackAmountGBP
		, CAST(SUM(r.TicketPayout * e.GBP) AS MONEY) AS TicketPayoutGBP
		, CAST(SUM(r.CashoutComm * e.GBP) AS MONEY) AS CashoutCommGBP
		, CAST(SUM(r.TicketPayout * e.GBP) AS MONEY) AS AmountDue_TicketPayoutGBP
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.GBP) AS MONEY) AS AmountDue_CommGBP
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.GBP) AS MONEY) AS Amount_TotalGBP
	FROM @Result r
		INNER JOIN #Exchange e ON r.rptDate = e.ExchageDate AND r.CurrencyID = e.ExchangeID
	GROUP BY 
		CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), r.rptDate, 112)
				WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), r.rptDate, 112)
				ELSE '0'
		END
		, r.CurrencyID
		, CASE WHEN r.CurrencyID = 51 THEN @VNDCurrencyName
				WHEN r.CurrencyID = 70 THEN 'MKK'
				ELSE e.Code
		END

	DROP TABLE #TempData
	DROP TABLE #Exchange
	DROP TABLE #CashoutCust
END
GO

GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CashoutWinloss] TO [vnteam]
GO 

GRANT EXECUTE ON [dbo].[Lrf_Rpt_CashoutWinloss] TO [bodbLicenseeNet]
GO 