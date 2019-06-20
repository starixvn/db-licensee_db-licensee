/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_CasinoTurnover]
	@FromDate		DATE,
	@ToDate			DATE,
	@BaseCurrency	VARCHAR(3),
	@UserName		VARCHAR(50)='',
	@StatusList		VARCHAR(50),
	@ProductCodes	VARCHAR(50),
	@MoveBetsDay	DATE,
	@AgentList		VARCHAR(MAX),
	@PageSize		INT = 50,
	@PageIndex		INT = 1,
	@TotalRows		INT = 0 OUTPUT
AS 
/*  Created: 20181127@Amanda
    Description: LAP - Casino Turnover Report
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20181127@Amanda: Created SP [RedmineID: #95178]
		- 20190620@Amanda: Centralize function to get exchange rate [Redmine: #112531]
		
    Param's Explanation:  
	  + @ProductCodes: "AB,CS,VB"
	  + @Status: "111,112,113"
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>
					  </ROOT>

*/
BEGIN  
    SET NOCOUNT ON

	DECLARE @tempAg	TABLE(custID INT, currency INT)
	DECLARE @Product TABLE (ProductCode VARCHAR(10), ProductId INT)
	DECLARE @Exchange TABLE (ExFromDate SMALLDATETIME, ExToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT)
	DECLARE @Status TABLE (Id INT)
	DECLARE @bettype TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))

	DECLARE @tmpToDate DATE, @tmpFromDate DATE, @custId INT
	DECLARE @IsTest BIT = 0
	

	CREATE TABLE #data(
		[Date]			DATE,
		CustId			INT,
		UserName		VARCHAR(50),
		NickName		VARCHAR(50),
		ProductCode		VARCHAR(5),
		BetCount		INT,
		Turnover		MONEY,
		ValidBetAmount	MONEY,
		Winlost			MONEY,
		CurrencyId		INT
	)
	
	CREATE TABLE #pagingData(
		RowNum			INT,
		[Date]			DATE,
		CustId			VARCHAR(50)
	)

	-- Parse XML to agent table
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'
		RETURN
	END CATCH;

	-- Split string
    INSERT INTO @Product (ProductCode, ProductId)
	SELECT ISNULL(Val,''), p.Productid 	
	FROM dbo.strSplit(@ProductCodes,',') c
	INNER JOIN bodb_licensee.dbo.Product3rd p WITH (NOLOCK) ON c.val = p.ProductPrefix

	INSERT INTO @Status (Id)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@StatusList,',')

	-- process string
    SET @UserName = LTRIM(RTRIM(ISNULL(@UserName,'')))			
	SET @UserName = REPLACE(@UserName,'''','''''')

    -- Get date from @MoveBetsDay + 1 to @ToDate
    IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)
		IF LEN(ISNULL(@ProductCodes, '')) > 0 
		BEGIN
			-- Insert Bettype
			INSERT INTO @bettype ( bettype, ProductCode )
			SELECT DISTINCT BetType, ProductPrefix
			FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductCodes, @IsTest)

			IF EXISTS (SELECT 1 FROM @Product WHERE ProductCode = 'CS')
				DELETE @bettype
				WHERE bettype = 72 AND ProductCode = 'CS'
		END	

		SET @tmpToDate = @ToDate	
		IF @FromDate <= @MoveBetsDay 
			SET @tmpFromDate = DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @tmpFromDate = @FromDate

		IF EXISTS (SELECT 1 FROM @Product WHERE ProductCode = 'AB')
		BEGIN
			INSERT INTO #Data(
				[Date],
				CustId,
				UserName,
				NickName,
				ProductCode,
				BetCount,
				Turnover,
				ValidBetAmount,
				Winlost,
				CurrencyId
			)
			SELECT	b.WinlostDate,
					b.custId,
					c.username,
					c.username2,
					'AB',
					COUNT(b.transid),
					SUM(b.stake),
					SUM(b.NetStake),
					SUM(b.Winlost - b.actual_stake),
					b.currency
			FROM dbo.bettransLC b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.Recommend = a.custID
			INNER JOIN @bettype t ON b.gameID = t.bettype
			INNER JOIN @status s ON b.StatusId = s.Id
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
			WHERE	b.WinlostDate >= @tmpFromDate 
					AND b.WinlostDate <= @tmpToDate
					AND t.ProductCode = 'AB'
					AND (@UserName = '' OR c.username2 LIKE '%$%' + @Username + '%' OR c.username LIKE '%' + @Username + '%')
			GROUP BY b.WinlostDate, b.custId, c.username, c.username2, b.currency
		END

		IF EXISTS (SELECT 1 FROM @Product WHERE ProductCode = 'CS' OR ProductCode = 'VB')
		BEGIN
			INSERT INTO #Data(
				[Date],
				CustId,
				UserName,
				NickName,
				ProductCode,
				BetCount,
				Turnover,
				ValidBetAmount,
				Winlost,
				CurrencyId
			)
			SELECT	b.WinlostDate,
					b.custId,
					c.username,
					c.username2,
					t.ProductCode,
					COUNT(b.transid),
					SUM(b.stake),
					SUM(b.stake),
					SUM(b.Winlost - b.actual_stake),
					b.currency
			FROM dbo.bettransRNG b WITH (NOLOCK)
			INNER JOIN @tempAg a ON b.Recommend = a.custID
			INNER JOIN @bettype t ON b.gameID = t.bettype
			INNER JOIN @status s ON b.StatusId = s.Id
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
			WHERE	b.WinlostDate >= @tmpFromDate
					AND b.WinlostDate <= @tmpToDate
					AND (t.ProductCode = 'CS' OR t.ProductCode = 'VB')
					AND (@UserName = '' OR c.username2 LIKE '%$%' + @Username + '%' OR c.username LIKE '%' + @Username + '%')
			GROUP BY b.WinlostDate, b.custId, c.username, c.username2, b.currency, t.ProductCode
		END
	END

	-- Get date from @FromDate to @MoveBetsDay
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @tmpFromDate = @FromDate	
		IF @ToDate >= @MoveBetsDay 
			SET @tmpToDate = @MoveBetsDay
		ELSE
			SET @tmpToDate = @ToDate

		INSERT INTO #data(
			[Date],
			CustId,
			UserName,
			NickName,
			ProductCode,
			BetCount,
			Turnover,
			ValidBetAmount,
			Winlost,
			CurrencyId
		)
		SELECT	rpt.WinlostDate,
				rpt.custId,
				c.username,
				c.username2,
				p.ProductCode,
				SUM(rpt.BetCount),
				SUM(rpt.Turnover),
				SUM(rpt.ValidBetAmount),
				SUM(rpt.Winlost),
				rpt.Currency
		FROM bodb_LicenseeReport.dbo.rptCasinoTurnover rpt WITH (NOLOCK)
		INNER JOIN @tempAg a ON rpt.Recommend = a.custID
		INNER JOIN @Product p ON rpt.ProductId = p.ProductId
		INNER JOIN @status s ON rpt.StatusId = s.Id
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON rpt.CustId = c.CustId
		WHERE rpt.WinlostDate >= @tmpFromDate 
				AND rpt.WinlostDate <= @tmpToDate
				AND (@UserName = '' OR c.username2 LIKE '%$%' + @Username + '%' OR c.username LIKE '%' + @Username + '%')
		GROUP BY rpt.WinlostDate, rpt.custId, c.username, c.username2, rpt.Currency, p.ProductCode
	END

	INSERT INTO #pagingData(
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

	-- Get Exchange Rate	
	;WITH Currency_CTE (CurrencyID) AS (
											SELECT DISTINCT currency
											FROM @tempAg
										)
	INSERT INTO @Exchange(ExFromDate, ExToDate, ExchangeID, Rate)
	SELECT	FromDate,
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
		SUBSTRING(d.NickName, CHARINDEX('$', d.NickName) + 1,LEN(d.NickName) - CHARINDEX('$',d.NickName)) AS NickName,
		d.ProductCode,
		d.BetCount,
		d.Turnover,
		d.ValidBetAmount,
		d.Winlost,
		d.Turnover * e.Rate			AS TurnoverBase,
		d.ValidBetAmount * e.Rate	AS ValidBetAmountBase,
		d.Winlost * e.Rate			AS WinlostBase
	FROM #data d
	INNER JOIN #pagingData p ON p.[Date] = d.[Date] AND p.CustId = d.CustId
	INNER JOIN @Exchange e ON d.CurrencyId = e.ExchangeID AND d.[Date] >= e.ExFromDate AND d.[Date] <= e.ExToDate
	WHERE p.RowNum BETWEEN @FromRow AND @ToRow
	ORDER BY p.RowNum

	-- Return Total
	SELECT
		SUM(d.BetCount)					AS BetCount,
		SUM(d.Turnover * e.Rate	)		AS Turnover,
		SUM(d.ValidBetAmount * e.Rate)	AS ValidBetAmount,
		SUM(d.Winlost * e.Rate)			AS Winlost
	FROM #data d
	INNER JOIN @Exchange e ON d.CurrencyId = e.ExchangeID AND d.[Date] >= e.ExFromDate AND d.[Date] <= e.ExToDate

	DROP TABLE #data
	DROP TABLE #pagingData
END
GO