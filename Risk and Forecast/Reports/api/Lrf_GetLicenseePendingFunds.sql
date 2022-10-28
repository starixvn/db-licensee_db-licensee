/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_GetLicenseePendingFunds]
    @BaseCurrency	VARCHAR(12) = '',
	@AgentList		VARCHAR(MAX)
AS 

/*
	Created: 20170119@Joseph
	Task : Dashboard API - Pending funds
	DB: DBACC.bodb02

	Revisions:
		- 20170119@Joseph: Copy from Lrf_Rpt_TurnOver [RedmineID: #70616]
		- 20170323@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]
		- 20170814@Alex  : Restrict permission by currency  [RedmineID: #80855]
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20191115@Merlin: Get data by AgentList instead of LicenseeID and CurrentcyList[RedmineID: #123651]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

	Param's Explanation:
	
*/

/*
	Demo:
	USE [bodb02]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[Lrf_GetLicenseePendingFunds]
			@AgentList = N'<ROOT><Agent AgentId="10842822" Currency="3"/><Agent AgentId="13880633" Currency="3"/></ROOT>'

	SELECT	'Return Value' = @return_value

	GO
*/

BEGIN
    SET NOCOUNT ON;
   
	CREATE TABLE #tmpAg (custID INT, currency INT);
	
	DECLARE @DocHandler INT
	
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #tmpAg(CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
 
	CREATE TABLE #tmpRpt
	(
		Winlostdate   SMALLDATETIME,
		Currency   INT,  
		PendingFund   MONEY
	);

	INSERT INTO #tmpRpt
	(
		Winlostdate, Currency, PendingFund
	)
	SELECT  p.winlostdate,
			a.currency,
			SUM(ISNULL(p.outstanding,0)) AS PendingFund
	FROM bodb_Report.dbo.rptdepwinlostbyproduct_SUM p WITH(NOLOCK)  
		INNER JOIN #tmpAg a ON a.CustID = p.custid
	WHERE sporttype NOT IN (-6, -7, -8, -9)
	GROUP BY p.winlostdate, a.currency
	HAVING SUM(ISNULL(p.outstanding,0)) > 0;
 
	INSERT INTO #tmpRpt
	(
		Winlostdate, Currency, PendingFund
	)
	SELECT  p.winlostdate,
		a.currency,
		SUM(ISNULL(p.outstanding,0)) AS PendingFund
	FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH(NOLOCK)    
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
		INNER JOIN #tmpAg a ON a.CustID = c.Recommend
	WHERE c.roleid = 1
		AND sporttype NOT IN (-6, -7, -8, -9)        
	GROUP BY p.winlostdate, a.currency
	HAVING SUM(ISNULL(p.outstanding,0)) > 0;

	CREATE TABLE #TempExchange(
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeID	INT,
		Rate		FLOAT
	);

	DECLARE @MinDate SMALLDATETIME, @MaxDate SMALLDATETIME
	SELECT @MinDate = MIN(winlostdate), @MaxDate = MAX(winlostdate)
	FROM #tmpRpt

	INSERT INTO #TempExchange(FromDate, ToDate, ExchangeID, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #tmpAg c WHERE e.ExchangeID = c.Currency)

	SELECT  CAST(SUM(b.PendingFund * e.Rate) AS MONEY) AS PendingFund
	FROM #tmpRpt b
		INNER JOIN #TempExchange e ON e.exchangeid = b.currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate

	DROP TABLE #TempExchange;
	DROP TABLE #tmpRpt;
	DROP TABLE #tmpAg;
END
GO
