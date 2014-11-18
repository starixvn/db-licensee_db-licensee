ALTER PROCEDURE [dbo].[Lrf_Rpt_PlaytechWinloss]  
 @LicenseeID	INT,
 @UserID		INT,
 @CurrencyID	INT = 0,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,
 @ReportType	TINYINT=1, 
 @excludeTest BIT = 0

AS  
/*  Created: Hannah
	Date: 2014-04-10
    Task : Playtech Casino Win Loss report 
    DB: DBACC.bodb02  
   
    Revisions:  
		- 20140513@Hannah: Add Progressive share and win values
		- 20140527@Hannah: Modify NetGaming values
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  + @BackupDay: The day we move tickets to rptDepWinlostByProduct_bk
*/  
BEGIN
	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss 
	(  
		winlostdate		DATETIME,  
		Currency		INT,
		Turnover		MONEY,	
		Winlost			MONEY,  
		LicenseeWL		MONEY, 
		BetCount		BIGINT,
		PShare			MONEY,
		PWin			MONEY,
		NetGaming		MONEY	
	)  

	DECLARE @sql NVARCHAR(1000)

	DECLARE @tempCust	TABLE( custID INT, currency INT)  
	DECLARE @VNDCurrencyName VARCHAR(20)
	

	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	SELECT @_FromDate = @FromDate, @_ToDate = @ToDate
	
	SELECT @VNDCurrencyName = currency 
	FROM exchange (NOLOCK) 
	WHERE ExchangeId = 51

	CREATE TABLE #currency(currencyID INT, LicenseeID INT)

	SET @sql = 'SELECT currencyID, LicenseeID
				FROM openquery( DBLIC,''SELECT * 
				FROM bodb02.dbo.Lrf_f_GetCurrencybyUser(' + CAST(@LicenseeID AS VARCHAR) + ', '+ CAST(@UserID AS VARCHAR) + +', 1)
						WHERE ('+ CAST(@currencyID AS VARCHAR) +' = 0  OR ('+ CAST(@currencyID AS VARCHAR) +' <> 0 AND CurrencyID = '+ CAST(@currencyID AS VARCHAR) +'))'')'

	INSERT INTO #currency(currencyID, LicenseeID)
	EXEC (@sql)
	
	DECLARE @Temp AS TABLE ( CustId INT,Currency INT )
	DECLARE @sql1 VARCHAR(500)
	SELECT  @sql1 =  'SELECT CustID,Currency   FROM  OPENQUERY(DBLIC, ''SELECT CustID,Currency  FROM bodb_licensee.dbo.f_SelLicenseeCust('+CAST(@LicenseeID AS VARCHAR(10))+')'')'
	INSERT INTO @Temp ( CustId ,Currency)
	EXEC (@sql1)
	
	INSERT INTO @tempCust (custID, currency) 
	SELECT  co.CustID 
			,lc.Currency 
	FROM dbo.Custinfo co WITH (NOLOCK)
		INNER JOIN #Currency c ON  co.Currency = c.CurrencyID 
		INNER JOIN 	@Temp lc   ON co.recommend = lc.CustId
	WHERE  (@excludeTest=0 OR (@excludeTest=1 AND lc.Currency <> 20))	
	
	
	DROP TABLE #Currency
	
	INSERT INTO #SAgWinLoss
	SELECT   
		r.winlostdate,  
		c.currency,			
		SUM(r.turnover) AS Turnover, 
		SUM(r.winlost) AS Winlost,  
		-SUM(r.winlost) AS LicenseeWL,
		SUM(r.BetCount) AS BetCount,
		SUM(ProgressiveShare) AS PShare,
		SUM(ProgressiveWin) AS PWin,
		(-SUM(r.winlost) - SUM(ProgressiveShare))AS NetGaming
	
	FROM 
		bodb_report.dbo.rptDepWinlost_PlaytechCS r WITH ( NOLOCK)
		INNER JOIN @tempCust c ON r.CustID = c.CustID AND r.Currency = c.Currency
		
	WHERE 
		r.winlostdate BETWEEN @FromDate AND @ToDate 
		AND r.sporttype = 254 			
	GROUP BY   
		r.winlostdate,c.currency

	CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@_FromDate, @_ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)

	SELECT   
	   CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8), w.winlostdate, 112)  
			WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6), w.winlostdate, 112)  
			ELSE '0' END ReportType,  
	   Currency ,   
			CASE WHEN Currency = 51 THEN @VNDCurrencyName 
				ELSE e.Code END currencyName,
	   SUM(Turnover)       AS Turnover,   
	   SUM(Winlost)        AS Winlost,  
	   SUM(LicenseeWL)     AS LicenseeWL,
	   SUM(BetCount)	   AS BetCount,
	   SUM(PShare)		   AS PShare,
	   SUM(PWin)		   AS PWin,
	   SUM(NetGaming)	   AS NetGaming,
   
	   --BaseRM  
	   CAST(SUM(Turnover*e.MYR)    AS MONEY)     AS TurnoverMYR,   
	   CAST(SUM(Winlost*e.MYR)	   AS MONEY)     AS WinlostMYR,  
	   CAST(SUM(LicenseeWL*e.MYR)  AS MONEY)     AS LicenseeWLMYR,
	   CAST(SUM(PShare*e.MYR)  AS MONEY)         AS PShareMYR,
	   CAST(SUM(PWin*e.MYR)  AS MONEY)			 AS PWinMYR,
	   CAST(SUM(NetGaming*e.MYR)  AS MONEY)      AS NetGamingMYR,
   
	   --BaseUSD  
	   CAST(SUM(Turnover*e.USD)    AS MONEY)     AS TurnoverUSD,   
	   CAST(SUM(Winlost*e.USD)	   AS MONEY)	 AS WinlostUSD,  
	   CAST(SUM(LicenseeWL*e.USD)  AS MONEY) 	 AS LicenseeWLUSD,
	   CAST(SUM(PShare*e.USD)    AS MONEY)       AS PShareUSD, 
	   CAST(SUM(PWin*e.USD)    AS MONEY)         AS PWinUSD,   
	   CAST(SUM(NetGaming*e.USD)    AS MONEY)    AS NetGamingUSD,   
  
		--BaseEUR  
	   CAST(SUM(Turnover*e.EUR)    AS MONEY)     AS TurnoverEUR,   
	   CAST(SUM(Winlost*e.EUR)	   AS MONEY)	 AS WinlostEUR,  
	   CAST(SUM(LicenseeWL*e.EUR)  AS MONEY)	 AS LicenseeWLEUR,
	   CAST(SUM(PShare*e.EUR)    AS MONEY)       AS PShareEUR,   
	   CAST(SUM(PWin*e.EUR)    AS MONEY)         AS PWinEUR,   
	   CAST(SUM(NetGaming*e.EUR)    AS MONEY)    AS NetGamingEUR  
	FROM	
		#SAgWinLoss w   
		INNER JOIN 	#TempExchange e ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
	GROUP BY   
		Currency
		,CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
			  WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
			  ELSE '0' END   
		, CASE WHEN Currency = 51 THEN @VNDCurrencyName 
				ELSE e.Code END
	ORDER BY ReportType  

	DROP TABLE #SAgWinLoss
	DROP TABLE #TempExchange 
 
END   

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_PlaytechWinloss] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_PlaytechWinloss] TO [vnteam]