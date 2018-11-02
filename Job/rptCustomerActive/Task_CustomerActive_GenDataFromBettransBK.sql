/*<info serverAlias="DBRPT-bodb_Report" executers="" isFunction="0" isNested="0"></info>*/
USE [bodb_Report]
GO

ALTER PROCEDURE dbo.Task_CustomerActive_GenDataFromBettransBK
	@FromDate	DATE,
	@ToDate		DATE
AS
/*   
	Creator: 20150204@Patrick
	Task: Gen history data from bettrans_bk
	DB: DBACC/bodb_Report
	
	Revisions:
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]

	Param's Explanation:
		ProductId: 1: Racing, 2: Number Game, 3: BA, 4: Live Casino, 5: Virtual Sports, 6: RNG Casino
			, 7: Bingo, 8: Keno, 9: Playtech Casino, 10: AG Casino
*/
BEGIN
	SET NOCOUNT ON

	IF @FromDate IS NULL OR @ToDate IS NULL
		RETURN

	--clean data from temp table
	DELETE FROM dbo.rptCustomerActiveTmp WITH(ROWLOCK)
	WHERE WinLostDate BETWEEN @FromDate AND @ToDate

	DECLARE @WinlostDate DATE, @MinTransId BIGINT, @MaxTransId BIGINT
	SELECT	@WinlostDate = @FromDate

	--get licensee who is multi currencies
	DECLARE @MultiCurrencies TABLE(recommend INT, currency INT, fromDate SMALLDATETIME, toDate SMALLDATETIME)
	INSERT INTO @MultiCurrencies(recommend, currency, fromDate, toDate)
	SELECT recommend, currency, fromDate, toDate FROM bodb_licensee.dbo.f_LicenseeMultiCurrencyConfigSel()
	
	CREATE TABLE #LicenseeBATransaction(transid BIGINT)
	--CREATE TABLE #rptCustomerActiveTmp (TransDate DATE, CustId INT, Recommend INT, CurrencyId INT, ProductId INT)

	WHILE @WinlostDate <= @ToDate
	BEGIN
		--get max, min transid
		SELECT @MinTransId = MIN(TransId), @MaxTransId = MAX(TransId)
		FROM bodb_archive.dbo.bettrans_bk a WITH (NOLOCK)
		WHERE a.winlostdate = @WinlostDate-- AND bettype < 19999
		OPTION (MAXDOP 1)

		--get BA tickets
		INSERT INTO #LicenseeBATransaction (transid)
		SELECT transid 
		FROM bodb_Licensee.dbo.LicenseeBATransaction WITH (NOLOCK) WHERE TransId BETWEEN @MinTransId AND @MaxTransId
		OPTION (MAXDOP 1)

		--For SportsBook
		INSERT INTO dbo.rptCustomerActiveTmp(TransDate, CustId, Recommend, CurrencyId, ProductId, WinLostDate)
		SELECT CAST(a.transdate AS DATE) AS TransDate, a.CustID, a.recommend, ISNULL(l.currency, a.currency) AS currency
			, CASE  WHEN (a.bettype < 31 OR (a.bettype >= 121 AND a.bettype < 1000) OR (a.bettype BETWEEN 1301 AND 1399)) AND ba.transid IS NULL THEN 0 -- SB
					WHEN a.bettype IN (31, 32, 33, 41, 42, 43) THEN 1	-- Racing
					WHEN a.bettype BETWEEN 81 AND 120 THEN 2 -- Number Game
					WHEN ba.transid IS NOT NULL THEN 3	-- BA
					WHEN a.bettype BETWEEN 1101 AND 1199 THEN 4 -- Live Casino
					WHEN a.bettype BETWEEN 1201 AND 1299 THEN 5 -- Virtual Sports
					WHEN a.bettype IN (71, 72) THEN 6 -- RnG Casino
					WHEN a.bettype = 73 THEN 7 -- Bingo
					WHEN a.bettype BETWEEN 1501 AND 1599 THEN 8 -- Keno
				ELSE - 1 END AS ProductId
			, winlostdate
		FROM bodb_archive.dbo.bettrans_bk a WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custid = a.srecommend
			--INNER JOIN @TmpLicenseeCust c ON a.recommend = c.custid-- AND a.currency = c.Currency
			LEFT JOIN #LicenseeBATransaction ba ON a.transid = ba.transid
			LEFT JOIN @MultiCurrencies l ON a.recommend = l.recommend AND @WinlostDate BETWEEN l.fromDate AND l.toDate --incase keenocen
		WHERE a.winlostdate = @WinlostDate
			AND bettype < 19999
		GROUP BY CAST(a.transdate AS DATE), a.CustID, a.recommend, ISNULL(l.currency, a.currency)
			, CASE  WHEN (a.bettype < 31 OR (a.bettype >= 121 AND a.bettype < 1000) OR (a.bettype BETWEEN 1301 AND 1399)) AND ba.transid IS NULL THEN 0 -- SB
					WHEN a.bettype IN (31, 32, 33, 41, 42, 43) THEN 1	-- Racing
					WHEN a.bettype BETWEEN 81 AND 120 THEN 2 -- Number Game
					WHEN ba.transid IS NOT NULL THEN 3	-- BA
					WHEN a.bettype BETWEEN 1101 AND 1199 THEN 4 -- Live Casino
					WHEN a.bettype BETWEEN 1201 AND 1299 THEN 5 -- Virtual Sports
					WHEN a.bettype IN (71, 72) THEN 6 -- RnG Casino
					WHEN a.bettype = 73 THEN 7 -- Bingo
					WHEN a.bettype BETWEEN 1501 AND 1599 THEN 8 -- Keno
				ELSE - 1 END
			, winlostdate
		OPTION (MAXDOP 1)
	
		--reset params
		DELETE #LicenseeBATransaction
		SELECT @MinTransId = 0, @MaxTransId = 0, @WinlostDate = DATEADD(D, 1, @WinlostDate)

		WAITFOR DELAY '00:00:00.280'
	
	END

	SELECT COUNT(1) FROM dbo.rptCustomerActiveTmp
	WHERE TransDate BETWEEN @FromDate AND @ToDate

	DROP TABLE #LicenseeBATransaction
	--DROP TABLE #rptCustomerActiveTmp
END

GO
GRANT VIEW DEFINITION ON [dbo].[Task_CustomerActive_GenDataFromBettransBK] TO [vnteam] AS [dbo]
GO