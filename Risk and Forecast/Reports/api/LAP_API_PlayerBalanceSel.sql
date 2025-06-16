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
		- 20250611@Kelvin: Alog - API - PlayerReport/QueryClosingBalance return more data fields [RedmineID: #230288]
*/
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #TempAg;
	CREATE TABLE #TempAg(CustId INT PRIMARY KEY, Currency INT);

	DROP TABLE IF EXISTS #rptPlayerBalance;
	CREATE TABLE #rptPlayerBalance 
	(
		rIdx				INT IDENTITY(1, 1) PRIMARY KEY
		, CustId			INT
		, Nickname			VARCHAR(50)
		, Username			VARCHAR(50)
		, ExchangeId		INT
		, OpeningBalance	MONEY
		, Deposit			MONEY
		, Withdrawal		MONEY
		, Promotion			MONEY
		, Turnover			MONEY
		, DrawGame			MONEY
		, NetTurnover		MONEY
		, Outstanding		MONEY
		, WinLoss			MONEY
		, PlayerComm		MONEY
		, WinLossTotal		MONEY
		, ClosingBalance	MONEY
		, TotalRows			INT
	)

	DROP TABLE IF EXISTS #SportType;
	CREATE TABLE #SportType (SportType INT PRIMARY KEY, ProductCode VARCHAR(10))

	/* Get Agent list */
	-----------------------------------------------------------------------------------------------------------------------------------
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
	-----------------------------------------------------------------------------------------------------------------------------------

	/* Get SportType list */
	-----------------------------------------------------------------------------------------------------------------------------------
	DECLARE @ProductList VARCHAR(MAX)

	;WITH cte_Product AS
	(
	SELECT DISTINCT tbl.ProductPrefix
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', 0) AS tbl
		LEFT JOIN bodb02.[dbo].[Lrf_f_SelExcludedBetType]() e ON e.BetType = tbl.BetType
		OUTER APPLY 
		(
			SELECT f.Bettype
			FROM bodb02.dbo.f_BettypePrizeGroup() f
			WHERE f.BettypeGroup = 'Contribution'
				AND f.Bettype = tbl.bettype
		) AS cont
	WHERE e.BetType IS NULL
		AND cont.Bettype IS NULL
		AND tbl.ProductID NOT IN (11, 31, 37) -- NOT Support Saba Promotion, AG-Casino & Exchange
	)
	SELECT @ProductList = STRING_AGG(ProductPrefix, ',')
	FROM cte_Product

	INSERT INTO #SportType (SportType, ProductCode)
	SELECT DISTINCT SportType, ISNULL(p.GroupProductPrefix, s.ProductCode)
	FROM bodb02.dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList) s 
		LEFT JOIN bodb02.dbo.Lrf_f_GroupProduct() p ON s.ProductID = p.ProductId

	-----------------------------------------------------------------------------------------------------------------------------------

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
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, 50) AS Nickname
				, c.username
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
		(
			Nickname
			, CustId
			, Username
			, ExchangeId
			, OpeningBalance
			, Deposit
			, Withdrawal
			, Promotion
			, Turnover
			, DrawGame
			, NetTurnover
			, Outstanding
			, WinLoss
			, PlayerComm
			, WinLossTotal
			, ClosingBalance
			, TotalRows
		)
		SELECT
			c.Nickname
			, c.custid
			, c.username
			, c.Currency AS ExchangeId
			, ISNULL(rpt.OpeningBalance, 0) AS OpeningBalance
			, ISNULL(rpt.Deposit, 0) AS Deposit
			, ISNULL(rpt.Withdrawal, 0) AS Withdrawal
			, ISNULL(rpt.Promotion, 0) AS Promotion
			, 0 AS Turnover
			, 0 AS DrawGame
			, 0 AS NetTurnover
			, 0 AS Outstanding
			, 0 AS WinLoss
			, 0 AS PlayerComm
			, 0 AS WinLossTotal
			, ISNULL(rpt.ClosingBalance, 0) AS ClosingBalance
			,c.TotalRows
		FROM CTE_Player c
			LEFT JOIN bodb_Report.dbo.rptDepWinlost AS rpt WITH (NOLOCK) ON rpt.CustID = c.custid AND rpt.winlostdate = @apiDate
		;

		;WITH CTE_Data AS
		(
			SELECT p.custid
				, SUM(ISNULL(CASE
								WHEN p.SportType IN (-2, -3, -5, -6, -7) THEN 0
								ELSE p.Turnover
							END, 0)) AS Turnover
				, SUM(ISNULL(p.OutStanding, 0)) AS Outstanding
				, SUM(ISNULL(p.winlost, 0)) AS Winloss
				, SUM(ISNULL(p.drawTO, 0)) AS DrawGame
				, SUM(ISNULL(p.playercomm, 0)) AS PlayerComm
			FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH (NOLOCK)
				INNER JOIN #rptPlayerBalance rpt ON rpt.CustId = p.custid
				INNER JOIN #SportType s ON s.SportType = p.SportType
			WHERE p.Winlostdate = @apiDate
			GROUP BY p.CustID
		)
		UPDATE #rptPlayerBalance
		SET Turnover = ISNULL(s.Turnover, 0)
			, Outstanding = ISNULL(s.Outstanding, 0)
			, WinLoss = ISNULL(s.Winloss, 0)
			, DrawGame = ISNULL(s.DrawGame, 0)
			, PlayerComm = ISNULL(s.PlayerComm, 0)
			, NetTurnover = ISNULL(s.Turnover, 0) - ISNULL(s.DrawGame, 0)
			, WinLossTotal = ISNULL(s.Winloss, 0) + ISNULL(s.PlayerComm, 0)
		FROM CTE_Data s
		WHERE #rptPlayerBalance.CustId = s.custid

	END

	RS_OUTPUT:
	--TODO: @TotalRows
	SELECT TOP(1) @TotalRows = TotalRows 
	FROM #rptPlayerBalance

	--TODO: result
	SELECT 
		Nickname
		, Username
		, ExchangeId
		, OpeningBalance
		, Deposit
		, Withdrawal
		, Promotion
		, Turnover
		, DrawGame
		, NetTurnover
		, Outstanding
		, WinLoss
		, WinLossTotal
		, ClosingBalance

	FROM #rptPlayerBalance
	ORDER BY rIdx
	;
	
	--SELECT @TotalRows [@TotalRows];
END
GO