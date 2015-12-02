USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_CasinoProgressiveWins] 
	 @LicenseeID	INT,
	 @UserID		INT, 
	 @CurrencyID	INT = 0,
	 @FromDate		SMALLDATETIME,  
	 @ToDate		SMALLDATETIME,  
	 @showMGCRnG	BIT=0,
	 @excludeTest	BIT = 0,
	 @MoveBetsDay	SMALLDATETIME,
	 @BalanceUpDay	SMALLDATETIME
 AS  
/*  Created: Sophia  
	Date: 20151119
    Task : Casino Progressive Wins [RedmineID: #47601]
    DB: DBEXT/bodb02  
   
    Revisions:

	Param's Explanation: 
	 
*/
BEGIN 
	SET NOCOUNT ON  	
	
	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	DECLARE @tempAg	TABLE( custID INT,Currency INT)   	 
	DECLARE @sporttype TABLE(sporttype INT)	 

	CREATE TABLE #JackPotWin
	( 
	  WinlostDate SMALLDATETIME, 
	  CustId INT,
	  ExternalId VARCHAR (50) ,
	  SystemId VARCHAR (30), 
	  RefNo BIGINT,
	  WinAmount MONEY, 
	  Bettype SMALLINT, 
	  SportType SMALLINT, 
	  TransDesc NVARCHAR(1000),
	  Currency INT
	)

	SELECT	currencyID,LicenseeID 
	INTO	#currency
	FROM	dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1) -- System is default=1 (LRF)
	WHERE	(@CurrencyID = 0  OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID))


	INSERT INTO @tempAg (custID,Currency) 
	SELECT custID,Currency
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc  
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE (@excludeTest = 0 OR (@excludeTest = 1 AND Currency <> 20))

	IF @showMGCRnG =1  -- MicroGamming - RNG Casino
	BEGIN 
		INSERT INTO @sporttype (sporttype)
		VALUES(205)
	END
	
	IF @MoveBetsDay < @ToDate
	BEGIN 
		SET @_ToDate = @Todate 

		IF @MoveBetsDay < @FromDate
			SET @_FromDate = @FromDate
		ELSE 
			SET @_FromDate = @MoveBetsDay

		INSERT INTO #JackPotWin (WinlostDate, CustId, ExternalId, SystemID, RefNo, WinAmount, Bettype, Sporttype, TransDesc, Currency)
		SELECT	p.WinlostDate, p.CustId, c.username2 as ExternalId, p.Username as SystemID, 
				p.RefNo, p.WinAmount, p.GameId as Bettype, p.ProductId as Sporttype, b.transdesc, tma.currency
		FROM	DBACC.bodb02.dbo.PayOutTrans p WITH (NOLOCK)
			INNER JOIN dbo.BettransRNG b WITH (NOLOCK) 
				ON p.RefNo = b.TransId
			INNER JOIN bodb_licensee.dbo.Licenseecustinfo c WITH (NOLOCK)
				ON c.CustId = p.CustId
			INNER JOIN @TempAg tma ON tma.CustID=c.recommend AND c.currency = tma.currency
		WHERE	p.Winlostdate BETWEEN @_FromDate AND @_ToDate
			AND p.ProductId IN (Select sporttype FROM @sporttype)
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN 
		IF @FromDate <= @BalanceUpDay
			SET @_FromDate = @BalanceUpDay
		ELSE
			SET @_FromDate = @FromDate 

		IF  @MoveBetsDay < @ToDate
			SET @_ToDate = @MoveBetsDay
		ELSE 
			SET @_ToDate = @Todate
		
		INSERT INTO #JackPotWin (WinlostDate, CustId, ExternalId, SystemID, RefNo, WinAmount, Bettype, Sporttype, TransDesc, currency)
		SELECT	p.WinlostDate, p.CustId, c.username2 as ExternalId, p.Username as SystemID, 
				p.RefNo, p.WinAmount, p.GameId as Bettype, p.ProductId as Sporttype, b.transdesc, tma.currency
		FROM	DBACC.bodb02.dbo.PayOutTrans p WITH (NOLOCK)
			INNER JOIN dbo.BettransRNG14 b WITH (NOLOCK) 
				ON p.RefNo = b.TransId
			INNER JOIN bodb_licensee.dbo.Licenseecustinfo c WITH (NOLOCK)
				ON c.CustId = p.CustId
			INNER JOIN @TempAg tma ON tma.CustID=c.recommend AND c.currency = tma.currency
		WHERE	p.Winlostdate BETWEEN @_FromDate AND @_ToDate
			AND p.ProductId IN (Select sporttype FROM @sporttype)

	END

	IF @FromDate < @BalanceUpDay
	BEGIN 
		SET @_FromDate = @FromDate 

		IF @BalanceUpDay < @ToDate
			SET @_ToDate = @BalanceUpDay
		ELSE 
			SET @_ToDate = @Todate
		
		INSERT INTO #JackPotWin (WinlostDate, CustId, ExternalId, SystemID, RefNo, WinAmount, Bettype, Sporttype, TransDesc, currency)
		SELECT	p.WinlostDate, p.CustId, c.username2 as ExternalId, p.Username as SystemID, 
				p.RefNo, p.WinAmount, p.GameId as Bettype, p.ProductId as Sporttype, b.transdesc, tma.currency
		FROM	DBACC.bodb02.dbo.PayOutTrans p WITH (NOLOCK)
			INNER JOIN DBARC.bodb_archive.dbo.BettransRNG_BK b WITH (NOLOCK) 
				ON p.RefNo = b.TransId
			INNER JOIN bodb_licensee.dbo.Licenseecustinfo c WITH (NOLOCK)
				ON c.CustId = p.CustId
			INNER JOIN @TempAg tma ON tma.CustID=c.recommend AND c.currency = tma.currency
		WHERE	p.Winlostdate BETWEEN @_FromDate AND @_ToDate
			AND p.ProductId IN (Select sporttype FROM @sporttype)

	END 


	SELECT *
	INTO #TempExchange 
	FROM dbo.Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #JackPotWin)

	----Get Data

	SELECT j.WinlostDate, J.CustId, j.ExternalId, j.SystemID, 
		  j.RefNo, j.WinAmount, j.Bettype, j.Sporttype, j.transdesc, j.currency,
		  j.WinAmount * e.EUR AS WinAmountEUR,
		  j.WinAmount * e.USD AS WinAmountUSD,
		  j.WinAmount * e.GBP AS WinAmountGBP
	FROM  #JackPotWin j
	INNER JOIN #TempExchange e
		ON j.winlostdate = e.ExchangeDate AND j.currency = e.ExchangeId
			
	
END

GO 
GRANT EXECUTE ON [Lrf_Rpt_CasinoProgressiveWins] TO [bodbLicenseeNet] AS [dbo]
GO