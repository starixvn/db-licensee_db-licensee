/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_CashoutWinloss_Detail]
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,	
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = '',
	@DefaultBaseCurrency	VARCHAR(3) = ''
AS
/*
	Created: 20170330@Harper
	Description: LRF - Implement Cash Out [#71727]
	DB: DBEXT.bodb02 
	Revisions: 
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180809@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]
		- 20190617@Amanda: Add Base currency param [RedmineID: #112531]

	Param's Explanation:  

	exec Lrf_Rpt_CashoutWinloss_Detail @fromdate='2017-04-20 00:00:00',@todate='2017-04-20 00:00:00',@AgentList=N'<ROOT><Agent AgentId="791088" Currency="3"/><Agent AgentId="860379" Currency="6"/><Agent AgentId="2428981" Currency="6"/><Agent AgentId="2812696" Currency="6"/><Agent AgentId="3575140" Currency="6"/><Agent AgentId="4362999" Currency="6"/></ROOT>',@MoveBetsDay='2017-04-18 00:00:00' 
*/

SET NOCOUNT ON
BEGIN
	
	DECLARE @FDate SMALLDATETIME,
			@TDate SMALLDATETIME,
			@TempFromDate SMALLDATETIME,
			@TempToDate SMALLDATETIME

	SELECT @FDate = @FromDate,
		   @TDate = @ToDate
	
	DECLARE @DocHandler INT
	CREATE TABLE #tempAg (custID INT, currency INT)

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #tempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #Exchange(FirstExMonth SMALLDATETIME, LastExMonth SMALLDATETIME, ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)

	CREATE TABLE #CashoutCust (CustId INT PRIMARY KEY)
	INSERT INTO #CashoutCust(CustId)
	SELECT CustId FROM bodb02.dbo.f_GetCashoutCustList('ALL', 14) -- VendorID of Cashout

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
				CustID			INT,
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

		INSERT INTO #TempData ( rptDate ,CurrencyID ,Bettype ,Transid ,Refno ,Actual_stake ,winlost ,awinlost ,transid2, CustID)			
		SELECT b.winlostdate, b.currency, b.bettype, b.transid, b.refno, b.actual_stake, b.winlost, b.awinlost, b.transid2, b.custid
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tempAg ag ON b.recommend = ag.custID AND b.currency = ag.currency
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
				  CustID,
		          CashoutTime ,
		          CashoutTicket ,
		          CashoutValue ,
		          BuyBackAmountSB ,
		          BuyBackAmountBA ,
				  CashoutComm,
				  TicketPayout
		        )		
		SELECT b.rptDate,
				b.CurrencyID,	
				b.custid,			
				COUNT (*) AS CashoutTime,
				COUNT(DISTINCT (b.refno)) AS CashoutTicket,
				SUM(b.actual_stake) AS CashoutValue,
				SUM(CASE WHEN b.transid2 = 0 THEN b.winlost ELSE 0 END) AS BuyBackAmountSB,
				SUM(CASE WHEN b.transid2 = 1 THEN b.winlost ELSE 0 END) AS BuyBackAmountBA,
				SUM(ISNULL(b.CashoutComm, 0)),
				SUM(ISNULL(b.TicketPayout, 0))
		FROM #TempData b
		WHERE b.bettype = 911			
		GROUP BY b.rptDate, b.CurrencyID, b.custid	
	END	

	IF @FDate <= @MoveBetsDay
	BEGIN
		SELECT @TempToDate = CASE WHEN @TDate >= @MoveBetsDay THEN @MoveBetsDay ELSE @TDate END
		
		INSERT INTO @Result
		        ( rptDate ,
		          CurrencyID ,
				  CustID,
		          CashoutTime ,
		          CashoutTicket ,
		          CashoutValue ,
		          BuyBackAmountSB ,
		          BuyBackAmountBA ,
				  CashoutComm,
				  TicketPayout
		        )		
		SELECT b.winlostdate, b.Currency, b.CustID
			, SUM(b.NumOfCashoutTrans)
			, SUM(b.NumOfCashoutTicket)
			, SUM(b.CashoutAmount)
			, SUM(b.BuyBackAmt)
			, SUM(b.BABuyBackAmt)
			, SUM(b.CashoutComm)
			, SUM(b.TicketPayout)
		FROM bodb_LicenseeReport.dbo.rptLicCashoutSummary b WITH (NOLOCK)			
			INNER JOIN #tempAg ag ON b.Recommend = ag.custID AND b.Currency = ag.currency
		WHERE b.winlostdate BETWEEN @FDate AND @TempToDate		
			AND b.ProductID = 25	
			AND b.RoleID = 1
		GROUP BY b.winlostdate, b.Currency, b.custid
	END
	
	--Get Exchange rate
	IF EXISTS (SELECT TOP (1) 1 FROM @Result)
	BEGIN
		DECLARE @SQL VARCHAR(500) = ''
		DECLARE @Rate VARCHAR(3) = '1', @DefaultRate VARCHAR(3) = '1'
		
		IF ISNULL(@BaseCurrency, '') <> ''
		BEGIN
			SET @Rate = @BaseCurrency
		END
		
		IF ISNULL(@DefaultBaseCurrency, '') <> ''
		BEGIN
			SET @DefaultRate = @DefaultBaseCurrency
		END

		SELECT @SQL = 'SELECT FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID, USD, EUR, GBP, ' + @Rate + ' AS Rate, ' + @DefaultRate + ' AS DefaultRate '
					+ 'FROM Lrf_f_GetSubExchangeDaily(''' + CONVERT( VARCHAR(10),@FDate, 120) + ''',''' + CONVERT( VARCHAR(10),@TDate, 120) + ''') e '
					+ 'WHERE EXISTS (SELECT TOP (1) 1 FROM #tempAg a WHERE e.ExchangeID = a.Currency)'

		INSERT INTO #Exchange(FirstExMonth, LastExMonth, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		EXECUTE (@SQL)
	END

	-- Select Result
	SELECT 		
		 r.CurrencyID
		, r.CustID
		, c.username AS SystemId
		, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS ExternalID
		, SUM(r.CashoutTime) AS CashoutTime
		, SUM(r.CashoutTicket) AS CashoutTicket
		
		, CAST(SUM(r.CashoutValue * e.Rate) AS MONEY)													AS CashoutValue
		, CAST(SUM(r.BuyBackAmountSB * e.Rate) AS MONEY)												AS BuyBackAmountSB
		, CAST(SUM(r.BuyBackAmountBA * e.Rate) AS MONEY)												AS BuyBackAmountBA
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.Rate) AS MONEY)							AS BuyBackAmount
		, CAST(SUM(r.TicketPayout * e.Rate) AS MONEY)													AS TicketPayout
		, CAST(SUM(r.CashoutComm * e.Rate) AS MONEY)													AS CashoutComm
		, CAST(SUM(r.TicketPayout * e.Rate) AS MONEY)													AS AmountDue_TicketPayout
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.Rate) AS MONEY)			AS AmountDue_Comm
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.Rate) AS MONEY) AS Amount_Total
		--- USD		
		, CAST(SUM(r.CashoutValue * e.USD) AS MONEY)													AS CashoutValueUSD
		, CAST(SUM(r.BuyBackAmountSB * e.USD) AS MONEY)													AS BuyBackAmountSBUSD
		, CAST(SUM(r.BuyBackAmountBA * e.USD) AS MONEY)													AS BuyBackAmountBAUSD
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.USD) AS MONEY)							AS BuyBackAmountUSD
		, CAST(SUM(r.TicketPayout * e.USD) AS MONEY)													AS TicketPayoutUSD
		, CAST(SUM(r.CashoutComm * e.USD) AS MONEY)														AS CashoutCommUSD
		, CAST(SUM(r.TicketPayout * e.USD) AS MONEY)													AS AmountDue_TicketPayoutUSD
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.USD) AS MONEY)			AS AmountDue_CommUSD
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.USD) AS MONEY) AS Amount_TotalUSD
		--- EUR		
		, CAST(SUM(r.CashoutValue * e.EUR) AS MONEY)													AS CashoutValueEUR
		, CAST(SUM(r.BuyBackAmountSB * e.EUR) AS MONEY)													AS BuyBackAmountSBEUR
		, CAST(SUM(r.BuyBackAmountBA * e.EUR) AS MONEY)													AS BuyBackAmountBAEUR
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.EUR) AS MONEY)							AS BuyBackAmountEUR
		, CAST(SUM(r.TicketPayout * e.EUR) AS MONEY)													AS TicketPayoutEUR
		, CAST(SUM(r.CashoutComm * e.EUR) AS MONEY)														AS CashoutCommEUR
		, CAST(SUM(r.TicketPayout * e.EUR) AS MONEY)													AS AmountDue_TicketPayoutEUR
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.EUR) AS MONEY)			AS AmountDue_CommEUR
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.EUR) AS MONEY) AS Amount_TotalEUR
		--- GBP		
		, CAST(SUM(r.CashoutValue * e.GBP) AS MONEY)													AS CashoutValueGBP
		, CAST(SUM(r.BuyBackAmountSB * e.GBP) AS MONEY)													AS BuyBackAmountSBGBP
		, CAST(SUM(r.BuyBackAmountBA * e.GBP) AS MONEY)													AS BuyBackAmountBAGBP
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.GBP) AS MONEY)							AS BuyBackAmountGBP
		, CAST(SUM(r.TicketPayout * e.GBP) AS MONEY)													AS TicketPayoutGBP
		, CAST(SUM(r.CashoutComm * e.GBP) AS MONEY)														AS CashoutCommGBP
		, CAST(SUM(r.TicketPayout * e.GBP) AS MONEY)													AS AmountDue_TicketPayoutGBP
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.GBP) AS MONEY)			AS AmountDue_CommGBP
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.GBP) AS MONEY) AS Amount_TotalGBP
		--- Default base currency		
		, CAST(SUM(r.CashoutValue * e.DefaultRate) AS MONEY)													AS CashoutValueBase
		, CAST(SUM(r.BuyBackAmountSB * e.DefaultRate) AS MONEY)													AS BuyBackAmountSBBase
		, CAST(SUM(r.BuyBackAmountBA * e.DefaultRate) AS MONEY)													AS BuyBackAmountBABase
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA) * e.DefaultRate) AS MONEY)							AS BuyBackAmountBase
		, CAST(SUM(r.TicketPayout * e.DefaultRate) AS MONEY)													AS TicketPayoutBase
		, CAST(SUM(r.CashoutComm * e.DefaultRate) AS MONEY)														AS CashoutCommBase
		, CAST(SUM(r.TicketPayout * e.DefaultRate) AS MONEY)													AS AmountDue_TicketPayoutBase
		, CAST(SUM((r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm) * e.DefaultRate) AS MONEY)			AS AmountDue_CommBase
		, CAST(SUM((r.TicketPayout - (r.BuyBackAmountSB + r.BuyBackAmountBA + r.CashoutComm)) * e.DefaultRate) AS MONEY) AS Amount_TotalBase
	FROM @Result r
		INNER JOIN Customer c WITH (NOLOCK) ON r.custid = c.custid
		INNER JOIN #Exchange e ON r.rptDate BETWEEN e.FirstExMonth AND e.LastExMonth AND r.CurrencyID = e.ExchangeID	
	GROUP BY 		
		  r.CurrencyID
		, r.CustID, c.username, c.username2

	DROP TABLE #TempData
	DROP TABLE #Exchange
	DROP TABLE #CashoutCust
	DROP TABLE #tempAg
END
GO