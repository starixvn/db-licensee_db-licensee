USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[LRF_Rpt_AGCasinoWinloss_Mem] 
 @LicenseeID	INT,
 @CustID		INT, --- recommend
 @Currency		INT = 0,
 @UserID		INT,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @TableType 	TINYINT = 1,
 @excludeTest BIT = 0
AS  
/*

 exec LRF_Rpt_AGCasinoWinloss_Mem
 @LicenseeID=1
,@Currency=0
,@UserID=10
,@CustID = 916515
,@FromDate='2014-04-01 00:00:00'
,@ToDate='2014-09-30 00:00:00'
,@excludeTest=0
*/
/*  Created: Jim
	Date: 2014-09-18
    Task : AG Win Loss report 
    DB: DBACC.bodb02  
    Revisions:  
 
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
		   ,co.Currency
		   ,SUM(c.TurnOver) AS TurnOver
		   ,SUM(c.BetCount) AS TotalTrans
		   ,SUM(c.Winlost)  AS Winlost
		   ,-SUM(c.Winlost) AS LicenseeWinlost
	FROM  bodb_report.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
		INNER JOIN dbo.Custinfo co WITH  (NOLOCK) ON c.CustID = co.CustID
	WHERE c.Winlostdate BETWEEN @FromDate AND @ToDate 
		  AND co.recommend =  @CustID
		  AND (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))		
	GROUP BY c.CustID
			,c.Winlostdate
		    ,co.Currency
	
	SELECT ExchangeDate
		   ,ExchangeId
		   ,Code
		   ,USD
		   ,EUR
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpResult)
	
	SELECT  SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
			,c.Username
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
		--INNER JOIN DBLIC.bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON r.CustID = c.CustID
		INNER JOIN dbo.customer c WITH  (NOLOCK) ON c.CustID = r.CustID
	GROUP BY SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2))
			 ,c.Username
			 ,r.Currency
			 ,CASE WHEN r.Currency=51  THEN  @VNDCurrencyName
				 ELSE e.Code 
				 END 		
	ORDER BY c.Username
	
	---------
	DROP TABLE #tmpResult
	DROP TABLE #Currency
	DROP TABLE #TempExchange 
	
END