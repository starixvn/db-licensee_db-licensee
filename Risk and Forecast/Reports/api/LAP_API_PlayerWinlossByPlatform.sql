/*<info serverAlias="DBRPT-bodb_Report" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_API_PlayerWinlossByPlatform]
	@AgentList			VARCHAR(MAX),
	@Winlostdate		SMALLDATETIME,
	@PlatformTypeIds	VARCHAR(MAX)	= '0',
	@BaseCurrency		VARCHAR(10)		= 'USD',
	@PageIndex			INT = 1,
	@PageSize			INT = 500,
	@TotalRows			INT = 0 OUTPUT
AS
/*
	Created: 20240812@Bobby
	Task: 209041 - LAP API - Get Player Winlos
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

	DECLARE @apiDate SMALLDATETIME, @PlatformCheck VARCHAR(MAX)
	SELECT @apiDate = CAST(@Winlostdate AS DATE),
		@TotalRows	= 0,
		@PlatformCheck = IIF(ISNULL(@PlatformTypeIds, '0') = '0', 'ALL', @PlatformTypeIds);

	DROP TABLE IF EXISTS #rptPlayerWinloss;
	CREATE TABLE #rptPlayerWinloss (
		rIdx INT IDENTITY(1, 1) PRIMARY KEY, 
		PlatformType INT, 
		Nickname VARCHAR(50), 
		BetCount INT, 
		Turnover MONEY, 
		Winloss MONEY, 
		TotalRows INT
	);

	-- Get exchange rate
	DECLARE @Exchange TABLE (ExchangeId	INT, Rate FLOAT);
	INSERT INTO @Exchange(ExchangeId, Rate)
	SELECT ExchangeID, Rate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@apiDate, @apiDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #TempAg AS c WHERE c.Currency = e.ExchangeID)

	--TODO: Get players winloss
	IF @PageIndex > 0
	BEGIN
		;WITH CTE_Bettype AS (
			SELECT DISTINCT BetType, RefTable
			FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', 0)
			WHERE ProductID NOT IN (11, 31, 37) -- NOT Support Saba Promotion, AG-Casino & Exchange
		),
		CTE_Platform AS (
			SELECT DISTINCT f.PlatformType, f.betfrom
			FROM bodb02.[dbo].[Lrf_f_BetFromType_Sel](@PlatformCheck) AS f
		)
		INSERT INTO #rptPlayerWinloss (PlatformType, Nickname, BetCount, Turnover, Winloss, TotalRows)
		SELECT rpt.PlatformType
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50) AS Nickname
			,SUM(rpt.BetCount) AS BetCount
			,SUM(rpt.Turnover) AS Turnover
			,SUM(rpt.Winloss) AS Winloss
			,COUNT(1) OVER() AS TotalRows
		FROM (
			SELECT pl.PlatformType
				,rpt.custid
				,COUNT(1) BetCount
				,SUM(ABS(rpt.stake) * ex.rate) AS Turnover
				,SUM((rpt.winlost - rpt.actual_stake) * ex.rate) AS Winloss
			FROM bodb02.dbo.bettrans AS rpt WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON a.custid = rpt.recommend
				INNER JOIN @Exchange ex ON ex.ExchangeId = a.Currency
				INNER JOIN CTE_Bettype bt ON bt.bettype = rpt.bettype AND bt.RefTable NOT IN (1,2)
				INNER JOIN CTE_Platform AS pl ON pl.betfrom = rpt.betfrom 
			WHERE rpt.winlostdate = @apiDate
				AND rpt.statusid IN (111, 112, 113)
			GROUP BY pl.PlatformType, rpt.custid

			UNION ALL
			SELECT pl.PlatformType
				,rpt.custid
				,COUNT(1) BetCount
				,SUM(ABS(rpt.stake) * ex.rate) AS Turnover
				,SUM((rpt.winlost - rpt.actual_stake) * ex.rate) AS Winloss
			FROM bodb02.dbo.bettransRNG AS rpt WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON a.custid = rpt.recommend
				INNER JOIN @Exchange ex ON ex.ExchangeId = a.Currency
				INNER JOIN CTE_Bettype bt ON bt.bettype = rpt.GameID AND bt.RefTable IN (1)
				INNER JOIN CTE_Platform AS pl ON pl.betfrom = rpt.betfrom
			WHERE rpt.winlostdate = @apiDate
				AND rpt.statusid IN (111, 112, 113)
			GROUP BY pl.PlatformType, rpt.custid

			UNION ALL
			SELECT pl.PlatformType
				,rpt.custid
				,COUNT(1) BetCount
				,SUM(ABS(rpt.stake) * ex.rate) AS Turnover
				,SUM((rpt.winlost - rpt.actual_stake) * ex.rate) AS Winloss
			FROM bodb02.dbo.bettransLC AS rpt WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON a.custid = rpt.recommend
				INNER JOIN @Exchange ex ON ex.ExchangeId = a.Currency
				INNER JOIN CTE_Bettype bt ON bt.bettype = rpt.GameID AND bt.RefTable IN (2)
				INNER JOIN CTE_Platform AS pl ON pl.betfrom = rpt.betfrom
			WHERE rpt.winlostdate = @apiDate
				AND rpt.statusid IN (111, 112, 113)
			GROUP BY pl.PlatformType, rpt.custid
		) AS rpt
		INNER JOIN bodb02.dbo.Customer c ON c.custid = rpt.custid
		GROUP BY rpt.PlatformType
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50)
		ORDER BY rpt.PlatformType
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50)
		OFFSET (@PageIndex-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
		; 
	END

	--TODO: @TotalRows
	SELECT TOP(1) @TotalRows = TotalRows 
	FROM #rptPlayerWinloss

	--TODO: result
	SELECT PlatformType, Nickname, BetCount, Turnover, Winloss
	FROM #rptPlayerWinloss
	ORDER BY rIdx
	;

	--SELECT @TotalRows [@TotalRows];
END
GO