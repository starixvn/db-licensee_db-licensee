set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER  PROCEDURE [dbo].[Lrf_Rpt_PlaytechWinlossDetail]  
	@LicenseeID	INT,
	@UserID		INT,
	@CurrencyID	INT = 0,
	@CustID		INT = 0, --AgentID			
	@FromDate	SMALLDATETIME,  
	@ToDate		SMALLDATETIME 
AS  
/*  Created: Hannah  
	Date: 2014-04-11 
    Task : Playtech Casino Win Loss report Member Level
    DB: DB052.bodb02  
   
    Revisions:  
	Param's Explanation:  
	  + @CustID: AgentID  
	  + @BaseCurrency (input currencyID): 2-MYR ; 3-USD; 6-EUR
	  + @BackupDay: The day we move tickets to rptDepWinlostByProduct_bk  
*/  
BEGIN  
	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss (  
		CustID			INT,   
		Currency		INT,  
		Turnover		MONEY,
		Winlost			MONEY,  
		LicenseeWL		MONEY,
		BetCount		BIGINT
	)  

	DECLARE @tempAg	TABLE( custID INT PRIMARY KEY, Currency INT)  
	DECLARE @Code VARCHAR(20), @TempCurrencyID INT
	DECLARE @site VARCHAR(50)
	DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,MYR FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate, ExchangeId))
	DECLARE @Super AS TABLE (custid INT PRIMARY KEY, currency INT)
	DECLARE @BackupDay SMALLDATETIME
	DECLARE @sql NVARCHAR(1000)

	SELECT @BackupDay = MIN(winlostdate)
	FROM [bodb_report].[dbo].[rptDepWinlostByProduct] WITH (NOLOCK) 

	SET @sql = 'SELECT currencyID, LicenseeID 
				FROM dbo.Lrf_f_GetCurrencybyUser(' + CAST(@LicenseeID AS VARCHAR) + ', '+ CAST(@UserID AS VARCHAR) + +', 1)
				WHERE ('+ CAST(@currencyID AS VARCHAR) +' = 0  OR ('+ CAST(@currencyID AS VARCHAR) +' <> 0 AND CurrencyID = '+ CAST(@currencyID AS VARCHAR) +'));'

	CREATE TABLE #currency(currencyID INT, LicenseeID INT)

	INSERT INTO #currency(currencyID, LicenseeID)
	EXEC DBEXT.bodb02.dbo.sp_executesql @sql

	INSERT INTO @tempAg (custID, currency) 
	SELECT custID, currency 
	FROM DBLIC.bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) 
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID 
	WHERE 
		(@CustID = 0 OR (@CustID <> 0 AND CustID = @CustID))
	
	SELECT @site = LicenseeName 
	FROM DBLIC.bodb_licensee.dbo.Licensees WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID

	INSERT INTO @Super(custid, currency)  
	SELECT CustID, currency 
	FROM bodb02.dbo.Dep_CustSuper dc WITH (NOLOCK)  
		INNER JOIN #Currency c ON dc.Currency = c.CurrencyID
	WHERE site = @site

	DROP TABLE #Currency

	SELECT TOP 1 @TempCurrencyID=currency FROM @tempAg 

	IF @TempCurrencyID in (51, 20)
		SELECT @Code = currency FROM exchange (nolock) WHERE ExchangeId = @TempCurrencyID
	ELSE
		SELECT @Code = code FROM exchange (nolock) WHERE exchangeid=@TempCurrencyID

	DECLARE @TempFromDate DATETIME 
	DECLARE @TempToDate DATETIME 
	DECLARE @FDate DATETIME   
	DECLARE @TDate DATETIME   
	--to Deal With Parameter Sniffing
	SELECT @FDate = @FromDate, @TDate = @ToDate 
	
	INSERT INTO @Exchange (exchangedate, exchangeid, usd, eur, myr, code)
	SELECT exchangedate, exchangeid, usd, eur, myr, code
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE exchangeid IN (SELECT Currency FROM @TempAg)

	DECLARE @eEUR FLOAT
	DECLARE @eUSD FLOAT
	SELECT TOP 1 @eEUR = eur, @eUSD = usd FROM @Exchange	
	
	IF @TDate >= @BackupDay
	BEGIN
		IF @FDate < @BackupDay 
			SET @TempFromDate =  @BackupDay
		ELSE
			SET @TempFromDate = @FDate

		INSERT INTO #SAgWinLoss
		SELECT   
			r.custID,
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
		GROUP BY r.custid, r.winlostdate,s.currency
	END  
 
	IF @FDate < @BackupDay 
	BEGIN
		IF @TDate >= @BackupDay
				SET @TempToDate = DATEADD(DAY, -1, @BackupDay)
			ELSE
				SET  @TempToDate = @TDate

		INSERT INTO #SAgWinLoss
		SELECT   
			r.custid,
			s.currency,			
			SUM(r.turnover) AS Turnover, 
			SUM(r.winlost) AS Winlost,  
			-SUM(r.winlost) AS LicenseeWL,
			SUM(r.BetCount) AS BetCount	
		FROM 
			bodb_report.dbo.rptDepWinlostByProduct_bk r WITH ( NOLOCK)
			INNER JOIN bodb02.dbo.custInfo ci WITH ( NOLOCK) ON ci.CustID = r.CustID
			INNER JOIN @Super s ON ci.srecommend = s.custid
			INNER JOIN @TempAg ag ON ag.custid = ci.recommend
		WHERE  
			r.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND ci.roleid = 1
			AND r.sporttype = 254
		GROUP BY r.custid, r.winlostdate, s.currency
	 END 
  
	SELECT 
		c.username,  
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
		w.custid, 
		w.currency,
		@Code	AS CurrencyName,
		SUM(Turnover)	AS Turnover,   
		SUM(Winlost)	AS Winlost,  
		SUM(LicenseeWL)	AS LicenseeWL,
		SUM(Betcount)	AS BetCount,	  
	  
		--BaseEUR  
		CAST(SUM(Turnover)*@eEUR	AS MONEY)   AS TurnoverEUR,   
		CAST(SUM(Winlost)*@eEUR		AS MONEY)   AS WinlostEUR,  
		CAST(SUM(LicenseeWL)*@eEUR	AS MONEY)   AS LicenseeWLEUR,
		--BaseUSD  
		CAST(SUM(Turnover)*@eUSD    AS MONEY)   AS TurnoverUSD,   
		CAST(SUM(Winlost)*@eUSD	    AS MONEY)   AS WinlostUSD,  
		CAST(SUM(LicenseeWL)*@eUSD  AS MONEY)   AS LicenseeWLUSD
	FROM	#SAgWinLoss w   
		INNER JOIN DBLIC.bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
	GROUP BY w.custid, c.username,c.username2,w.currency

	DROP TABLE #SAgWinLoss 
END   

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_PlaytechWinlossDetail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_PlaytechWinlossDetail] TO [vnteam]  