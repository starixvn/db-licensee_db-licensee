/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets_Total]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@ProductCodes	VARCHAR(100),
	@GameCodes		VARCHAR(MAX),
	@CurrencyList   VARCHAR(500),
	@BaseCurrency	VARCHAR(12) = '',
	@SearchRefNo	BIGINT = NULL
AS 
/*  Created: 20191104@Amanda
    Description: LAP - Implement new report for auditing
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20191104@Amanda: Created new SP [RedmineID: #122789]
		- 20200325@Bobby: Ploutos Integration - [redmine: #125252]
		- 20200917@Sol: Joinning with playerProfile - [redmine: #125252]
		- 20200924@Sol: Convert INH to VND - [redmine: #139910]
		- 20201201@Sol: Audit - Add mode sum by SettlementTime - [Redmine: #146188]
		- 20210517@Sol: Audit - show data with status = 0 orr 1 - [Redmine: #155266]
		- 20210416@Sol: Get data from archived table and main table - [Redmine: #152202]
		- 20211001@Sol: LAP - Auditing licensees - Enhance Daily Bets - [Redmine: #162355]
		- 20220302@Sol: temporary prevent Nova88 from viewing data from 1-Mar-2022 - [Redmine: #169131]
		- 20220118@Sol: LAP - Auditing licensees - Daily Bets - Filter by Sport - [RedmineID: #166056]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20231123@Bobby: Daily Bets - Ivory search RefNo [redmine: #197277]
		- 20240109@Bobby: Daily Bets - 12B add Payout column [redmine: #198014]

	Developer's Notes:
		
    Param's Explanation:  
	  + @CurrencyList: xml structure
					  <ROOT>
					   <Agent Id="13" Code="CNY"/>
					   <Agent Id="51" Code="INH"/> 
					  </ROOT>
	  EXEC   [dbo].[Lrf_Rpt_Audit_DailyBets]
		    @SiteName = N'Opal88',
		    @Date = '2019-06-20',
		    @ProductCodes = N'SB,NG',
		    @CurrencyList=N'<ROOT><CR Id="13" Code="CNY"/><CR Id="15" Code="IDR"/> </ROOT>'	    
*/
BEGIN  
    SET NOCOUNT ON;

	DECLARE @Product TABLE (ProductCode VARCHAR(10))
	DECLARE @GameCode TABLE (GameCode VARCHAR(10))
	DECLARE @Currency AS TABLE(Id INT, Code VARCHAR(5), ExRate FLOAT)
	DECLARE @ArchivedDate DATETIME, @CurrDate DATETIME, @SearchTransId BIGINT;

	SELECT @SearchTransId = @SearchRefNo;

	----temporary prevent Nova88 from viewing data from 1-Mar-2022
	IF (@SiteName = 'Nova88' AND @Date >= CAST('20220301' AS DATE))
	BEGIN
		--- RETURN - SUM total
		SELECT TotalRows = 0
				,TotalTurnover = 0
				,TotalWinLoss = 0
		RETURN
	END

	SET @CurrDate = @Date

	--get archived date -> last day of archived month => add 1 more day to cover time, such as: 23:59:59 
	SELECT @ArchivedDate = DATEADD(DAY, 1, CAST(s.VValue AS DATE))
	FROM dbo.SystemSettings s WITH(NOLOCK)
	WHERE s.VName = 'PloutosArchivedMonth'

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	---insert gamecode
	INSERT INTO @GameCode(GameCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@GameCodes,',');

	-- Get Currency
	;WITH CTE_Currency AS (
		SELECT T.C.value('./@Id', 'INT') AS Id
			,T.C.value('./@Code', 'VARCHAR(5)') AS Code
		FROM (
			VALUES (CAST(@CurrencyList AS XML))
		) AS xd(dataX)
		CROSS APPLY xd.dataX.nodes('/ROOT/CR') AS T(C)
	)
	INSERT INTO @Currency (Id, Code)
	SELECT MIN(Id) AS Id,
		CASE  
            WHEN Id = 20 THEN 'UUS' 
            WHEN Id = 51 THEN 'VND' 
            WHEN Id = 70 THEN 'MMK' 
            ELSE Code
        END
	FROM CTE_Currency
	GROUP BY 
		CASE  
            WHEN Id = 20 THEN 'UUS' 
            WHEN Id = 51 THEN 'VND' 
            WHEN Id = 70 THEN 'MMK' 
            ELSE Code
        END

	UPDATE c
	SET c.ExRate = ISNULL(e.Rate, 1)
	FROM @Currency c
	LEFT JOIN dbo.Lrf_f_GetExchangeRate(@Date, @Date, @BaseCurrency, '') e ON c.Id = e.ExchangeId

	SELECT @SiteName = dbo.Lrf_f_MappingAuditSite(@SiteName)

	DECLARE @TempToDate DATETIME = DATEADD(DAY, 1, @Date)

	DECLARE @showSB BIT = 0,
			@showNG BIT = 0,
			@showCS BIT = 0,
			@showLC BIT = 0
	
	SELECT @showSB = 1 FROM @Product WHERE ProductCode = 'SB'
	SELECT @showNG = 1 FROM @Product WHERE ProductCode = 'NG'
	SELECT @showCS = 1 FROM @Product WHERE ProductCode = 'CS'
	SELECT @showLC = 1 FROM @Product WHERE ProductCode = 'LC'

	-- Return data	
	IF (@CurrDate >= @ArchivedDate)
	BEGIN
		SELECT
			COUNT(a.TransactionId)				AS TotalRows,
			SUM(a.BetAmount * c.ExRate)			AS TotalTurnover,
			- SUM(a.NetAmount * c.ExRate)		AS TotalWinLoss,
			SUM((a.BetAmount-a.NetAmount)* c.ExRate) AS TotalPayout
		FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
		WHERE  
			a.BrandCode = @SiteName
			AND a.StatusID IN (0, 1)
			AND a.SettlementDate >= @CurrDate AND a.SettlementDate < @TempToDate 
			AND ( 
					(@showSB = 1 AND a.GamePlatformCode = 'SB') 
					OR (@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
					OR (@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
					OR (@showLC = 1 AND a.GamePlatformCode = 'CA')
				)
			AND a.GameCode IN (SELECT GameCode FROM @GameCode)
			AND a.TransactionId = ISNULL(@SearchTransId, a.TransactionId)
	END
	ELSE
	BEGIN
		
		SELECT
			COUNT(a.TransactionId)				AS TotalRows,
			SUM(a.BetAmount * c.ExRate)			AS TotalTurnover,
			- SUM(a.NetAmount * c.ExRate)		AS TotalWinLoss,
			SUM((a.BetAmount-a.NetAmount)* c.ExRate) AS TotalPayout
		FROM bodb_Ploutos.dbo.BetTicket_BK a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
		WHERE  
			a.BrandCode = @SiteName
			AND a.StatusID IN (0, 1)
			AND a.SettlementDate >= @Date AND a.SettlementDate < @TempToDate 
			AND ( 
					(@showSB = 1 AND a.GamePlatformCode = 'SB') 
					OR (@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
					OR (@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
					OR (@showLC = 1 AND a.GamePlatformCode = 'CA')
				)
			AND a.GameCode IN (SELECT GameCode FROM @GameCode)
			AND a.TransactionId = ISNULL(@SearchTransId, a.TransactionId)
	END
		
END
GO