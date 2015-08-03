USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[LRF_Rpt_MicroGamingWinloss]
 @LicenseeID	INT,
 @CurrencyID	INT = 0,
 @UserID		INT,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,  
 @ReportType	TINYINT=1,  
 @excludeTest   BIT = 0
AS  

/*
[LRF_Rpt_MicroGamingWinloss] 
 @LicenseeID	=1,
 @CurrencyID	 = 0,
 @UserID		=10,
 @FromDate		='2015-05-01',  
 @ToDate		='2015-08-01',   
 @ReportType	=2,
 @excludeTest    = 0
*/
/*  Created: Jim
	Date: 2015-07-28
    Task : MicroGaming Win Loss report 
    DB: DBEXT.bodb02  
    Revisions:  
		 
	Param's Explanation:  
	  + @excludeTest: remove currency UUS
	  + @ReportType: 1-Daily; 2-Monthly;  
*/ 
BEGIN
	CREATE TABLE #tmpResult (WinlostDate	  DATETIME  	
							 ,Currency 		  INT
							 ,TypeID		  TINYINT 
							 ,TypeName		  VARCHAR(200)								 
							 ,TurnOver 		  MONEY
							 ,TotalTrans	  INT	
							 ,Winlost  		  MONEY
							 ,LicenseeWinlost MONEY
							)
	CREATE TABLE #Bettype (Bettype INT,TypeID TINYINT,TypeName VARCHAR(200)) 
	CREATE TABLE #TempAg  (CustId INT, Currency INT)
	DECLARE @VNDCurrencyName VARCHAR(20)
	 
	SELECT @VNDCurrencyName = currency 
	FROM  dbo.Exchange WITH (NOLOCK) 
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

	INSERT INTO #TempAg (CustId,Currency)
	SELECT lc.CustID, lc.Currency 
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
	INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID
		AND lc.Currency = c.CurrencyID
	WHERE (
			@CurrencyID = 0
			OR (Currency = @CurrencyID)
			)
	INSERT INTO #Bettype (Bettype,TypeID,TypeName)	
	EXEC LRF_MicroGamingWinloss_Bettype @TypeID = 0
		
	
	INSERT INTO #tmpResult ( Winlostdate
							 ,Currency 
							 ,TypeID	
							 ,TypeName
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)

	SELECT 
		   b.rptDate Winlostdate		
		   ,b.CurrencyID Currency
		   ,bet.TypeID
		   ,bet.TypeName
		   ,SUM(b.TurnOver) AS TurnOver
		   ,SUM(b.BetCount) AS TotalTrans
		   ,SUM(b.Winloss)  AS Winlost
		   ,SUM(b.WinlossA) AS LicenseeWinlost
	FROM  bodb_licensee.dbo.rpt_Betting b  WITH (NOLOCK)
		  INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID
		  INNER JOIN #Bettype bet ON b.bettype  = bet.bettype
	WHERE b.rptDate BETWEEN @FromDate AND @ToDate 
	GROUP BY 	b.rptDate  		
				,b.CurrencyID  
				,bet.TypeID
				 ,bet.TypeName
	SELECT ExchangeDate
		   ,ExchangeId
		   ,Code
		   ,USD
		   ,EUR
		   ,GBP
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpResult)
	
	SELECT  CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),r.winlostdate,112)  
				 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),r.winlostdate,112)  
				 ELSE '0' END winlostdate 
		   ,r.TypeID
		   ,r.TypeName
		   ,r.Currency
		   ,CASE WHEN r.Currency=51  THEN  @VNDCurrencyName
				 ELSE e.Code 
				 END CurrencyName		
		   ,SUM(r.TurnOver)   	 AS TurnOver
		   ,SUM(r.TotalTrans) 	 AS TotalTrans
		   ,SUM(r.Winlost)		 AS Winlost
		   ,SUM(r.LicenseeWinlost) AS LicenseeWinlost
		---USD
			,SUM(r.TurnOver*e.USD)   	 	AS TurnOverUSD
			,SUM(r.Winlost*e.USD)		 	AS WinlostUSD
			,SUM(r.LicenseeWinlost*e.USD)   AS LicenseeWinlostUSD
		---EUR
			,SUM(r.TurnOver*e.EUR)   	 	AS TurnOverEUR
			,SUM(r.Winlost*e.EUR)		 	AS WinlostEUR
			,SUM(r.LicenseeWinlost*e.EUR)   AS LicenseeWinlostEUR
		---GBP
			,SUM(r.TurnOver*e.GBP)   	 	AS TurnOverGBP
			,SUM(r.Winlost*e.GBP)		 	AS WinlostGBP
			,SUM(r.LicenseeWinlost*e.GBP)   AS LicenseeWinlostGBP	
	FROM #tmpResult r
		INNER JOIN #TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.currency = e.ExchangeId
	GROUP BY  CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),r.winlostdate,112)  
				 WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),r.winlostdate,112)  
				 ELSE '0' END
			   ,r.TypeID
			   ,r.TypeName
		      ,r.Currency
		      ,CASE WHEN r.Currency=51  THEN  @VNDCurrencyName
				 ELSE e.Code 
				 END	
	ORDER BY r.TypeID
			
	
	---------
	DROP TABLE #tmpResult
	DROP TABLE #Currency
	DROP TABLE #TempAg
	DROP TABLE #TempExchange 
	DROP TABLE #Bettype 
	
END
 GO
GRANT EXECUTE ON [dbo].[LRF_Rpt_MicroGamingWinloss] TO [bodbLicenseeNet]  
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_Rpt_MicroGamingWinloss] TO [vnteam] 