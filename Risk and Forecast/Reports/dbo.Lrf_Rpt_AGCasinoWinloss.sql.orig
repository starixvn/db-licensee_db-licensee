USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_AGCasinoWinloss]
	  @LicenseeID	INT
	, @Currency		INT				= 0
	, @UserID		INT
	, @FromDate		SMALLDATETIME
	, @ToDate		SMALLDATETIME
	, @excludeTest	BIT				= 0
	, @ReportType	TINYINT			= 1
WITH RECOMPILE
AS  

/*  Created: Jim
	Date: 2014-09-18
    Task : AG Win Loss report 
    DB: DBACC.bodb02  
    Revisions:  
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150112@Florent: add filter ReportType 
		- 20150123@Jim: support base on Currency GBP
		- 20150917@Florent: Change datasource for AG Casino
	Param's Explanation:  
	  
	  + @excludeTest: remove currency UUS
	  + @ReportType : 1 Daily, 2 Monthly
*/  


/*
 exec Lrf_Rpt_AGCasinoWinloss 
 @LicenseeID=1
,@Currency=0
,@FromDate='2014-04-01 00:00:00'
,@ToDate='2014-09-30 00:00:00'
,@excludeTest=0
,@UserId=10
*/
SET NOCOUNT ON
BEGIN
	CREATE TABLE #tmpResult (Winlostdate DATETIME, Currency INT,TurnOver MONEY,TotalTrans INT,Winlost MONEY,LicenseeWinlost MONEY)						
	CREATE TABLE #Currency(currencyID INT)
	CREATE TABLE #tmpCust (CustId INT, Currency INT, srecommend INT)
	CREATE TABLE #TempExchange(ExchangeDate DATETIME, ExchangeId INT, Code NVARCHAR(5), USD FLOAT, EUR FLOAT,GBP FLOAT)
		
	DECLARE @VNDCurrencyName VARCHAR(20)
	DECLARE @sql NVARCHAR(1000)
	
	SELECT @VNDCurrencyName = currency 
	FROM  dbo.Exchange WITH (NOLOCK) 
	WHERE ExchangeId = 51

	SET @sql = 'SELECT CurrencyID 
				FROM OPENQUERY( DBLIC,''SELECT CurrencyID 
										FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(' + CAST(@LicenseeID AS VARCHAR) + ', '+ CAST(@UserID AS VARCHAR) + +', 1)
										WHERE ('+ CAST(@Currency AS VARCHAR) +' = 0  OR ('+ CAST(@currency AS VARCHAR) +' <> 0 
											AND CurrencyID = '+ CAST(@currency AS VARCHAR) +'))''
											)'
	INSERT INTO #Currency (CurrencyID)						
	EXEC (@sql)
	
	DECLARE @Temp AS TABLE ( CustId INT, Currency INT )
	DECLARE @sql1 VARCHAR(500)
	SELECT  @sql1 = 'SELECT CustID, Currency 
					FROM OPENQUERY(DBLIC, ''SELECT CustID, Currency 
											FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')'
	INSERT INTO @Temp (CustId, Currency)
	EXEC (@sql1)
	
	INSERT INTO #tmpCust (CustID, Currency, srecommend)	
	SELECT co.CustID, lc.Currency , co.srecommend
	FROM dbo.custInfo co WITH (NOLOCK)
		INNER JOIN #Currency c ON co.Currency = c.CurrencyID 
		INNER JOIN @Temp lc ON co.recommend = lc.CustId AND lc.Currency = co.Currency
	WHERE (@excludeTest = 0 OR (@excludeTest = 1 AND lc.Currency <> 20))	
	
	DECLARE @TempFromDate	DATETIME 
	DECLARE @TempToDate		DATETIME 
	DECLARE @GapDate		DATETIME

	SELECT @GapDate = MAX(c.Winlostdate) FROM bodb_report.dbo.rptDepWinlost_AGCasino c WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #tmpCust tc WHERE c.Custid = tc.CustId)

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
					INSERT INTO #tmpResult (Winlostdate, Currency, TurnOver, TotalTrans, Winlost, LicenseeWinlost)
						(							
							SELECT c.Winlostdate, c.Currency
									, SUM(c.stake)		AS TurnOver
									, COUNT(1)			AS TotalTrans
									, SUM(c.winlost - c.actual_stake)	AS Winlost
									, - SUM(c.Winlost - c.actual_stake)	AS LicenseeWinlost
							FROM dbo.bettransLC c WITH (NOLOCK)
								INNER JOIN #tmpCust ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
							WHERE c.Winlostdate BETWEEN @FromDate2 AND @ToDate 
								AND c.statusID IN (111, 112, 113)
								AND c.productID = 10 -- AG
							GROUP BY c.Winlostdate, c.Currency
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
					INSERT INTO #tmpResult (Winlostdate, Currency, TurnOver, TotalTrans, Winlost, LicenseeWinlost)
						(
							SELECT c.Winlostdate, c.Currency
									, SUM(c.TurnOver) AS TurnOver
									, SUM(c.BetCount) AS TotalTrans
									, SUM(c.Winlost)  AS Winlost
									, -SUM(c.Winlost) AS LicenseeWinlost
							FROM DBLIC.bodb_Licensee.dbo.rptLicWinloss2 c WITH (NOLOCK)
								INNER JOIN (SELECT DISTINCT srecommend, Currency FROM #tmpCust) ct ON c.Custid = ct.srecommend AND c.Currency = ct.Currency
							WHERE c.Winlostdate BETWEEN @TempFromDate AND @ToDate2 
								AND c.roleid = 4
								AND c.sporttype = 250 -- AG Casino
								AND c.statusID <> 101								
							GROUP BY c.Winlostdate, c.Currency
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
			INSERT INTO #tmpResult (Winlostdate, Currency, TurnOver, TotalTrans, Winlost, LicenseeWinlost)
				(
					SELECT c.Winlostdate, c.Currency
							, SUM(c.TurnOver) AS TurnOver
							, SUM(c.BetCount) AS TotalTrans
							, SUM(c.Winlost)  AS Winlost
							, -SUM(c.Winlost) AS LicenseeWinlost
					FROM bodb_report.dbo.rptDepWinlost_AGCasino c WITH (NOLOCK)
						INNER JOIN #tmpCust ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
					WHERE c.Winlostdate BETWEEN @FromDate AND @TempToDate 
					GROUP BY c.Winlostdate, c.Currency
				)
		END
	END

	INSERT INTO #TempExchange(ExchangeDate, ExchangeId, Code, USD, EUR,GBP)
		(
			SELECT ExchangeDate, ExchangeId, Code, USD, EUR	,GBP 
			FROM dbo.Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
			WHERE ExchangeId IN (SELECT DISTINCT Currency FROM #tmpResult)
		)
	
	SELECT --r.Winlostdate
		   CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			END AS Winlostdate
		, r.Currency
		, CASE 
		 	WHEN Currency = 51
		 		THEN @VNDCurrencyName
		 	ELSE e.Code
		 	END						AS CurrencyName
		, SUM(r.TurnOver)			AS TurnOver
		, SUM(r.TotalTrans)			AS TotalTrans
		, SUM(r.Winlost)			AS Winlost
		, SUM(r.LicenseeWinlost)	AS LicenseeWinlost
		---USD
		, SUM(r.TurnOver * e.USD)	AS TurnOverUSD
		, SUM(r.Winlost * e.USD)	AS WinlostUSD
		, SUM(r.LicenseeWinlost * e.USD) AS LicenseeWinlostUSD
		---EUR
		, SUM(r.TurnOver * e.EUR)	AS TurnOverEUR
		, SUM(r.Winlost * e.EUR)	AS WinlostEUR
		, SUM(r.LicenseeWinlost * e.EUR) AS LicenseeWinlostEUR
		---GBP
		, SUM(r.TurnOver * e.GBP)	AS TurnOverGBP
		, SUM(r.Winlost * e.GBP)	AS WinlostGBP
		, SUM(r.LicenseeWinlost * e.GBP) AS LicenseeWinlostGBP
	FROM #tmpResult r
	INNER JOIN #TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.Currency = e.ExchangeId
	GROUP BY --r.Winlostdate
		 CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			 END
		, r.Currency
		, CASE 
			WHEN Currency = 51
				THEN @VNDCurrencyName
			ELSE e.Code
			END
	--ORDER BY r.Winlostdate
	ORDER BY CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			 END
	---------
	DROP TABLE #tmpResult
	DROP TABLE #Currency
	DROP TABLE #tmpCust
	DROP TABLE #TempExchange 
	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_AGCasinoWinloss] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_AGCasinoWinloss] TO [vnteam]  