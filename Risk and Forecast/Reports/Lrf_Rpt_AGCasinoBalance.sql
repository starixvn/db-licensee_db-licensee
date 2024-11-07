/*<info serverAlias="DBPTCS-bodb_PlaytechCS" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_AGCasinoBalance] 
	@FromDate				SMALLDATETIME,  
	@ToDate					SMALLDATETIME,   
	@AgentList				VARCHAR(MAX),
	@BaseCurrency			VARCHAR(12) = '',
	@DefaultBaseCurrency	VARCHAR(12) = ''
/*  Created: Winnie
	Date: 2015-01-20
    Task : AG balance report 
    DB: DBPTCS.bodb_PlaytechCS  
    Revisions:
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20161125@Paul: improve performance by using temp table #BalanceAGCasino [Redmine: #66801]
		- 20160104@Francis: change join type from inner join to hash join for remote query to enhance duration
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180529@Joseph: Add OPTION RECOMPILE to fix performance issue
		- 20190617@Amanda: Add Base currency param [RedmineID: #112531]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20241011@Kelvin: AG Casino Win Loss - Enhance consistency check [RedmineID: #211837]
*/ 
AS
BEGIN
	IF (MONTH ( @FromDate )<>MONTH (@ToDate))
	BEGIN
		Print 'Just view data in 1 month'
		RETURN
	END

	--DECLARE 

	CREATE TABLE #tmpResult (
		Winlostdate DATETIME
		,Custid		  INT
		,Currency 		  INT
		,TurnOver 		  MONEY
		,TotalTrans	  INT	
		,Winlost  		  MONEY
		,LicenseeWinlost MONEY
		,PRIMARY KEY(Winlostdate,Currency,Custid)
	)
		
	DECLARE  @TmpCTECalc TABLE(	
		date			DATETIME,
		currency		INT,
		OpeningBalance	MONEY,
		TransferIn		MONEY,
		TransferOut		MONEY,
		ClosingBalance	MONEY
	)

	CREATE TABLE #tmpCust (
		CustId INT
		,Currency INT
	)
	
	CREATE TABLE #BalanceAGCasino(
		WinlostDate DATETIME,
		Currency smallint,
		CustId int,
		OpeningBalance money
	)
	
	CREATE CLUSTERED INDEX ix_#BalanceAGCasino_cl ON #BalanceAGCasino(WinlostDate, Currency, CustId)

	CREATE TABLE #TempExchange(ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)

	DECLARE @minWinlostdate SMALLDATETIME,@tmpCurrency INT,@tmpOpeningBalance MONEY
	
	SELECT @minWinlostdate = MIN(winlostdate) FROM DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers WITH(NOLOCK)

	DECLARE @Temp AS TABLE ( CustId INT,Currency INT )

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @Temp(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	INSERT INTO #tmpCust (CustID,Currency)	
	SELECT  co.CustID 
			,co.Currency 
	FROM bodb02.dbo.Custinfo co WITH (NOLOCK)
	WHERE EXISTS (
			SELECT 1
			FROM @Temp lc
			WHERE co.recommend = lc.CustId AND lc.Currency = co.Currency
		)
	
	INSERT INTO #BalanceAGCasino(WinlostDate, Currency, CustId, OpeningBalance)
	SELECT WinlostDate, b.Currency, b.CustId, OpeningBalance
	FROM BalanceAGCasino b WITH(NOLOCK)
	WHERE b.WinlostDate BETWEEN @FromDate AND @ToDate
		AND EXISTS (
			SELECT 1
			FROM #tmpCust c
			WHERE b.Currency = c.Currency AND b.CustId = c.CustId
		)
		OPTION (RECOMPILE)
		
	INSERT INTO #tmpResult (Winlostdate
							, CustId 
							 ,Currency 	
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)

	SELECT	c.Winlostdate
			,ct.CustId
			,ct.Currency
			,SUM(c.TurnOver) AS TurnOver
			,SUM(c.BetCount) AS TotalTrans
			,SUM(c.Winlost)  AS Winlost
			,-SUM(c.Winlost) AS LicenseeWinlost
	FROM  bodb_LicenseeReport.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
		INNER HASH JOIN #tmpCust ct ON c.CustID = ct.CustID AND c.Currency = ct.Currency
	WHERE c.Winlostdate BETWEEN @FromDate AND @ToDate 
	GROUP BY c.Winlostdate	
		    ,ct.Currency	
			,ct.CustId

	IF(@FromDate>=@minWinlostdate)--get from transfer3rdOthers
	BEGIN
		INSERT INTO @TmpCTECalc(DATE,	Currency,OpeningBalance,TransferIn,	TransferOut,ClosingBalance)	
		SELECT	b.WinlostDate,b.currency,SUM(b.OpeningBalance),SUM(ISNULL(r.TransferIn,0)) AS TransferIn,
				SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,SUM(b.OpeningBalance+ISNULL(t.WinLost,0)+ISNULL(r.TransferIn,0)+(ISNULL(r.TransferOut,0))) AS ClosingBalance
		FROM #BalanceAGCasino b
			LEFT JOIN #tmpResult t  on  b.WinlostDate=t.WinlostDate AND b.Currency=t.Currency AND b.CustId=t.CustId
			LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers r WITH (NOLOCK)  ON b.WinlostDate=r.[winlostdate] AND b.Currency=r.currency   AND b.CustId=r.CustId AND r.[PartnerId]=3
		GROUP BY b.WinlostDate
			,b.currency
	END
	ELSE IF(@ToDate<@minWinlostdate)---get from transfer3rdOthers_bk
	BEGIN 
		INSERT INTO @TmpCTECalc(DATE,	Currency,OpeningBalance,TransferIn,	TransferOut,ClosingBalance)	
		SELECT	b.WinlostDate,b.currency,SUM(b.OpeningBalance),SUM(ISNULL(r.TransferIn,0)) AS TransferIn,
				SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,SUM(b.OpeningBalance+ISNULL(t.WinLost,0)+ISNULL(r.TransferIn,0)+(ISNULL(r.TransferOut,0))) AS ClosingBalance
		FROM #BalanceAGCasino b
			LEFT JOIN #tmpResult t   on  b.WinlostDate=t.WinlostDate AND b.Currency=t.Currency AND b.CustId=t.CustId
			LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers_bk r WITH (NOLOCK)  ON b.WinlostDate=r.[winlostdate] AND b.Currency=r.currency   AND b.CustId=r.CustId AND r.[PartnerId]=3
		GROUP BY b.WinlostDate
				,b.currency
	END 
	ELSE ---get from transfer3rdOthers_bk and  from transfer3rdOthers
	BEGIN 
		INSERT INTO @TmpCTECalc(DATE,	Currency,OpeningBalance,TransferIn,	TransferOut,ClosingBalance)	
		SELECT	b.WinlostDate,b.currency,SUM(b.OpeningBalance),SUM(ISNULL(r.TransferIn,0)) AS TransferIn,
				SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,SUM(b.OpeningBalance+ISNULL(t.WinLost,0)+ISNULL(r.TransferIn,0)+(ISNULL(r.TransferOut,0))) AS ClosingBalance
		FROM #BalanceAGCasino b
			LEFT JOIN #tmpResult t   on  b.WinlostDate=t.WinlostDate AND b.Currency=t.Currency AND b.CustId=t.CustId
			LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers_bk r WITH (NOLOCK)  ON b.WinlostDate=r.[winlostdate] AND b.Currency=r.currency   AND b.CustId=r.CustId AND r.[PartnerId]=3
		WHERE (b.WinlostDate BETWEEN @FromDate AND (@minWinlostdate-1)) 
		GROUP BY b.WinlostDate
				,b.currency

		INSERT INTO @TmpCTECalc(DATE,	Currency,OpeningBalance,TransferIn,	TransferOut,ClosingBalance)	
		SELECT	b.WinlostDate,b.currency,SUM(b.OpeningBalance),SUM(ISNULL(r.TransferIn,0)) AS TransferIn,
				SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,SUM(b.OpeningBalance+ISNULL(t.WinLost,0)+ISNULL(r.TransferIn,0)+(ISNULL(r.TransferOut,0))) AS ClosingBalance
		FROM #BalanceAGCasino b
			LEFT JOIN #tmpResult t   on  b.WinlostDate=t.WinlostDate AND b.Currency=t.Currency AND b.CustId=t.CustId
			LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers r WITH (NOLOCK)  ON b.WinlostDate=r.[winlostdate] AND b.Currency=r.currency   AND b.CustId=r.CustId AND r.[PartnerId]=3
		WHERE (b.WinlostDate BETWEEN @minWinlostdate AND @ToDate) 
		GROUP BY b.WinlostDate 
				,b.currency
	END 

	IF EXISTS (SELECT TOP (1) 1 FROM @TmpCTECalc)
	BEGIN
		INSERT INTO #TempExchange(ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@ToDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM @Temp a WHERE e.ExchangeID = a.Currency)
	END

	SELECT	a.[date],a.currency
			,TotalTrans
			
			,a.OpeningBalance*e.Rate	AS OpeningBalance
			,a.ClosingBalance *e.Rate	AS ClosingBalance
			,a.TransferIn*e.Rate		AS TransferIn
			,a.TransferOut * e.Rate		AS TransferOut
			,TurnOver*e.Rate			AS TurnOver
			,Winlost*e.Rate				AS Winlost
			,LicenseeWinlost*e.Rate		AS LicenseeWinlost
			
			,a.OpeningBalance*e.USD		AS OpeningBalanceUSD 
			,a.ClosingBalance *e.USD	AS ClosingBalanceUSD
			,a.TransferIn*e.USD			AS TransferInUSD
			,a.TransferOut * e.USD		AS TransferOutUSD
			,TurnOver*e.USD				AS TurnOverUSD
			,Winlost*e.USD				AS WinlostUSD 
			,LicenseeWinlost*e.USD		AS LicenseeWinlostUSD
			
			,a.OpeningBalance*e.EUR		AS OpeningBalanceEUR 
			,a.ClosingBalance *e.EUR	AS ClosingBalanceEUR
			,a.TransferIn*e.EUR			AS TransferInEUR
			,a.TransferOut * e.EUR		AS TransferOutEUR
			,TurnOver*e.EUR				AS TurnOverEUR
			,Winlost*e.EUR				AS WinlostEUR 
			,LicenseeWinlost*e.EUR		AS LicenseeWinlostEUR
			
			,a.OpeningBalance*e.GBP		AS OpeningBalanceGBP 
			,a.ClosingBalance *e.GBP	AS ClosingBalanceGBP
			,a.TransferIn*e.GBP			AS TransferInGBP
			,a.TransferOut * e.GBP		AS TransferOutGBP
			,TurnOver*e.GBP				AS TurnOverGBP
			,Winlost*e.GBP				AS WinlostGBP 
			,LicenseeWinlost*e.GBP		AS LicenseeWinlostGBP
			
			,a.OpeningBalance*e.DefaultRate		AS OpeningBalanceBase
			,a.ClosingBalance *e.DefaultRate	AS ClosingBalanceBase
			,a.TransferIn*e.DefaultRate			AS TransferInBase
			,a.TransferOut * e.DefaultRate		AS TransferOutBase
			,TurnOver*e.DefaultRate				AS TurnOverBase
			,Winlost*e.DefaultRate				AS WinlostBase 
			,LicenseeWinlost*e.DefaultRate		AS LicenseeWinlostBase
	FROM @TmpCTECalc a 
		LEFT JOIN (
			SELECT  Winlostdate,Currency, SUM(TurnOver) AS TurnOver,
				SUM(TotalTrans) AS TotalTrans,
				SUM(Winlost) AS Winlost,
				SUM(LicenseeWinlost) AS LicenseeWinlost
			FROM #tmpResult GROUP BY Winlostdate,Currency
		) b ON a.date=b.Winlostdate AND a.currency =b.Currency
		LEFT JOIN #TempExchange e ON a.currency = e.ExchangeId
	order BY a.date asc	
	

	---------
	DROP TABLE #tmpResult
	DROP TABLE #tmpCust
	DROP TABLE #TempExchange
	
END
GO