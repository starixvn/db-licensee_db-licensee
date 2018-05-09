/*<info serverAlias="DBEXT-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Lrf_Rpt_ThirdPartyWinloss    Script Date: 4/7/2015 10:01:49 AM ******/
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_ThirdPartyWinloss]
	  @ProductID	INT
	, @FromDate		SMALLDATETIME
	, @ToDate		SMALLDATETIME
	, @ReportType	TINYINT			= 1
	, @AgentList	VARCHAR(MAX)

AS  

/*  Created: Winnie
	Date: 2015-03-16
    Task : GD Win Loss report 
    DB: DBEXT.bodb02  
    Revisions:  		
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
	Param's Explanation:  
	  
	  + @excludeTest: remove currency UUS
	  + @ReportType : 1 Daily, 2 Monthly
*/  


/*
 exec [Lrf_Rpt_GoldDeluxeWinloss] 
 @LicenseeID=1
,@Currency=0
,@FromDate='2014-04-01 00:00:00'
,@ToDate='2014-09-30 00:00:00'
,@excludeTest=0
,@UserId=10
*/
SET NOCOUNT ON
BEGIN
	CREATE   TABLE #tmpResult (Winlostdate DATETIME, Currency INT,TurnOver MONEY,TotalTrans INT,Winlost MONEY,LicenseeWinlost MONEY)						
	DECLARE  @tmpCust TABLE (CustId INT, Currency INT)
	DECLARE  @TempExchange TABLE(ExchangeDate DATETIME, ExchangeId INT, Code NVARCHAR(5), USD FLOAT, EUR FLOAT,GBP FLOAT)
	
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

	
	INSERT INTO @tmpCust (CustID, Currency)	
	SELECT co.CustID, lc.Currency 
	FROM dbo.custInfo co WITH (NOLOCK)
		INNER JOIN @Temp lc ON co.recommend = lc.CustId AND lc.Currency = co.Currency	

	INSERT INTO #tmpResult (Winlostdate, Currency, TurnOver, TotalTrans, Winlost, LicenseeWinlost)
		(
			SELECT c.Winlostdate, ct.Currency
					, SUM(c.TurnOver) AS TurnOver
					, SUM(c.BetCount) AS TotalTrans
					, SUM(c.Winlost)  AS Winlost
					, -SUM(c.Winlost) AS LicenseeWinlost
			FROM [bodb_LicenseeReport].dbo.rptDepWinlost_ThirdParty c WITH (NOLOCK)
				INNER JOIN @tmpCust ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
			WHERE c.ProductId=@ProductID AND c.Winlostdate BETWEEN @FromDate AND @ToDate 
			GROUP BY c.Winlostdate, ct.Currency
		)

	INSERT INTO @TempExchange(ExchangeDate, ExchangeId, Code, USD, EUR,GBP)
		(
			SELECT ExchangeDate, ExchangeId, Code, USD, EUR	,GBP 
			FROM dbo.Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
			WHERE ExchangeId IN (SELECT DISTINCT Currency FROM #tmpResult)
		)
	
	SELECT --r.Winlostdate
		   CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			END AS Winlostdate
		, r.Currency
		, SUM(r.TurnOver)			AS TurnOver
		, SUM(r.TotalTrans)			AS TotalTrans
		, SUM(r.Winlost)			AS Winlost
		, SUM(r.LicenseeWinlost)	AS LicenseeWinlost
		---USD
		, SUM(r.TurnOver * e.USD)	AS TurnOverUSD
		, SUM(r.Winlost * e.USD)	AS WinlostUSD
		, SUM(r.LicenseeWinlost * e.USD) AS LicenseeWinlostUSD
		---EUR
		, SUM(r.TurnOver * e.EUR)	AS TurnOverEUR
		, SUM(r.Winlost * e.EUR)	AS WinlostEUR
		, SUM(r.LicenseeWinlost * e.EUR) AS LicenseeWinlostEUR
		---GBP
		, SUM(r.TurnOver * e.GBP)	AS TurnOverGBP
		, SUM(r.Winlost * e.GBP)	AS WinlostGBP
		, SUM(r.LicenseeWinlost * e.GBP) AS LicenseeWinlostGBP
	FROM #tmpResult r
	INNER JOIN @TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.Currency = e.ExchangeId
	GROUP BY --r.Winlostdate
		 CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			 END
		, r.Currency
	--ORDER BY r.Winlostdate
	ORDER BY CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			 END
	---------
	
	
END
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO