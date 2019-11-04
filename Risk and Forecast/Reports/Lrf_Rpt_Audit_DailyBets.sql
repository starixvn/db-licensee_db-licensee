/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@ProductCodes	VARCHAR(100),
	@CurrencyList   VARCHAR(500),
	@BaseCurrency	VARCHAR(3) = '',
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@SortBy			VARCHAR(10) = 'TransactionId',
	@SortOrder		VARCHAR(4) = 'asc'
AS 
/*  Created: 20191028@Amanda
    Description: LAP - Implement new report for auditing
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20191028@Amanda: Created new SP [RedmineID: #122789]

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
    SET NOCOUNT ON
	DECLARE @Product TABLE (ProductCode VARCHAR(10))

	CREATE TABLE #Currency (Id INT, Code VARCHAR(5), Name VARCHAR(5), ExRate FLOAT)

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@CurrencyList
		INSERT INTO #Currency (Id, Code, Name)
		SELECT DISTINCT Id, Code, Code
		FROM OPENXML(@DocHandler, '/ROOT/CR', 1) WITH (Id [int], Code VARCHAR(5)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
    
    UPDATE #Currency
	SET     Code =  CASE  
                        WHEN Id = 20 THEN 'UUS' 
                        WHEN Id = 51 THEN 'VND' 
                        WHEN Id = 70 THEN 'MMK' 
                        ELSE Code
                    END 
	WHERE   Id IN (20,51,70)
	
	UPDATE c
	SET c.ExRate = ISNULL(e.Rate, 1)
	FROM #Currency c
	LEFT JOIN dbo.Lrf_f_GetExchangeRate(@Date, @Date, @BaseCurrency, '') e ON c.Id = e.ExchangeId

	IF (@SiteName = 'IvoryBet')
	BEGIN
		SET @SiteName = 'ivorysport'
	END
	
	IF (@SortBy = 'Turnover')
	BEGIN
		SET @SortBy = 'BetAmount'
	END
	ELSE IF (@SortBy = 'WinLoss')
	BEGIN
		SET @SortBy = 'NetAmount'
		SET @SortOrder = CASE WHEN @SortOrder = 'asc' THEN 'desc' ELSE 'asc' END
	END
	ELSE
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

	DECLARE @Sql NVARCHAR(MAX)

	SET @Sql =	
	N'WITH RowNum_Cte AS (
		SELECT
			ROW_NUMBER() OVER (ORDER BY ' + @SortBy + ' ' + @SortOrder + N') AS row_num,
			c.Name AS CurrencyName,
			a.TransactionId,
			a.BetAmount * c.ExRate AS Turnover,
			(-a.NetAmount) * c.ExRate AS WinLoss
		FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK)
		INNER JOIN #Currency c ON c.Code = a.CurrencyCode
		WHERE  a.WinLostDate >= @Date AND a.WinLostDate < @TempToDate 
				AND Brand = @SiteName
				AND ( 
					(@showSB = 1 AND a.GameType = ''SB'') 
					OR (@showNG = 1 AND a.GameType = ''RNG'' AND a.GameCode = ''161'')
					OR (@showCS = 1 AND a.GameType = ''RNG'' AND a.GameCode <> ''161'')
					OR (@showLC = 1 AND a.GameType = ''CA'')
	)), Count_Cte AS (SELECT COUNT(1) AS TotalRows, SUM(Turnover) AS TotalTurnover, SUM(WinLoss) AS TotalWinLoss FROM RowNum_Cte)
	SELECT r.row_num AS [Index], a.PlayerName, r.CurrencyName, a.TransactionId AS RefNo, a.TransactionDate AS TransTime,
			CASE
				WHEN a.GameType = ''SB'' THEN ''SB''
				WHEN a.GameType = ''RNG'' AND a.GameCode = ''161'' THEN ''NG''
				WHEN a.GameType = ''RNG'' AND a.GameCode <> ''161'' THEN ''CS''
				WHEN a.GameType = ''CA'' THEN ''LC''
				ELSE ''''
			END AS ProductCode,
			a.BetType,
			a.BetAmount AS Turnover,
			-a.NetAmount AS WinLoss,
			CASE
				WHEN a.NetAmount > 0 THEN -1
				WHEN a.NetAmount < 0 THEN 1
				ELSE 0
			END AS [Status],
			c.TotalRows, c.TotalTurnover, c.TotalWinLoss
	FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK)
	INNER JOIN RowNum_Cte r ON a.TransactionId = r.TransactionId
	CROSS JOIN Count_Cte c
	WHERE r.row_num BETWEEN @RowStart AND @RowEnd
	ORDER BY r.row_num'

	EXEC sp_executesql @Sql, N'@showSB BIT, @showNG BIT, @showCS BIT, @showLC BIT, @SiteName VARCHAR(50), @Date DATE, @TempToDate DATE, @RowStart INT, @RowEnd INT',
	@showSB, @showNG, @showCS, @showLC, @SiteName, @Date, @TempToDate, @RowStart, @RowEnd
	
	DROP TABLE #Currency
END
GO