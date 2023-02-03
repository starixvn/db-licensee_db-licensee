USE bodb_LicenseeReport;
GO

CREATE OR ALTER PROCEDURE LAP_Rpt_WinlossAnalysis_ByProduct_FullSel
	@FromDate		SMALLDATETIME = '2023-01-01',
	@ToDate			SMALLDATETIME = NULL,
	@MovebetDay		SMALLDATETIME = NULL,
	@BalanceUpDay	SMALLDATETIME = NULL,

	----------filtering
	@AgentList		XML = NULL,
	@Currencies		VARCHAR(1000) = 'ALL',
	@BaseCurency	VARCHAR(10) = 'EUR',
	@ProductIds		VARCHAR(MAX) = NULL,
	@SportIds		VARCHAR(MAX) = NULL,
	@BettypeIds		VARCHAR(MAX) = NULL,
	@StatusIds		VARCHAR(1000) = '112,113',
	@PlatformIds	VARCHAR(1000) = '0',
	@LiveStatusIds	VARCHAR(1000) = NULL, --0,1,2,3
	@IsTest			BIT = 0,

	------ player 
	@IsVIP			BIT = 0,
	@CustomerClass	VARCHAR(1000) = NULL,
	@OddsGroup		VARCHAR(1000) = NULL,
	@SearchCustID	INT	= NULL, --1411402

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
		@rptToDate		SMALLDATETIME,
		@Betfroms		NVARCHAR(1000),
		@LiveIds		VARCHAR(1000),
		@PlayerList		XML,
		@BettypeRef		XML,
		@SportCheck		VARCHAR(1000)
		;

	-- INPUT: validation
	SELECT @TotalRow	= 0,
		@PageIndex		= IIF(@PageIndex <= 0, 1, @PageIndex),
		@PageSize		= IIF(@PageSize <= 0, 50, @PageSize),
		@pageOffset		= (@PageIndex - 1) * @PageSize,
		@startTime		= CURRENT_TIMESTAMP,
		@today			= CAST(@startTime AS DATE),
		@yesterday		= DATEADD(DAY, -1, @today),
		@FromDate		= IIF(@FromDate IS NULL, @yesterday, @FromDate),
		@ToDate			= IIF(@ToDate IS NULL, @today, @ToDate),

		----------------Default values 
		@Currencies		= IIF(@Currencies='ALL', NULL, @Currencies),
		@ProductIds		= IIF(@ProductIds='ALL', NULL, @ProductIds),
		@SportIds		= IIF(@SportIds='ALL', NULL, @SportIds),
		@BettypeIds		= IIF(@BettypeIds='ALL', NULL, @BettypeIds),
		@StatusIds		= IIF(@StatusIds='ALL', '111,112,113', @StatusIds),
		@LiveStatusIds	= IIF(@LiveStatusIds='ALL', NULL, @LiveStatusIds),
		@CustomerClass	= IIF(@CustomerClass='ALL', NULL, @CustomerClass),
		@OddsGroup		= IIF(@OddsGroup='ALL', NULL, @OddsGroup),
		@PlatformIds	= IIF(@PlatformIds='ALL', NULL, @PlatformIds)
		;

	DECLARE @AgencySel	TABLE(recommend INT PRIMARY KEY);
	DECLARE @ProductSel TABLE (ProductId INT PRIMARY KEY);

	-- sample data:
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

		
		;WITH AgencySel AS (
			SELECT t.c.value('@AgencyId', 'int') AS recommend
				,t.c.value('@Currency', 'varchar(10)') AS Currency
			FROM @AgentList.nodes('/root/row') AS t(c)
		),
		CurrencySel AS (
			SELECT t.value AS Code
			FROM STRING_SPLIT(@Currencies, ',') AS t
		)
		INSERT INTO @AgencySel(recommend)
		SELECT a.recommend 
		FROM AgencySel a
		LEFT JOIN CurrencySel c ON c.Code = a.Currency
		WHERE 1 = CASE 
					WHEN @IsTest = 1 THEN 1
					WHEN @IsTest = 0 AND ISNULL(a.Currency, 'N/A') <> 'UUS' THEN 1
				ELSE 0 END
			AND (@Currencies IS NULL OR c.Code IS NOT NULL);

		-- Re-write agency list
		SELECT @AgentList = (SELECT recommend AS '@AgencyId' FROM @AgencySel FOR XML PATH, ROOT('root'));

		SELECT @ProductIds='37,1,25,3,23,28,63,8,50,40,38,5,42,66,69,70,21,47,39,45,11,46,52,51,57,65,22,6,34,32,55,56,60,61,62,67,68,72,73';

		--SELECT @SportIds = '-1'
	END -- sample

	--TODO: Saba sports
	SET @SportCheck = @SportIds;
	IF CHARINDEX('-', @SportCheck) > 0
	BEGIN
		IF NOT ',' + @SportCheck + ',' LIKE '%,1,%'
		BEGIN
			SET @SportCheck += ',1';
		END
	END

	--TODO: Event Products, Sports, Bettypes selection
	SELECT @BettypeRef = (
		SELECT DISTINCT tbl.ProductID AS '@p', 
			tbl.BetType AS '@b', 
			tbl.RefTable AS '@r',
			tbl.EventType AS '@e',
			tbl.SportType AS '@s'
		FROM bodb02.dbo.SportBettypeMatrix tbl WITH(NOLOCK)
		WHERE 
			(@ProductIDs IS NULL OR ',' + @ProductIDs + ',' LIKE '%,' + CAST(tbl.ProductID AS VARCHAR(3)) + ',%')
			AND (@SportCheck IS NULL OR ',' + @SportCheck + ',' LIKE '%,' + CAST(tbl.SportType AS VARCHAR(3)) + ',%')
			AND (@BettypeIDs IS NULL OR ',' + @BettypeIDs + ',' LIKE '%,' + CAST(tbl.BetType AS VARCHAR(3)) + ',%')
			--AND tbl.IsTest = IIF(@IsTest = 1, tbl.IsTest, @IsTest)
		FOR XML PATH, ROOT('root')
	);

	

	-- TODO: Platform selection
	SET @Betfroms = NULL;
	IF @PlatformIds IS NOT NULL
	BEGIN
		SELECT @Betfroms = COALESCE(@Betfroms + ',', '') + t.BetFrom
		FROM (
			SELECT DISTINCT f.BetFrom
			FROM STRING_SPLIT(@PlatformIds,',') AS ids
			CROSS APPLY bodb02.[dbo].[f_GetBetFromByPlatform](ids.value) AS f
		) AS t
	END
	--SELECT @PlatformIds AS [@PlatformIds], @Betfroms AS [@Betfroms]

	--TODO: Live Status selection [0: All, 1:Live, 2:Non-Live, 3: Mix]
	SET @LiveIds = NULL;
	IF @LiveStatusIds IS NOT NULL
	BEGIN
		SELECT @LiveIds = @LiveStatusIds
	END

	--TODO: Player selection
	--VIP Player: bodb02.Dep_CustVIP???
	--Customer Class:bodb02.custinfo.CustomerClass
	--Odds Group: bodb02.Customer.ugroup
	SET @PlayerList = NULL;
	DROP TABLE IF EXISTS #playerSel;
	CREATE TABLE #playerSel (custid INT);
	IF (
		@SearchCustID > 0
		OR @IsVIP = 1
		OR @CustomerClass IS NOT NULL
		OR @OddsGroup IS NOT NULL
	)
	BEGIN
		INSERT INTO #playerSel(custid)
		SELECT c.CustID
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid = c.custid
		INNER JOIN @AgencySel ag ON ag.recommend = ci.recommend
		LEFT JOIN bodb02.dbo.Dep_CustVIP vip ON c.custid = vip.CustID
		WHERE c.roleid = 1
			AND (@SearchCustID IS NULL OR c.custid = @SearchCustID)
			AND (@OddsGroup IS NULL
				OR ',' + @OddsGroup + ',' LIKE '%,' + c.ugroup + ',%')
			AND (@CustomerClass IS NULL
				OR ',' + @CustomerClass + ',' LIKE '%,0,%' AND CONVERT(VARCHAR(6), ci.CustomerClass) IS NULL
				OR ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%')
			AND (@IsVIP = 0 OR vip.CustID > 0);

		SET @PlayerList = (SELECT custid AS '@CustId' FROM #playerSel FOR XML PATH, ROOT('root'));

		--SELECT @PlayerList [@PlayerList]
	END

	DROP TABLE IF EXISTS #rptData;
	CREATE TABLE #rptData(
		ProductID SMALLINT, BreakBy INT, 
		BetCount INT,
		Turnover MONEY, 
		NetTurnover MONEY,
		MemWinloss MONEY, 
		MemComm MONEY,
		LicWinloss MONEY, 
		LicComm MONEY,
		AmtDueToBA MONEY, 
		Margin	SMALLMONEY,
		CONSTRAINT PK PRIMARY KEY CLUSTERED (ProductID, BreakBy)
	);

	--select @SportIds AS [@SportIds]

	-- TODO: filter raw data
	IF @ToDate >= @today --> get today data in bettrans
	BEGIN
		SELECT @rptFromDate = @FromDate--@today
			, @rptToDate	= @today;
		
		--select *
		--FROM [dbo].[f_LicenseeWinlossActiveSel] (
		--	@AgentList, 
		--	@rptFromDate, 
		--	@rptToDate, 
		--	@BettypeRef,
		--	@StatusIds,
		--	@Betfroms,
		--	@LiveIds,
		--	@PlayerList,
		--	@SportIds
		--) AS b

		INSERT INTO #rptData (ProductId, BreakBy, BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin)
		SELECT b.ProductId, 
			CASE WHEN @BreakdownMode = 3 THEN b.recommend ELSE b.currency END AS BreakBy,
			SUM(b.BetCount) AS BetCount,
			SUM(b.Turnover) AS Turnover,
			SUM(b.NetTurnover) AS NetTurnover,
			SUM(b.MemWinloss) AS MemWinloss, 
			SUM(b.MemComm) AS MemComm,
			-SUM(b.MemWinloss) AS LicWinloss, 
			SUM(b.LicComm) AS LicComm,
			SUM(b.AmtDueToBA) AS AmtDueToBA,
			SUM(b.MemWinloss)/SUM(IIF(ISNULL(b.NetTurnover,0)=0, b.Turnover, b.NetTurnover)) AS [Margin]
		FROM [dbo].[f_LicenseeWinlossActiveSel] (
			@AgentList, 
			@rptFromDate, 
			@rptToDate, 
			@BettypeRef,
			@StatusIds,
			@Betfroms,
			@LiveIds,
			@PlayerList,
			@SportIds
		) AS b
		GROUP BY b.ProductId, 
			CASE WHEN @BreakdownMode = 3 THEN b.recommend ELSE b.currency END
			
	END

	IF @FromDate < @today -- get sum data from yesterday vs backward
	BEGIN
		SELECT @rptFromDate = @FromDate
			, @rptToDate	= IIF(@ToDate >= @today, @yesterday, @ToDate);

		INSERT INTO #rptData (ProductId, BreakBy, BetCount, Turnover
			--, NetTurnover, MemWinloss, MemComm
			--, LicWinloss, LicComm, AmtDueToBA, Margin
		)
		SELECT b.ProductId, 
			CASE WHEN @BreakdownMode = 3 THEN b.recommend ELSE b.currency END AS BreakBy,
			SUM(b.BetCount) AS BetCount,
			SUM(b.Turnover) AS Turnover
			--,SUM(b.NetTurnover) AS NetTurnover,
			--SUM(b.MemWinloss) AS MemWinloss, 
			--SUM(b.MemComm) AS MemComm,
			--SUM(b.LicWinloss) AS LicWinloss, 
			--SUM(b.LicComm) AS LicComm,
			--SUM(b.AmtDueToBA) AS AmtDueToBA,
			--SUM(LicWinloss/IIF(ISNULL(NetTurnover,0)=0, Turnover, NetTurnover)) AS [Margin]
		 FROM dbo.rptLicenseeWinloss b WITH(NOLOCK)
			INNER JOIN @AgencySel a ON a.recommend = b.recommend
			INNER JOIN @ProductSel p ON p.ProductId = b.ProductId
		WHERE
			b.WinlostDate BETWEEN @rptFromDate AND @rptToDate
		--	b.statusID IN (112, 113)

		GROUP BY b.ProductId, 
			CASE WHEN @BreakdownMode = 3 THEN b.recommend ELSE b.currency END
	END

	-- TODO: paging
	;WITH paging AS (
		SELECT rIdx, GroupBy
			, rTotal
		FROM (
			SELECT t.GroupBy, 
				COUNT(1) OVER() AS rTotal,
				ROW_NUMBER() OVER(ORDER BY t.GroupBy ASC) AS rIdx
			FROM (
				SELECT DISTINCT rpt.ProductID AS GroupBy
				FROM #rptData rpt
			) AS t
		) AS p
		ORDER BY p.rIdx ASC
		OFFSET @pageOffset ROWS FETCH NEXT @PageSize ROWS ONLY
	),
	result AS (
		SELECT p.rIdx, p.GroupBy,
			rpt.BreakBy,
			rpt.BetCount,
			rpt.Turnover,
			NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin,
			p.rTotal
		FROM paging p
		INNER JOIN #rptData rpt ON p.GroupBy = rpt.ProductID 
	)
	SELECT rIdx, GroupBy, BreakBy, BetCount, Turnover, 
		NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin,
		rTotal
	INTO #result
	FROM result rs
	
	-- total row
	SELECT TOP(1) @TotalRow = rs.rTotal
	FROM #result rs

	-- output

	SELECT rIdx, GroupBy, BreakBy, BetCount, Turnover,
		NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
	FROM (
		SELECT rs.rIdx, rs.GroupBy,
			CAST(IIF(LEN(ex.Code)=0, 'N/A',ex.Code) AS NVARCHAR(100)) AS BreakBy,
			BetCount, Turnover,
			NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
		FROM #result rs
			INNER JOIN bodb02.dbo.Exchange ex with(nolock) ON ex.exchangeid = rs.BreakBy
		WHERE @BreakdownMode = 1
		UNION ALL
		SELECT rs.rIdx, rs.GroupBy,
			ci.username AS BreakBy,
			BetCount, Turnover,
			NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
		FROM #result rs
			INNER JOIN bodb02.dbo.custinfo ci with(nolock) ON ci.custid = rs.BreakBy
		WHERE @BreakdownMode = 3
	) AS rs
	ORDER BY rs.rIdx, rs.GroupBy


	--SELECT rs.rIdx, rs.GroupBy,
	--	CASE 
	--		WHEN @BreakdownMode = 1 THEN IIF(LEN(ex.Code)=0, 'N/A',ex.Code)
	--		WHEN @BreakdownMode = 3 THEN ci.username
	--	END AS BreakBy,
	--	turnover
	--FROM #result rs
	--	LEFT JOIN bodb02.dbo.Exchange ex with(nolock) ON ex.exchangeid = rs.BreakBy
	--	LEFT JOIN bodb02.dbo.custinfo ci with(nolock) ON ci.custid = rs.BreakBy
	--ORDER BY rs.rIdx,
	--	CASE 
	--		WHEN @BreakdownMode = 1 THEN ex.exchangeid
	--		WHEN @BreakdownMode = 3 THEN ci.custid
	--	END ASC

	SELECT rs.rIdx, rs.GroupBy,	SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
		SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
		SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(Margin) AS Margin
	FROM #result rs
	GROUP BY rs.rIdx, rs.GroupBy

	SELECT @TotalRow AS TotalRow,
		SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
		SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
		SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(Margin) AS Margin
	FROM #rptData

	SELECT DATEDIFF(MILLISECOND, @startTime, CURRENT_TIMESTAMP) AS Duration_Ms

END