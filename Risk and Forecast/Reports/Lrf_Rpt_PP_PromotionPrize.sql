/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_PP_PromotionPrize]
	@AgentId		INT = 0,	
	@UserName		VARCHAR(50) = '',
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME, 
	@MoveBetsDay	SMALLDATETIME,
	@AgentList		VARCHAR(MAX)
AS 
/*  Created: Amanda  
	Date: 2019-03-04
    Task : Integrate PP Promotion Prize [RedmineID: #109471]
    DB: DB052.bodb02  
   
    Revisions:  
	- 20190304@Amanda: Get PP Promotion Prize data [RedmineID: #109471]

	Param's Explanation:
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>
					  </ROOT>
*/  
BEGIN  

	SET NOCOUNT ON  

	CREATE TABLE #PPData
	(  
		winlostdate			DATETIME,  
		CurrencyId			INT,
		Winlost				MONEY,
		CustId				INT
	) 
	CREATE TABLE #Exchange(FirstExchangeDateByMonth SMALLDATETIME, LastExchangeDateByMonth SMALLDATETIME, ExchangeID INT, Code VARCHAR(5), USD FLOAT, EUR FLOAT, GBP FLOAT)
	CREATE TABLE #tmpCust(CustId INT)
	
	DECLARE @tempAg	TABLE(custID INT, currency INT)  

	DECLARE @betType SMALLINT = 4300,-- Promotion Prize
			@sportType SMALLINT = 248			

	DECLARE @_FromDate SMALLDATETIME, @_ToDate SMALLDATETIME
	SELECT @_FromDate = @FromDate, @_ToDate = @ToDate

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency		
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data
		WHERE @AgentId = 0 OR (@AgentId <> 0 AND AgentId = @AgentId)

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	SELECT @Username = LTRIM(RTRIM(ISNULL(@Username, '')))

	IF @Username <> ''
	BEGIN
		INSERT INTO #tmpCust
		SELECT c.custid
		FROM dbo.Customer c WITH (NOLOCK)
		INNER JOIN @TempAg a ON a.custID = c.recommend 
		WHERE (c.username2 	LIKE '%$%' + @Username + '%' OR c.username	LIKE '%' + @Username + '%') And c.roleid = 1
	END

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME

	IF @_ToDate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate

		INSERT INTO #PPData
		(  
			winlostdate, CurrencyId, Winlost, CustId
		)
		SELECT   
			b.winlostdate,  
			b.currency,
			b.winlost,
			b.custid
		FROM
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.recommend = a.custID AND b.Currency = a.Currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.bettype = @betType
			AND b.statusID = 112
	END  

	IF @_FromDate <= @MoveBetsDay 
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate
	
		INSERT INTO #PPData
		(  
			winlostdate, CurrencyId, Winlost, CustId
		)
		SELECT   
			b.winlostdate,  
			b.currency,
			b.winlost,
			b.custid
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.recommend = a.custID AND b.Currency = a.Currency
		WHERE 
			b.winlostdate BETWEEN @_FromDate AND @TempToDate
			And b.sporttype = @sportType
			AND b.bettype = @betType
			AND b.statusID = 112
			AND b.roleID = 1
	END
	
	IF @Username <> ''
	BEGIN
		DELETE d
		FROM #PPData d
		LEFT JOIN #tmpCust c ON d.custid = c.custid
		WHERE c.custid IS NULL
	END
	
	-- #Region: Handle Exchange Rate
	DECLARE @MinDate SMALLDATETIME, @MaxDate SMALLDATETIME
	
	SELECT @MinDate = MIN (winlostdate),
		   @MaxDate = MAX (winlostdate)
	FROM   #PPData
	
	INSERT INTO #Exchange(FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID, Code, USD, EUR, GBP)
	SELECT FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID, Code, USD, EUR, GBP
	FROM dbo.Lrf_f_GetSubExchangeDaily(@MinDate, @MaxDate)

	-- #Region: Return data

	SELECT	p.winlostdate AS [Date],
			p.CurrencyId,
			SUM(p.Winlost) AS Amount,
			c.username AS UserName,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS NickName
	FROM #PPData p
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON p.CustId = c.custid
	GROUP BY p.winlostdate, p.CustId, p.CurrencyId, c.username, c.username2
	ORDER BY p.winlostdate
	
	SELECT	SUM(p.Winlost * e.USD) AS SumAmountUSD,
			SUM(p.Winlost * e.EUR) AS SumAmountEUR,
			SUM(p.Winlost * e.GBP) AS SumAmountGBP
	FROM #PPData p
	INNER JOIN #Exchange e ON e.ExchangeID = p.CurrencyId AND p.winlostdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	
	DROP TABLE #PPData
	DROP TABLE #Exchange
END
GO