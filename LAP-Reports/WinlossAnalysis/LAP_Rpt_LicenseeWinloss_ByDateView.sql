USE bodb_LicenseeReport;
GO

CREATE OR ALTER PROCEDURE LAP_Rpt_WinlossAnalysis_ByDate
	@rptData		LAP_WinlossAnalysis READONLY,
	@BreakBy		TINYINT = 1,
	@PageIndex		INT = 1,
	@PageSize		INT = 50,
	@TotalRow		INT = 0 OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @pageOffset INT;
	-- INPUT: validation
	SELECT @TotalRow	= 0,
		@BreakBy		= IIF(@BreakBy NOT IN (1,2,3), 1, @BreakBy),
		@PageIndex		= IIF(@PageIndex <= 0, 1, @PageIndex),
		@PageSize		= IIF(@PageSize <= 0, 50, @PageSize),
		@pageOffset		= (@PageIndex - 1) * @PageSize;


	-- TODO: paging
	WITH paging AS (
		SELECT rIdx, GroupBy, rTotal
		FROM (
			SELECT t.GroupBy,
				COUNT(1) OVER() AS rTotal,
				ROW_NUMBER() OVER(ORDER BY t.GroupBy) AS rIdx
			FROM (
				SELECT 
					rpt.Winlostdate AS GroupBy
				FROM @rptData rpt
				GROUP BY
					rpt.Winlostdate
			) AS t
		) AS p
		ORDER BY p.rIdx ASC
		OFFSET @pageOffset ROWS FETCH NEXT @PageSize ROWS ONLY
	),
	result AS (
		SELECT p.rIdx, p.GroupBy,
			CASE 
				WHEN @BreakBy = 1 THEN rpt.Currency
				WHEN @BreakBy = 2 THEN rpt.ProductId
				WHEN @BreakBy = 3 THEN rpt.recommend
				ELSE rpt.Currency
			END AS BreakBy,
			SUM(rpt.turnover) AS turnover,
			p.rTotal

		FROM paging p
		INNER JOIN @rptData rpt ON 
			p.GroupBy = rpt.winlostdate
		GROUP BY p.rIdx, p.GroupBy, p.rTotal,
			CASE 
				WHEN @BreakBy = 1 THEN rpt.Currency
				WHEN @BreakBy = 2 THEN rpt.ProductId
				WHEN @BreakBy = 3 THEN rpt.recommend
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
			WHEN @BreakBy = 1 THEN ' ex.Code AS Currency' 
			WHEN @BreakBy = 2 THEN ' p.ProductName AS Product'
			WHEN @BreakBy = 3 THEN ' ci.username AS Agency' 
		END + '\
		, turnover
	FROM #result rs' +
		CASE 
			WHEN @BreakBy = 1 THEN ' INNER JOIN bodb02.dbo.Exchange ex WITH(NOLOCK) ON ex.exchangeid = rs.BreakBy'
			WHEN @BreakBy = 2 THEN ' INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.productid = rs.BreakBy'
			WHEN @BreakBy = 3 THEN ' INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON ci.custid = rs.BreakBy'
		END + '\
	ORDER BY rs.rIdx, rs.BreakBy';

	EXEC (@outputSQL);

END

