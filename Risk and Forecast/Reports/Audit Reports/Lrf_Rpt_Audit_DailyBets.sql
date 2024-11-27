/*<info serverAlias="DBPLO-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@ProductCodes	VARCHAR(100),
	@GameCodes		VARCHAR(MAX),
	@CurrencyList   VARCHAR(MAX),
	@BaseCurrency	VARCHAR(12) = '',
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@SortBy			VARCHAR(50) = 'TransactionId',
	@SortOrder		VARCHAR(4) = 'asc',
	@LoginName		VARCHAR(50) = '',
	@SearchRefNo	BIGINT = NULL
AS 
/*  Created: 20191028@Amanda
    Description: LAP - Implement new report for auditing
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20191028@Amanda: Created new SP [RedmineID: #122789]
		- 20200325@Bobby: Ploutos Integration - [redmine: #125252]
		- 20201201@Sol: Audit - Add mode sum by SettlementTime - [Redmine: #146188]
		- 20210517@Sol: Audit - show data with status = 0 orr 1 - [Redmine: #155266]
		- 20210416@Sol: Get data from archived table and main table - [Redmine: #152202]
		- 20211001@Sol: LAP - Auditing licensees - Enhance Daily Bets - [Redmine: #162355]
		- 20220302@Sol: temporary prevent Nova88 from viewing data from 1-Mar-2022 - [Redmine: #169131]
		- 20220118@Sol: LAP - Auditing licensees - Daily Bets - Filter by Sport - [RedmineID: #166056]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20230704@Bobby: Fix paging lag [Redmine #190828]
		- 20230814@Evan: Ivory - Adjust rate show real figures for currency cut off 000 [Redmine #192602]
		- 20231025@Bobby: Customer Admin - [redmine: #195850]
		- 20231116@Bobby: Daily Bets - add audit admin login [redmine: #195850]
		- 20231123@Bobby: Daily Bets - Ivory search RefNo [redmine: #197277]
		- 20231109@Evan: 12B - Adjust rate show real figures for currency cut off 000 [Redmine #196557]
		- 20240109@Bobby: Daily Bets - 12B add Payout column [redmine: #198014]
		- 20241121@Kelvin: LAP - Support BRL base currency, extend length @CurrencyList [RedmineID: #208662]

	Developer's Notes:
		
    Param's Explanation:  
	  + @CurrencyList: xml structure
					  <ROOT>
					   <Agent Id="13" Code="CNY"/>
					   <Agent Id="51" Code="IDR"/> 
					  </ROOT>
	  EXEC   [dbo].[Lrf_Rpt_Audit_DailyBets]
		    @SiteName = N'Opal88',
		    @Date = '2019-06-20',
		    @ProductCodes = N'SB,NG',
			@GameCodes = '01,010,011'
		    @CurrencyList=N'<ROOT><CR Id="13" Code="CNY"/><CR Id="15" Code="IDR"/> </ROOT>'	    
*/
BEGIN  
    
	SET NOCOUNT ON;
	
	DECLARE @Product TABLE (ProductCode VARCHAR(10))
	DECLARE @GameCode TABLE (GameCode VARCHAR(10))
	DECLARE @Currency AS TABLE (Id INT, Code VARCHAR(5), Name VARCHAR(5), ExRate FLOAT, ExRateOrg FLOAT)
	DECLARE @ArchivedDate DATETIME, @CurrDate DATETIME, @IsAuditUser BIT, @SearchTransId BIGINT;

	SELECT @SearchTransId = @SearchRefNo;
	
	CREATE table #DailyResult
	(
		[Index] INT IDENTITY (1, 1) PRIMARY KEY
		,RefNo	BIGINT
		,PlayerName	VARCHAR(30)
		,CurrencyName VARCHAR(5)
		,TransTime DATETIME
		,BetType NVARCHAR(128)
		,ProductCode VARCHAR(10)
		,Turnover MONEY
		,WinLoss MONEY
		,Payout MONEY
		,[Status] SMALLINT
		,TurnoverBased MONEY
		,WinLossBased MONEY
		,PayoutBased MONEY
		,GameCode VARCHAR(10)
	)

	----temporary prevent Nova88 from viewing data from 1-Mar-2022
	IF (@SiteName = 'Nova88' AND @Date >= CAST('20220301' AS DATE))
	BEGIN
		SELECT p.[Index]
			,p.RefNo
			,PlayerName
			,CurrencyName
			,TransTime
			,p.BetType
			,ProductCode
			,Turnover
			,WinLoss
			,Payout
			,p.TurnoverBased
			,p.WinLossBased
			,PayoutBased
			,[Status]
		FROM #DailyResult p
		
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
	FROM dbo.strSplit(@ProductCodes,',');

	---insert gamecode
	INSERT INTO @GameCode(GameCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@GameCodes,',');

	-- Get Currency
	WITH CTE_Currency AS (
		SELECT T.C.value('./@Id', 'INT') AS Id
			,T.C.value('./@Code', 'VARCHAR(5)') AS Code
		FROM (
			VALUES (CAST(@CurrencyList AS XML))
		) AS xd(dataX)
		CROSS APPLY xd.dataX.nodes('/ROOT/CR') AS T(C)
	)
	INSERT INTO @Currency (Id, Code, Name)
	SELECT MIN(Id) AS Id,
		CASE  
            WHEN Id = 20 THEN 'UUS' 
            WHEN Id = 51 THEN 'VND' 
            WHEN Id = 70 THEN 'MMK' 
            ELSE Code
        END,
        Code
	FROM CTE_Currency
	GROUP BY CASE  
            WHEN Id = 20 THEN 'UUS' 
            WHEN Id = 51 THEN 'VND' 
            WHEN Id = 70 THEN 'MMK' 
            ELSE Code
        END,
        Code
	
	-- GET ExRate
	UPDATE c
	SET c.ExRate = ISNULL(e.Rate, 1),
		c.ExRateOrg = CASE WHEN @SiteName IN ('Ivorybet','12B') THEN 1 * ex.MultipliedBy ELSE 1 END
	FROM @Currency c
	LEFT JOIN dbo.Lrf_f_GetExchangeRate(@CurrDate, @CurrDate, @BaseCurrency, '') e ON c.Id = e.ExchangeId
	INNER JOIN Exchange ex WITH(NOLOCK) ON c.Id = ex.ExchangeId
	SELECT @SiteName = dbo.Lrf_f_MappingAuditSite(@SiteName)

	IF (@SortBy NOT IN ('WinLoss', 'Turnover', 'Payout', 'TurnoverBased', 'WinLossBased', 'PayoutBased'))
	BEGIN
		SET @SortBy = 'TransactionId'
		SET @SortOrder = 'asc'
	END
	
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
	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	-- Audit Login
	SET @IsAuditUser = 0;
	DECLARE @auditLogin TABLE(LoginName VARCHAR(50))
	INSERT @auditLogin (LoginName) 
	VALUES('GCOMRCI1'),('Pagcor12'),('Pagcor1'),('Pagcoracc');

	SELECT TOP 1 @IsAuditUser = 1 
	FROM @auditLogin 
	WHERE (LoginName = @LoginName AND @SiteName = '12Bet') OR @SiteName <> '12Bet'

	-- GATHER BET Soure
	IF (@CurrDate >= @ArchivedDate)
	BEGIN
		INSERT INTO #DailyResult
		(
			RefNo	
			,PlayerName	
			,CurrencyName	
			,TransTime	
			,BetType	
			,ProductCode	
			,Turnover	
			,WinLoss	
			,Payout
			,[Status]	
			,TurnoverBased
			,WinLossBased
			,PayoutBased
			,GameCode
		)
		SELECT 
			a.TransactionId
			,a.Playername
			,a.Name as CurrencyName
			,a.TransTime
			,a.BetType
			,a.ProductCode
			,a.Turnover
			,a.WinLoss
			,a.Payout
			,a.Status
			,TurnoverBased
			,WinLossBased
			,PayoutBased
			,a.GameCode
		FROM (
				SELECT
					a.TransactionId
					,c.Name
					,a.BetAmount * c.ExRateOrg AS BetAmount					
					,a.NetAmount * c.ExRateOrg AS NetAmount				
					,a.BetAmount * c.ExRate AS TurnoverBased
					,-a.NetAmount * c.ExRate AS WinLossBased
					,(a.BetAmount-a.NetAmount)* c.ExRate AS PayoutBased
					,IIF(@IsAuditUser = 1, pp.Username, pp.Username2) AS Playername,
					a.TransactionDate AS TransTime,
					a.BettypeName AS BetType,
					CASE
						WHEN a.GamePlatformCode = 'SB' THEN 'SB'
						WHEN a.GamePlatformCode = 'RNG' AND a.GameCode = '0161' THEN 'NG'
						WHEN a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161' THEN 'CS'
						WHEN a.GamePlatformCode = 'CA' THEN 'LC'
						ELSE ''
					END AS ProductCode,
					a.BetAmount * c.ExRateOrg AS Turnover,
					-a.NetAmount * c.ExRateOrg AS WinLoss,
					(a.BetAmount-a.NetAmount)* c.ExRateOrg AS Payout,
					CASE
						WHEN a.NetAmount > 0 THEN -1
						WHEN a.NetAmount < 0 THEN 1
						ELSE 0
					END AS [Status],
					a.GameCode
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
			) AS a
			ORDER BY 
				CASE WHEN @SortOrder = 'desc' THEN 
							CASE 
								WHEN @SortBy = 'Turnover' THEN a.BetAmount
								WHEN @SortBy = 'WinLoss' THEN a.NetAmount
								WHEN @SortBy = 'Payout' THEN a.Payout
								WHEN @SortBy = 'TurnoverBased' THEN a.TurnoverBased
								WHEN @SortBy = 'WinLossBased' THEN a.WinLossBased
								WHEN @SortBy = 'PayoutBased' THEN a.PayoutBased
								ELSE a.TransactionId
							END
						ELSE 1
						END DESC
				, CASE WHEN @SortOrder = 'asc' THEN 
							CASE
							WHEN @SortBy = 'Turnover' THEN a.BetAmount
							WHEN @SortBy = 'WinLoss' THEN a.NetAmount
							WHEN @SortBy = 'Payout' THEN a.Payout
							WHEN @SortBy = 'TurnoverBased' THEN a.TurnoverBased
							WHEN @SortBy = 'WinLossBased' THEN a.WinLossBased
							WHEN @SortBy = 'PayoutBased' THEN a.PayoutBased
							ELSE a.TransactionId
							END
						ELSE 1	
						END ASC
				, a.TransactionId ASC
	END
	ELSE
	BEGIN
		INSERT INTO #DailyResult
		(
			RefNo	
			,PlayerName	
			,CurrencyName	
			,TransTime	
			,BetType	
			,ProductCode	
			,Turnover	
			,WinLoss	
			,Payout
			,[Status]	
			,TurnoverBased
			,WinLossBased
			,PayoutBased
			,GameCode
		)
		SELECT 
			a.TransactionId
			,a.Playername
			,a.Name as CurrencyName
			,a.TransTime
			,a.BetType
			,a.ProductCode
			,a.Turnover
			,a.WinLoss
			,a.Payout
			,a.Status
			,TurnoverBased
			,WinLossBased
			,PayoutBased
			,a.GameCode
		FROM (
				SELECT
					a.TransactionId
					,c.Name
					,a.BetAmount * c.ExRateOrg AS BetAmount					
					,a.NetAmount * c.ExRateOrg AS NetAmount				
					,a.BetAmount * c.ExRate AS TurnoverBased
					,-a.NetAmount * c.ExRate AS WinLossBased
					,(a.BetAmount-a.NetAmount)* c.ExRate AS PayoutBased
					,IIF(@IsAuditUser = 1, pp.Username, pp.Username2) AS Playername,
					a.TransactionDate AS TransTime,
					a.BettypeName AS BetType,
					CASE
						WHEN a.GamePlatformCode = 'SB' THEN 'SB'
						WHEN a.GamePlatformCode = 'RNG' AND a.GameCode = '0161' THEN 'NG'
						WHEN a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161' THEN 'CS'
						WHEN a.GamePlatformCode = 'CA' THEN 'LC'
						ELSE ''
					END AS ProductCode,
					a.BetAmount * c.ExRateOrg AS Turnover,
					-a.NetAmount * c.ExRateOrg AS WinLoss,
					(a.BetAmount-a.NetAmount)* c.ExRateOrg AS Payout,
					CASE
						WHEN a.NetAmount > 0 THEN -1
						WHEN a.NetAmount < 0 THEN 1
						ELSE 0
					END	AS [Status],
					a.GameCode
				FROM bodb_Ploutos.dbo.BetTicket_BK a WITH (NOLOCK)
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
			) AS a
			ORDER BY 
				CASE WHEN @SortOrder = 'desc' THEN 
							CASE 
								WHEN @SortBy = 'Turnover' THEN a.BetAmount
								WHEN @SortBy = 'WinLoss' THEN a.NetAmount
								WHEN @SortBy = 'Payout' THEN a.Payout
								WHEN @SortBy = 'TurnoverBased' THEN a.TurnoverBased
								WHEN @SortBy = 'WinLossBased' THEN a.WinLossBased
								WHEN @SortBy = 'PayoutBased' THEN a.PayoutBased
								ELSE a.TransactionId
							END
						ELSE 1
						END DESC
				, CASE WHEN @SortOrder = 'asc' THEN 
							CASE
							WHEN @SortBy = 'Turnover' THEN a.BetAmount
							WHEN @SortBy = 'WinLoss' THEN a.NetAmount
							WHEN @SortBy = 'Payout' THEN a.Payout
							WHEN @SortBy = 'TurnoverBased' THEN a.TurnoverBased
							WHEN @SortBy = 'WinLossBased' THEN a.WinLossBased
							WHEN @SortBy = 'PayoutBased' THEN a.PayoutBased
							ELSE a.TransactionId
							END
						ELSE 1	
						END ASC
				, a.TransactionId ASC
	END
		
	--- RETURN BET in Detail
	SELECT p.[Index]
		,p.RefNo
		,PlayerName
		,CurrencyName
		,TransTime
		,CASE WHEN BetType = '-' THEN g.GameName ELSE p.BetType END BetType
		,ProductCode
		,g.GameName AS SportName
		,Turnover
		,WinLoss
		,Payout
		,p.TurnoverBased
		,p.WinLossBased
		,PayoutBased
		,[Status]
	FROM #DailyResult p
		INNER JOIN bodb_Ploutos.dbo.GameDetail g WITH(NOLOCK)
			ON p.GameCode = g.GameCode
	WHERE p.[Index] BETWEEN @RowStart AND @RowEnd
	ORDER BY p.[Index]

	--- RETURN - SUM total
	SELECT TotalRows = COUNT(1) 
			,TotalTurnover = SUM(TurnoverBased) 
			,TotalWinLoss = SUM(WinLossBased) 
			,TotalPayout = SUM(PayoutBased) 
	FROM #DailyResult

	DROP TABLE #DailyResult;
END
GO