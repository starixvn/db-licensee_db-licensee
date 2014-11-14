USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[Lrf_Rpt_AGCasinoWinloss] 
 @LicenseeID	INT,
 @Currency		INT = 0,
 @UserID		INT,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @TableType 	TINYINT = 1,
 @excludeTest   BIT = 0
AS  

/*  Created: Jim
	Date: 2014-09-18
    Task : AG Win Loss report 
    DB: DBACC.bodb02  
    Revisions:  
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	Param's Explanation:  
	  + @TableType:  0-all
					 1-normal ticket
					 2-vip ticket
					
	  + @excludeTest: remove currency UUS
*/  


/*
 exec Lrf_Rpt_AGCasinoWinloss 
 @LicenseeID=1
,@Currency=0
,@TableType=1
,@FromDate='2014-04-01 00:00:00'
,@ToDate='2014-09-30 00:00:00'
,@excludeTest=0
,@UserId=10
*/


BEGIN
	CREATE TABLE #tmpResult (Winlostdate DATETIME
							 ,Currency 		  INT
							 ,TurnOver 		  MONEY
							 ,TotalTrans	  INT	
							 ,Winlost  		  MONEY
							 ,LicenseeWinlost MONEY
							)
						
	CREATE TABLE #Currency(currencyID INT
						  ,LicenseeID INT
						  )
	CREATE TABLE #tmpAg (CustId INT
					 
						)
		
	DECLARE @IsVIPGame TINYINT
	DECLARE @VNDCurrencyName VARCHAR(20)
	DECLARE @sql NVARCHAR(1000)

	SELECT @IsVIPGame= CASE @TableType WHEN 1 -- normal ticker
									   THEN 0
									   WHEN 2 -- vip ticket
									   THEN 1
									   ELSE NULL
						END
	
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
	
	DECLARE @Temp AS TABLE ( LicenseeId INT,CustId INT,Currency INT )
	DECLARE @sql1 VARCHAR(500)
	SELECT  @sql1 =  'SELECT LicenseeId,CustID,Currency   FROM  OPENQUERY(DBLIC, ''SELECT LicenseeId,CustID,Currency  FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')'
	INSERT INTO @Temp (LicenseeId ,CustId ,Currency)
	EXEC (@sql1)
	
	INSERT INTO #tmpAg (CustID)	
	SELECT DISTINCT lc.CustID 
	FROM @Temp lc  
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID 
	WHERE  (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	
	
	INSERT INTO #tmpResult (Winlostdate 
							 ,Currency 	
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)

	SELECT c.Winlostdate
		   ,co.Currency
		   ,SUM(c.TurnOver) AS TurnOver
		   ,SUM(c.BetCount) AS TotalTrans
		   ,SUM(c.Winlost)  AS Winlost
		   ,-SUM(c.Winlost) AS LicenseeWinlost
	FROM  bodb_report.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
		INNER JOIN dbo.Custinfo co WITH  (NOLOCK) ON c.CustID = co.CustID
		INNER JOIN #tmpAg ag ON co.recommend = ag.CustID
	WHERE c.Winlostdate BETWEEN @FromDate AND @ToDate 
		  AND (@TableType = 0 OR (@TableType  <> 0 AND IsVIPGame = @IsVIPGame))
	GROUP BY c.Winlostdate
		    ,co.Currency
	
	SELECT ExchangeDate
		   ,ExchangeId
		   ,Code
		   ,USD
		   ,EUR
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpResult)
	
	SELECT r.Winlostdate
		   ,r.Currency
		   ,CASE WHEN Currency=51  THEN  @VNDCurrencyName
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
	GROUP BY r.Winlostdate
			 ,r.Currency
			 ,CASE WHEN Currency=51  THEN  @VNDCurrencyName
				 ELSE e.Code 
				 END 		
	ORDER BY r.Winlostdate
	
	---------
	DROP TABLE #tmpResult
	DROP TABLE #Currency
	DROP TABLE #tmpAg
	DROP TABLE #TempExchange 
	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_AGCasinoWinloss] TO [bodbLicenseeNet]  
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_AGCasinoWinloss] TO [vnteam] 