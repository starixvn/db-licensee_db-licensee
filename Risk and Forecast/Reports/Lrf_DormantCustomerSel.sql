/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_DormantCustomerSel]
	@Username		VARCHAR(50)		= NULL,
	@SearchOption	TINYINT			= 0,
	@PageSize		INT				= 50,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0  OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(12)
AS

/*
	Created: 20181121@Joseph
	Task: Get dormant customers
	DB: DBEXT.bodb02

	Revisions:
		- 20181121@Joseph: Create [#102680]
		- 20190621@Amanda: Add @BaseCurrency parameter [Redmine: #112531]
		- 20200222@Kos: Enhance performance [Redmine: #129003]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]	
		- 20211222@Johnson: support search by option for dormant accounts [RedmineID: #164294]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
	Parameter's Explanation:
		@searchOption: 0- default search on LRF
						1- Match prefix
						2- Match case						
						3- Match Precise
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @TempAg (CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #ResultData
	(
		CustId			INT PRIMARY KEY,
		Username		NVARCHAR(50),
		Nickname		NVARCHAR(50),
		Balance			MONEY,
		ArchivedDate	DATE,
		Currency		TINYINT,
		RowNumber		INT
	)

	CREATE TABLE #AllMember
	(
		CustId			INT PRIMARY KEY CLUSTERED,
		Username2		VARCHAR(50),
		Username		VARCHAR(50),
		Balance			MONEY,
		ArchivedDate	DATE,
		Recommend		INT
	)

	SET @Username = LTRIM(RTRIM(ISNULL(@Username, '')))

	-- Get all data
	INSERT INTO #AllMember (
		CustId,
		Username2,
		Username,
		Balance,
		ArchivedDate,
		Recommend)
	SELECT
		dc.CustID,
		dc.Username2,
		dc.Username,
		dc.ClosingBalance,
		dc.ArchivedDate,
		dc.Recommend
	FROM dbo.Dep_Customer_Archived AS dc WITH (NOLOCK, INDEX = IX_Recommend)
		INNER JOIN @TempAg AS a ON dc.Recommend = a.CustId 
	WHERE 1= CASE WHEN @SearchOption = 0 AND (dc.username2 LIKE '%$' + @Username + '%'	OR dc.username LIKE  @Username + '%') THEN 1
				WHEN @SearchOption = 1 AND dc.username2 LIKE '%$' + @Username + '%' THEN 1
				WHEN @SearchOption = 2 AND SUBSTRING(dc.username2,CHARINDEX('$',dc.username2)+1,len(dc.username2)) LIKE '%' + @Username + '%' THEN 1
				WHEN @SearchOption = 3 AND (dc.username2 LIKE '%$' + @Username + '' OR dc.username = '' + @Username + '') THEN 1
				ELSE 0 END
		AND dc.username NOT LIKE '%01OddsAdj%'

	DELETE c
	FROM #AllMember AS c
	WHERE EXISTS (SELECT 1 FROM dbo.Customer WITH (NOLOCK) WHERE custid = c.CustId)

	-- Get total rows
	SELECT @TotalRows = COUNT(CustId)
	FROM #AllMember

	-- Paging
	DECLARE @RowStart INT, @RowEnd INT

	SELECT
		@PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1 

	INSERT INTO #ResultData (
		CustId,
		Username,
		Nickname,
		Balance,
		ArchivedDate,
		Currency,
		RowNumber)
	SELECT
		a.CustId,
		a.Username,
		a.Nickname,
		a.Balance,
		a.ArchivedDate,
		c.Currency,
		a.RowNumber
	FROM
		(
			SELECT
				CustId,
				Username,
				SUBSTRING(Username2, CHARINDEX('$', Username2) + 1, LEN(Username2) - CHARINDEX('$', Username2)) AS Nickname,
				Balance,
				ArchivedDate,
				Recommend,
				ROW_NUMBER() OVER (ORDER BY CustId ASC) AS RowNumber
			FROM #AllMember
		) AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON a.Recommend = c.custid
	WHERE a.RowNumber BETWEEN @RowStart AND @RowEnd

	-- Get exchange rate
	DECLARE @CurrentDate DATETIME

	SELECT @CurrentDate = CONVERT(DATE, GETDATE())

	DECLARE @ExchangeRate TABLE (
		ExchangeId	INT,
		Rate		FLOAT
	)

	INSERT INTO @ExchangeRate
	SELECT
		ExchangeID,
		Rate
	FROM dbo.Lrf_f_GetExchangeRate(@CurrentDate, @CurrentDate, @BaseCurrency, '')

	-- Return data
	SELECT
		t.CustId,
		t.Username,
		t.Nickname,
		t.ArchivedDate,
		t.RowNumber,
		t.Currency,
		ISNULL(t.Balance, 0) * ISNULL(e.Rate, 0) AS Balance
	FROM #ResultData AS t
		LEFT JOIN @ExchangeRate AS e ON t.Currency = e.ExchangeId
	ORDER BY t.Username ASC

	DROP TABLE #ResultData
	DROP TABLE #AllMember
END
GO