/*<info serverAlias="DBRPT-bodb_Report" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_API_PlayerBalanceSel]
	@AgentList		VARCHAR(MAX),
	@Winlostdate	SMALLDATETIME,
	@PageIndex		INT = 1,
	@PageSize		INT = 500,
	@TotalRows		INT = 0 OUTPUT
AS
/*
	Created: 20240812@Bobby
	Task: 209041 - LAP API - Get Player Balance
	DB: DBRPT/bodb_Report

	Revisions:
		- 20240812@Bobby: Init [RedmineID: #209041]
*/
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #TempAg;
	CREATE TABLE #TempAg(CustId INT PRIMARY KEY, Currency INT);

	DROP TABLE IF EXISTS #rptPlayerBalance;
	CREATE TABLE #rptPlayerBalance (rIdx INT IDENTITY(1, 1) PRIMARY KEY, Nickname VARCHAR(50), ExchangeId INT, ClosingBalance MONEY, TotalRows INT)

	DECLARE @DocHandler INT
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg(CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH

		GOTO RS_OUTPUT;
	END CATCH;

	DECLARE @apiDate SMALLDATETIME, @openingDate SMALLDATETIME, @toDay SMALLDATETIME;
	SELECT @apiDate = CAST(@Winlostdate AS DATE),
		@toDay		= CAST(GETDATE() AS DATE),
		@TotalRows	= 0;

	--TODO: Get players balance
	IF @apiDate < @toDay AND @PageIndex > 0
	BEGIN
		SET @openingDate = DATEADD(DAY, 1, @apiDate);
		;WITH CTE_Player AS (
			SELECT c.custid
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50) AS Nickname
				, a.Currency
				, COUNT(1) OVER() AS TotalRows
			FROM bodb02.dbo.Customer c (NOLOCK)
			INNER JOIN #TempAg AS a ON a.custid = c.recommend
			
			WHERE c.roleid = 1
				AND c.username2 IS NOT NULL --exclude dummy accounts
				AND a.Currency <> 20 --exclude UUS accounts
				AND c.creatdate < @openingDate
			ORDER BY SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50)
			OFFSET (@PageIndex-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
		)
		INSERT INTO #rptPlayerBalance
		SELECT c.Nickname, c.Currency AS ExchangeId, ISNULL(rpt.OpeningBalance,0) AS ClosingBalance
			,c.TotalRows
		FROM CTE_Player c
			LEFT JOIN dbo.rptDepWinlost_Main AS rpt WITH (NOLOCK) ON rpt.CustID = c.custid AND rpt.winlostdate = @openingDate
		; 
	END

	RS_OUTPUT:
	--TODO: @TotalRows
	SELECT TOP(1) @TotalRows = TotalRows 
	FROM #rptPlayerBalance

	--TODO: result
	SELECT Nickname, ExchangeId, ClosingBalance
	FROM #rptPlayerBalance
	ORDER BY rIdx
	;
	
	--SELECT @TotalRows [@TotalRows];
END
GO