USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_GetLicenseeWLByPlatform]
	@LicenseeID INT,  
	@UserID  INT,  
	@CurrencyID INT = 0,  
	@FromDate  SMALLDATETIME,    
	@ToDate  SMALLDATETIME, 
	@MoveBetsDay SMALLDATETIME
AS  
  
/*  
	Created: 20170119@Joseph
    Task : Dashboard API
    DB: DBEXT/bodb02    

	Revisions:
		- 20170119@Joseph: Copy from Lrf_Rpt_PlatformWinloss [RedmineID: #70616]
     
	Param's Explanation: 
		+ @MoveBetsDay: The day we move tickets to bettrans14  
*/  
      
BEGIN        
	SET NOCOUNT ON;

	IF DATEDIFF(MONTH,@FromDate,@ToDate) > 1
		RETURN;

	CREATE TABLE #WinLoss (
		Winlostdate DATE,
		Currency	INT ,
		PlatformType	TINYINT,
		LicenseeWL	MONEY
	);

	DECLARE @TempFromDate SMALLDATETIME,
			@TempToDate SMALLDATETIME, 
			@FDate SMALLDATETIME,
			@TDate SMALLDATETIME;

	CREATE TABLE #tempAg	(custID INT, Currency INT);

	CREATE CLUSTERED INDEX ix_tempAg_cl ON #tempAg(Currency, custID);

	--to Deal WITH Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate;

	SELECT  currencyID, LicenseeID 
	INTO #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID,1)-- System is default=1 (LRF)
	WHERE (@CurrencyID = 0 OR CurrencyID = @CurrencyID);

	INSERT INTO #tempAg (custID, currency) 
	SELECT custID, currency 
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE Currency <> 20;

	DROP TABLE #Currency;

	CREATE TABLE #PlatformList (betfrom NVARCHAR(1), PlatformType TINYINT);

	INSERT INTO #PlatformList (betfrom, PlatformType)
	SELECT	d.betfrom, d.PlatformType
	FROM (
		VALUES	(1, 'd'),
				(2, 'a'),
				(3, 'e'),
				(4, 'm'),
				(5, 's'),
				(3, 'u'),
				(5, 'l')
	) d(PlatformType, betfrom);
	
	CREATE TABLE #Exchange (ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId));

	INSERT INTO #Exchange (exchangedate, exchangeid, eur, usd, gbp, code)
	SELECT exchangedate, exchangeid, eur, usd, gbp, code
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate) t_ex
	WHERE EXISTS (SELECT 1 FROM #tempAg t_ag WHERE t_ag.Currency = t_ex.ExchangeId);

	IF @TDate>@MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay);
		ELSE
			SET @TempFromDate = @FDate;
	
		INSERT INTO #WinLoss (Winlostdate, Currency, PlatformType, LicenseeWL)
		SELECT  b.winlostdate, 
				tma.currency,
				pl.PlatformType,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tempAg tma ON tma.CustID = b.recommend AND b.currency = tma.currency
			INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
		WHERE b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
								OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) 
			AND b.bettype NOT IN (901,902,903,904)
			AND b.tpositiontaking <> 0
		GROUP BY  b.winlostdate, 
				tma.currency, 
				pl.PlatformType;
	END		
				
	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay;
			ELSE
				SET  @TempToDate = @TDate;

		INSERT INTO #WinLoss (Winlostdate, Currency, PlatformType, LicenseeWL)
		SELECT	b.winlostdate,
				b.currency,
				pl.PlatformType,
				- SUM(b.winlost) AS LicenseeWL
		FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN 	#tempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
		WHERE b.Winlostdate BETWEEN @FDate AND @TempToDate
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.sporttype = 0 AND b.bettype = 0 --Sportbooks
			AND (b.isBA = 0 OR b.isBA IS NULL)
		GROUP BY b.currency,
				b.winlostdate,
				pl.PlatformType;
	END			

	SELECT  w.PlatformType, 	
			SUM(LicenseeWL)		AS LicenseeWL,		
			--BASE EUR
			SUM(LicenseeWL * e.EUR)	AS LicenseeWLEUR,	
			--BASE USD
			SUM(LicenseeWL * e.USD)	AS LicenseeWLUSD,
			--BASE GBP
			SUM(LicenseeWL * e.GBP)	AS LicenseeWLGBP
	FROM #WinLoss w 
		INNER JOIN  #Exchange e on w.Currency = e.exchangeid AND e.ExchangeDate = w.Winlostdate
	GROUP BY w.PlatformType
	ORDER BY w.PlatformType;

	DROP TABLE #Exchange;
	DROP TABLE #WinLoss;
	DROP TABLE #tempAg;

	SET NOCOUNT OFF;
END  
GO

GRANT EXECUTE ON [dbo].[Lrf_GetLicenseeWLByPlatform] TO [bodbLicenseeNet] AS [dbo]
GO