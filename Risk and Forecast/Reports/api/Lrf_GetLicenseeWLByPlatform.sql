 /*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_GetLicenseeWLByPlatform]
	@LicenseeID INT,  
	@CurrencyIDList VARCHAR(500)  = 0,
	@FromDate	SMALLDATETIME,    
	@ToDate		SMALLDATETIME
AS  
  
/*  
	Created: 20170119@Joseph
    Task : Dashboard API
    DB: DBEXT/bodb02    

	Revisions:
		- 20170119@Joseph: Copy from Lrf_Rpt_PlatformWinloss [RedmineID: #70616]
		- 20170323@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]
		- 20170814@Alex  : Restrict permission by currency  [RedmineID: #80855]
     
	Param's Explanation: 
*/  
      
BEGIN        
	SET NOCOUNT ON;

	IF DATEDIFF(MONTH,@FromDate,@ToDate) > 0
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

	CREATE TABLE #tempAg(custID INT, Currency INT);

	CREATE CLUSTERED INDEX ix_tempAg_cl ON #tempAg(Currency, custID);

	--to Deal WITH Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate;

	INSERT INTO #tempAg (custID, currency) 
	SELECT custID, currency 
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
	WHERE Currency IN
                (
                    SELECT val
                    FROM dbo.strSplit(@CurrencyIDList, ',')
                );

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
	
	CREATE TABLE #Exchange (ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT, CNY FLOAT, MYR FLOAT, THB FLOAT, IDR FLOAT, Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId));

	INSERT INTO #Exchange (exchangedate, exchangeid, eur, usd, gbp, cny, myr, thb, idr, code)
	SELECT exchangedate, exchangeid, eur, usd, gbp, cny, myr, thb, idr, code
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate) t_ex
	WHERE EXISTS (SELECT 1 FROM #tempAg t_ag WHERE t_ag.Currency = t_ex.ExchangeId);

	DECLARE @MoveBetsDay SMALLDATETIME;

	DECLARE @MoveBetTable AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME);
	INSERT INTO @MoveBetTable (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay;

	SELECT TOP 1 @MoveBetsDay = MoveBetsDay
	FROM @MoveBetTable;

	IF @TDate > @MoveBetsDay
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
			AND (b.bettype < 901 OR b.bettype > 904)
			AND (b.bettype < 911 OR b.bettype > 914)
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
			SUM(LicenseeWL * e.GBP)	AS LicenseeWLGBP,
			--BASE CNY
			SUM(LicenseeWL * e.CNY)	AS LicenseeWLCNY,
			--BASE MYR
			SUM(LicenseeWL * e.MYR)	AS LicenseeWLMYR,
			--BASE THB
			SUM(LicenseeWL * e.THB)	AS LicenseeWLTHB,
			--BASE IDR
			SUM(LicenseeWL * e.IDR)	AS LicenseeWLIDR
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