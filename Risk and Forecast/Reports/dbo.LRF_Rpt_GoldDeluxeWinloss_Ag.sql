/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

/****** Object:  StoredProcedure [dbo].[LRF_Rpt_GoldDeluxeWinloss_Ag]    Script Date: 3/30/2015 5:19:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER PROCEDURE [dbo].[LRF_Rpt_GoldDeluxeWinloss_Ag] 
	@LicenseeId		INT, 
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,  
	@AgentList		VARCHAR(MAX)
AS  

/*  Created: Winnie
	Date: 2015-03-16
    Task : GD Win Loss report 
    DB: DBEXT.bodb02   
    Revisions:  		
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20181114@Joseph: Integrate Bidme games (GD product) [#101599]

	Param's Explanation:  
*/  

BEGIN

	DECLARE @ProductID			INT
		,	@FDate				DATE
		,	@TDate				DATE
		,	@ProductPrefix		VARCHAR(2)

	SELECT @FDate = @FromDate,
		   @TDate = @ToDate,
		   @ProductPrefix = 'GD'

	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = @ProductPrefix

	CREATE TABLE #tmpResult (
		CustID INT
		,WinlostDate DATETIME  	
		,Currency INT
		,TurnOver MONEY
		,TotalTrans	INT	
		,Winlost MONEY
		,LicenseeWinlost MONEY
		,TipsAmount MONEY
		,TipsSharing MONEY
		,AmountDue MONEY)
						
	CREATE TABLE #tmpCust (  Recommend INT
							,CustId INT
							,Currency INT	
							)
		
	DECLARE @sql NVARCHAR(1000)
	 
	DECLARE @Temp AS TABLE ( CustId INT,Currency INT )

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @Temp(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	
	-- Get Charge rates
	DECLARE @PartyID	VARCHAR(10)
	DECLARE @ChargeRates AS TABLE(Rate MONEY, FromDate DATE, ToDate DATE, ChargeType TINYINT)

	SELECT @PartyID = CAST(PartyID AS VARCHAR)
	FROM bodb_licensee.dbo.OAS_Party WITH(NOLOCK)
	WHERE OldRefID = @LicenseeId AND PartyType = 1
	
	INSERT INTO @ChargeRates(Rate, FromDate, ToDate, ChargeType)
	SELECT DI_Rate, Fromdate, Todate, ChargeType
	FROM bodb_licensee.dbo.LA_f_ChargeInfo(@PartyID, @FDate, @TDate, @ProductPrefix, 'OA', 1)
	WHERE (ChargeType = 1 OR ChargeType = 12) AND DI_Rate > 0

	IF NOT EXISTS (SELECT 1 FROM @ChargeRates)
	BEGIN
		INSERT INTO @ChargeRates(Rate, FromDate, ToDate, ChargeType)
		SELECT DI_Rate, Fromdate, Todate, ChargeType
		FROM bodb_licensee.dbo.LA_f_GetChargeInfoWithTrialTime(@PartyID, @FDate, @TDate, @ProductPrefix, 'OA', 1)
		WHERE (ChargeType = 1 OR ChargeType = 12) AND DI_Rate > 0
	END

	-- Get data

	INSERT INTO #tmpCust (Recommend,CustID,Currency)	
	SELECT   lc.CustId AS Recommend
			 ,co.CustID
			 ,lc.Currency
	FROM 
		dbo.CustInfo co WITH (NOLOCK)
		INNER JOIN @Temp lc ON lc.CustId = co.Recommend AND co.Currency = lc.Currency
	
	INSERT INTO #tmpResult (CustId 
							 ,Winlostdate
							 ,Currency 	
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost
							 ,TipsAmount
							 ,TipsSharing
							 ,AmountDue)

	SELECT ag.recommend AS CustID
		    ,c.Winlostdate		
		    ,ag.Currency
		    ,SUM(c.TurnOver) AS TurnOver
		    ,SUM(c.BetCount) AS TotalTrans
		    , SUM(CASE WHEN c.bettype = 1706 -- GD Tips
					THEN 0 ELSE c.Winlost END) AS Winlost
			,-SUM(CASE WHEN c.bettype = 1706 -- GD Tips
					THEN 0 ELSE c.Winlost END) AS LicenseeWinlost
			,SUM(CASE WHEN c.bettype = 1706 -- GD Tips
					THEN c.Winlost ELSE 0 END) AS TipsAmount
			,SUM(CASE WHEN c.bettype = 1706 -- GD Tips
					THEN c.Winlost * (1-ISNULL(rateTip.Rate,1)) ELSE 0 END) AS TipsSharing
			,SUM(CASE WHEN c.bettype = 1706 -- GD Tips
					THEN c.Winlost * ISNULL(rateTip.Rate,1)
					ELSE -c.Winlost * (1-ISNULL(rate.Rate,1)) END) AS AmountDue
	FROM  [bodb_LicenseeReport].dbo.rptDepWinlost_ThirdParty c  WITH (NOLOCK)
		  INNER JOIN #tmpCust ag ON c.CustID = ag.CustID AND c.Currency = ag.Currency
		  LEFT JOIN @ChargeRates rateTip ON c.Winlostdate BETWEEN rateTip.FromDate AND rateTip.ToDate AND rateTip.ChargeType = 12
		  LEFT JOIN @ChargeRates rate ON c.Winlostdate BETWEEN rate.FromDate AND rate.ToDate AND rate.ChargeType = 1
	WHERE c.ProductId=@ProductId AND c.Winlostdate BETWEEN @FDate AND @TDate 
	GROUP BY ag.recommend
			,c.Winlostdate
		    ,ag.Currency
	
	SELECT ExchangeDate
		   ,ExchangeId
		   ,Code
		   ,USD
		   ,EUR
		   ,GBP
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpResult)
	
	SELECT r.CustID
		   ,c.Username
		   ,r.Currency
		   ,SUM(r.TurnOver)   	 AS TurnOver
		   ,SUM(r.TotalTrans) 	 AS TotalTrans
		   ,SUM(r.Winlost)		 AS Winlost
		   ,SUM(r.LicenseeWinlost) AS LicenseeWinlost
		   ,SUM(r.TipsAmount)			AS TipsAmount
		   ,SUM(r.TipsSharing)		AS TipsSharing
		   ,SUM(r.AmountDue)			AS AmountDue
		---USD
			,SUM(r.TurnOver*e.USD)   	 	AS TurnOverUSD
			,SUM(r.Winlost*e.USD)		 	AS WinlostUSD
			,SUM(r.LicenseeWinlost*e.USD)   AS LicenseeWinlostUSD
			,SUM(r.TipsAmount*e.USD)			AS TipsAmountUSD
		   ,SUM(r.TipsSharing*e.USD)		AS TipsSharingUSD
		   ,SUM(r.AmountDue*e.USD)			AS AmountDueUSD
		---EUR
			,SUM(r.TurnOver*e.EUR)   	 	AS TurnOverEUR
			,SUM(r.Winlost*e.EUR)		 	AS WinlostEUR
			,SUM(r.LicenseeWinlost*e.EUR)   AS LicenseeWinlostEUR
			,SUM(r.TipsAmount*e.EUR)			AS TipsAmountEUR
		   ,SUM(r.TipsSharing*e.EUR)		AS TipsSharingEUR
		   ,SUM(r.AmountDue*e.EUR)			AS AmountDueEUR
		---GBP
			,SUM(r.TurnOver*e.GBP)   	 	AS TurnOverGBP
			,SUM(r.Winlost*e.GBP)		 	AS WinlostGBP
			,SUM(r.LicenseeWinlost*e.GBP)   AS LicenseeWinlostGBP	
			,SUM(r.TipsAmount*e.GBP)			AS TipsAmountGBP
		   ,SUM(r.TipsSharing*e.GBP)		AS TipsSharingGBP
		   ,SUM(r.AmountDue*e.GBP)			AS AmountDueGBP
	FROM #tmpResult r
		INNER JOIN #TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.currency = e.ExchangeId
		INNER JOIN dbo.CustInfo c WITH (NOLOCK) ON r.CustID = c.CustID
	GROUP BY r.CustId 
			 ,c.Username
			 ,r.CustID
			 ,r.Currency	
	ORDER BY c.Username
			
	
	---------
	DROP TABLE #tmpResult
	DROP TABLE #tmpCust
	DROP TABLE #TempExchange 
	
END
GO
