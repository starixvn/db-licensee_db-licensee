/*<info serverAlias="DBPTCS-bodb_PlaytechCS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[LRF_Rpt_AGCasinoBalance_Mem] 
	@CustID					INT, --- recommend
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@PageSize				INT = 1000,
	@PageIndex				INT = 1,
	@TotalRows				INT = 0 OUTPUT,
	@AgentList				VARCHAR(MAX),
	@BaseCurrency			VARCHAR(3) = '',
	@DefaultBaseCurrency	VARCHAR(3) = ''
AS  
/*  Created: Winnie
	Date: 20150123
    Task : AG Win Loss report 
    DB: DBPTCS.bodb_PlaytechCS  
    Revisions:  
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20190617@Amanda: Add Base currency param [RedmineID: #112531]
*/  

BEGIN
	CREATE TABLE #tmpResult (
		CustID			  INT
		, WinlostDate	  DATETIME
		, Currency 		  INT
		, TurnOver 		  MONEY
		, TotalTrans	  INT
		, Winlost  		  MONEY
		, LicenseeWinlost MONEY
	)

	CREATE TABLE #tmpCust (CustId INT ,Currency INT)

	CREATE TABLE #TempExchange(ExchangeId INT, Rate FLOAT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)

	DECLARE @minWinlostdate SMALLDATETIME
	DECLARE @RowStart INT 
			,@RowEnd INT 
	SELECT  @PageIndex = @PageIndex - 1 
        ,@RowStart = @PageSize * @PageIndex + 1 
        ,@RowEnd = @RowStart + @PageSize - 1

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
	SELECT   co.CustID
			 ,lc.Currency
	FROM 
		bodb02.dbo.CustInfo co WITH (NOLOCK)
		INNER JOIN @Temp lc ON lc.CustId = co.Recommend AND co.Currency = lc.Currency
		INNER JOIN [dbo].[BalanceAGCasino] d WITH ( NOLOCK) ON co.custid=d.CustId
	WHERE lc.CustId =  @CustID AND d.WinlostDate BETWEEN @FromDate AND @ToDate

	INSERT INTO #TempExchange(ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
	SELECT ExchangeID, USD, EUR, GBP, Rate, DefaultRate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @FromDate, @BaseCurrency, @DefaultBaseCurrency) e
	WHERE EXISTS (SELECT 1 FROM @Temp a WHERE e.ExchangeID = a.Currency)
	
	INSERT INTO #tmpResult (CustId 
							 ,Winlostdate
							 ,Currency 	
							 ,TurnOver 	
							 ,TotalTrans
							 ,Winlost  	
							 ,LicenseeWinlost 
							)

	SELECT c.CustID
		   ,c.Winlostdate		
		   ,ag.Currency
		   ,SUM(c.TurnOver) AS TurnOver
		   ,SUM(c.BetCount) AS TotalTrans
		   ,SUM(c.Winlost)  AS Winlost
		   ,-SUM(c.Winlost) AS LicenseeWinlost
	FROM  DBRPT.bodb_report.dbo.rptDepWinlost_AGCasino c  WITH (NOLOCK)
		INNER JOIN #tmpCust ag ON c.CustID = ag.CustID AND c.Currency = ag.Currency 	
	WHERE c.Winlostdate BETWEEN @FromDate AND @ToDate 	
	GROUP BY c.CustID
			,c.Winlostdate
		    ,ag.Currency
	IF(@FromDate>=@minWinlostdate)----get from transfer3rdOthers
	BEGIN
		;WITH CTE
		AS
		(	
			SELECT ag.CustId AS CustID	,ag.Currency
				,ISNULL(	
				(SELECT TOP 1 SUM(ISNULL(m.ClosingBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate<@FromDate AND ag1.CustId=ag.custid GROUP BY m.winlostdate  ORDER BY  m.winlostdate  desc),
				--0
				(SELECT TOP 1 SUM(ISNULL(m.OpeningBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate=@FromDate AND ag1.CustId=ag.custid )
				) AS OpeningBalance
				,SUM(ISNULL(r.TransferIn,0)) AS TransferIn ,SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,ISNULL(	
				(SELECT TOP 1 SUM(ISNULL(m.ClosingBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate<@FromDate AND ag1.CustId=ag.custid GROUP BY m.winlostdate  ORDER BY  m.winlostdate  desc),
				--0
				ISNULL((SELECT TOP 1 SUM(ISNULL(m.OpeningBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate=@FromDate AND ag1.CustId=ag.custid ),0)
				)
					   +SUM(ISNULL(r.TransferIn,0))+SUM(ISNULL(r.TransferOut,0))+SUM(ISNULL(t.Winlost,0)) AS ClosingBalance
				,ROW_NUMBER() OVER ( ORDER BY ag.CustID ) AS RowNum
			FROM   #tmpCust ag
				LEFT JOIN BalanceAGCasino a  WITH (NOLOCK) on a.Custid=ag.Custid AND ag.currency=a.currency AND a.WinlostDate between @Fromdate and @Todate
				LEFT JOIN #tmpResult t   on t.Custid=ag.Custid AND ag.currency=t.currency --AND t.WinlostDate between @Fromdate and @Todate
				LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers r WITH (NOLOCK)  ON ag.currency=r.currency AND r.CustId=ag.CustId  AND r.Winlostdate BETWEEN @FromDate AND @ToDate AND r.[PartnerId]=3
				--WHERE 
			GROUP BY ag.CustId		
					,ag.Currency
		)
		SELECT c.Username,a.Currency,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
			b.TotalTrans,
			
			a.OpeningBalance		*e.Rate	AS OpeningBalance,
			a.TransferIn			*e.Rate	AS TransferIn,
			a.TransferOut			*e.Rate	AS TransferOut,
			a.ClosingBalance		*e.Rate	AS ClosingBalance,
			b.TurnOver				*e.Rate	AS TurnOver,
			b.Winlost				*e.Rate	AS Winlost,
			b.LicenseeWinlost		*e.Rate	AS LicenseeWinlost,
		
			a.OpeningBalance		*e.USD	AS OpeningBalanceUSD,
			a.ClosingBalance		*e.USD	AS ClosingBalanceUSD,
			a.TransferIn			*e.USD	AS TransferInUSD,
			a.TransferOut			*e.USD	AS TransferOutUSD,
			TurnOver				*e.USD	AS TurnOverUSD,
			Winlost					*e.USD	AS WinlostUSD,
			LicenseeWinlost			*e.USD	AS LicenseeWinlostUSD,
		
			a.OpeningBalance		*e.EUR	AS OpeningBalanceEUR,
			a.ClosingBalance		*e.EUR	AS ClosingBalanceEUR,
			a.TransferIn			*e.EUR	AS TransferInEUR,
			a.TransferOut			*e.EUR	AS TransferOutEUR,
			TurnOver				*e.EUR	AS TurnOverEUR,
			Winlost					*e.EUR	AS WinlostEUR,
			LicenseeWinlost			*e.EUR	AS LicenseeWinlostEUR,
		
			a.OpeningBalance		*e.GBP	AS OpeningBalanceGBP,
			a.ClosingBalance		*e.GBP	AS ClosingBalanceGBP,
			a.TransferIn			*e.GBP	AS TransferInGBP,
			a.TransferOut			*e.GBP	AS TransferOutGBP,
			TurnOver				*e.GBP	AS TurnOverGBP,
			Winlost					*e.GBP	AS WinlostGBP,
			LicenseeWinlost			*e.GBP	AS LicenseeWinlostGBP,
			
			a.OpeningBalance		*e.DefaultRate	AS OpeningBalanceBase,
			a.ClosingBalance		*e.DefaultRate	AS ClosingBalanceBase,
			a.TransferIn			*e.DefaultRate	AS TransferInBase,
			a.TransferOut			*e.DefaultRate	AS TransferOutBase,
			TurnOver				*e.DefaultRate	AS TurnOverBase,
			Winlost					*e.DefaultRate	AS WinlostBase,
			LicenseeWinlost			*e.DefaultRate	AS LicenseeWinlostBase
		FROM CTE a LEFT JOIN #tmpResult b ON a.Custid=b.CustID AND a.currency=b.Currency 
		INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON a.CustID = c.CustID
		LEFT JOIN #TempExchange e ON a.currency = e.ExchangeId
		WHERE a.RowNum 	BETWEEN @RowStart AND @RowEnd 
		--AND a.OpeningBalance!=0 OR a.ClosingBalance!=0 OR a.TransferIn!=0 OR a.TransferOut!=0 OR TurnOver!=0 OR TotalTrans!=0 OR Winlost!=0 OR LicenseeWinlost !=0
	END
	ELSE ----get from transfer3rdOthers_bk
	BEGIN
		;WITH CTE
		AS
		(	
			SELECT ag.CustId AS CustID	,ag.Currency
				,ISNULL(	
				(SELECT TOP 1 SUM(ISNULL(m.ClosingBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate<@FromDate AND ag1.CustId=ag.custid GROUP BY m.winlostdate  ORDER BY  m.winlostdate  desc),
				--0
				(SELECT TOP 1 SUM(ISNULL(m.OpeningBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate=@FromDate AND ag1.CustId=ag.custid )
				) AS OpeningBalance
				,SUM(ISNULL(r.TransferIn,0)) AS TransferIn ,SUM(ABS(ISNULL(r.TransferOut,0))) AS TransferOut
				,ISNULL(	
				(SELECT TOP 1 SUM(ISNULL(m.ClosingBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate<@FromDate AND ag1.CustId=ag.custid GROUP BY m.winlostdate  ORDER BY  m.winlostdate  desc),
				--0
				ISNULL((SELECT TOP 1 SUM(ISNULL(m.OpeningBalance,0)) FROM BalanceAGCasino m  WITH (NOLOCK) INNER JOIN #tmpCust ag1 ON m.Currency=ag1.Currency AND m.CustId=ag1.CustId WHERE m.WinlostDate=@FromDate AND ag1.CustId=ag.custid ),0)
				)
					   +SUM(ISNULL(r.TransferIn,0))+SUM(ISNULL(r.TransferOut,0))+SUM(ISNULL(t.Winlost,0)) AS ClosingBalance
				,ROW_NUMBER() OVER ( ORDER BY ag.CustID ) AS RowNum
			FROM   #tmpCust ag
				LEFT JOIN BalanceAGCasino a  WITH (NOLOCK) on a.Custid=ag.Custid AND ag.currency=a.currency AND a.WinlostDate between @Fromdate and @Todate
				LEFT JOIN #tmpResult t  WITH (NOLOCK)  on t.Custid=ag.Custid AND ag.currency=t.currency --AND t.WinlostDate between @Fromdate and @Todate
				LEFT JOIN DBRPT.bodb_report.dbo.rptDepWinlost_Transfer3rdOthers_bk r WITH (NOLOCK)  ON ag.currency=r.currency AND r.CustId=ag.CustId  AND r.Winlostdate BETWEEN @FromDate AND @ToDate AND r.[PartnerId]=3
				--WHERE
			GROUP BY ag.CustId		
					,ag.Currency
		)
		SELECT c.Username,a.Currency,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
			b.TotalTrans,
			
			a.OpeningBalance				*e.Rate	AS OpeningBalance,
			a.TransferIn					*e.Rate	AS TransferIn,
			a.TransferOut					*e.Rate	AS TransferOut,
			a.ClosingBalance				*e.Rate	AS ClosingBalance,
			b.TurnOver						*e.Rate	AS TurnOver,
			b.Winlost						*e.Rate	AS Winlost,
			b.LicenseeWinlost				*e.Rate	AS LicenseeWinlost,

			a.OpeningBalance				*e.USD	AS OpeningBalanceUSD,
			a.ClosingBalance				*e.USD	AS ClosingBalanceUSD,
			a.TransferIn					*e.USD	AS TransferInUSD,
			a.TransferOut					*e.USD	AS TransferOutUSD,
			TurnOver						*e.USD	AS TurnOverUSD,
			Winlost							*e.USD	AS WinlostUSD,
			LicenseeWinlost					*e.USD	AS LicenseeWinlostUSD,

			a.OpeningBalance				*e.EUR	AS OpeningBalanceEUR,
			a.ClosingBalance				*e.EUR	AS ClosingBalanceEUR,
			a.TransferIn					*e.EUR	AS TransferInEUR,
			a.TransferOut					*e.EUR	AS TransferOutEUR,
			TurnOver						*e.EUR	AS TurnOverEUR,
			Winlost							*e.EUR	AS WinlostEUR,
			LicenseeWinlost					*e.EUR	AS LicenseeWinlostEUR,

			a.OpeningBalance				*e.GBP	AS OpeningBalanceGBP,
			a.ClosingBalance				*e.GBP	AS ClosingBalanceGBP,
			a.TransferIn					*e.GBP	AS TransferInGBP,
			a.TransferOut					*e.GBP	AS TransferOutGBP,
			TurnOver						*e.GBP	AS TurnOverGBP,
			Winlost							*e.GBP	AS WinlostGBP,
			LicenseeWinlost					*e.GBP	AS LicenseeWinlostGBP,
			
			a.OpeningBalance				*e.DefaultRate	AS OpeningBalanceBase,
			a.ClosingBalance				*e.DefaultRate	AS ClosingBalanceBase,
			a.TransferIn					*e.DefaultRate	AS TransferInBase,
			a.TransferOut					*e.DefaultRate	AS TransferOutBase,
			TurnOver						*e.DefaultRate	AS TurnOverBase,
			Winlost							*e.DefaultRate	AS WinlostBase,
			LicenseeWinlost					*e.DefaultRate	AS LicenseeWinlostBase
		FROM CTE a LEFT JOIN #tmpResult b ON a.Custid=b.CustID AND a.currency=b.Currency
		INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON a.CustID = c.CustID
		LEFT JOIN #TempExchange e ON a.currency = e.ExchangeId
		WHERE a.RowNum 	BETWEEN @RowStart AND @RowEnd 
		--AND a.OpeningBalance!=0 OR a.ClosingBalance!=0 OR a.TransferIn!=0 OR a.TransferOut!=0 OR TurnOver!=0 OR TotalTrans!=0 OR Winlost!=0 OR LicenseeWinlost !=0
	END
	select @TotalRows=COUNT(custID) FROM #tmpCust
	---------
	DROP TABLE #tmpCust
	DROP TABLE #tmpResult
	DROP TABLE #TempExchange
	
END
GO
