/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_CasinoTurnover]
	@AgentList		VARCHAR(MAX),
	@UserName		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductCodes	VARCHAR(100),
	@StatusList		VARCHAR(50),
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT		= 50,
	@PageIndex		INT		= 1,
	@TotalRows		INT		= 0 OUTPUT
AS

/*
	Created: 20181127@Amanda
	Description: LAP - Casino Turnover Report
	DB: DBEXT.bodb02

	Revisions:
		- 20181127@Amanda: Created SP [RedmineID: #95178]
		- 20190620@Amanda: Centralize function to get exchange rate [Redmine: #112531]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200615@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20201201@Mark: Casino Turnover Report - Support Saba.club, PP and PG Soft products [RedmineID: #146135]
		- 20201224@Hogan: Integrate GDG [RedmineID: #147267]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210416@Hogan: Integrate Habanero RNG Games [RedmineID: #150843]
		- 20210428@Hogan: Integrate WM Live Casino [RedmineID: #140944]
		- 20210519@Louis: Integrate Big Gaming product [RedmineID: #146773]
		- 20210525@Hogan: Integrate Vgaming [RedmineID: #151583]
		- 20210630@Hogan: Integrate Creative Gaming [RedmineID: #152619]
		- 20211105@Hogan: Integrate AdvantPlay RNG & Mini [RedmineID: #158186]
		- 20220322@Kos: Revise net turnover [RedmineID: #169843]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

	Param's Explanation:
		+ @ProductCodes: "AB,CS,VB"
		+ @Status: "111,112,113"
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId);

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	DECLARE @Product TABLE (ProductCode VARCHAR(10), ProductId INT)
	DECLARE @Status TABLE (Id INT)

	DECLARE @TmpToDate SMALLDATETIME,
		@TmpFromDate SMALLDATETIME,
		@CustId INT

	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR(10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType
	FROM dbo.Lrf_f_SelExcludedBetType()

	CREATE TABLE #Data (
		Date			SMALLDATETIME,
		CustId			INT,
		Username		VARCHAR(50),
		NickName		VARCHAR(50),
		ProductCode		VARCHAR(5),
		BetCount		INT,
		Turnover		MONEY,
		ValidBetAmount	MONEY,
		WinLost			MONEY,
		CurrencyId		TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum	INT,
		[Date]	SMALLDATETIME,
		CustId	VARCHAR(50)
	)

	-- Split string
	INSERT INTO @Product (ProductCode, ProductId)
	SELECT ISNULL(Val,''), p.Productid
	FROM dbo.strSplit(@ProductCodes,',') AS c
		INNER JOIN bodb_licensee.dbo.Product3rd AS p WITH (NOLOCK) ON c.val = p.ProductPrefix

	INSERT INTO @Status (Id)
	SELECT ISNULL(Val,'')
	FROM dbo.strSplit(@StatusList,',')

	-- process string
	SET @UserName = LTRIM(RTRIM(ISNULL(@UserName, '')))
	SET @UserName = REPLACE(@UserName, '''', '''''')

	-- bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN
		DECLARE @BetType TABLE (BetType SMALLINT PRIMARY KEY, ProductCode VARCHAR(10), RefTable TINYINT)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO @BetType (BetType, ProductCode, RefTable)
		SELECT DISTINCT BetType, ProductPrefix, RefTable
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductCodes, @IsTest)
		WHERE BetType NOT IN (SELECT BetType FROM @ExcludedBetType e WHERE e.ProductCode = ProductPrefix)
			AND BetType NOT IN (72)

		SET @TmpFromDate = CASE
								WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @FromDate
							END

		-- bettransRNG
		IF EXISTS (SELECT 1 FROM @BetType WHERE RefTable = 1)
		BEGIN
			INSERT INTO #Data (
				Date,
				CustId,
				Username,
				NickName,
				ProductCode,
				BetCount,
				Turnover,
				ValidBetAmount,
				WinLost,
				CurrencyId
			)
			SELECT
				b.winlostdate,
				b.custid,
				c.username,
				c.username2,
				t.ProductCode,
				COUNT(b.transid) AS BetCount,
				SUM(b.stake) AS Turnover,
				SUM(b.BetStake) AS ValidBetAmount,
				SUM(b.winlost - b.actual_stake) AS WinLost,
				b.currency AS CurrencyId
			FROM dbo.bettransRnG AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
				INNER JOIN @BetType AS t ON t.BetType = b.gameID
				INNER JOIN @Status AS s ON s.Id = b.statusID
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.CustId
			WHERE b.WinlostDate BETWEEN @tmpFromDate AND @ToDate
				AND t.RefTable = 1
				AND (t.ProductCode <> 'SBC' OR b.ProductId <> 150)
				AND (t.ProductCode <> 'VGA' OR b.ProductId <> 173)
				AND (@UserName = ''
					OR c.username2 LIKE '%$%' + @Username + '%'
					OR c.username LIKE '%' + @Username + '%')
			GROUP BY b.winlostdate,
				b.custid,
				c.username,
				c.username2,
				b.currency,
				t.ProductCode
		END

		-- bettransLC
		IF EXISTS (SELECT 1 FROM @BetType WHERE RefTable = 2)
		BEGIN
			INSERT INTO #Data (
				Date,
				CustId,
				UserName,
				NickName,
				ProductCode,
				BetCount,
				Turnover,
				ValidBetAmount,
				WinLost,
				CurrencyId
			)
			SELECT
				b.winlostdate,
				b.custid,
				c.username,
				c.username2,
				t.ProductCode,
				COUNT(b.transid) AS BetCount,
				SUM(b.stake) AS Turnover,
				SUM(b.NetStake) AS ValidBetAmount,
				SUM(b.winlost - b.actual_stake) AS WinLost,
				b.currency AS CurrencyId
			FROM dbo.bettransLC AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
				INNER JOIN @BetType AS t ON t.BetType = b.gameID
				INNER JOIN @Status AS s ON s.Id = b.StatusId
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.CustId
			WHERE b.WinlostDate BETWEEN @TmpFromDate AND @ToDate
				AND t.RefTable = 2
				AND (@UserName = ''
					OR c.username2 LIKE '%$%' + @Username + '%'
					OR c.username LIKE '%' + @Username + '%')
			GROUP BY b.winlostdate,
				b.custId,
				c.username,
				c.username2,
				b.currency,
				t.ProductCode
		END
	END

	-- bettrans14 range
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @TmpToDate = CASE
							WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @ToDate
						END

		INSERT INTO #Data (
			Date,
			CustId,
			Username,
			NickName,
			ProductCode,
			BetCount,
			Turnover,
			ValidBetAmount,
			WinLost,
			CurrencyId
		)
		SELECT rpt.WinlostDate,
			rpt.custId,
			c.username,
			c.username2,
			p.ProductCode,
			SUM(rpt.BetCount) AS BetCount,
			SUM(rpt.Turnover) AS Turnover,
			SUM(rpt.ValidBetAmount) AS ValidBetAmount,
			SUM(rpt.Winlost) AS WinLost,
			rpt.Currency AS CurrencyId
		FROM bodb_LicenseeReport.dbo.rptCasinoTurnover AS rpt WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON rpt.Recommend = a.custID
			INNER JOIN @Product AS p ON rpt.ProductId = p.ProductId
			INNER JOIN @Status AS s ON rpt.StatusId = s.Id
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON rpt.CustId = c.CustId
		WHERE rpt.WinlostDate BETWEEN @FromDate AND @TmpToDate
			AND (rpt.TicketType IS NULL OR rpt.TicketType = 0) -- Normal Ticket
			AND (@UserName = ''
				OR c.username2 LIKE '%$%' + @Username + '%'
				OR c.username LIKE '%' + @Username + '%')
		GROUP BY
			rpt.WinlostDate,
			rpt.CustId,
			c.username,
			c.username2,
			rpt.Currency,
			p.ProductCode
	END

	INSERT INTO #PagingData (
		RowNum,
		[Date],
		CustId
	)
	SELECT
		ROW_NUMBER() OVER (ORDER BY [Date] ASC, UserName ASC),
		[Date],
		CustId
	FROM #data
	GROUP BY [Date], CustId, UserName
	
	SET @TotalRows = @@ROWCOUNT

	DECLARE @Exchange TABLE (ExFromDate SMALLDATETIME, ExToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT)

	-- Get Exchange Rate
	;WITH Currency_CTE (CurrencyID) AS (SELECT DISTINCT currency FROM #TempAg)
	INSERT INTO @Exchange(ExFromDate, ExToDate, ExchangeID, Rate)
	SELECT
		FromDate,
		ToDate,
		ExchangeID,
		Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') e
		INNER JOIN Currency_CTE c ON e.ExchangeId = c.CurrencyID

	-- Return Data
	DECLARE @FromRow INT, @ToRow INT
	SET @FromRow = (@PageIndex - 1) * @PageSize + 1
	SET @ToRow = @FromRow + @PageSize - 1

	SELECT
		d.[Date],
		d.UserName,
		SUBSTRING(d.NickName, CHARINDEX('$', d.NickName) + 1, LEN(d.NickName) - CHARINDEX('$', d.NickName)) AS NickName,
		d.ProductCode,
		d.BetCount,
		d.Turnover,
		d.ValidBetAmount,
		d.Winlost,
		d.Turnover * e.Rate			AS TurnoverBase,
		d.ValidBetAmount * e.Rate	AS ValidBetAmountBase,
		d.Winlost * e.Rate			AS WinlostBase
	FROM #Data AS d
		INNER JOIN #PagingData AS p ON p.[Date] = d.[Date] AND p.CustId = d.CustId
		INNER JOIN @Exchange AS e ON d.CurrencyId = e.ExchangeID AND d.[Date] BETWEEN e.ExFromDate AND e.ExToDate
	WHERE p.RowNum BETWEEN @FromRow AND @ToRow
	ORDER BY p.RowNum ASC

	-- Return Total
	SELECT
		SUM(d.BetCount)	AS BetCount,
		SUM(d.Turnover			* e.Rate) AS Turnover,
		SUM(d.ValidBetAmount	* e.Rate) AS ValidBetAmount,
		SUM(d.WinLost			* e.Rate) AS Winlost
	FROM #Data AS d
		INNER JOIN @Exchange AS e ON d.CurrencyId = e.ExchangeID AND d.[Date] BETWEEN e.ExFromDate AND e.ExToDate

	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #TempAg
END
GO
