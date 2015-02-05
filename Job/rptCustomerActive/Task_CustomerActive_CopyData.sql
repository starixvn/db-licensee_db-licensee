USE bodb_LicenseeReport
GO
ALTER PROCEDURE dbo.Task_CustomerActive_CopyData
AS
/*   
 Task: Copy data from staging table to main table
 DB: DBLIC/bodb_LicenseeReport
 Revisions: 
 Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @sql VARCHAR(8000)
	DECLARE @TransDateTable TABLE (RowIndex INT IDENTITY(1,1), TransDate DATE)
	SET @sql = ''
	SELECT @sql = 'SELECT TransDate
					FROM OPENQUERY(DBARC, ''SELECT TransDate 
					FROM bodb_report.dbo.rptCustomerActiveTmp WITH (NOLOCK) GROUP BY TransDate OPTION (MAXDOP 1)'')'

	INSERT INTO @TransDateTable(TransDate)
	EXEC (@sql)

	IF NOT EXISTS (SELECT TOP 1 1 FROM @TransDateTable )
		RETURN

	CREATE TABLE #DataTemp (TransDate DATE, CustId INT, Recommend INT, CurrencyId INT, ProductId INT)

	DECLARE @TransDate DATE, @RowIndex INT
	SET @RowIndex = 1
	WHILE EXISTS (SElECT 1 FROM @TransDateTable WHERE RowIndex = @RowIndex)
	BEGIN
		SELECT @TransDate = TransDate FROM @TransDateTable WHERE RowIndex = @RowIndex
		SELECT @RowIndex = @RowIndex + 1, @sql = ''

		SELECT @sql = 'SELECT TransDate, CustId, Recommend, CurrencyId, ProductId
						FROM OPENQUERY(DBARC, ''SELECT TransDate, CustId, Recommend, CurrencyId, ProductId 
						FROM bodb_report.dbo.rptCustomerActiveTmp WITH (NOLOCK) WHERE TransDate = ''''' + CAST(@TransDate AS VARCHAR(20)) 
																										+ ''''' OPTION (MAXDOP 1)'')'
		--SELECT @TransDate AS '@TransDate', @sql AS '@sql'

		INSERT INTO #DataTemp(TransDate, CustId, Recommend, CurrencyId, ProductId)
		EXEC (@sql)

		INSERT INTO dbo.rptCustomerActive(TransDate, CustId, Recommend, CurrencyId, ProductId)
		SELECT tmp.TransDate, tmp.CustId, tmp.Recommend, tmp.CurrencyId, tmp.ProductId
		FROM (
			SELECT TransDate, CustId, Recommend, CurrencyId, ProductId
			FROM #DataTemp
			GROUP BY TransDate, CustId, Recommend, CurrencyId, ProductId
		)tmp LEFT JOIN dbo.rptCustomerActive rpt WITH(NOLOCK) 
		ON tmp.TransDate = rpt.TransDate AND tmp.CustId = rpt.CustId AND tmp.ProductId = rpt.ProductId
		WHERE rpt.TransDate IS NULL
		OPTION (MAXDOP 1)

		DELETE #DataTemp

		WAITFOR DELAY '00:00:00.280'

	END

	DROP TABLE #DataTemp
END

GO

