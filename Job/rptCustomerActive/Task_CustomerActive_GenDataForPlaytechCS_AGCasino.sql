USE bodb_LicenseeReport
GO
CREATE PROCEDURE dbo.Task_CustomerActive_GenDataForPlaytechCS_AGCasino @FromDate DATE
	, @ToDate DATE
AS
/*   
	Creator: 20150204@Patrick
	Task: Generate for Playtech CS & AG Casino
	DB: DBLIC/bodb_LicenseeReport
	Revisions: 
	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	IF @FromDate IS NULL OR @ToDate IS NULL
		RETURN

	DECLARE @WinlostDate DATE, @MinTransId BIGINT, @MaxTransId BIGINT
	CREATE TABLE #DataTmp(TransDate DATE, Recommend INT, CustId INT, CurrencyId INT, ProductId INT)
	
	SELECT @WinlostDate = @FromDate

	WHILE @WinlostDate <= @ToDate
	BEGIN
		-- For Playtech Casino
		INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
		SELECT CAST(TransDate AS DATE) AS TransDate
			, b.CustID, b.recommend, b.currency, 9 AS ProductId
		FROM bodb_PlaytechCS.dbo.bettrans_PlaytechCS b WITH(NOLOCK)
		WHERE Winlostdate = @WinlostDate
		GROUP BY CAST(TransDate AS DATE), b.CustID, b.recommend, b.currency
		OPTION (RECOMPILE)

		-- For AG Casino
		INSERT INTO #DataTmp(TransDate, CustId, Recommend, CurrencyId, ProductId)
		SELECT CAST(TransDate AS DATE) AS TransDate
			, b.CustID, b.recommend, b.currency, 10 AS ProductId
		FROM bodb_PlaytechCS.dbo.bettrans_AGCasino b WITH(NOLOCK)
		WHERE Winlostdate = @WinlostDate
		GROUP BY CAST(TransDate AS DATE), b.CustID, b.recommend, b.currency
		OPTION (RECOMPILE)

		--merge to main table
		INSERT INTO dbo.rptCustomerActive(TransDate, CustId, Recommend, CurrencyId, ProductId)
		SELECT tmp.TransDate, tmp.CustId, tmp.Recommend, tmp.CurrencyId, tmp.ProductId
		FROM #DataTmp tmp
			LEFT JOIN dbo.rptCustomerActive rpt WITH(NOLOCK)
			ON tmp.TransDate = rpt.TransDate AND tmp.CustId = rpt.CurrencyId AND tmp.ProductId = rpt.ProductId
		WHERE rpt.TransDate IS NULL

		--reset params
		SELECT @WinlostDate = DATEADD(D, 1, @WinlostDate)
		DELETE #DataTmp

		WAITFOR DELAY '00:00:00.280'
	
	END

	DROP TABLE #DataTmp
END

GO
GRANT VIEW DEFINITION ON [dbo].[Task_CustomerActive_GenDataForPlaytechCS_AGCasino] TO [vnteam] AS [dbo]
GO
