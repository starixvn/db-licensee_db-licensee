/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_AdminBetList]  	
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@BaseCurrency	VARCHAR(12) = 'USD',
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@SortBy			VARCHAR(50) = 'TransactionId',
	@SortOrder		VARCHAR(4) = 'asc'
AS 
/*  
	Created: 20231025@Bobby
    Description: LAP - Implement new report for auditing
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20231025@Bobby: Customer Admin - [redmine: #195850]
		
    Param's Explanation:  
	  
*/
BEGIN  
    
	SET NOCOUNT ON;
	
	DECLARE @SiteName VARCHAR(10) = '12Bet';
	DECLARE @Product TABLE (ProductCode VARCHAR(10))
	DECLARE @Currency AS TABLE (Id INT, Code VARCHAR(5), Name VARCHAR(5), ExRate FLOAT, ExRateOrg FLOAT)

	DROP TABLE IF EXISTS #DailyResult;
	CREATE TABLE #DailyResult
	(
		[Index] INT IDENTITY (1, 1) PRIMARY KEY
		,RefNo	BIGINT
		,TransTime DATETIME
		,BetType NVARCHAR(128)
		,ProductCode VARCHAR(10)
		,Turnover MONEY
		,WinLoss MONEY
		,[Status] SMALLINT
		,TurnoverBased MONEY
		,WinLossBased MONEY
		,GameCode VARCHAR(10)
	);

	-- Get Currency
	WITH CTE_Currency AS (
		SELECT ex.Code AS Code, c.Currency AS Id
		FROM dbo.custinfo c WITH(NOLOCK)
		INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON c.Currency = ex.ExchangeId
		WHERE c.CustId = @CustId
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
		c.ExRateOrg = CASE WHEN @SiteName = 'Ivorybet' THEN 1 * ex.MultipliedBy ELSE 1 END
	FROM @Currency c
	LEFT JOIN dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') e ON c.Id = e.ExchangeId
	INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON c.Id = ex.ExchangeId
	SELECT @SiteName = dbo.Lrf_f_MappingAuditSite(@SiteName)

	IF (@SortBy <> 'WinLoss' AND @SortBy <> 'Turnover' AND @SortBy <> 'TurnoverBased' AND @SortBy <> 'WinLossBased')
	BEGIN
		SET @SortBy = 'TransactionId'
		SET @SortOrder = 'asc'
	END

	-- Fixed: SB only
	INSERT INTO @Product(ProductCode) VALUES('SB');
	DECLARE @TempToDate DATETIME = DATEADD(DAY, 1, @ToDate)

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

	-- GATHER BET Soure
	INSERT INTO #DailyResult
	(
		RefNo	
		,TransTime	
		,BetType	
		,ProductCode	
		,Turnover	
		,WinLoss	
		,[Status]	
		,TurnoverBased
		,WinLossBased
		,GameCode
	)
	SELECT 
		a.TransactionId
		,a.TransTime
		,a.BetType
		,a.ProductCode
		,a.Turnover
		,a.WinLoss
		,a.Status
		,TurnoverBased
		,WinLossBased
		,a.GameCode
	FROM (
			SELECT
				a.TransactionId
				,a.BetAmount * c.ExRateOrg AS BetAmount					
				,a.NetAmount * c.ExRateOrg AS NetAmount				
				,a.BetAmount * c.ExRate AS TurnoverBased
				,-a.NetAmount * c.ExRate AS WinLossBased
				,a.TransactionDate AS TransTime,
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
				CASE
					WHEN a.NetAmount > 0 THEN -1
					WHEN a.NetAmount < 0 THEN 1
					ELSE 0
				END AS [Status],
				a.GameCode
			FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
			INNER JOIN @Currency c ON c.Code = a.CurrencyCode
			WHERE 
				a.BrandCode = @SiteName
				AND a.CustId = @CustId
				AND a.StatusID IN (0, 1)
				AND a.SettlementDate >= @FromDate AND a.SettlementDate < @TempToDate 
				AND ( 
					(@showSB = 1 AND a.GamePlatformCode = 'SB') 
					OR (@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
					OR (@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
					OR (@showLC = 1 AND a.GamePlatformCode = 'CA')
				)
		) AS a
		ORDER BY 
			CASE WHEN @SortOrder = 'desc' THEN 
						CASE 
							WHEN @SortBy = 'Turnover' THEN a.BetAmount
							WHEN @SortBy = 'WinLoss' THEN a.NetAmount
							WHEN @SortBy = 'TurnoverBased' THEN a.TurnoverBased
							WHEN @SortBy = 'WinLossBased' THEN a.WinLossBased
							ELSE a.TransactionId
						END
					ELSE 1
					END DESC
			, CASE WHEN @SortOrder = 'asc' THEN 
						CASE
						WHEN @SortBy = 'Turnover' THEN a.BetAmount
						WHEN @SortBy = 'WinLoss' THEN a.NetAmount
						WHEN @SortBy = 'TurnoverBased' THEN a.TurnoverBased
						WHEN @SortBy = 'WinLossBased' THEN a.WinLossBased
						ELSE a.TransactionId
						END
					ELSE 1	
					END ASC
			, a.TransactionId ASC
	
		
	--- RETURN BET in Detail
	SELECT p.[Index]
		,p.RefNo
		,TransTime
		,CASE WHEN BetType = '-' THEN g.GameName ELSE p.BetType END BetType
		,ProductCode
		,g.GameName AS SportName
		,Turnover
		,WinLoss
		,p.TurnoverBased
		,p.WinLossBased
		,[Status]
	FROM #DailyResult p
		INNER JOIN bodb_Ploutos.dbo.GameDetail g WITH(NOLOCK)
			ON p.GameCode = g.GameCode
	WHERE p.[Index] BETWEEN @RowStart AND @RowEnd
	ORDER BY p.[Index];
	
	--- RETURN - SUM total
	SELECT TotalRows = COUNT(1) 
			,TotalTurnover = SUM(TurnoverBased) 
			,TotalWinLoss = SUM(WinLossBased) 
	FROM #DailyResult
END
GO