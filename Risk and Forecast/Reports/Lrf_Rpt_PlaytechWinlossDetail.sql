set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER  PROCEDURE [dbo].[Lrf_Rpt_PlaytechWinlossDetail]  
	@LicenseeID	INT,
	@UserID		INT,
	@CurrencyID	INT = 0,
	@CustID		INT = 0, --AgentID			
	@FromDate	SMALLDATETIME,  
	@ToDate		SMALLDATETIME,
	@excludeTest BIT = 0
AS  
/*  Created: Hannah  
	Date: 2014-04-11 
    Task : Playtech Casino Win Loss report Member Level
    DB: DBACC.bodb02  
   
    Revisions:  
		- 20140513@Hannah: Add Progressive share and win values
	Param's Explanation:  
	  + @CustID: AgentID  
	  + @BaseCurrency (input currencyID): 2-MYR ; 3-USD; 6-EUR
*/  
BEGIN  
	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss (  
		CustID			INT,   
		Currency		INT,  
		Turnover		MONEY,
		Winlost			MONEY,  
		LicenseeWL		MONEY,
		BetCount		BIGINT,
		PShare			MONEY,
		PWin			MONEY,
		NetGaming		MONEY	
	)  

	DECLARE @tempAg	TABLE( custID INT PRIMARY KEY, Currency INT)  
	DECLARE @Code VARCHAR(20), @TempCurrencyID INT
	DECLARE @site VARCHAR(50)
	DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,MYR FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate, ExchangeId))
	DECLARE @Super AS TABLE (custid INT PRIMARY KEY, currency INT)
	DECLARE @sql NVARCHAR(1000)

	CREATE TABLE #currency(currencyID INT, LicenseeID INT)

	SET @sql = 'SELECT currencyID, LicenseeID
				FROM openquery( DBLIC,''SELECT * 
				FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(' + CAST(@LicenseeID AS VARCHAR) + ', '+ CAST(@UserID AS VARCHAR) + +', 1)
						WHERE ('+ CAST(@currencyID AS VARCHAR) +' = 0  OR ('+ CAST(@currencyID AS VARCHAR) +' <> 0 AND CurrencyID = '+ CAST(@currencyID AS VARCHAR) +'))'')'

	INSERT INTO #currency(currencyID, LicenseeID)
	EXEC (@sql)

	INSERT INTO @tempAg (custID, currency) 
	SELECT custID, currency 
	FROM DBLIC.bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) 
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID 
	WHERE 
		(@CustID = 0 OR (@CustID <> 0 AND CustID = @CustID))
		AND (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))
	
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

	--to Deal With Parameter Sniffing
	
	INSERT INTO @Exchange (exchangedate, exchangeid, usd, eur, myr, code)
	SELECT exchangedate, exchangeid, usd, eur, myr, code
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT Currency FROM @TempAg)

	DECLARE @eEUR FLOAT
	DECLARE @eUSD FLOAT
	SELECT TOP 1 @eEUR = eur, @eUSD = usd FROM @Exchange	
	
	INSERT INTO #SAgWinLoss
	SELECT   
		r.custID,
		s.currency,			
		SUM(r.turnover) AS Turnover, 
		SUM(r.winlost) AS Winlost,  
		-SUM(r.winlost) AS LicenseeWL,
		SUM(r.BetCount) AS BetCount,
		SUM(ProgressiveShare) AS PShare,
		SUM(ProgressiveWin) AS PWin,
		SUM(NetGaming) AS NetGaming	
	FROM 
		bodb_report.dbo.rptDepWinlost_PlaytechCS r WITH ( NOLOCK)
		INNER JOIN bodb02.dbo.custInfo ci WITH ( NOLOCK) ON ci.CustID = r.CustID
		INNER JOIN @Super s ON ci.srecommend = s.custid
		INNER JOIN @TempAg a ON ci.recommend = a.custid
	WHERE 
		r.winlostdate BETWEEN @FromDate AND @ToDate
		AND ci.roleid = 1
		AND r.sporttype = 254
	GROUP BY r.custid, r.winlostdate,s.currency 
  
	SELECT 
		c.username,  
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
		w.custid, 
		w.currency,
		@Code			AS CurrencyName,
		SUM(Turnover)	AS Turnover,   
		SUM(Winlost)	AS Winlost,  
		SUM(LicenseeWL)	AS LicenseeWL,
		SUM(Betcount)	AS BetCount,	  
		SUM(PShare)		AS PShare,
		SUM(PWin)		AS PWin,
		SUM(NetGaming)	AS NetGaming,
	  
		--BaseEUR  
		CAST(SUM(Turnover)*@eEUR	AS MONEY)   AS TurnoverEUR,   
		CAST(SUM(Winlost)*@eEUR		AS MONEY)   AS WinlostEUR,  
		CAST(SUM(LicenseeWL)*@eEUR	AS MONEY)   AS LicenseeWLEUR,
		CAST(SUM(PShare)*@eEUR		AS MONEY)   AS PShareEUR,  
		CAST(SUM(PWin)*@eEUR		AS MONEY)   AS PWinEUR,  
		CAST(SUM(NetGaming)*@eEUR	AS MONEY)   AS NetGamingEUR,  

		--BaseUSD  
		CAST(SUM(Turnover)*@eUSD    AS MONEY)   AS TurnoverUSD,   
		CAST(SUM(Winlost)*@eUSD	    AS MONEY)   AS WinlostUSD,  
		CAST(SUM(LicenseeWL)*@eUSD  AS MONEY)   AS LicenseeWLUSD,
		CAST(SUM(PShare)*@eUSD	    AS MONEY)   AS PShareUSD,  
		CAST(SUM(PWin)*@eUSD	    AS MONEY)   AS PWinUSD,  
		CAST(SUM(NetGaming)*@eUSD	AS MONEY)   AS NetGamingUSD 

	FROM	#SAgWinLoss w   
		INNER JOIN DBLIC.bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
	GROUP BY w.custid, c.username,c.username2,w.currency

	DROP TABLE #SAgWinLoss 
END   

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_PlaytechWinlossDetail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_PlaytechWinlossDetail] TO [vnteam]  