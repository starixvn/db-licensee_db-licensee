USE bodb_LicenseeReport
GO
ALTER PROCEDURE dbo.Task_CustomerActive_GenDataFromBettrans 
	@TransDate DATE
AS
/*
	 Creator: 20150204@Patrick
	 Task: Generate data for Customer Active
	 DB: DBLIC/bodb_LicenseeReport
	 Revisions:
		- 20150318@Patrick: Duplicate data for BA tickets
		- 20150916@Jim: support microgaming
		- 20150921@Jim: support AG Casino
	 Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON
	IF @TransDate IS NULL
		RETURN

	DECLARE @ProductCodes VARCHAR(125), @FromDate DATE, @ToDate DATE
	SELECT @FromDate = DATEADD(D, -1, @TransDate), @ToDate = DATEADD(D, 1, @TransDate)
	
	
	--get product prefix
	SET @ProductCodes = 'SB'
	SELECT @ProductCodes = COALESCE(@ProductCodes + ',' + ProductPrefix, ProductPrefix)
	FROM bodb_licensee.dbo.Product3rd WITH(NOLOCK) WHERE ProductPrefix NOT IN ('PTCS', 'AGC')

	--bettype mapping
	CREATE TABLE #Bettype (Bettype INT, ProductID INT)
    INSERT INTO #Bettype
    SELECT Bettype, ProductID 
	FROM bodb_licensee.dbo.LA_f_BettypeProductMapping(0, @ProductCodes)

	IF EXISTS (SELECT ProductID FROM #Bettype WHERE ProductID IN (0/*SB*/, 3/*BA*/) GROUP BY ProductID HAVING COUNT(1) > 1)
	BEGIN
		DELETE #Bettype WHERE ProductID = 3
	END

	--get licensee who is multi currencies
	DECLARE @MultiCurrencies TABLE(recommend INT, currency INT, fromDate SMALLDATETIME, toDate SMALLDATETIME)
	INSERT INTO @MultiCurrencies(recommend, currency, fromDate, toDate)
	SELECT recommend, currency, fromDate, toDate 
	FROM bodb_licensee.dbo.f_LicenseeMultiCurrencyConfigSel()

	CREATE TABLE #DataTmp (TransDate DATE, CustId INT, Recommend INT, CurrencyId INT, ProductId INT)

	--For SportsBook --merge
	INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	SELECT CAST(a.transdate AS DATE) AS TransDate, a.CustID, a.recommend, a.currency
		, CASE WHEN ba.transid IS NOT NULL THEN 3 ELSE bt.ProductID END AS ProductId
	FROM bodb02.dbo.bettrans a WITH (NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeCust c WITH(NOLOCK) ON a.recommend = c.custid
		INNER JOIN #Bettype bt ON a.bettype = bt.bettype
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction ba WITH (NOLOCK) ON a.transid = ba.transid
		LEFT JOIN @MultiCurrencies l ON a.recommend = l.recommend AND @TransDate BETWEEN l.fromDate AND l.toDate --incase keennocen
	WHERE a.bettype < 19999
		AND (a.transdate > @FromDate AND a.transdate < @ToDate
			OR a.winlostdate = @TransDate)
	GROUP BY CAST(a.transdate AS DATE), a.CustID, a.recommend, a.currency
		, CASE WHEN ba.transid IS NOT NULL THEN 3 ELSE bt.ProductID END
	OPTION (MAXDOP 1)

	--For Keno from translog table
	INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	SELECT b.TransDate, b.CustId, b.Recommend, b.currency, b.ProductId
	FROM (
		SELECT CAST(a.transdate AS DATE) AS TransDate, a.CustID, a.recommend
			, a.currency, bt.ProductId
		FROM bodb02.dbo.translog a WITH (NOLOCK)
			INNER JOIN bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK) ON a.recommend = lc.custid
			INNER JOIN #Bettype bt ON a.gameID = bt.bettype
		WHERE a.transdate > @FromDate AND transdate < @ToDate
		GROUP BY CAST(a.transdate AS DATE), a.CustID, a.recommend, a.currency, bt.ProductId
	)b LEFT JOIN #DataTmp tmp ON b.TransDate = tmp.TransDate AND b.custid = tmp.CustId AND b.ProductId = tmp.ProductId
	WHERE tmp.TransDate IS NULL
	OPTION (MAXDOP 1)
	-- Microgaming RNG
	INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	SELECT b.TransDate, b.CustId, b.Recommend, b.currency, b.ProductId
	FROM (
	SELECT g.transdate,g.custid,g.recommend,g.currency,14 ProductId
	FROM bodb02.dbo.bettransRnG g WITH (NOLOCK) 
		INNER JOIN bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK) ON g.recommend = lc.custid
	WHERE g.transdate  > @FromDate AND g.transdate < @ToDate
	) b
	LEFT JOIN #DataTmp tmp ON b.TransDate = tmp.TransDate AND b.custid = tmp.CustId AND tmp.ProductID=14
	WHERE tmp.TransDate IS NULL
	GROUP BY b.TransDate, b.CustId, b.Recommend, b.currency, b.ProductId
	
	-- AG Casino
	--INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	--SELECT CAST(TransDate AS DATE) AS TransDate, b.CustID, b.recommend, b.currency, 9 AS ProductId
	--FROM bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH(NOLOCK)
	--WHERE Winlostdate = @TransDate
	--GROUP BY CAST(TransDate AS DATE), b.CustID, b.recommend, b.currency
	--OPTION (RECOMPILE) --> Currently, playtech cs is terminated

	-- For AG Casino
	INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	SELECT b.TransDate, b.CustId, b.Recommend, b.currency, b.ProductId
	FROM (
	SELECT blc.transdate,blc.custid,blc.recommend,blc.currency,10 ProductId
	FROM bodb02.dbo.bettransLC blc WITH (NOLOCK) 
		INNER JOIN bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK) ON blc.recommend = lc.custid
	WHERE blc.transdate  > @FromDate AND blc.transdate < @ToDate
	) b
	LEFT JOIN #DataTmp tmp ON b.TransDate = tmp.TransDate AND b.custid = tmp.CustId AND tmp.ProductID=10
	WHERE tmp.TransDate IS NULL
	GROUP BY b.TransDate, b.CustId, b.Recommend, b.currency, b.ProductId
	
	-- AG Casino
	INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	SELECT b.TransDate, b.CustId, b.Recommend, b.currency, b.ProductId
	FROM (
	SELECT blc.transdate,blc.custid,blc.recommend,blc.currency,10 ProductId
	FROM bodb02.dbo.bettransLC blc WITH (NOLOCK) 
		INNER JOIN bodb_licensee.dbo.LicenseeCust lc WITH(NOLOCK) ON blc.recommend = lc.custid
	WHERE blc.transdate  > @FromDate AND blc.transdate < @ToDate
	) b
	LEFT JOIN #DataTmp tmp ON b.TransDate = tmp.TransDate AND b.custid = tmp.CustId AND tmp.ProductID=10
	WHERE tmp.TransDate IS NULL
	GROUP BY b.TransDate, b.CustId, b.Recommend, b.currency, b.ProductId
	
	--merge to business table
	INSERT INTO dbo.rptCustomerActive(TransDate, CustId, Recommend, CurrencyId, ProductId)
	SELECT tmp.TransDate, tmp.CustId, tmp.Recommend, tmp.CurrencyId, tmp.ProductId
	FROM #DataTmp tmp
		LEFT JOIN dbo.rptCustomerActive rpt WITH(NOLOCK) 
		ON tmp.TransDate = rpt.TransDate AND tmp.CustId = rpt.CustId AND tmp.ProductId = rpt.ProductId
	WHERE rpt.TransDate IS NULL
	OPTION (MAXDOP 1)

	DROP TABLE #Bettype
	DROP TABLE #DataTmp
END

GO
GRANT VIEW DEFINITION ON [dbo].[Task_CustomerActive_GenDataDaily] TO [vnteam] AS [dbo]
GO