/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_DormantCustomerSel]
	@username		VARCHAR(50) = NULL,
	@PageSize		INT = 50,
	@PageIndex		INT = 1,
	@TotalRows		INT = 0  OUTPUT,
	@AgentList		VARCHAR(MAX)
AS

/*
	Created: 20181121@Joseph
	Task: Get dormant customers
	DB: DBEXT/bodb02

	Revisions:
	- 20181121@Joseph: Create
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @currentDate DATETIME   
	SELECT  @currentDate = CONVERT(DATE, GETDATE())

	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
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
		custid					INT PRIMARY KEY,
		username				NVARCHAR (50),
		nickname				NVARCHAR (50),
        Balance                 MONEY,
		RowNumber				INT
	)

	CREATE TABLE #AllMember
	(
		CustID			INT PRIMARY KEY CLUSTERED,
		username2		VARCHAR(50),
		username		VARCHAR(50),
        Balance         MONEY
	)


	DECLARE @CustID INT, @i INT, @max INT, @LastOffBy INT

	SET @username = LTRIM(RTRIM(@username))
			
    INSERT INTO #AllMember (CustID, username2, username, Balance)
            SELECT c.custid, c.username2, c.username, c.ClosingBalance
            FROM #AgentData t
                INNER JOIN dbo.Dep_Customer_Archived c WITH (NOLOCK) ON c.recommend = t.custid	
            WHERE (c.username2 LIKE '%$' + @Username + '%'  OR c.username LIKE  @Username + '%')
    
    SELECT @TotalRows = COUNT(custid) FROM #AllMember

    INSERT INTO #ResultData (custid, username, nickname, Balance, RowNumber)
    SELECT a.custid, a.username, a.nickname, a.Balance, a.RowNumber
    FROM 
        (
            SELECT m.custid, 
                m.username, 
                SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
                m.Balance,
                ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
            FROM #AllMember m
        ) a 
    WHERE a.rownumber BETWEEN @rowstart AND @rowend

	SELECT *
	INTO #ExchangeRate
	FROM Lrf_f_GetExchangeDaily(@currentDate, @currentDate)

	SELECT
		t.custid,
		username,
		nickname,
        RowNumber,
		ISNULL(t.Balance, 0) AS Balance
	FROM #ResultData t
	ORDER BY t.username

	DROP TABLE #AgentData
	DROP TABLE #ResultData
	DROP TABLE #ExchangeRate
	DROP TABLE #AllMember
END
GO