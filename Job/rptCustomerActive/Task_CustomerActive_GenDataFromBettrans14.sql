USE bodb_LicenseeReport
GO
ALTER PROCEDURE dbo.Task_CustomerActive_GenDataFromBettrans14 @FromDate DATE
	, @ToDate DATE
	, @ProductCodes VARCHAR(125) = 'SB,NG,BA,LC,VS,CS,GB,KN'
AS
/*   
	Creator: 20150204@Patrick
	Task: Generate for rptCustomerActive from bettrans14
	DB: DBLIC/bodb_LicenseeReport
	Revisions: 
		- 20150318@Patrick: Duplicate data for BA tickets
	Param's Explanation:
	
*/

BEGIN
	SET NOCOUNT ON

	IF @FromDate IS NULL OR @ToDate IS NULL OR @ProductCodes IS NULL
		RETURN

	DECLARE @FromTransDate DATE, @ToTransDate DATE--, @MinTransId BIGINT, @MaxTransId BIGINT
	SELECT @FromTransDate = DATEADD(D, -1, @FromDate), @ToTransDate = DATEADD(D, 1, @FromDate)

	--get licensee cust
	--DECLARE @TmpLicenseeCust AS TABLE ( CustId INT, Currency INT )
	--INSERT INTO @TmpLicenseeCust (CustId, Currency)
	--SELECT CustID, Currency FROM bodb_licensee.dbo.f_SelLicenseeCust(0)

	--get licensee who is multi currencies
	DECLARE @MultiCurrencies TABLE(recommend INT, currency INT, fromDate SMALLDATETIME, toDate SMALLDATETIME)
	INSERT INTO @MultiCurrencies(recommend, currency, fromDate, toDate)
	SELECT recommend, currency, fromDate, toDate 
	FROM bodb_licensee.dbo.f_LicenseeMultiCurrencyConfigSel()

	CREATE TABLE #DataTmp (TransDate DATE, CustId INT, Recommend INT, CurrencyId INT, ProductId INT)

	--bettype mapping
	CREATE TABLE #Bettype (Bettype INT, ProductID INT)
    INSERT INTO #Bettype
    SELECT Bettype, ProductID 
	FROM bodb_licensee.dbo.LA_f_BettypeProductMapping(0, @ProductCodes)

	IF EXISTS (SELECT ProductID FROM #Bettype WHERE ProductID IN (0/*SB*/, 3/*BA*/) GROUP BY ProductID HAVING COUNT(1) > 1)
	BEGIN
		DELETE #Bettype WHERE ProductID = 3
	END
	
	DECLARE @TotalDays INT, @Index INT
	SELECT @TotalDays = DATEDIFF(D, @FromDate, @ToDate), @Index = 0
	
	WHILE @Index <= @TotalDays
	BEGIN
		INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
		SELECT CAST(a.transdate AS DATE) AS TransDate, a.CustID, a.recommend
			, ISNULL(l.currency, a.currency) AS currency
			, CASE WHEN ba.transid IS NOT NULL THEN 3 ELSE bt.ProductID END AS ProductId
		FROM bodb02.dbo.bettrans14 a WITH (NOLOCK)
			INNER JOIN bodb_licensee.dbo.LicenseeCust c WITH(NOLOCK) ON a.recommend = c.custid
			INNER JOIN #Bettype bt ON a.bettype = bt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction ba WITH (NOLOCK) ON a.transid = ba.transid
			LEFT JOIN @MultiCurrencies l ON a.recommend = l.recommend AND @FromTransDate BETWEEN l.fromDate AND l.toDate --incase keennocen
		WHERE a.bettype < 19999
			AND ((a.transdate > @FromTransDate AND a.transdate < @ToTransDate )
				OR (a.winlostdate > @FromTransDate AND a.winlostdate < @ToTransDate))
		GROUP BY CAST(a.transdate AS DATE), a.CustID, a.recommend
			, ISNULL(l.currency, a.currency), CASE WHEN ba.transid IS NOT NULL THEN 3 ELSE bt.ProductID END
		OPTION (MAXDOP 1)

		--merge to business table
		INSERT INTO dbo.rptCustomerActive(TransDate, CustId, Recommend, CurrencyId, ProductId)
		SELECT tmp.TransDate, tmp.CustId, tmp.Recommend, tmp.CurrencyId, tmp.ProductId
		FROM #DataTmp tmp
			LEFT JOIN dbo.rptCustomerActive rpt WITH(NOLOCK) 
			ON tmp.TransDate = rpt.TransDate AND tmp.CustId = rpt.CustId AND tmp.ProductId = rpt.ProductId
		WHERE rpt.TransDate IS NULL
		OPTION (MAXDOP 1)

		--clean data
		DELETE #DataTmp
		SELECT @FromTransDate = DATEADD(D, 1, @FromTransDate)
			, @ToTransDate = DATEADD(D, 1, @ToTransDate)
			, @Index = @Index + 1

		WAITFOR DELAY '00:00:00.280'
	END

	DROP TABLE #Bettype
	DROP TABLE #DataTmp
END

GO
GRANT VIEW DEFINITION ON [dbo].[Task_CustomerActive_GenDataFromBettrans14] TO [vnteam] AS [dbo]
GO