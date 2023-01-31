USE bodb_LicenseeReport;
GO

CREATE OR ALTER PROCEDURE LAP_Rpt_WinlossAnalysis_ByProduct_FullSel
	@FromDate		SMALLDATETIME = '2023-01-01',
	@ToDate			SMALLDATETIME = NULL,
	@MovebetDay		SMALLDATETIME = NULL,
	@BalanceUpDay	SMALLDATETIME = NULL,

	----------filtering
	@AgentList		XML = NULL,
	@ProductIds		NVARCHAR(MAX) = NULL,
	@SportIds		NVARCHAR(MAX) = NULL,
	@BettypeIds		NVARCHAR(MAX) = NULL,

	-- grouping
	@BreakdownMode		TINYINT =  1,

	----------paging
	@PageIndex		INT = 1,
	@PageSize		INT = 5,
	@TotalRow		INT = 0 OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @pageOffset INT,
		@today			SMALLDATETIME,
		@yesterday		SMALLDATETIME,
		@startTime		DATETIME,
		@rptFromDate	SMALLDATETIME,
		@rptToDate		SMALLDATETIME;

	-- INPUT: validation
	SELECT @TotalRow	= 0,
		@PageIndex		= IIF(@PageIndex <= 0, 1, @PageIndex),
		@PageSize		= IIF(@PageSize <= 0, 50, @PageSize),
		@pageOffset		= (@PageIndex - 1) * @PageSize,
		@startTime		= CURRENT_TIMESTAMP,
		@today			= CAST(@startTime AS DATE),
		@yesterday		= DATEADD(DAY, -1, @today),
		@FromDate		= IIF(@FromDate IS NULL, @yesterday, @FromDate),
		@ToDate			= IIF(@ToDate IS NULL, @today, @ToDate)

	DECLARE @AgencySel	TABLE(recommend INT);
	DECLARE @ProductSel TABLE (ProductId INT)
	DECLARE	@rptData	dbo.LAP_WinlossAnalysis;

	-- sample:
	BEGIN
		SET @AgentList = '<root>
		  <row AgencyId="41561179" />
		  <row AgencyId="6006447" />
		  <row AgencyId="44616944" />
		  <row AgencyId="40586156" />
		  <row AgencyId="14180031" />
		  <row AgencyId="1574100" />
		  <row AgencyId="2308751" />
		  <row AgencyId="14551801" />
		  <row AgencyId="10063439" />
		  <row AgencyId="37144035" />
		  <row AgencyId="17126508" />
		  <row AgencyId="3167654" />
		  <row AgencyId="3233980" />
		  <row AgencyId="4345531" />
		  <row AgencyId="836230" />
		  <row AgencyId="791049" />
		  <row AgencyId="4359308" />
		  <row AgencyId="15867159" />
		  <row AgencyId="38451676" />
		  <row AgencyId="2308854" />
		  <row AgencyId="1015423" />
		  <row AgencyId="37144045" />
		</root>'

		INSERT INTO @AgencySel(recommend)
		SELECT t.c.value('@AgencyId', 'int') AS recommend
		FROM @AgentList.nodes('/root/row') AS t(c)

	END -- sample

	-- TODO: filter raw data
	IF @ToDate >= @today --> get today data in bettrans
	BEGIN
		SELECT @rptFromDate = @FromDate--@today
			, @rptToDate	= @today;

		INSERT INTO @rptData (ProductId, recommend, currency, turnover)
		SELECT b.ProductId, b.recommend,  b.currency,
			SUM(b.Turnover) AS Turnover
		FROM [dbo].[f_LicenseeWinlossActiveSel] (@AgentList, @rptFromDate, @rptToDate, @ProductIds) AS b
		--WHERE
		--	b.statusID IN (112, 113)

		GROUP BY b.ProductId, b.recommend, b.currency
			
	END

	IF @FromDate < @today -- get sum data from yesterday
	BEGIN
		SELECT @rptFromDate = @FromDate
			, @rptToDate	= IIF(@ToDate >= @today, @yesterday, @ToDate);

		INSERT INTO @rptData (ProductId, recommend, currency, turnover)
		SELECT b.ProductId, b.recommend,  b.currency,
			SUM(b.Turnover) AS Turnover
		 FROM dbo.rptLicenseeWinloss b WITH(NOLOCK)
			INNER JOIN @AgencySel a ON a.recommend = b.recommend
			LEFT JOIN @ProductSel p ON p.ProductId = b.ProductId
		WHERE
			b.WinlostDate BETWEEN @rptFromDate AND @rptToDate
		--	b.statusID IN (112, 113)

		GROUP BY b.ProductId, b.recommend, b.currency
	END

	-- TODO: paging
	;WITH paging AS (
		SELECT rIdx, GroupBy, ProductName, rTotal
		FROM (
			SELECT t.GroupBy, t.ProductName,
				COUNT(1) OVER() AS rTotal,
				ROW_NUMBER() OVER(ORDER BY t.GroupBy) AS rIdx
			FROM (
				SELECT DISTINCT p.ProductID AS GroupBy, p.ProductName
				FROM @rptData rpt
				INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = rpt.productid
			) AS t
		) AS p
		ORDER BY p.rIdx ASC
		OFFSET @pageOffset ROWS FETCH NEXT @PageSize ROWS ONLY
	),
	result AS (
		SELECT p.rIdx, p.ProductName AS GroupBy,
			CASE 
				WHEN @BreakdownMode = 1 THEN rpt.Currency
				WHEN @BreakdownMode = 3 THEN rpt.recommend
				ELSE rpt.Currency
			END AS BreakBy,
			SUM(rpt.turnover) AS turnover,
			p.rTotal

		FROM paging p
		INNER JOIN @rptData rpt ON p.GroupBy = rpt.ProductID 
		GROUP BY p.rIdx, p.ProductName, p.rTotal,
			CASE 
				WHEN @BreakdownMode = 1 THEN rpt.Currency
				WHEN @BreakdownMode = 3 THEN rpt.recommend
				ELSE rpt.Currency
			END
	)
	SELECT rs.rIdx, rs.GroupBy, rs.BreakBy, rs.turnover, rs.rTotal
	INTO #result
	FROM result rs
	
	-- total row
	SELECT @TotalRow = rs.rTotal
	FROM #result rs


	-- output
	DECLARE @outputSQL NVARCHAR(MAX);
	SET @outputSQL = 
	N'SELECT rs.rIdx, rs.GroupBy,' +
		CASE 
			WHEN @BreakdownMode = 1 THEN ' ex.Code AS Currency' 
			WHEN @BreakdownMode = 3 THEN ' ci.username AS Agency' 
		END + '\
		, turnover
	FROM #result rs' +
		CASE 
			WHEN @BreakdownMode = 1 THEN ' INNER JOIN bodb02.dbo.Exchange ex with(nolock) ON ex.exchangeid = rs.BreakBy'
			WHEN @BreakdownMode = 3 THEN ' INNER JOIN bodb02.dbo.custinfo ci with(nolock) ON ci.custid = rs.BreakBy'
		END + '\
	ORDER BY rs.rIdx, ' +
		CASE 
			WHEN @BreakdownMode = 1 THEN ' ex.exchangeid'
			WHEN @BreakdownMode = 3 THEN ' ci.custid'
		END

	EXEC (@outputSQL);

	SELECT @TotalRow AS TotalRow	
		, DATEDIFF(MILLISECOND, @startTime, CURRENT_TIMESTAMP) AS Duration_Ms

END