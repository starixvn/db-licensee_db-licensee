ALTER PROCEDURE [dbo].[Lrf_GetLicenseePendingFunds]
    @LicenseeID		INT,
	@UserID			INT,
    @CurrencyID		INT = 0
AS 
/*
Created: 20170119@Joseph
Task : Dashboard API - Pending funds
DB: DBEXT.bodb02

Revisions:
	- 20170119@Joseph: Copy from Lrf_Rpt_Outstanding
Param's Explanation:
	
*/
BEGIN
    SET NOCOUNT ON
    DECLARE
        @Today		SMALLDATETIME,
		@FromDate	DATETIME,
		@ToDate		DATETIME
	
	SELECT  @Today	= CONVERT(DATE, GETDATE()) 
    
    SELECT	@FromDate	= CASE WHEN MAX(m.eventdate) <= @Today THEN MAX(m.eventdate) ELSE @Today END,
			@ToDate		= @Today
	FROM dbo.match14 m (NOLOCK)
	GROUP BY m.eventdate 	        
	
	SELECT currencyID, LicenseeID INTO #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)
	WHERE (@CurrencyID = 0 OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID))

    DECLARE @TempAg TABLE (CustId INT, Currency INT)
    INSERT INTO @TempAg(CustId, Currency)
    SELECT CustID, Currency 
	FROM
		bodb_licensee.dbo.f_SelLicenseeCust(@LicenseeID) lc   
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID

	DROP TABLE #Currency
		
    DECLARE @Outstanding TABLE
	(
		currency	INT,
		outstanding MONEY    
	)       
    
    INSERT INTO @Outstanding
	-- bettrans --
	SELECT                 
		b.currency,
		SUM(actual_stake) Outstanding
		   
	FROM 
		dbo.bettrans AS b WITH(NOLOCK)
		INNER JOIN @TempAg a ON b.recommend = a.CustId AND b.Currency = a.Currency
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid                  
	WHERE  
		BA.transid IS NULL 
		AND b.bettype <= 1399 
		AND b.ruben = 0
		AND b.matchid > 0
		AND b.bettype NOT BETWEEN 2101 AND 2399 -- exclude OWRnG
		AND b.bettype NOT BETWEEN 4001 AND 7999 -- exclude Voidbridge
	
	GROUP BY
		b.currency
		
	-- translog --
	UNION ALL
	SELECT
		t.currency,
		SUM(t.actual_stake) Outstanding
	FROM
		dbo.translog t WITH (NOLOCK) 
		INNER JOIN @TempAg a ON t.recommend = a.CustId AND t.Currency = a.Currency
	WHERE
		t.statusID = 0
	GROUP BY
		t.currency     
	
	-- bettrans RNG --
	UNION ALL
	SELECT
		g.currency,
		SUM(g.actual_stake) Outstanding
	FROM
		dbo.BettransRNG g WITH (NOLOCK) 
		INNER JOIN @TempAg a ON g.recommend = a.CustId AND g.Currency = a.Currency
		INNER JOIN dbo.Custinfo c WITH (NOLOCK) ON g.CustID = c.CustID
	WHERE
		statusid IN (0, 1) -- AND IsSum = 0
	GROUP BY g.currency

	-- bettransLC --
	UNION ALL
	SELECT
		g.currency,
		SUM(g.actual_stake) Outstanding
	FROM
		dbo.bettransLC g WITH (NOLOCK) 
		INNER JOIN @TempAg a ON g.recommend = a.CustId AND g.Currency = a.Currency
		INNER JOIN dbo.Custinfo c WITH (NOLOCK) ON g.CustID = c.CustID
	WHERE
		statusid IN (0, 1) -- AND IsSum = 0
		
	GROUP BY g.currency
    
    SELECT  
		ISNULL(SUM(Outstanding),0.00) AS SumOutstanding,
        ISNULL(SUM(Outstanding * e.USD),0.00) AS SumOutstandingUSD,
        ISNULL(SUM(Outstanding * e.EUR),0.00) AS SumOutstandingEUR,
		ISNULL(SUM(Outstanding * e.GBP),0.00) AS SumOutstandingGBP
    FROM
		@Outstanding b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.currency
END