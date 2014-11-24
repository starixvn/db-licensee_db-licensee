USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[LRF_Rpt_AGCasinoWinloss_Ag] 
 @LicenseeID	INT,
 @Currency		INT = 0,
 @UserID		INT,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @excludeTest   BIT = 0
AS  

/*

 exec LRF_Rpt_AGCasinoWinloss_Ag
 @LicenseeID=1
,@Currency=0
,@FromDate='2014-04-01 00:00:00'
,@ToDate='2014-09-30 00:00:00'
,@userId=10
,@excludeTest=0
*/
/*  Created: Jim
	Date: 2014-09-18
    Task : AG Win Loss report 
    DB: DBACC.bodb02  
    Revisions:  
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
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
						  )
	CREATE TABLE #tmpCust (  Recommend INT
							,CustId INT
							,Currency INT	
							)
		
	DECLARE @VNDCurrencyName VARCHAR(20)
	DECLARE @sql NVARCHAR(1000)
	 
	SELECT @VNDCurrencyName = currency 
	FROM  dbo.Exchange WITH (NOLOCK) 
	WHERE ExchangeId = 51

	SET @sql = 'SELECT CurrencyID
					FROM OPENQUERY( DBLIC,''SELECT CurrencyID
											FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(' + CAST(@LicenseeID AS VARCHAR) + ', '+ CAST(@UserID AS VARCHAR) + +', 1)
							WHERE ('+ CAST(@Currency AS VARCHAR) +' = 0  OR ('+ CAST(@currency AS VARCHAR) +' <> 0 AND CurrencyID = '+ CAST(@currency AS VARCHAR) +'))''
								)'
	INSERT INTO #Currency (CurrencyID)						
	EXEC (@sql)
	
	DECLARE @Temp AS TABLE (CustId INT,Currency INT )
	DECLARE @sql1 VARCHAR(500)
	SELECT  @sql1 =  'SELECT CustID,Currency   FROM  OPENQUERY(DBLIC, ''SELECT CustID,Currency  FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')'
	INSERT INTO @Temp (CustId ,Currency)
	EXEC (@sql1)
	
	INSERT INTO #tmpCust (Recommend,CustID,Currency)	
	SELECT   lc.CustId AS Recommend
			 ,co.CustID
			 ,lc.Currency
	FROM 
		dbo.CustInfo co WITH (NOLOCK)
		INNER JOIN @Temp lc ON lc.CustId = co.Recommend AND co.Currency = lc.Currency
		INNER JOIN #Currency c ON  lc.Currency = c.CurrencyID 
	WHERE  (@excludeTest=0 OR (@excludeTest=1 AND lc.Currency <> 20))	
	
	INSERT INTO #tmpResult (CustId 
							 ,Winlostdate
							 ,Currency 	
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)

	SELECT ag.recommend AS CustID
		   ,c.Winlostdate		
		   ,ag.Currency
		   ,SUM(c.TurnOver) AS TurnOver
		   ,SUM(c.BetCount) AS TotalTrans
		   ,SUM(c.Winlost)  AS Winlost
		   ,-SUM(c.Winlost) AS LicenseeWinlost
	FROM  bodb_report.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
		  INNER JOIN #tmpCust ag ON c.CustID = ag.CustID AND c.Currency = ag.Currency
	WHERE c.Winlostdate BETWEEN @FromDate AND @ToDate 
	GROUP BY ag.recommend
			,c.Winlostdate
		    ,ag.Currency
	
	SELECT ExchangeDate
		   ,ExchangeId
		   ,Code
		   ,USD
		   ,EUR
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpResult)
	
	SELECT c.Username
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
			,SUM(r.LicenseeWinlost*e.USD) AS LicenseeWinlostUSD
		---EUR
			,SUM(r.TurnOver*e.EUR)   	 	AS TurnOverEUR
			,SUM(r.Winlost*e.EUR)		 	AS WinlostEUR
			,SUM(r.LicenseeWinlost*e.EUR) AS LicenseeWinlostEUR
	FROM #tmpResult r
		INNER JOIN #TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.currency = e.ExchangeId
		INNER JOIN dbo.CustInfo c WITH (NOLOCK) ON r.CustID = c.CustID
	GROUP BY  c.Username
			 ,r.Currency
			 ,CASE WHEN r.Currency=51  THEN  @VNDCurrencyName
				 ELSE e.Code 
				 END 		
	ORDER BY c.Username
	
	---------
	DROP TABLE #tmpResult
	DROP TABLE #Currency
	DROP TABLE #tmpCust
	DROP TABLE #TempExchange 
	
END
GO
GRANT EXECUTE ON [dbo].[LRF_Rpt_AGCasinoWinloss_Ag] TO [bodbLicenseeNet]  
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_Rpt_AGCasinoWinloss_Ag] TO [vnteam] 