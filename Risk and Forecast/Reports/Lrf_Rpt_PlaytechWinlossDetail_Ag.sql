ALTER PROCEDURE [dbo].[Lrf_Rpt_PlaytechWinlossDetail_Ag]  
 @LicenseeID	INT,
 @UserID		INT,
 @CurrencyID	INT = 0,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME
 
 AS  
/*  Created: Hannah
	Date: 2014-04-11  
    Task : Playtech Casino Win Loss report Agent Level
    DB: DBACC.bodb02  
   
    Revisions: 
	Param's Explanation:  
	  + @BackupDay: The day we move tickets to rptDepWinlostByProduct_bk  
*/  
BEGIN  
	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss (  
		winlostdate		DATETIME,  
		CustID			INT,   
		Currency		INT,  
		Turnover		MONEY,
		Winlost			MONEY,
		LicenseeWL		MONEY, 
		BetCount		BIGINT
	)  

	DECLARE @Super AS TABLE (custid INT PRIMARY KEY, currency INT)
	DECLARE @TempAg	TABLE( custID INT, currency INT)  
	DECLARE @LicenseeName VARCHAR(50)
	DECLARE @VNDCurrencyName VARCHAR(20)
	DECLARE @BackupDay SMALLDATETIME
	DECLARE @sql NVARCHAR(1000)

	SELECT @BackupDay = MIN(winlostdate)
	FROM [bodb_report].[dbo].[rptDepWinlostByProduct] WITH (NOLOCK) 

	SELECT @VNDCurrencyName = currency 
	FROM exchange (NOLOCK) 
	WHERE ExchangeId = 51 

	SELECT @LicenseeName = LicenseeName 
	FROM DBLIC.bodb_Licensee.dbo.Licensees WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID

	CREATE TABLE #currency(currencyID INT, LicenseeID INT)

	SET @sql = 'SELECT currencyID, LicenseeID
				FROM openquery( DB052,''SELECT * 
				FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(' + CAST(@LicenseeID AS VARCHAR) + ', '+ CAST(@UserID AS VARCHAR) + +', 1)
						WHERE ('+ CAST(@currencyID AS VARCHAR) +' = 0  OR ('+ CAST(@currencyID AS VARCHAR) +' <> 0 AND CurrencyID = '+ CAST(@currencyID AS VARCHAR) +'))'')'

	INSERT INTO #currency(currencyID, LicenseeID)
	EXEC (@sql)
  
	INSERT INTO @TempAg (custID, currency) 
	SELECT custID, currency 
	FROM DBLIC.bodb_Licensee.dbo.LicenseeCust lc (NOLOCK) 
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID   

	INSERT INTO @Super(custid, currency)  
	SELECT CustID,currency
	FROM bodb02.dbo.Dep_CustSuper dc WITH (NOLOCK)  
		INNER JOIN #Currency c ON dc.Currency = c.CurrencyID 
	WHERE  site = @LicenseeName	
	  
	DROP TABLE #Currency

	DECLARE @TempFromDate DATETIME 
	DECLARE @TempToDate DATETIME 
	DECLARE @FDate DATETIME 
	DECLARE @TDate DATETIME 
	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate 
  
	IF @TDate >= @BackupDay
	BEGIN
		IF @FDate < @BackupDay 
			SET @TempFromDate =  @BackupDay
		ELSE
			SET @TempFromDate = @FDate
	
		INSERT INTO #SAgWinLoss
		SELECT   
			r.winlostdate,  
			ci.recommend AS custID,
			s.currency,			
			SUM(r.turnover) AS Turnover, 
			SUM(r.winlost) AS Winlost,  
			-SUM(r.winlost) AS LicenseeWL,
			SUM(r.BetCount) AS BetCount	
		FROM 
			bodb_report.dbo.rptDepWinlostByProduct r WITH ( NOLOCK)
			INNER JOIN bodb02.dbo.custInfo ci WITH ( NOLOCK) ON ci.CustID = r.CustID
			INNER JOIN @Super s ON ci.srecommend = s.custid
			INNER JOIN @TempAg a ON ci.recommend = a.custid
		WHERE 
			r.winlostdate BETWEEN @TempFromDate AND @TDate 
			AND ci.roleid = 1  
			AND r.sporttype = 254
		GROUP BY   
			r.winlostdate,s.currency,ci.recommend
	END  
 
	IF @FDate < @BackupDay 
	BEGIN
		IF @TDate >= @BackupDay
				SET @TempToDate = DATEADD(DAY, -1, @BackupDay)
			ELSE
				SET  @TempToDate = @TDate
	
		INSERT INTO #SAgWinLoss
		SELECT   
			r.winlostdate, 
			ci.recommend AS custID,
			s.currency,		
			SUM(r.turnover) as turnover, 
			SUM(r.winlost) AS Winlost,  
			-SUM(r.winlost) AS LicenseeWL,
			SUM(r.BetCount) AS BetCount	
		FROM 
			bodb_report.dbo.rptDepWinlostByProduct_bk r WITH ( NOLOCK)
			INNER JOIN bodb02.dbo.custInfo ci WITH ( NOLOCK) ON ci.CustID = r.CustID
			INNER JOIN @TempAg ag ON ag.custid = ci.recommend
			INNER JOIN @Super s ON ci.srecommend = s.custid

		WHERE  
			r.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND ci.roleid = 1 
			AND r.sporttype = 254
		GROUP BY  r.winlostdate,s.currency, ci.recommend
	END 
 
	CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)
 
	SELECT   
		c.username,  
		w.custid, 
		w.currency,
		CASE WHEN w.Currency = 51 THEN @VNDCurrencyName 
				ELSE e.Code END AS CurrencyName,
		SUM(Turnover)		 AS Turnover,   
		SUM(Winlost)		 AS Winlost,  
		SUM(LicenseeWL)		 AS LicenseeWL,
		SUM(Betcount)	 	 AS BetCount,
		--BaseRM  
		CAST(SUM(Turnover*e.MYR)	 AS MONEY)     AS TurnoverMYR,   
		CAST(SUM(Winlost*e.MYR)	     AS MONEY)     AS WinlostMYR,  
		CAST(SUM(LicenseeWL*e.MYR)   AS MONEY)     AS LicenseeWLMYR,
		--BaseUSD  
		CAST(SUM(Turnover*e.USD)     AS MONEY)     AS TurnoverUSD,   
		CAST(SUM(Winlost*e.USD)	     AS MONEY)     AS WinlostUSD,  
		CAST(SUM(LicenseeWL*e.USD)   AS MONEY)     AS LicenseeWLUSD,
		--BaseEUR  
		CAST(SUM(Turnover*e.EUR)     AS MONEY)     AS TurnoverEUR,   
		CAST(SUM(Winlost*e.EUR)	     AS MONEY)     AS WinlostEUR,  
		CAST(SUM(LicenseeWL*e.EUR)   AS MONEY)     AS LicenseeWLEUR
	FROM	#SAgWinLoss w   
		INNER JOIN #TempExchange e	ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
		INNER JOIN CustInfo c WITH(NOLOCK) ON w.custid = c.custid
	GROUP BY w.currency,w.custid, c.username, 
			CASE WHEN w.Currency = 51 THEN @VNDCurrencyName 
				ELSE e.Code END
	ORDER BY w.currency

	DROP TABLE #SAgWinLoss
	DROP TABLE #TempExchange
END 

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_PlaytechWinlossDetail_Ag] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_PlaytechWinlossDetail_Ag] TO [vnteam]  