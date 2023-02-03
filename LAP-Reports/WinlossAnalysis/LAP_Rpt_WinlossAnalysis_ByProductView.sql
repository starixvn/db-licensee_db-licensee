USE bodb_LicenseeReport;
GO

CREATE OR ALTER PROCEDURE LAP_Rpt_WinlossAnalysis_ByProduct
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
		@BreakBy		= IIF(@BreakBy NOT IN (1,3), 1, @BreakBy),
		@PageIndex		= IIF(@PageIndex <= 0, 1, @PageIndex),
		@PageSize		= IIF(@PageSize <= 0, 50, @PageSize),
		@pageOffset		= (@PageIndex - 1) * @PageSize;

	--select @BreakBy AS [@BreakBy];
	-- TODO: paging
	WITH paging AS (
		SELECT rIdx, GroupBy, rTotal
		FROM (
			SELECT t.GroupBy,
				COUNT(1) OVER() AS rTotal,
				ROW_NUMBER() OVER(ORDER BY t.GroupBy) AS rIdx
			FROM (
				SELECT DISTINCT rpt.ProductID AS GroupBy
				FROM @rptData rpt
			) AS t
		) AS p
		ORDER BY p.rIdx ASC
		OFFSET @pageOffset ROWS FETCH NEXT @PageSize ROWS ONLY
	),
	result AS (
		SELECT p.rIdx, p.GroupBy,
			CASE 
				WHEN @BreakBy = 1 THEN rpt.Currency
				WHEN @BreakBy = 3 THEN rpt.recommend
				ELSE rpt.Currency
			END AS BreakBy,
			SUM(rpt.turnover) AS turnover,
			p.rTotal

		FROM paging p
		INNER JOIN @rptData rpt ON p.GroupBy = rpt.ProductID 
		GROUP BY p.rIdx, p.GroupBy, p.rTotal,
			CASE 
				WHEN @BreakBy = 1 THEN rpt.Currency
				WHEN @BreakBy = 3 THEN rpt.recommend
				ELSE rpt.Currency
			END
	)
	SELECT rs.rIdx, rs.GroupBy, rs.BreakBy, rs.turnover, rs.rTotal
	INTO #result
	FROM result rs
	
	-- total row
	SELECT TOP(1) @TotalRow = rs.rTotal
	FROM #result rs


	-- output
	DECLARE @outputSQL NVARCHAR(MAX);
	SET @outputSQL = 
	N'SELECT rs.rIdx, rs.GroupBy,' +
		CASE 
			WHEN @BreakBy = 1 THEN ' IIF(LEN(ex.Code)=0, ''N/A'', ex.Code) AS Currency' 
			WHEN @BreakBy = 3 THEN ' ci.username AS Agency' 
		END + '\
		, turnover
	FROM #result rs' +
		CASE 
			WHEN @BreakBy = 1 THEN ' INNER JOIN bodb02.dbo.Exchange ex with(nolock) ON ex.exchangeid = rs.BreakBy'
			WHEN @BreakBy = 3 THEN ' INNER JOIN bodb02.dbo.custinfo ci with(nolock) ON ci.custid = rs.BreakBy'
		END + '\
	ORDER BY rs.rIdx, ' +
		CASE 
			WHEN @BreakBy = 1 THEN ' ex.exchangeid'
			WHEN @BreakBy = 3 THEN ' ci.custid'
		END

	EXEC sp_executesql @outputSQL;

	SELECT rs.rIdx, rs.GroupBy,	SUM(Turnover) AS Turnover
	FROM #result rs
	GROUP BY rs.rIdx, rs.GroupBy

	SELECT @TotalRow AS TotalRow,
		SUM(Turnover) AS Turnover
	FROM @rptData

END