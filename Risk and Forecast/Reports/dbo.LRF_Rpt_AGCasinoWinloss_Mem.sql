USE [bodb02]
GO
 
ALTER  PROCEDURE [dbo].[LRF_Rpt_AGCasinoWinloss_Mem] 
 @LicenseeID	INT,
 @CustID		INT, --- recommend
 @Currency		INT = 0,
 @UserID		INT,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
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
			- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
			- 20141121@Jim: as more table alias 
			- 20150123@Jim: support base on Currency GBP
			- 20150917@Florent: Change datasource for AG Casino
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
		    AND lc.CustId =  @CustID
	
	/*		
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
	FROM  bodb_report.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
		INNER JOIN #tmpCust ag ON c.CustID = ag.CustID AND c.Currency = ag.Currency 	
	WHERE c.Winlostdate BETWEEN @FromDate AND @ToDate 
		 AND (@excludeTest=0 OR (@excludeTest=1 AND ag.Currency <> 20))		
	GROUP BY c.CustID
			,c.Winlostdate
		    ,ag.Currency
	*/

	DECLARE @TempFromDate	DATETIME 
	DECLARE @TempToDate		DATETIME 
	DECLARE @GapDate		DATETIME

	SELECT @GapDate = MAX(c.Winlostdate) FROM bodb_report.dbo.rptDepWinlost_AGCasino c WITH (NOLOCK)

	IF @ToDate > @GapDate
	BEGIN
		IF @FromDate <= @GapDate 
			SET @TempFromDate =  DATEADD(DAY,1,@GapDate)
		ELSE
			SET @TempFromDate = @FromDate
		BEGIN
			DECLARE @FromDate2		DATETIME 
			DECLARE @ToDate2		DATETIME 
			DECLARE @MoveBetsDay	DATETIME

			--get MoveBetsDay
			DECLARE @MoveBet TABLE (BalanceUpDay DATETIME, MoveBetsDay DATETIME)
			INSERT INTO @MoveBet (BalanceUpDay, MoveBetsDay)
			EXEC dbo.Lrf_SelBalanceUpDay

			SELECT @MoveBetsDay = MoveBetsDay FROM @MoveBet
			--
			IF @ToDate > @MoveBetsDay
			BEGIN
				IF @TempFromDate <= @MoveBetsDay 
					SET @FromDate2 =  DATEADD(DAY, 1, @MoveBetsDay)
				ELSE
					SET @FromDate2 = @FromDate
				BEGIN
					--SELECT @FromDate2, @ToDate															
					INSERT INTO #tmpResult(CustId, Winlostdate, Currency ,TurnOver, TotalTrans, Winlost, LicenseeWinlost)
						(							
							SELECT c.CustId, c.Winlostdate, c.Currency
									, SUM(c.stake)		AS TurnOver
									, COUNT(1)			AS TotalTrans
									, SUM(c.winlost - c.actual_stake)	AS Winlost
									, - SUM(c.Winlost - c.actual_stake)	AS LicenseeWinlost
							FROM dbo.bettransLC c WITH (NOLOCK)
								INNER JOIN #tmpCust ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
							WHERE c.Winlostdate BETWEEN @FromDate2 AND @ToDate 
								AND c.statusID IN (111, 112, 113)
								AND c.productID = 10 -- AG
							GROUP BY c.CustId, c.Winlostdate, c.Currency
						)
				END
			END
			IF @TempFromDate <= @MoveBetsDay 
			BEGIN
				IF @ToDate >= @MoveBetsDay
						SET @ToDate2 = @MoveBetsDay
					ELSE
						SET @ToDate2 = @MoveBetsDay			
				BEGIN
					--SELECT @TempFromDate, @ToDate2
					INSERT INTO #tmpResult(CustId, Winlostdate, Currency ,TurnOver, TotalTrans, Winlost, LicenseeWinlost)
						(
							SELECT c.CustID , c.Winlostdate, c.Currency
									, SUM(c.TurnOver) AS TurnOver
									, SUM(c.BetCount) AS TotalTrans
									, SUM(c.Winlost)  AS Winlost
									, -SUM(c.Winlost) AS LicenseeWinlost
							FROM DBLIC.bodb_Licensee.dbo.rptLicWinloss2 c WITH (NOLOCK)
								INNER JOIN #tmpCust ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
							WHERE c.Winlostdate BETWEEN @TempFromDate AND @ToDate2 
								AND c.roleid = 1
								AND c.sporttype = 250 -- AG Casino
								AND c.statusID <> 101								
							GROUP BY c.CustId, c.Winlostdate, c.Currency
						)						
				END
			END
		END
	END
	
	IF @FromDate <= @GapDate 
	BEGIN
		IF @ToDate >= @GapDate
				SET @TempToDate = @GapDate
			ELSE
				SET  @TempToDate = @ToDate			
		BEGIN
			--SELECT @FromDate, @TempToDate 
			INSERT INTO #tmpResult (CustID, Winlostdate, Currency, TurnOver, TotalTrans, Winlost, LicenseeWinlost)
				(
					SELECT c.CustId AS CustID
						   ,c.Winlostdate		
						   ,c.Currency
						   ,SUM(c.TurnOver) AS TurnOver
						   ,SUM(c.BetCount) AS TotalTrans
						   ,SUM(c.Winlost)  AS Winlost
						   ,-SUM(c.Winlost) AS LicenseeWinlost
					FROM  bodb_report.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
						  INNER JOIN #tmpCust ct ON c.CustID = ct.CustID AND c.Currency = ct.Currency
					WHERE c.Winlostdate BETWEEN @FromDate AND @TempToDate 
					GROUP BY c.CustId, c.Winlostdate, c.Currency
				)
		END
	END

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
			 ,CASE WHEN r.Currency=51  THEN  @VNDCurrencyName
				 ELSE e.Code 
				 END 		
	ORDER BY c.Username
	
	---------
	DROP TABLE #tmpCust
	DROP TABLE #tmpResult
	DROP TABLE #Currency
	DROP TABLE #TempExchange 	
END
