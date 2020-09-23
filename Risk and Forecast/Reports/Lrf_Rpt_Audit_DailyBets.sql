/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@ProductCodes	VARCHAR(100),
	@CurrencyList   VARCHAR(500),
	@BaseCurrency	VARCHAR(3) = '',
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@SortBy			VARCHAR(50) = 'TransactionId',
	@SortOrder		VARCHAR(4) = 'asc'
AS 
/*  Created: 20191028@Amanda
    Description: LAP - Implement new report for auditing
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20191028@Amanda: Created new SP [RedmineID: #122789]
		- 20200325@Bobby: Ploutos Integration - [redmine: #125252]

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
		    @CurrencyList=N'<ROOT><CR Id="13" Code="CNY"/><CR Id="15" Code="IDR"/> </ROOT>'	    
*/
BEGIN  
    
	SET NOCOUNT ON;
	
	DECLARE @cutoffDate DATE;
	DECLARE @Product TABLE (ProductCode VARCHAR(10))
	DECLARE @Currency AS TABLE (Id INT, Code VARCHAR(5), Name VARCHAR(5), ExRate FLOAT)

	--get cutoffDate
	SELECT @cutoffDate = f.CutOffDate 
	FROM Lrf_f_GetCutOffDateBySite() f
	WHERE f.ReportType = 1 AND f.SiteName = @SiteName

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',');

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
	SELECT 
		Id,
		CASE  
            WHEN Id = 20 THEN 'UUS' 
            WHEN Id = 51 THEN 'VND' 
            WHEN Id = 70 THEN 'MMK' 
            ELSE Code
        END,
        Code
	FROM CTE_Currency
	
	-- GET ExRate
	UPDATE c
	SET c.ExRate = ISNULL(e.Rate, 1)
	FROM @Currency c
	LEFT JOIN dbo.Lrf_f_GetExchangeRate(@Date, @Date, @BaseCurrency, '') e ON c.Id = e.ExchangeId

	IF (@SiteName = 'IvoryBet')
	BEGIN
		SET @SiteName = 'ivorysport'
	END
	
	IF (@SortBy = 'WinLoss')
	BEGIN
		SET @SortOrder = CASE WHEN @SortOrder = 'asc' THEN 'desc' ELSE 'asc' END
	END

	IF (@SortBy <> 'WinLoss' AND @SortBy <> 'Turnover')
	BEGIN
		SET @SortBy = 'TransactionId'
		SET @SortOrder = 'asc'
	END
	
	DECLARE @TempToDate DATE = DATEADD(DAY, 1, @Date)

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
	SELECT a.TransactionId
		, a.Name
		, ROW_NUMBER() OVER (
				ORDER BY CASE WHEN @SortOrder = 'desc' THEN 
									CASE 
										WHEN @SortBy = 'Turnover' THEN a.BetAmount
										WHEN @SortBy = 'WinLoss' THEN a.NetAmount
										ELSE a.TransactionId
									END
								ELSE 1
								END DESC
						, CASE WHEN @SortOrder = 'asc' THEN 
									CASE
									WHEN @SortBy = 'Turnover' THEN a.BetAmount
									WHEN @SortBy = 'WinLoss' THEN a.NetAmount
									ELSE a.TransactionId
									END
								ELSE 1	
								END ASC
					) AS rowIdx
		, TotalRows		= COUNT(1) OVER()
		, TotalTurnover = SUM(BetAmount_Rate) OVER()
		, TotalWinLoss	= -SUM(NetAmount_Rate) OVER()
	INTO #tempPaging
	FROM (
		SELECT
			a.TransactionId
			, c.Name
			, a.BetAmount
			, a.NetAmount
			, a.BetAmount * c.ExRate AS BetAmount_Rate
			, a.NetAmount * c.ExRate AS NetAmount_Rate
			, 'AuditTicket' AS SourceName
		FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		WHERE  a.WinLostDate >= @Date AND a.WinLostDate < @TempToDate 
				AND Brand = @SiteName
				AND ( 
					(@showSB = 1 AND a.GameType = 'SB') 
					OR (@showNG = 1 AND a.GameType = 'RNG' AND a.GameCode = '161')
					OR (@showCS = 1 AND a.GameType = 'RNG' AND a.GameCode <> '161')
					OR (@showLC = 1 AND a.GameType = 'CA')
				)
				AND a.WinLostDate < @cutoffDate

		UNION ALL
		SELECT
			a.TransactionId
			, c.Name
			, a.BetAmount
			, a.NetAmount
			, a.BetAmount * c.ExRate AS BetAmount_Rate
			, a.NetAmount * c.ExRate AS NetAmount_Rate
			, 'BetTicket' AS SourceName
		FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
		WHERE  a.WinLostDate >= @Date AND a.WinLostDate < @TempToDate 
				AND a.BrandCode = @SiteName
				AND ( 
					(@showSB = 1 AND a.GamePlatformCode = 'SB') 
					OR (@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
					OR (@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
					OR (@showLC = 1 AND a.GamePlatformCode = 'CA')
				)
				AND a.WinLostDate >= @cutoffDate
	) AS a

	--select * from #tempPaging

	--- RETURN BET in Detail
	SELECT p.rowIdx AS [Index]
		, p.TransactionId AS RefNo
		, PlayerName
		, CurrencyName
		, TransTime
		, BetType
		, ProductCode
		, Turnover
		, WinLoss
		, [Status]
	FROM(
		SELECT p.rowIdx,
			p.TransactionId,
			a.PlayerName,
			p.Name									AS CurrencyName,
			a.TransactionDate						AS TransTime,
			a.BetType,
			CASE
				WHEN a.GameType = 'SB' THEN 'SB'
				WHEN a.GameType = 'RNG' AND a.GameCode = '161' THEN 'NG'
				WHEN a.GameType = 'RNG' AND a.GameCode <> '161' THEN 'CS'
				WHEN a.GameType = 'CA' THEN 'LC'
				ELSE ''
			END										AS ProductCode,
			a.BetAmount								AS Turnover,
			-a.NetAmount							AS WinLoss,
			CASE
				WHEN a.NetAmount > 0 THEN -1
				WHEN a.NetAmount < 0 THEN 1
				ELSE 0
			END										AS [Status]
		FROM #tempPaging p
		INNER JOIN bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK) ON a.TransactionId = p.TransactionId
		WHERE p.rowIdx BETWEEN @RowStart AND @RowEnd
			AND a.WinLostDate < @cutoffDate

		UNION ALL
		SELECT p.rowIdx,
			p.TransactionId,
			pp.Username AS Playername,
			p.Name									AS CurrencyName,
			a.TransactionDate						AS TransTime,
			a.BettypeName							AS BetType,
			CASE
				WHEN a.GamePlatformCode = 'SB' THEN 'SB'
				WHEN a.GamePlatformCode = 'RNG' AND a.GameCode = '0161' THEN 'NG'
				WHEN a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161' THEN 'CS'
				WHEN a.GamePlatformCode = 'CA' THEN 'LC'
				ELSE ''
			END										AS ProductCode,
			a.BetAmount								AS Turnover,
			-a.NetAmount							AS WinLoss,
			CASE
				WHEN a.NetAmount > 0 THEN -1
				WHEN a.NetAmount < 0 THEN 1
				ELSE 0
			END										AS [Status]
		FROM #tempPaging p
		INNER JOIN bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK) ON a.TransactionId = p.TransactionId
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
		WHERE p.rowIdx BETWEEN @RowStart AND @RowEnd
			AND a.WinLostDate >= @cutoffDate
	) AS p
	ORDER BY p.rowIdx

	--- RETURN - SUM total
	SELECT TOP(1) TotalRows,TotalTurnover,TotalWinLoss
	FROM #tempPaging

	DROP TABLE #tempPaging;
END
GO