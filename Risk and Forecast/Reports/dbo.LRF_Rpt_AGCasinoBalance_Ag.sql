/*<info serverAlias="DBPTCS-bodb_PlaytechCS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[LRF_Rpt_AGCasinoBalance_Ag] 
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@AgentList				VARCHAR(MAX),
	@BaseCurrency			VARCHAR(3) = '',
	@DefaultBaseCurrency	VARCHAR(3) = ''
AS
/*  Created: Winnie
	Date: 20150122
    Task : AG Balance report 
    DB: DBPTCS.bodb_PlaytechCS  
    Revisions: 
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20190618@Amanda: Add Base currency param [RedmineID: #112531]
*/  

BEGIN
	IF (MONTH ( @FromDate )<>MONTH (@ToDate))
	BEGIN
	Print 'Just view data in 1 month'
	RETURN
	END
	CREATE TABLE #tmpResult (
		CustID				INT
		, Currency 			INT
		, TurnOver 			MONEY
		, TotalTrans		INT	
		, Winlost  			MONEY
		, LicenseeWinlost	MONEY
	)

	CREATE TABLE #tmpCust ( 
		Recommend			INT
		, CustId			INT
		, Currency			INT	
	)

	CREATE TABLE #TempOpeningBalance (
		Recommend			INT
		,OpeningBalance		MONEY
	)
	
	CREATE TABLE #TempExchange(ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)
			
	DECLARE @minWinlostdate SMALLDATETIME
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
	
	INSERT INTO #tmpCust (Recommend,CustID,Currency)	
	SELECT   lc.CustId AS Recommend
			 ,co.CustID
			 ,lc.Currency
	FROM 
		bodb02.dbo.CustInfo co WITH (NOLOCK)
		INNER JOIN @Temp lc ON lc.CustId = co.Recommend AND co.Currency = lc.Currency
		INNER JOIN [dbo].[BalanceAGCasino] d WITH ( NOLOCK) ON co.custid=d.CustId
	WHERE d.WinlostDate BETWEEN @FromDate AND @ToDate

	INSERT INTO #TempExchange(ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
	SELECT ExchangeID, USD, EUR, GBP, Rate, DefaultRate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @FromDate, @BaseCurrency, @DefaultRate) e
	WHERE EXISTS (SELECT 1 FROM @Temp a WHERE e.ExchangeID = a.Currency)

		
	INSERT INTO #tmpResult (CustId 							
							 ,Currency 	
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)

	SELECT ag.recommend AS CustID		  
		   ,ag.Currency
		   ,SUM(c.TurnOver) AS TurnOver
		   ,SUM(c.BetCount) AS TotalTrans
		   ,SUM(c.Winlost)  AS Winlost
		   ,-SUM(c.Winlost) AS LicenseeWinlost
	FROM  DBRPT.bodb_report.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
		  INNER JOIN #tmpCust ag ON c.CustID = ag.CustID AND c.Currency = ag.Currency
	WHERE c.Winlostdate BETWEEN @FromDate AND @ToDate 
	GROUP BY ag.recommend			
		    ,ag.Currency

	INSERT INTO #TempOpeningBalance(Recommend)
	SELECT DISTINCT Recommend from #tmpCust
	; WITH sums as (
	   SELECT  SUM(ISNULL(t.ClosingBalance,0)) AS OpeningBalance,ag2.Recommend,t.WinlostDate
		FROM BalanceAGCasino t WITH (NOLOCK) 
		INNER JOIN #tmpCust ag2 ON  t.CustId=ag2.CustId AND t.Currency=ag2.Currency 
		WHERE t.WinlostDate<@FromDate 
		GROUP BY t.winlostdate,ag2.Recommend 	
	)

	UPDATE a
	SET a.OpeningBalance=b.OpeningBalance
	FROM #TempOpeningBalance a
	INNER JOIN 
	(SELECT Recommend, OpeningBalance FROM(
	select Recommend, OpeningBalance,
			  row_number() over (partition by Recommend order by WinlostDate desc) rownum
		  from sums
		  ) a
		  where a.rownum = 1) b ON a.Recommend=b.Recommend
		  
	UPDATE  a
	SET a.OpeningBalance =  (SELECT  SUM(ISNULL(t.OpeningBalance,0)) 
		FROM BalanceAGCasino t WITH (NOLOCK) 
		INNER JOIN #tmpCust ag2 ON  t.CustId=ag2.CustId AND t.Currency=ag2.Currency 
		WHERE t.WinlostDate=@FromDate AND ag2.Recommend= a.Recommend)
	FROM #TempOpeningBalance a
	WHERE OpeningBalance IS NULL


	IF(@FromDate>=@minWinlostdate)----get from transfer3rdOthers
	BEGIN
		;WITH CTE
		AS
		(	
			SELECT ag.recommend AS CustID
				,ag.Currency	
				,SUM(ISNULL(r.TransferIn,0)) AS TransferIn ,SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,SUM(ISNULL(r.TransferIn,0))+SUM(ISNULL(r.TransferOut,0))+ISNULL((SELECT Winlost FROM #tmpResult WHERE CustId=ag.Recommend AND Currency=ag.Currency),0)AS ClosingBalance
			FROM   #tmpCust ag
				LEFT JOIN BalanceAGCasino a  WITH (NOLOCK) on a.Custid=ag.Custid AND ag.currency=a.currency AND a.WinlostDate between @Fromdate and @Todate--where a.CustId in (select custid from #tmpCust where recommend=a.recommend)
				--LEFT JOIN #tmpResult t  WITH (NOLOCK)  on t.Custid=ag.Recommend AND ag.currency=t.currency AND t.WinlostDate between @Fromdate and @Todate
				LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers r WITH (NOLOCK)  ON ag.currency=r.currency AND r.CustId=ag.CustId  AND r.Winlostdate BETWEEN @FromDate AND @ToDate AND r.[PartnerId]=3
				--WHERE 
			GROUP BY ag.recommend		
				,ag.Currency
		)
		SELECT c.CustId,c.Username,a.Currency,
			b.TotalTrans,
			
			o.OpeningBalance								*e.Rate	AS OpeningBalance,
			a.TransferIn									*e.Rate	AS TransferIn,
			a.TransferOut									*e.Rate	AS TransferOut,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))	*e.Rate	AS ClosingBalance,
			b.TurnOver										*e.Rate	AS TurnOver,
			ISNULL(b.Winlost,0)								*e.Rate	AS Winlost,
			b.LicenseeWinlost								*e.Rate AS LicenseeWinlost,
			
			o.OpeningBalance								*e.USD	AS OpeningBalanceUSD,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))	*e.USD	AS ClosingBalanceUSD,
			a.TransferIn									*e.USD	AS TransferInUSD,
			a.TransferOut									*e.USD	AS TransferOutUSD,
			TurnOver										*e.USD	AS TurnOverUSD,
			ISNULL(b.Winlost,0)								*e.USD	AS WinlostUSD,
			LicenseeWinlost									*e.USD	AS LicenseeWinlostUSD,
			
			o.OpeningBalance								*e.EUR	AS OpeningBalanceEUR,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))	*e.EUR	AS ClosingBalanceEUR,
			a.TransferIn									*e.EUR	AS TransferInEUR,
			a.TransferOut									*e.EUR	AS TransferOutEUR,
			TurnOver										*e.EUR	AS TurnOverEUR,
			ISNULL(b.Winlost,0)								*e.EUR	AS WinlostEUR,
			LicenseeWinlost									*e.EUR	AS LicenseeWinlostEUR,
			
			o.OpeningBalance								*e.GBP	AS OpeningBalanceGBP,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))	*e.GBP	AS ClosingBalanceGBP,
			a.TransferIn									*e.GBP	AS TransferInGBP,
			a.TransferOut									*e.GBP	AS TransferOutGBP,
			TurnOver										*e.GBP	AS TurnOverGBP,
			ISNULL(b.Winlost,0)								*e.GBP	AS WinlostGBP,
			LicenseeWinlost									*e.GBP	AS LicenseeWinlostGBP,
			
			o.OpeningBalance								*e.DefaultRate	AS OpeningBalanceBase,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))	*e.DefaultRate	AS ClosingBalanceBase,
			a.TransferIn									*e.DefaultRate	AS TransferInBase,
			a.TransferOut									*e.DefaultRate	AS TransferOutBase,
			TurnOver										*e.DefaultRate	AS TurnOverBase,
			ISNULL(b.Winlost,0)								*e.DefaultRate	AS WinlostBase,
			LicenseeWinlost									*e.DefaultRate	AS LicenseeWinlostBase
		FROM CTE a LEFT JOIN #tmpResult b ON a.Custid=b.CustID AND a.currency=b.Currency
		INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON a.CustID = c.CustID
		LEFT JOIN #TempExchange e ON a.currency = e.ExchangeId
		LEFT JOIN #TempOpeningBalance o ON a.CustID=o.Recommend
		--WHERE o.OpeningBalance!=0 OR a.ClosingBalance!=0 OR a.TransferIn!=0 OR a.TransferOut!=0 OR TurnOver!=0 OR TotalTrans!=0 OR Winlost!=0 OR LicenseeWinlost !=0


	END
	ELSE
	BEGIN--get from transfer3rdOthers_bk
		;WITH CTE
		AS
		(	
			SELECT ag.recommend AS CustID
				,ag.Currency	
				,SUM(ISNULL(r.TransferIn,0)) AS TransferIn ,SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,SUM(ISNULL(r.TransferIn,0))+SUM(ISNULL(r.TransferOut,0))+ ISNULL((SELECT Winlost FROM #tmpResult WHERE CustId=ag.Recommend AND Currency=ag.Currency),0)AS ClosingBalance
			FROM   #tmpCust ag
				LEFT JOIN BalanceAGCasino a  WITH (NOLOCK) on a.Custid=ag.Custid AND ag.currency=a.currency AND a.WinlostDate between @Fromdate and @Todate--where a.CustId in (select custid from #tmpCust where recommend=a.recommend)
				--LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_AGCasino t  WITH (NOLOCK)  on t.Custid=ag.Custid AND ag.currency=t.currency AND t.WinlostDate between @Fromdate and @Todate
				LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers_bk r WITH (NOLOCK)  ON ag.currency=r.currency AND r.CustId=ag.CustId  AND r.Winlostdate BETWEEN @FromDate AND @ToDate AND r.[PartnerId]=3
				--WHERE 
			GROUP BY ag.recommend		
					,ag.Currency
		)
		SELECT c.CustId,c.Username,a.Currency,
			b.TotalTrans,
			
			o.OpeningBalance									*e.Rate	AS OpeningBalance,
			a.TransferIn										*e.Rate	AS TransferIn,
			a.TransferOut										*e.Rate	AS TransferOut,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))		*e.Rate	AS ClosingBalance,
			b.TurnOver											*e.Rate	AS TurnOver,		
			ISNULL(b.Winlost,0)									*e.Rate	AS Winlost,
			b.LicenseeWinlost									*e.Rate	AS LicenseeWinlost,
			
			o.OpeningBalance									*e.USD	AS OpeningBalanceUSD,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))		*e.USD	AS ClosingBalanceUSD,
			a.TransferIn										*e.USD	AS TransferInUSD,
			a.TransferOut										*e.USD	AS TransferOutUSD,
			TurnOver											*e.USD	AS TurnOverUSD,
			ISNULL(b.Winlost,0)									*e.USD	AS WinlostUSD,
			LicenseeWinlost										*e.USD	AS LicenseeWinlostUSD,
			
			o.OpeningBalance									*e.EUR	AS OpeningBalanceEUR,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))		*e.EUR	AS ClosingBalanceEUR,
			a.TransferIn										*e.EUR	AS TransferInEUR,
			a.TransferOut										*e.EUR	AS TransferOutEUR,
			TurnOver											*e.EUR	AS TurnOverEUR,
			ISNULL(b.Winlost,0)									*e.EUR	AS WinlostEUR,
			LicenseeWinlost										*e.EUR	AS LicenseeWinlostEUR,
			
			o.OpeningBalance									*e.GBP	AS OpeningBalanceGBP,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))		*e.GBP	AS ClosingBalanceGBP,
			a.TransferIn										*e.GBP	AS TransferInGBP,
			a.TransferOut										*e.GBP	AS TransferOutGBP,
			TurnOver											*e.GBP	AS TurnOverGBP,
			ISNULL(b.Winlost,0)									*e.GBP	AS WinlostGBP,
			LicenseeWinlost										*e.GBP	AS LicenseeWinlostGBP,
			
			o.OpeningBalance									*e.DefaultRate	AS OpeningBalanceBase,
			(a.ClosingBalance+ISNULL(o.OpeningBalance,0))		*e.DefaultRate	AS ClosingBalanceBase,
			a.TransferIn										*e.DefaultRate	AS TransferInBase,
			a.TransferOut										*e.DefaultRate	AS TransferOutBase,
			TurnOver											*e.DefaultRate	AS TurnOverBase,
			ISNULL(b.Winlost,0)									*e.DefaultRate	AS WinlostBase,
			LicenseeWinlost										*e.DefaultRate	AS LicenseeWinlostBase
		FROM CTE a LEFT JOIN #tmpResult b ON a.Custid=b.CustID AND a.currency=b.Currency
		INNER JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON a.CustID = c.CustID
		LEFT JOIN #TempExchange e ON a.currency = e.ExchangeId
		LEFT JOIN #TempOpeningBalance o ON a.CustID=o.Recommend
		--WHERE o.OpeningBalance!=0 OR a.ClosingBalance!=0 OR a.TransferIn!=0 OR a.TransferOut!=0 OR TurnOver!=0 OR TotalTrans!=0 OR Winlost!=0 OR LicenseeWinlost !=0
	END

	---------
	DROP TABLE #tmpResult
	DROP TABLE #tmpCust
	DROP TABLE #TempOpeningBalance
	DROP TABLE #TempExchange
END

GO