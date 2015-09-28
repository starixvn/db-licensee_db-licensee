USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[LRF_Rpt_MicroGamingWinloss_xpre]    Script Date: 10/02/2015 12:58:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER  PROCEDURE [dbo].[LRF_Rpt_MicroGamingWinloss]
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
		  20150921@Jim: support RNG bettype
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
			,@MoveBetsDay DATETIME
			,@TempFromDate DATETIME
			,@TempToDate DATETIME	
	SELECT    
        @MoveBetsDay = MAX(eventdate)  
    FROM dbo.match14 WITH(NOLOCK)  
    		
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
	AND (@excludeTest=0 OR (@excludeTest=1 AND CurrencyID <> 20))	
	
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
	EXEC LRF_MicroGamingWinloss_Bettype_xpre @TypeID = 0
		
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate
				INSERT INTO #tmpResult ( Winlostdate
							 ,Currency 
							 ,TypeID	
							 ,TypeName
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)
				SELECT  b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName
						, SUM(stake) turnover
						, COUNT(b.transid) TotalTrans
						, SUM(b.winlost - b.actual_stake) AS Winlost
						, SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWinlost
				FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
				INNER JOIN #Bettype bet ON b.bettype  = bet.bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND b.statusID IN (111, 112, 113)
							AND b.bettype NOT IN (2008,2009)
				GROUP BY b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName
				INSERT INTO #tmpResult ( Winlostdate
							 ,Currency 
							 ,TypeID	
							 ,TypeName
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)
							
				SELECT 	b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName
						, SUM(stake) turnover
						, COUNT(b.transid) TotalTrans
						, SUM(b.winlost - b.actual_stake) AS Winlost
						, SUM(- 1 * (b.winlost - b.actual_stake)) AS LicenseeWinlost
				FROM dbo.bettransRnG b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid AND t.Currency = b.Currency
				INNER JOIN #Bettype bet ON b.gameID  = bet.bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
							AND b.statusID IN (111, 112, 113)
							AND bet.bettype IN (2007,2008)
				GROUP BY b.winlostdate
						, t.currency
						, bet.TypeID
						, bet.TypeName		
	END	
	
	IF @FromDate <= @MoveBetsDay 
	BEGIN
		IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @ToDate
				
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
			   ,-SUM(b.Winloss) AS LicenseeWinlost
	FROM  bodb_LicenseeReport.dbo.rpt_ThirdPartyWL_ExtraGMT b  WITH (NOLOCK)
			  INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID
		  INNER JOIN #Bettype bet ON b.bettypeID  = bet.bettype
		WHERE b.rptDate BETWEEN @FromDate AND @TempToDate
		  AND b.StatusId NOT IN (-1,103)
		 -- AND b.CustomerCategory = -1	
		GROUP BY 	b.rptDate  		
					,b.CurrencyID  
					,bet.TypeID
					 ,bet.TypeName
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