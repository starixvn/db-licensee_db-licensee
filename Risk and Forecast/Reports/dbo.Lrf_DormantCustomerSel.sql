/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_DormantCustomerSel]
	@username		VARCHAR(50) = NULL,
	@PageSize		INT = 50,
	@PageIndex		INT = 1,
	@TotalRows		INT = 0  OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)
AS

/*
	Created: 20181121@Joseph
	Task: Get dormant customers
	DB: DBEXT/bodb02

	Revisions:
	- 20181121@Joseph: Create [#102680]
	- 20190621@Amanda: Add @BaseCurrency parameter [Redmine: #112531]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @currentDate DATETIME   
	SELECT  @currentDate = CONVERT(DATE, GETDATE())

	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #AgentData (custid INT)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #AgentData(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
 
	SET @Username = ISNULL(@Username, '')

	CREATE TABLE #ResultData
	(
		custid			INT PRIMARY KEY,
		username		NVARCHAR (50),
		nickname		NVARCHAR (50),
        Balance         MONEY,
		ArchivedDate	DATE,
		Currency		TINYINT,
		RowNumber		INT
	)

	CREATE TABLE #AllMember
	(
		CustID			INT PRIMARY KEY CLUSTERED,
		username2		VARCHAR(50),
		username		VARCHAR(50),
        Balance         MONEY,
		ArchivedDate	DATE,
		Currency		TINYINT
	)

	SET @username = LTRIM(RTRIM(@username))
			
    INSERT INTO #AllMember (CustID, username2, username, Balance, ArchivedDate, Currency)
            SELECT dc.custid, dc.username2, dc.username, dc.ClosingBalance, dc.ArchivedDate, c.currency
            FROM #AgentData a
                INNER JOIN dbo.Dep_Customer_Archived dc WITH (NOLOCK) ON dc.recommend = a.custid	
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON dc.recommend = c.custid 
            WHERE (dc.username2 LIKE '%$' + @Username + '%'  OR dc.username LIKE  @Username + '%') 
				AND dc.CustID NOT IN (SELECT CustID FROM dbo.Customer WITH (NOLOCK))
    
    SELECT @TotalRows = COUNT(custid) FROM #AllMember

    INSERT INTO #ResultData (custid, username, nickname, Balance, ArchivedDate, Currency, RowNumber)
    SELECT a.custid, a.username, a.nickname, a.Balance, a.ArchivedDate, a.Currency, a.RowNumber
    FROM 
        (
            SELECT m.custid, 
                m.username, 
                SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
                m.Balance,
				m.ArchivedDate,
				m.Currency,
                ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
            FROM #AllMember m
        ) a 
    WHERE a.rownumber BETWEEN @rowstart AND @rowend

	SELECT ExchangeID, Rate
	INTO #ExchangeRate
	FROM Lrf_f_GetExchangeRate(@currentDate, @currentDate, @BaseCurrency, '')

	SELECT
		t.custid,
		username,
		nickname,
		ArchivedDate,
        RowNumber,
		ISNULL(t.Balance, 0) * ISNULL(e.Rate,0) AS Balance
	FROM #ResultData t
	LEFT JOIN #ExchangeRate e ON t.Currency = e.ExchangeID
	ORDER BY t.username

	DROP TABLE #AgentData
	DROP TABLE #ResultData
	DROP TABLE #ExchangeRate
	DROP TABLE #AllMember
END
GO