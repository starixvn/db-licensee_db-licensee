USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[LRF_Rpt_ThirdPartyWinloss_Mem]    Script Date: 3/30/2015 5:21:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER  PROCEDURE [dbo].[LRF_Rpt_ThirdPartyWinloss_Mem] 
 @LicenseeID	INT,
 @ProductID	    INT,
 @CustID		INT, --- recommend
 @Currency		INT = 0,
 @UserID		INT,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @excludeTest BIT = 0
AS  
/*

 exec [LRF_Rpt_ThirdPartyWinloss_Mem]
 @LicenseeID=1
,@Currency=0
,@UserID=10
,@CustID = 916515
,@FromDate='2014-04-01 00:00:00'
,@ToDate='2014-09-30 00:00:00'
,@excludeTest=0
*/
/*  Created: Winnie
	Date: 2015-03-16
    Task : GD Win Loss report 
    DB: DBEXT.bodb02   
    Revisions:  			
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
	Param's Explanation:  
	  + @excludeTest: remove currency UUS
*/  

BEGIN
	CREATE TABLE #tmpResult (CustID			  INT
							 ,WinlostDate	  DATETIME  	
							 ,Currency 		  INT
							 ,TurnOver 		  MONEY
							 ,TotalTrans	  INT	
							 ,Winlost  		  MONEY
							 ,LicenseeWinlost MONEY
							)
						
	CREATE TABLE #Currency(currencyID INT
						  ,LicenseeID INT
						  )
	
	CREATE TABLE #tmpCust (  CustId INT
							,Currency INT	
							)
		
		
	DECLARE @VNDCurrencyName VARCHAR(20)
	DECLARE @sql NVARCHAR(1000)
	 
	SELECT @VNDCurrencyName = currency 
	FROM  dbo.Exchange WITH (NOLOCK) 
	WHERE ExchangeId = 51

	SET @sql = 'SELECT CurrencyID, LicenseeID
					FROM OPENQUERY( DBLIC,''SELECT CurrencyID, LicenseeID
											FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(' + CAST(@LicenseeID AS VARCHAR) + ', '+ CAST(@UserID AS VARCHAR) + +', 1)
							WHERE ('+ CAST(@Currency AS VARCHAR) +' = 0  OR ('+ CAST(@currency AS VARCHAR) +' <> 0 AND CurrencyID = '+ CAST(@currency AS VARCHAR) +'))''
								)'
	INSERT INTO #Currency (CurrencyID,LicenseeID)						
	EXEC (@sql)
	
	DECLARE @Temp AS TABLE (CustId INT,Currency INT )
	DECLARE @sql1 VARCHAR(500)
	SELECT  @sql1 =  'SELECT CustID,Currency   FROM  OPENQUERY(DBLIC, ''SELECT CustID,Currency  FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')'
	INSERT INTO @Temp (CustId ,Currency)
	EXEC (@sql1)
	
	INSERT INTO #tmpCust (CustID,Currency)	
	SELECT   co.CustID
			 ,lc.Currency
	FROM 
		dbo.CustInfo co WITH (NOLOCK)
		INNER JOIN @Temp lc ON lc.CustId = co.Recommend AND co.Currency = lc.Currency
		INNER JOIN #Currency c ON  lc.Currency = c.CurrencyID 
	WHERE  (@excludeTest=0 OR (@excludeTest=1 AND lc.Currency <> 20))	
		    AND ((@CustID <> 0 AND lc.CustId =  @CustID) OR @CustID = 0)
			
	INSERT INTO #tmpResult (CustId 
							 ,Winlostdate
							 ,Currency 	
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)

	SELECT c.CustID
		   ,c.Winlostdate		
		   ,ag.Currency
		   ,SUM(c.TurnOver) AS TurnOver
		   ,SUM(c.BetCount) AS TotalTrans
		   ,SUM(c.Winlost)  AS Winlost
		   ,-SUM(c.Winlost) AS LicenseeWinlost
	FROM  [bodb_LicenseeReport].dbo.rptDepWinlost_ThirdParty c  WITH (NOLOCK)
		INNER JOIN #tmpCust ag ON c.CustID = ag.CustID AND c.Currency = ag.Currency 	
	WHERE c.ProductId=@ProductID AND c.Winlostdate BETWEEN @FromDate AND @ToDate 
		 AND (@excludeTest=0 OR (@excludeTest=1 AND ag.Currency <> 20))		
	GROUP BY c.CustID
			,c.Winlostdate
		    ,ag.Currency
	
	SELECT ExchangeDate
		   ,ExchangeId
		   ,Code
		   ,USD
		   ,EUR
		   ,GBP
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpResult)
	
	SELECT  SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
			,c.Username
			,r.Currency
		    ,CASE	WHEN r.Currency=51  THEN  @VNDCurrencyName
					WHEN r.Currency=70  THEN  'MKK'
				 ELSE e.Code 
				 END CurrencyName		
		    ,SUM(r.TurnOver)   	 AS TurnOver
		    ,SUM(r.TotalTrans) 	 AS TotalTrans
		    ,SUM(r.Winlost)		 AS Winlost
		    ,SUM(r.LicenseeWinlost) AS LicenseeWinlost
		---USD
			,SUM(r.TurnOver*e.USD)   	 	AS TurnOverUSD
			,SUM(r.Winlost*e.USD)		 	AS WinlostUSD
			,SUM(r.LicenseeWinlost*e.USD) AS LicenseeWinlostUSD
		---EUR
			,SUM(r.TurnOver*e.EUR)   	 	AS TurnOverEUR
			,SUM(r.Winlost*e.EUR)		 	AS WinlostEUR
			,SUM(r.LicenseeWinlost*e.EUR) AS LicenseeWinlostEUR
		---GBP
			,SUM(r.TurnOver*e.GBP)   	 	AS TurnOverGBP
			,SUM(r.Winlost*e.GBP)		 	AS WinlostGBP
			,SUM(r.LicenseeWinlost*e.GBP) AS LicenseeWinlostGBP
	FROM #tmpResult r
		INNER JOIN #TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.currency = e.ExchangeId
		--INNER JOIN DBLIC.bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON r.CustID = c.CustID
		INNER JOIN dbo.customer c WITH  (NOLOCK) ON c.CustID = r.CustID
	GROUP BY SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2))
			 ,c.Username
			 ,r.Currency
			 ,CASE  WHEN r.Currency=51  THEN  @VNDCurrencyName
					WHEN r.Currency=70  THEN  'MKK'
				 ELSE e.Code 
				 END 		
	ORDER BY c.Username
	
	---------
	DROP TABLE #tmpCust
	DROP TABLE #tmpResult
	DROP TABLE #Currency
	DROP TABLE #TempExchange 
	
	
END

