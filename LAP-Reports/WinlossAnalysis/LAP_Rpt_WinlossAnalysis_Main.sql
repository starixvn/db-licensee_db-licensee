USE bodb_LicenseeReport;
GO

CREATE OR ALTER PROCEDURE LAP_Rpt_WinlossAnalysis_Main
	@FromDate		SMALLDATETIME = '2023-01-01',
	@ToDate			SMALLDATETIME = NULL,
	@MovebetDay		SMALLDATETIME = NULL,
	@BalanceUpDay	SMALLDATETIME = NULL,

	----------filtering
	@AgentList		XML = NULL,
	@ProductIds		VARCHAR(MAX) = NULL,
	@SportIds		VARCHAR(MAX) = NULL,
	@BettypeIds		VARCHAR(MAX) = NULL,
	@StatusIds		VARCHAR(1000) = '112,113',

	----------grouping
	@GroupMode		TINYINT = 3,
	@BreakdownMode	TINYINT = 1,

	----------paging
	@PageIndex		INT = 1,
	@PageSize		INT = 5,
	@TotalRow		INT = 0 OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @today		SMALLDATETIME,
		@yesterday		SMALLDATETIME,
		@startTime		DATETIME,
		@rptFromDate	SMALLDATETIME,
		@rptToDate		SMALLDATETIME;

	-- INPUT: validation
	SELECT 
		@startTime	= CURRENT_TIMESTAMP,
		@today		= CAST(@startTime AS DATE),
		@yesterday	= DATEADD(DAY, -1, @today),
		@FromDate	= IIF(@FromDate IS NULL, @yesterday, @FromDate),
		@ToDate		= IIF(@ToDate IS NULL, @today, @ToDate)

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


		SELECT @ProductIds='37,1,25,3,23,28,63,8,50,40,38,5,42,66,69,70,21,47,39,45,11,46,52,51,57,65,22,6,34,32,55,56,60,61,62,67,68,72,73'
	END -- sample

	--select @FromDate, @ToDate

	-- TODO: filter raw data
	IF @ToDate >= @today --> get today data in bettrans
	BEGIN
		SELECT @rptFromDate = @FromDate--@today
			, @rptToDate	= @today;

		INSERT INTO @rptData (ProductId, recommend, currency, winlostdate, turnover)
		SELECT b.ProductId, b.recommend,  b.currency,
			CASE 
				WHEN @GroupMode IN (2) THEN DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate) 
				ELSE b.winlostdate 
			END AS winlostdate,
			SUM(b.Turnover) AS Turnover
		FROM [dbo].[f_LicenseeWinlossActiveSel] (
			@AgentList, 
			@rptFromDate, 
			@rptToDate, 
			@ProductIds, 
			@SportIds, 
			@BettypeIds, 
			@StatusIds
		) AS b

		GROUP BY b.ProductId, b.recommend, b.currency,
			CASE 
				WHEN @GroupMode IN (2) THEN DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate) 
				ELSE b.winlostdate 
			END
	END

	IF @FromDate < @today -- get sum data from yesterday
	BEGIN
		SELECT @rptFromDate = @FromDate
			, @rptToDate	= IIF(@ToDate >= @today, @yesterday, @ToDate);

		INSERT INTO @rptData (ProductId, recommend, currency, winlostdate, turnover)
		SELECT b.ProductId, b.recommend,  b.currency,
			CASE 
				WHEN @GroupMode IN (2) THEN DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate) 
				ELSE b.winlostdate 
			END AS winlostdate,
			SUM(b.Turnover) AS Turnover
		 FROM dbo.rptLicenseeWinloss b WITH(NOLOCK)
		--FROM [dbo].[f_LicenseeWinlossActive] (@rptFromDate, @rptToDate) AS b
			INNER JOIN @AgencySel a ON a.recommend = b.recommend
			LEFT JOIN @ProductSel p ON p.ProductId = b.ProductId
		--WHERE
		--	b.statusID IN (112, 113)

		GROUP BY b.ProductId, b.recommend, b.currency,
			CASE 
				WHEN @GroupMode IN (2) THEN DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate) 
				ELSE b.winlostdate 
			END
	END

	--select distinct recommend AS '@AgencyId'
	--from @rptData
	--for xml path, root('root');

	-- TODO: grouping & paging
	SET @TotalRow = 0;
	--select @BreakdownMode AS [@BreakdownMode];
	IF @GroupMode IN (1,2) -- date/month
	BEGIN
		EXEC dbo.LAP_Rpt_WinlossAnalysis_ByDate 
			@rptData	= @rptData,
			@BreakBy	= @BreakdownMode,
			@PageIndex	= @PageIndex,
			@PageSize	= @PageSize,
			@TotalRow	= @TotalRow OUTPUT
	END
	ELSE IF @GroupMode IN (3) -- group by product
	BEGIN
		EXEC dbo.LAP_Rpt_WinlossAnalysis_ByProduct 
			@rptData	= @rptData,
			@BreakBy	= @BreakdownMode,
			@PageIndex	= @PageIndex,
			@PageSize	= @PageSize,
			@TotalRow	= @TotalRow OUTPUT
	END

	SELECT DATEDIFF(MILLISECOND, @startTime, CURRENT_TIMESTAMP) AS Duration_Ms
END
GO
