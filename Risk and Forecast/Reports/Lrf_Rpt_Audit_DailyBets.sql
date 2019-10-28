/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@ProductCodes	VARCHAR(100),
	@CurrencyList   VARCHAR(500),
	@BaseCurrency	VARCHAR(3) = '',
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@SortBy			VARCHAR(10) = 'RefNo',
	@SortOrder		VARCHAR(3) = 'asc'
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

	DECLARE @Currency TABLE (Id INT, Code VARCHAR(5), Name VARCHAR(5))

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@CurrencyList
		INSERT INTO @Currency (Id, Code, Name)
		SELECT DISTINCT Id, Code, Code
		FROM OPENXML(@DocHandler, '/ROOT/CR', 1) WITH (Id [int], Code VARCHAR(5)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
    
    UPDATE @Currency
	SET     Code =  CASE  
                        WHEN Id = 20 THEN 'UUS' 
                        WHEN Id = 51 THEN 'VND' 
                        WHEN Id = 70 THEN 'MMK' 
                        ELSE Code
                    END 
	WHERE   Id IN (20,51,70)

	DECLARE @TempToDate DATE = DATEADD(DAY, 1, @Date)
     
	CREATE TABLE #AuditData
	(
		Winlostdate			DATE,
		CurrencyId			INT,
		PlayerName			VARCHAR(100),
		CurrencyName		VARCHAR(10),
		RefNo				BIGINT,
		TransTime			DATETIME,
		ProductCode			VARCHAR(10),
		BetType				VARCHAR(100),
		Turnover			MONEY,
		WinLoss				MONEY,
		[Status]			SMALLINT,
	)
	
	CREATE TABLE #PagingAuditData
	(
		[Index]				INT,
		PlayerName			VARCHAR(100),
		CurrencyName		VARCHAR(10),
		RefNo				BIGINT,
		TransTime			DATETIME,
		ProductCode			VARCHAR(10),
		BetType				VARCHAR(100),
		Turnover			MONEY,
		WinLoss				MONEY,
		[Status]			SMALLINT
	)

	DECLARE @showSB BIT = 0,
			@showNG BIT = 0,
			@showCS BIT = 0,
			@showLC BIT = 0
	
	SELECT @showSB = 1 FROM @Product WHERE ProductCode = 'SB'
	SELECT @showNG = 1 FROM @Product WHERE ProductCode = 'NG'
	SELECT @showCS = 1 FROM @Product WHERE ProductCode = 'CS'
	SELECT @showLC = 1 FROM @Product WHERE ProductCode = 'LC'

	-- Retrive data from rptDep_AuditTickets		
	INSERT INTO #AuditData
		(  
			Winlostdate,
			CurrencyId,
			PlayerName,
			CurrencyName,
			RefNo,
			TransTime,
			ProductCode,
			BetType,
			Turnover,
			WinLoss,
			[Status]
		)
	SELECT	a.PlayerName,
			c.Id,
			c.Name,
			a.TransactionId,
			a.TransactionDate,
			CASE
				WHEN a.GameType = 'SB' THEN 'SB'
				WHEN a.GameType = 'RNG' AND a.GameCode = '161' THEN 'NG'
				WHEN a.GameType = 'RNG' AND a.GameCode <> '161' THEN 'CS'
				WHEN a.GameType = 'CA' THEN 'LC'
				ELSE ''
			END,
			a.BetType,
			a.BetAmount,
			- a.NetAmount,
			CASE
				WHEN a.NetAmount > 0 THEN 1
				WHEN a.NetAmount < 0 THEN -1
				ELSE 0
			END
	FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK)
	INNER JOIN @Currency c ON c.Code = a.CurrencyCode
	WHERE  a.WinLostDate >= @Date AND a.WinLostDate < @TempToDate 
			AND Brand = @SiteName
			AND (
					(@showSB = 1 AND a.GameType = 'SB') 
				OR	(@showNG = 1 AND a.GameType = 'RNG' AND a.GameCode = '161')
				OR	(@showCS = 1 AND a.GameType = 'RNG' AND a.GameCode <> '161')
				OR	(@showLC = 1 AND a.GameType = 'CA')
			)

	-- Exchange Rate
	CREATE TABLE #Exchange (ExFromDate DATE, ExToDate DATE, ExchangeID INT, USD FLOAT, GBP FLOAT, EUR FLOAT, Rate FLOAT, DefaultRate FLOAT )
	
	INSERT INTO #Exchange(ExFromDate, ExToDate, ExchangeID, Rate)
	SELECT	FromDate, 
			ToDate,
			ExchangeID,
			Rate
	FROM dbo.Lrf_f_GetExchangeRate(@Date, @Date, @BaseCurrency, '') exc

	-- Return data
	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Sql NVARCHAR(2000)

	SET @Sql = 
		N'SELECT a.*
		FROM
			(
				SELECT
					ROW_NUMBER() OVER (ORDER BY ' + @SortBy + ' ' + @SortOrder + N') AS [Index],
					d.*
				FROM #AuditData AS d
			) AS a
		WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
		ORDER BY a.RowNum'

	INSERT INTO #PagingAuditData
	EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

	SELECT
		[Index],
		PlayerName,
		CurrencyName,
		RefNo,
		TransTime,
		ProductCode,
		BetType,
		Turnover,
		WinLoss,
		[Status]
	FROM #PagingAuditData

	SELECT
		SUM(d.Turnover * e.Rate)	AS Turnover,
		SUM(d.WinLoss * e.Rate)		AS WinLoss,
		COUNT(d.RefNo)				AS TotalRows
	FROM #AuditData d
	INNER JOIN #Exchange e ON d.Winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND d.CurrencyId = e.ExchangeID	
		
	DROP TABLE #AuditData
	DROP TABLE #PagingAuditData
	DROP TABLE #Exchange
END
GO