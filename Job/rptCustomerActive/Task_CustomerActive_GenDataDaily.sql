USE bodb_LicenseeReport
GO
ALTER PROCEDURE dbo.Task_CustomerActive_GenDataDaily @TransDate DATE
AS
/*
	 Creator: 20150204@Patrick
	 Task: Generate data for Customer Active
	 DB: DBLIC/bodb_LicenseeReport
	 Revisions: 
	 Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON
	IF @TransDate IS NULL
		RETURN

	DECLARE @ProductCodes VARCHAR(125), @FromDate DATE, @ToDate DATE
	SELECT @FromDate = DATEADD(D, -1, @TransDate), @ToDate = DATEADD(D, 1, @TransDate)

	----get licensee cust
	--DECLARE @TmpLicenseeCust AS TABLE ( CustId INT, Currency INT)
	--INSERT INTO @TmpLicenseeCust (CustId, Currency)
	--SELECT CustID, Currency FROM bodb_licensee.dbo.f_SelLicenseeCust(0)
	
	--get product prefix
	SELECT @ProductCodes = COALESCE(@ProductCodes + ',' + ProductPrefix, ProductPrefix)
	FROM bodb_licensee.dbo.Product3rd WITH(NOLOCK) WHERE ProductPrefix NOT IN ('PTCS', 'AGC')

	--bettype mapping
	CREATE TABLE #Bettype (Bettype INT, ProductID INT)
    INSERT INTO #Bettype
    SELECT Bettype, ProductID 
	FROM bodb_licensee.dbo.LA_f_BettypeProductMapping(0, @ProductCodes)

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
		AND a.transdate > @FromDate AND a.transdate < @ToDate
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

	-- For Playtech Casino --merge
	--INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	--SELECT CAST(TransDate AS DATE) AS TransDate, b.CustID, b.recommend, b.currency, 9 AS ProductId
	--FROM bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH(NOLOCK)
	--WHERE Winlostdate = @TransDate
	--GROUP BY CAST(TransDate AS DATE), b.CustID, b.recommend, b.currency
	--OPTION (RECOMPILE) --> Currently, playtech cs is terminated

	-- For AG Casino
	INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
	SELECT CAST(TransDate AS DATE) AS TransDate, b.CustID, b.recommend, b.currency, 10 AS ProductId
	FROM bodb_PlaytechCS.dbo.bettrans_AGCasino b WITH(NOLOCK)
	WHERE Winlostdate = @TransDate
	GROUP BY CAST(TransDate AS DATE), b.CustID, b.recommend, b.currency
	OPTION (RECOMPILE)

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