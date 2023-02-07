USE bodb_LicenseeReport;
GO

CREATE OR ALTER PROCEDURE dbo.LAP_Rpt_WinlossAnalysis_AgencySel
	@FromDate		SMALLDATETIME = '2023-01-10',
	@ToDate			SMALLDATETIME = NULL,
	@MovebetDay		SMALLDATETIME = NULL,

	----------filtering
	@AgentList		XML = NULL,
	@BaseCurrency	VARCHAR(10) = 'EUR',
	@ProductCodes	VARCHAR(MAX) = NULL, --'SB,NG,etc...'
	@SportIds		VARCHAR(MAX) = NULL,
	@BettypeIds		VARCHAR(MAX) = NULL,
	@StatusIds		VARCHAR(1000) = '112,113',
	@PlatformIds	VARCHAR(1000) = 'ALL',
	@LiveStatusIds	VARCHAR(1000) = NULL, --0,1,2,3

	-- grouping
	@GroupMode		TINYINT = 3, -- support [3->8]
	@BreakdownMode	TINYINT = 1,

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
		@BetfromRef		XML,
		@LiveIds		VARCHAR(1000),
		@BettypeRef		XML,
		@SportCheck		VARCHAR(1000),
		@ProductCheck	VARCHAR(MAX)
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
		@ProductCodes	= IIF(@ProductCodes='ALL', NULL, @ProductCodes),
		@SportIds		= IIF(@SportIds='ALL', NULL, @SportIds),
		@BettypeIds		= IIF(@BettypeIds='ALL', NULL, @BettypeIds),
		@StatusIds		= IIF(@StatusIds='ALL', '111,112,113', @StatusIds),
		@LiveStatusIds	= IIF(@LiveStatusIds='ALL', NULL, @LiveStatusIds),
		@PlatformIds	= IIF(@PlatformIds='ALL', '0', @PlatformIds)
		;

	-- local vars
	DECLARE @GroupBy		TINYINT,
			@BreakBy		TINYINT;

	SELECT @GroupBy			= @GroupMode,
		@BreakBy			= CASE WHEN @GroupMode IN (3,4) AND @BreakdownMode = 2 THEN 1 ELSE @BreakdownMode END

	DECLARE @AgencySel	TABLE(recommend INT PRIMARY KEY, Currency INT);
	DECLARE @ProductSel TABLE (ProductId INT PRIMARY KEY);

	-- sample data:
	BEGIN
		SET @AgentList = '<ROOT>
		  <Agent AgencyId="41561179" Currency="13" />
		  <Agent AgencyId="6006447" Currency="61" />
		  <Agent AgencyId="44616944" Currency="61" />
		  <Agent AgencyId="40586156" Currency="20" />
		  <Agent AgencyId="14180031" Currency="20" />
		  <Agent AgencyId="1574100" Currency="20" />
		  <Agent AgencyId="2308751" Currency="20" />
		  <Agent AgencyId="14551801" Currency="45" />
		  <Agent AgencyId="10063439" Currency="20" />
		  <Agent AgencyId="37144035" Currency="13" />
		  <Agent AgencyId="17126508" Currency="2" />
		  <Agent AgencyId="3167654" Currency="51" />
		  <Agent AgencyId="3233980" Currency="20" />
		  <Agent AgencyId="4345531" Currency="20" />
		  <Agent AgencyId="836230" Currency="13" />
		  <Agent AgencyId="791049" Currency="3" />
		  <Agent AgencyId="4359308" Currency="13" />
		  <Agent AgencyId="15867159" Currency="20" />
		  <Agent AgencyId="38451676" Currency="69" />
		  <Agent AgencyId="2308854" Currency="13" />
		  <Agent AgencyId="1015423" Currency="9" />
		  <Agent AgencyId="37144045" Currency="20" />
		</ROOT>'

		
		;WITH AgencySel AS (
			SELECT t.c.value('@AgencyId', 'INT') AS recommend
				,t.c.value('@Currency', 'INT') AS Currency
			FROM @AgentList.nodes('/ROOT/Agent') AS t(c)
		)
		INSERT INTO @AgencySel(recommend, Currency)
		SELECT a.recommend, Currency
		FROM AgencySel a;

		--SELECT @ProductCodes='37,1,25,3,23,28,63,8,50,40,38,5,42,66,69,70,21,47,39,45,11,46,52,51,57,65,22,6,34,32,55,56,60,61,62,67,68,72,73';
		--SET @ProductCodes = 'SB,RB,NG,LC,VS,CS,BG,KN,P2P,PTCS,AGC,GD,MGCLC,VG,CB,SB2,MGCRNG,RNGS2,CF,CR,AB,VB,NG2,FW,CO,LK3,VS2,LT,VJ,BF,BX,PP,PG,CC,SG,VRG,SAG,TG,LC2,SBC,I4D,LT2,SXG,IBCLC,BBIN,VS3,RNGW,WM,ION,RNGC2,SBS2,PGS,JK,BGG,GDG,MXG,HB,CG,SLT,VRG2,PPL,VGA,AP,APM,BTC,FGGL,,SEA,MGRNG,TIP,JIG';
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
	--BA product
	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = ( POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2) 
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 3)),
			@ProductCheck = @ProductCodes;

	IF @SBBACheck & 4 = 0 -- 0.SB
		AND @SBBACheck & 8 = 8 -- 1.BA
	BEGIN
		SELECT @ProductCheck = CONCAT(@ProductCheck,',SB');
	END

	;WITH CTE_Product AS (
		SELECT 0 AS ProducID, p.ProductName, p.ProductPrefix AS ProductCode
		FROM bodb02.dbo.Products p WITH(NOLOCK) 
		WHERE p.ProductID = 1
		UNION ALL
		SELECT DISTINCT p3.ProductID, p3.ProductName, p3.ProductPrefix AS ProductCode
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
		INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
		WHERE p3.Enabled = 1
	)
	SELECT @BettypeRef = (
		SELECT DISTINCT p.ProductID AS '@p', 
			CASE WHEN p.ProductID = 1 THEN @SBBACheck ELSE POWER(2*1,4) END AS '@p3',
			m.BetType AS '@b', 
			m.RefTable AS '@r',
			m.EventType AS '@e'
		FROM CTE_Product p3 WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductPrefix = p3.ProductCode
		INNER JOIN bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) ON m.ProductID = p.ProductID
		WHERE p3.ProductCode NOT IN ('SPR', 'CB')
			AND (@ProductCheck IS NULL OR ',' + @ProductCheck + ',' LIKE '%,' + p3.ProductCode + ',%')
			AND (@SportCheck IS NULL OR ',' + @SportCheck + ',' LIKE '%,' + CAST(m.SportType AS VARCHAR(3)) + ',%')
			AND (@BettypeIDs IS NULL OR ',' + @BettypeIDs + ',' LIKE '%,' + CAST(m.BetType AS VARCHAR(3)) + ',%')
		FOR XML PATH('Row'), ROOT('ROOT')
	);

	--SELECT @ProductCheck AS [@ProductCheck], @SBBACheck AS [@SBBACheck], @BettypeRef AS [@BettypeRef]

	-- TODO: Platform selection
	SET @BetfromRef = NULL;
	IF @PlatformIds IS NOT NULL
	BEGIN
		SELECT @BetfromRef =  (
			SELECT DISTINCT ids.value AS '@PlatformId', f.BetFrom AS '@BetFrom'
			FROM STRING_SPLIT(@PlatformIds,',') AS ids
			CROSS APPLY bodb02.[dbo].[f_GetBetFromByPlatform]('0') AS f
			FOR XML PATH('Row'), ROOT('ROOT')
		); 
		--select @BetfromRef AS [@BetfromRef]
	END
	--SELECT @PlatformIds AS [@PlatformIds], @Betfroms AS [@Betfroms]

	--TODO: Live Status selection [0: All, 1:Live, 2:Non-Live, 3: Mix]
	SET @LiveIds = NULL;
	IF @LiveStatusIds IS NOT NULL
	BEGIN
		SELECT @LiveIds = @LiveStatusIds
	END
	DROP TABLE IF EXISTS #rptData;
	CREATE TABLE #rptData(
		GroupBy INT, BreakBy INT,
		BetCount	INT,
		Turnover	MONEY, 
		NetTurnover MONEY,
		MemWinloss	MONEY, 
		MemComm		MONEY,
		LicWinloss	MONEY, 
		LicComm		MONEY,
		AmtDueToBA	MONEY, 
		Margin		SMALLMONEY,
		------------BASE
		BaseTurnover	MONEY, 
		BaseNetTurnover MONEY,
		BaseMemWinloss	MONEY, 
		BaseMemComm		MONEY,
		BaseLicWinloss	MONEY, 
		BaseLicComm		MONEY,
		BaseAmtDueToBA	MONEY, 
		BaseMargin		SMALLMONEY
		--,CONSTRAINT CIX_rptData PRIMARY KEY (GroupBy, BreakBy)
	);
	CREATE CLUSTERED INDEX CIX_rptData ON #rptData(GroupBy, BreakBy);

	DROP TABLE IF EXISTS #tmpExchange;

	SELECT FromDate, ToDate, ExchangeID, Rate
	INTO #tmpExchange
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT TOP 1 1 FROM @AgencySel a WHERE a.Currency = e.ExchangeID)

	-- TODO: filter raw data
	IF @ToDate >= @today --> get today data in bettrans
	BEGIN
		SELECT @rptFromDate = @FromDate--@today
			, @rptToDate	= @today;

		--select @BreakBy, *
		--FROM [dbo].[LAP_f_WinlossAnalysis_BettransSel] (
		--	@AgentList, 
		--	@rptFromDate, 
		--	@rptToDate, 
		--	@BettypeRef,
		--	@StatusIds,
		--	@BetfromRef,
		--	@LiveIds,
		--	@BaseCurrency,
		--	@SportIds
		--) AS b

		INSERT INTO #rptData (GroupBy, BreakBy, 
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA
			--, BaseMargin
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, '2000-01-01', b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, '2000-01-01', (DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate))) 
				WHEN @GroupBy = 3 THEN b.ProductId 
				WHEN @GroupBy = 4 THEN ISNULL(b.sporttype, -9999) 
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN b.platformId 
				WHEN @GroupBy = 8 THEN b.custid
				ELSE b.ProductId
			END AS GroupBy, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 AND @GroupBy NOT IN (3,4) THEN b.ProductId
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE b.currency 
			END AS BreakBy,
			SUM(b.BetCount) AS BetCount,
			SUM(b.Turnover) AS Turnover,
			SUM(b.NetTurnover) AS NetTurnover,
			SUM(b.MemWinloss) AS MemWinloss, 
			SUM(b.MemComm) AS MemComm,
			-SUM(b.MemWinloss) AS LicWinloss, 
			SUM(b.LicComm) AS LicComm,
			SUM(b.AmtDueToBA) AS AmtDueToBA,
			SUM(b.MemWinloss)/SUM(IIF(ISNULL(b.NetTurnover,0)=0, b.Turnover, b.NetTurnover)) AS [Margin]
			--0 AS [Margin]
			,-----------BASE
			SUM(b.Turnover * e.Rate) AS BaseTurnover,
			SUM(b.NetTurnover * e.Rate) AS BaseNetTurnover,
			SUM(b.MemWinloss * e.Rate) AS BaseMemWinloss, 
			SUM(b.MemComm * e.Rate) AS BaseMemComm,
			-SUM(b.MemWinloss * e.Rate) AS BaseLicWinloss, 
			SUM(b.LicComm * e.Rate) AS BaseLicComm,
			SUM(b.AmtDueToBA * e.Rate) AS BaseAmtDueToBA
		FROM [dbo].[LAP_f_WinlossAnalysis_BettransSel] (
			@AgentList, 
			@rptFromDate, 
			@rptToDate, 
			@BettypeRef,
			@StatusIds,
			@BetfromRef,
			@LiveIds,
			@BaseCurrency,
			@SportIds
		) AS b
		CROSS APPLY (
			SELECT TOP 1 Rate FROM #tmpExchange e 
			WHERE e.exchangeid = b.currency 
				AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
		) AS e
		GROUP BY CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, '2000-01-01', b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, '2000-01-01', (DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate))) 
				WHEN @GroupBy = 3 THEN b.ProductId 
				WHEN @GroupBy = 4 THEN ISNULL(b.sporttype, -9999)
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN b.platformId 
				WHEN @GroupBy = 8 THEN b.custid 
				ELSE b.ProductId
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 AND @GroupBy NOT IN (3,4) THEN b.ProductId
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE b.currency END
			
	END

	IF @FromDate < @today -- get sum data from yesterday vs backward
	BEGIN
		SELECT @rptFromDate = @FromDate
			, @rptToDate	= IIF(@ToDate >= @today, @yesterday, @ToDate);

		INSERT INTO #rptData (GroupBy, BreakBy, BetCount, Turnover
			--, NetTurnover, MemWinloss, MemComm
			--, LicWinloss, LicComm, AmtDueToBA, Margin
		)
		SELECT b.ProductId AS GroupBy, 
			CASE WHEN @BreakBy = 3 THEN b.recommend ELSE b.currency END AS BreakBy,
			SUM(b.BetCount) AS BetCount,
			SUM(b.Turnover) AS Turnover
			--,SUM(b.NetTurnover) AS NetTurnover,
			--SUM(b.MemWinloss) AS MemWinloss, 
			--SUM(b.MemComm) AS MemComm,
			--SUM(b.LicWinloss) AS LicWinloss, 
			--SUM(b.LicComm) AS LicComm,
			--SUM(b.AmtDueToBA) AS AmtDueToBA,
			--SUM(LicWinloss/IIF(ISNULL(NetTurnover,0)=0, Turnover, NetTurnover)) AS [Margin]
		 FROM bodb_LicenseeReport.dbo.rptLicenseeWinloss b WITH(NOLOCK)
			INNER JOIN @AgencySel a ON a.recommend = b.recommend
			INNER JOIN @ProductSel p ON p.ProductId = b.ProductId
		WHERE
			b.WinlostDate BETWEEN @rptFromDate AND @rptToDate
		--	b.statusID IN (112, 113)

		GROUP BY b.ProductId, 
			CASE WHEN @BreakBy = 3 THEN b.recommend ELSE b.currency END
	END

	-- TODO: paging
	;WITH paging AS (
		SELECT rIdx, GroupBy, GroupKey
			, rTotal
		FROM (
			SELECT t.GroupBy, t.GroupKey,
				COUNT(1) OVER() AS rTotal,
				ROW_NUMBER() OVER(ORDER BY t.GroupKey ASC) AS rIdx
			FROM (
				SELECT DISTINCT FORMAT(DATEADD(HOUR, rpt.GroupBy, '2000-01-01'), 'yyyy-MM-dd') AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				WHERE @GroupBy IN(1,2)
				UNION ALL
				SELECT DISTINCT ck.ProductCode AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = rpt.GroupBy
				OUTER APPLY (
					SELECT 
						CASE 
							WHEN p.ProductID = 1 AND @SBBACheck <= 6 THEN 'SB' 
							WHEN p.ProductID = 1 AND @SBBACheck <= 10 THEN 'BA' 
							WHEN p.ProductID = 1 AND @SBBACheck <= 14 THEN 'SB,BA' 
							ELSE p.ProductPrefix 
						END AS ProductCode
				) AS ck
				WHERE @GroupBy = 3
				UNION ALL
				SELECT DISTINCT CONCAT(ISNULL(s.ProductPrefix, IIF(rpt.GroupBy < 0,'SB','N/A')), '#', rpt.GroupBy) AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				OUTER APPLY (
					SELECT TOP 1 p.ProductPrefix
					FROM bodb02.dbo.SportBettypeMatrix sm WITH(NOLOCK)
					INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductID = sm.ProductID
					WHERE sm.SportType = rpt.GroupBy
				) AS s 
				WHERE @GroupBy = 4
				UNION ALL
				SELECT DISTINCT CAST(ex.Code AS NVARCHAR(100)) AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				INNER JOIN bodb02.dbo.Exchange ex WITH(NOLOCK) ON ex.ExchangeId = rpt.GroupBy
				WHERE @GroupBy = 6
				UNION ALL
				SELECT DISTINCT CONCAT(ck.ExternalID,'#',ci.username) AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				INNER JOIN bodb02.dbo.customer ci WITH(NOLOCK) ON ci.custid = rpt.GroupBy
				CROSS APPLY (SELECT SUBSTRING(ci.username2,CHARINDEX('$',ci.username2)+1,100) AS ExternalID) AS ck
				WHERE @GroupBy = 8
				UNION ALL
				SELECT DISTINCT CAST(rpt.GroupBy AS NVARCHAR(100)) AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				WHERE @GroupBy IN(5,7)
			) AS t
		) AS p
		ORDER BY p.rIdx ASC
		OFFSET @pageOffset ROWS FETCH NEXT @PageSize ROWS ONLY
	),
	result AS (
		SELECT p.rIdx, p.GroupBy, p.GroupKey,
			rpt.BreakBy,
			rpt.BetCount,
			rpt.Turnover, rpt.NetTurnover, rpt.MemWinloss, rpt.MemComm, rpt.LicWinloss, rpt.LicComm, rpt.AmtDueToBA, rpt.Margin
			,---------BASE
			rpt.BaseTurnover, rpt.BaseNetTurnover, rpt.BaseMemWinloss, rpt.BaseMemComm, rpt.BaseLicWinloss, rpt.BaseLicComm, rpt.BaseAmtDueToBA
			--, rpt.BaseMargin
			,p.rTotal
		FROM paging p
		INNER JOIN #rptData rpt ON rpt.GroupBy = p.GroupKey
	)
	SELECT rIdx, GroupBy, GroupKey, BreakBy, BetCount, 
		Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
		,----BASE
		BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA
		--, BaseMargin
		,rTotal
	INTO #result
	FROM result rs
	
	-- total row
	SELECT TOP(1) @TotalRow = rs.rTotal
	FROM #result rs

	-- TOTO: output GRID
	SELECT rIdx, GroupBy, BreakBy,
		BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
		, ----BASE
		BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA
		--, BaseMargin
	FROM (
		SELECT rs.rIdx, rs.GroupBy, rs.GroupKey, CAST(ex.Code AS NVARCHAR(100)) AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA
			--, BaseMargin
		FROM #result rs
			LEFT JOIN bodb02.dbo.Exchange ex WITH(NOLOCK) ON ex.exchangeid = rs.BreakBy
		WHERE @BreakBy = 1
		UNION ALL
		SELECT rs.rIdx, rs.GroupBy,	rs.GroupKey, p.ProductPrefix AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover,	NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA
			--, BaseMargin
		FROM #result rs
			INNER JOIN bodb02.dbo.Products p with(nolock) ON p.ProductID = rs.BreakBy
		WHERE @BreakBy = 2
		UNION ALL
		SELECT rs.rIdx, rs.GroupBy,	rs.GroupKey, ci.username AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover,	NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA
			--, BaseMargin
		FROM #result rs
			LEFT JOIN bodb02.dbo.custinfo ci with(nolock) ON ci.custid = rs.BreakBy
		WHERE @BreakBy = 3
	) AS rs
	ORDER BY rs.rIdx, rs.GroupKey, rs.BreakOrder

	SELECT rs.rIdx, rs.GroupBy,	SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
		SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
		SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(Margin) AS Margin
		,----BASE
		SUM(BaseTurnover) AS BaseTurnover, SUM(BaseNetTurnover) AS BaseNetTurnover, 
		SUM(BaseMemWinloss) AS BaseMemWinloss, SUM(BaseMemComm) AS BaseMemComm, 
		SUM(BaseLicWinloss) AS BaseLicWinloss, SUM(BaseLicComm) AS BaseLicComm
		--,SUM(BaseAmtDueToBA) AS BaseAmtDueToBA, SUM(BaseMargin) AS BaseMargin
	FROM #result rs
	GROUP BY rs.rIdx, rs.GroupBy
	ORDER BY rs.rIdx

	SELECT @TotalRow AS TotalRow,
		SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
		SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
		SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(Margin) AS Margin
		,-----BASE
		SUM(BaseTurnover) AS BaseTurnover, SUM(BaseNetTurnover) AS BaseNetTurnover, 
		SUM(BaseMemWinloss) AS BaseMemWinloss, SUM(BaseMemComm) AS BaseMemComm, 
		SUM(BaseLicWinloss) AS BaseLicWinloss, SUM(BaseLicComm) AS BaseLicComm
		--,SUM(BaseAmtDueToBA) AS BaseAmtDueToBA, SUM(BaseMargin) AS BaseMargin
	FROM #rptData

	SELECT DATEDIFF(MILLISECOND, @startTime, CURRENT_TIMESTAMP) AS Duration_Ms

END