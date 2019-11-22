/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_PromotionPrize]
	@AgentId		INT = 0,	
	@UserName		VARCHAR(50) = '',
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME, 
	@MoveBetsDay	SMALLDATETIME,
	@AgentList		VARCHAR(MAX),
	@DefaultBaseCurrency	VARCHAR(3)
AS 
/*  Created: Amanda  
	Date: 2019-03-04
    Task : Integrate PP Promotion Prize [RedmineID: #109471]
    DB: DB052.bodb02  
   
    Revisions:  
	- 20190304@Amanda: Get PP Promotion Prize data [RedmineID: #109471]
	- 20190621@Amanda: Add @@DefaultBaseCurrency parameter [Redmine: #112531]
	- 20191017@Amanda: Rename SP from Lrf_Rpt_PP_PromotionPrize to Lrf_Rpt_PromotionPrize and integrate NPH Promotion [Redmine: #120333]
	- 20191122@Amanda: Include PP Tournament Prize [Redmine: #123804]

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

	CREATE TABLE #PromotionData
	(  
		winlostdate			DATETIME,  
		CurrencyId			INT,
		Winlost				MONEY,
		CustId				INT,
		BetType				INT
	) 
	CREATE TABLE #Exchange(FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, USD FLOAT, EUR FLOAT, GBP FLOAT, DefaultRate FLOAT)
	CREATE TABLE #tmpCust(CustId INT)
	
	DECLARE @tempAg	TABLE(custID INT, currency INT)  

	DECLARE @PPPromotion	SMALLINT = 4300,-- PP Promotion Prize
			@PPTournament	SMALLINT = 4299,-- PP Tournament Prize
			@PPsportType	SMALLINT = 248,
			@NPHPbetType	SMALLINT = 17000,-- NPH Promotion
			@NPHPsportType	SMALLINT = 246,
			@PP				VARCHAR(10) = 'PP',
			@NPHP			VARCHAR(10) = 'NPHP'

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

		INSERT INTO #PromotionData
		(  
			winlostdate, CurrencyId, Winlost, CustId, BetType
		)
		SELECT   
			b.winlostdate,  
			b.currency,
			b.winlost,
			b.custid,
			b.bettype
		FROM
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.recommend = a.custID AND b.Currency = a.Currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.bettype IN (@PPPromotion, @PPTournament, @NPHPbetType)
			AND b.statusID = 112
	END  

	IF @_FromDate <= @MoveBetsDay 
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate
	
		INSERT INTO #PromotionData
		(  
			winlostdate, CurrencyId, Winlost, CustId, BetType
		)
		SELECT   
			b.winlostdate,  
			b.currency,
			b.winlost,
			b.custid,
			b.bettype
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.recommend = a.custID AND b.Currency = a.Currency
		WHERE 
			b.winlostdate BETWEEN @_FromDate AND @TempToDate
			And b.sporttype IN (@PPsportType, @NPHPsportType)
			AND b.bettype IN (@PPPromotion, @PPTournament, @NPHPbetType)
			AND b.statusID = 112
			AND b.roleID = 1
	END
	
	IF @Username <> ''
	BEGIN
		DELETE d
		FROM #PromotionData d
		LEFT JOIN #tmpCust c ON d.custid = c.custid
		WHERE c.custid IS NULL
	END
	
	-- #Region: Handle Exchange Rate
	DECLARE @MinDate SMALLDATETIME, @MaxDate SMALLDATETIME
	
	SELECT @MinDate = MIN (winlostdate),
		   @MaxDate = MAX (winlostdate)
	FROM   #PromotionData
	
	INSERT INTO #Exchange(FromDate, ToDate, ExchangeID, USD, EUR, GBP, DefaultRate)
	SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, DefaultRate
	FROM dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, '', @DefaultBaseCurrency)

	-- #Region: Return data
	SELECT	CASE WHEN p.BetType = @NPHPbetType THEN @NPHP ELSE @PP END AS ProductCode,
			SUM(p.Winlost * e.USD) AS SumAmountUSD,
			SUM(p.Winlost * e.EUR) AS SumAmountEUR,
			SUM(p.Winlost * e.GBP) AS SumAmountGBP,
			SUM(p.Winlost * e.DefaultRate) AS SumAmountBase
	FROM #PromotionData p
	INNER JOIN #Exchange e ON e.ExchangeID = p.CurrencyId AND p.winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY p.BetType
	
	SELECT	CASE WHEN p.BetType = @NPHPbetType THEN @NPHP ELSE @PP END AS ProductCode,
			p.winlostdate	AS [Date],
			p.CurrencyId,
			SUM(p.Winlost)	AS Amount,
			c.username		AS UserName,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS NickName
	FROM #PromotionData p
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON p.CustId = c.custid
	GROUP BY p.BetType, p.winlostdate, p.CustId, p.CurrencyId, c.username, c.username2
	ORDER BY p.winlostdate
	
	DROP TABLE #PromotionData
	DROP TABLE #Exchange
END
GO