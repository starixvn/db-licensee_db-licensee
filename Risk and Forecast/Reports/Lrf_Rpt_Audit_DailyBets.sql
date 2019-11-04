/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@ProductCodes	VARCHAR(100),
	@CurrencyList   VARCHAR(500),
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@SortBy			VARCHAR(50) = 'TransactionId',
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

	DECLARE @Currency AS TABLE (Id INT, Code VARCHAR(5), Name VARCHAR(5))

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@CurrencyList
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
		FROM OPENXML(@DocHandler, '/ROOT/CR', 1) WITH (Id [int], Code VARCHAR(5)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'
		RETURN
	END CATCH;
	
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

	IF (@SortOrder = 'asc')
	BEGIN
		;WITH PagingData_CTE AS (
		SELECT
			ROW_NUMBER() OVER (ORDER BY CASE 
				WHEN @SortBy = 'Turnover' THEN a.BetAmount
				WHEN @SortBy = 'WinLoss' THEN a.NetAmount
				ELSE a.TransactionId
				END ASC )							AS [Index],
			a.PlayerName,
			c.Name									AS CurrencyName,
			a.TransactionId							AS RefNo,
			a.TransactionDate						AS TransTime,
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
		)
		SELECT *
		FROM PagingData_CTE
		WHERE [Index] BETWEEN @RowStart AND @RowEnd
	END
	ELSE
	BEGIN
		;WITH PagingData_CTE AS (
		SELECT
			ROW_NUMBER() OVER (ORDER BY CASE 
				WHEN @SortBy = 'Turnover' THEN a.BetAmount
				WHEN @SortBy = 'WinLoss' THEN a.NetAmount
				ELSE a.TransactionId
				END DESC )							AS [Index],
			a.PlayerName,
			c.Name									AS CurrencyName,
			a.TransactionId							AS RefNo,
			a.TransactionDate						AS TransTime,
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
		)
		SELECT *
		FROM PagingData_CTE
		WHERE [Index] BETWEEN @RowStart AND @RowEnd
	END
END
GO