/*<info serverAlias="DBPLO-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets_Detail]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@CurrencyList   VARCHAR(MAX),
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@SearchRefNo	BIGINT = NULL,
	@TotalRow		INT = 0 OUTPUT
AS 
/*  Created: 20240108@Bobby
    Description: LAP - AuditIvory Implement daily bets detail
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20240108@Bobby: LAP - AuditIvory daily bets detail [RedmineID: #194883]
		- 20241121@Kelvin: LAP - Support BRL base currency, extend length @CurrencyList [RedmineID: #208662]
		
    Param's Explanation:  
	  + @CurrencyList: xml structure
		<ROOT>
			<CR Id="13" Code="CNY"/>
			<CR Id="51" Code="IDR"/> 
		</ROOT>
		+ @PageIndex:
			- 0	: Do exporting excel
			- >0: Do paging
*/
BEGIN  
    
	SET NOCOUNT ON;

	DECLARE @Currency AS TABLE (Id INT, Code VARCHAR(5), Name VARCHAR(5), ExRateOrg FLOAT)
	DECLARE @CurrDate		DATETIME
		, @TempToDate		DATETIME
		, @SearchTransId	BIGINT
		, @Offset			INT;

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
	
	SELECT @CurrDate		= @Date
		, @TempToDate		= DATEADD(DAY, 1, @Date)
		, @SearchTransId	= @SearchRefNo
	;

	-- GET ExRate
	UPDATE c
	SET c.ExRateOrg = CASE WHEN @SiteName IN ('Ivorybet','12B') THEN 1 * ex.MultipliedBy ELSE 1 END
	FROM @Currency c
	INNER JOIN dbo.Exchange ex WITH(NOLOCK) ON c.Id = ex.ExchangeId

	-- TODO: Site mapping
	SELECT @SiteName = dbo.Lrf_f_MappingAuditSite(@SiteName)

	-- TODO: paging
	SELECT @TotalRow	= 0,
		@PageIndex		= @PageIndex - 1,
		@Offset			= @PageSize * @PageIndex
	;
	-- TODO: Export excel
	SELECT @Offset	= IIF(@PageIndex < 0, 0, @Offset)
		, @PageSize	= IIF(@PageIndex < 0, 2147483647, @PageSize) -- max value int 4 Bytes
	;

	DROP TABLE IF EXISTS #result;

	SELECT
		a.SettlementDate
		,br.BrandUrl
		,CASE
			WHEN a.GamePlatformCode = 'SB' THEN 'SB'
			WHEN a.GamePlatformCode = 'CA' THEN 'CA'
			ELSE 'SB'
		END AS GameType
		,c.Name AS CurrencyCode
		,a.DebitAmount
		,a.CreditAmount
		,CONVERT(MONEY, a.BetAmount * c.ExRateOrg) AS Turnover
		,CONVERT(MONEY, -a.NetAmount * c.ExRateOrg) AS WinLoss
		,a.TransactionId AS RefNo
		,ROW_NUMBER() OVER (ORDER BY a.TransactionId ASC) AS rIdx
		,COUNT(1) OVER () AS TotalRow
	INTO #result
	FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.Brand br WITH(NOLOCK) ON br.BrandCode = a.BrandCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
	WHERE 
		a.BrandCode = @SiteName
		AND a.StatusID IN (0, 1)
		AND a.SettlementDate >= @CurrDate AND a.SettlementDate < @TempToDate 
		AND a.TransactionId = ISNULL(@SearchTransId, a.TransactionId)
	ORDER BY rIdx ASC
	OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
	
	--TODO: Set OUTPUT
	SELECT TOP(1) @TotalRow = TotalRow
	FROM #result

	SELECT SettlementDate
		,BrandUrl
		,GameType
		,CurrencyCode
		,DebitAmount
		,CreditAmount
		,Turnover
		,WinLoss
		,RefNo
		,rIdx
	FROM #result
	ORDER BY rIdx ASC
END