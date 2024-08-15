/*<info serverAlias="DBRPT-bodb_Report" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_API_PlayerWinlossByProduct]
	@AgentList		VARCHAR(MAX),
	@Winlostdate	SMALLDATETIME,
	@ProductCodes	VARCHAR(MAX)	= '0',
	@BaseCurrency	VARCHAR(10)		= 'USD',
	@PageIndex		INT = 1,
	@PageSize		INT = 500,
	@TotalRows		INT = 0 OUTPUT
AS
/*
	Created: 20240812@Bobby
	Task: 209041 - LAP API - Get Player Winloss
	DB: DBRPT/bodb_Report

	Revisions:
		- 20240812@Bobby: Init [RedmineID: #209041]
*/
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #TempAg;
	CREATE TABLE #TempAg(CustId INT PRIMARY KEY, Currency INT);

	DECLARE @DocHandler INT
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg(CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	DECLARE @apiDate SMALLDATETIME, @ProductCheck VARCHAR(MAX);
	SELECT @apiDate		= CAST(@Winlostdate AS DATE),
		@TotalRows		= 0,
		@ProductCheck	= IIF(ISNULL(@ProductCodes, '0') = '0', 'ALL', @ProductCodes);

	-- Get exchange rate
	DECLARE @Exchange TABLE (ExchangeId	INT, Rate FLOAT);
	INSERT INTO @Exchange(ExchangeId, Rate)
	SELECT ExchangeID, Rate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@apiDate, @apiDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #TempAg AS c WHERE c.Currency = e.ExchangeID)

	DROP TABLE IF EXISTS #rptPlayerWinloss;
	CREATE TABLE #rptPlayerWinloss (
		rIdx INT IDENTITY(1, 1) PRIMARY KEY, 
		ProductID INT, 
		ProductCode VARCHAR(15), 
		Nickname VARCHAR(50), 
		BetCount INT, 
		Turnover MONEY, 
		Winloss MONEY, 
		TotalRows INT
	);

	--MERGE Sports Lotery vs Bitcons INTO Sportbook
	SELECT @ProductCheck = IIF(CONCAT(',',@ProductCheck,',') LIKE '%,SB,%', CONCAT(@ProductCheck, ',SLT,BTC'), @ProductCheck)
	;

	--TODO: Get player winloss by rptDepWinlost_Trans
	IF @PageIndex > 0
	BEGIN
		;WITH CTE_rptDepTrans AS (
			SELECT rpt.custid, IIF(ck.ProductID IN (63, 69), 1, ck.ProductID) AS ProductID, IIF(ck.ProductID IN (63, 69), 'SB', ck.ProductCode) AS ProductCode
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50) as Nickname
				, sum(rpt.BetCount) BetCount, sum(rpt.Turnover*ex.Rate) Turnover, sum(rpt.winloss*ex.Rate) Winloss
				, count(1) over() as TotalRows
			FROM dbo.rptDepWinlost_Trans rpt WITH(NOLOCK)
				INNER JOIN (
					SELECT DISTINCT IIF(bm.productid = 1, 0, bm.sporttype) AS sporttype, bm.productid, p.ProductPrefix as ProductCode
					FROM bodb02.dbo.SportBettypeMatrix bm WITH(NOLOCK)
					INNER JOIN bodb02.dbo.products p WITH(NOLOCK) ON p.ProductID = bm.ProductID
					WHERE p.ProductID NOT IN (11, 31, 37) -- NOT Support Saba Promotion, AG-Casino & Exchange
						AND (@ProductCheck = 'ALL' or CONCAT(',',@ProductCheck,',') LIKE '%,' + p.ProductPrefix + ',%')
				) AS pt on pt.SportType = rpt.SportType
				INNER JOIN bodb02.dbo.Customer c ON c.custid = rpt.custid
				INNER JOIN #TempAg a on a.CustId = c.recommend AND a.Currency <> 20
				INNER JOIN @Exchange ex ON ex.ExchangeId = a.Currency
				LEFT JOIN bodb02.dbo.Lrf_f_GroupProduct() lf ON lf.Productid = pt.Productid
				OUTER APPLY (
					SELECT ISNULL(lf.GroupProductId, pt.ProductID) AS ProductID
						, ISNULL(lf.GroupProductPrefix, pt.ProductCode) AS ProductCode
				) AS ck
			WHERE rpt.Winlostdate = @apiDate
				AND rpt.SportType != -1
				AND rpt.PartnerID = -1
				AND rpt.BetCount > 0
			GROUP BY rpt.custid, IIF(ck.ProductID IN (63, 69), 1, ck.ProductID), IIF(ck.ProductID IN (63, 69), 'SB', ck.ProductCode)
				, SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50), rpt.CustID
			ORDER BY IIF(ck.ProductID IN (63, 69), 1, ck.ProductID),SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50)
			OFFSET (@PageIndex-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
		)
		INSERT INTO #rptPlayerWinloss (ProductID, ProductCode, Nickname, BetCount, Turnover, Winloss, TotalRows)
		SELECT ProductID, ProductCode, Nickname, BetCount, Turnover, Winloss, TotalRows
		FROM CTE_rptDepTrans
		ORDER BY ProductID, Nickname
		;
	END

	--TODO: @TotalRows
	SELECT TOP(1) @TotalRows = TotalRows 
	FROM #rptPlayerWinloss

	--TODO: result
	SELECT ProductCode, Nickname, BetCount, Turnover, Winloss
	FROM #rptPlayerWinloss
	ORDER BY rIdx
	;

	--SELECT @TotalRows [@TotalRows];
END
GO