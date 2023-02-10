/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE OR ALTER PROCEDURE dbo.LAP_Rpt_WinlossAnalysis_AgencySel
	@FromDate		SMALLDATETIME = '2023-01-01 00:00:00',
	@ToDate			SMALLDATETIME = '2023-02-28 00:00:00',
	@MovebetDay		SMALLDATETIME = '2023-01-07 00:00:00',

	----------filtering
	@AgentList		XML = NULL,
	@BaseCurrency	VARCHAR(10)		= 'EUR',
	@ProductCodes	VARCHAR(MAX)	= 'ALL', --'SB,NG,etc...'
	@SportIds		VARCHAR(MAX)	= 'ALL',
	@BettypeIds		VARCHAR(MAX)	= 'ALL',
	@StatusIds		VARCHAR(1000)	= 'ALL',
	@PlatformIds	VARCHAR(1000)	= 'ALL',
	@LiveStatusIds	VARCHAR(1000)	= 'ALL',

	-- grouping
	@GroupMode		TINYINT = 1,
	@BreakdownMode	TINYINT = 1,

	----------paging
	@PageIndex		INT = 1,
	@PageSize		INT = 5,
	@Error			VARCHAR(250) = '' OUTPUT
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - GEN Bettrans
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TotalRow	INT,
		@pageOffset		INT,
		@today			SMALLDATETIME,
		@yesterday		SMALLDATETIME,
		@startTime		DATETIME,
		@rptFromDate	SMALLDATETIME,
		@rptToDate		SMALLDATETIME,
		@BetfromRef		XML,
		@LiveIds		VARCHAR(1000),
		@BettypeRef		XML,
		@SportCheck		VARCHAR(1000),
		@ProductCheck	VARCHAR(MAX),
		@StatusCheck	VARCHAR(1000),
		@PlatformCheck	VARCHAR(1000),
		@GroupBy		TINYINT,
		@BreakBy		TINYINT,
		@IsExportExcel	BIT,
		@BaseDate		SMALLDATETIME = '2000-01-01'
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
		@StatusCheck	= IIF(@StatusIds='ALL', '111,112,113,114,115', @StatusIds),
		@LiveIds		= IIF(@LiveStatusIds='ALL', '0,1,2', @LiveStatusIds),
		@PlatformCheck	= IIF(@PlatformIds IS NULL, 'ALL', @PlatformIds),
		---- EXPORT
		@IsExportExcel	= IIF(@PageIndex=0 AND @PageSize=0, 1, 0)
		;

	-- VALIDATE: Group modes
	SELECT @GroupBy		= @GroupMode,
			@BreakBy	= CASE 
							WHEN @GroupMode IN (3,4) AND @BreakdownMode = 2 THEN 1
							WHEN @GroupMode IN (6) AND @BreakdownMode = 1 THEN 2
							ELSE @BreakdownMode 
						END

	DECLARE @AgencySel		TABLE(recommend INT PRIMARY KEY, Currency INT);
	DECLARE @ProductSel		TABLE (ProductId INT, Product3rdId INT);

	-- sample data:
	BEGIN
		SET @AgentList = '<ROOT>
		  <Agent AgencyId="40586156" Currency="20" />
		  <Agent AgencyId="4359308" Currency="13" />
		  <Agent AgencyId="791088" Currency="6" />
		  <Agent AgencyId="17098615" Currency="20" />
		  <Agent AgencyId="37144035" Currency="13" />
		  <Agent AgencyId="791049" Currency="3" />
		  <Agent AgencyId="6006447" Currency="61" />
		  <Agent AgencyId="932255" Currency="13" />
		  <Agent AgencyId="1255630" Currency="20" />
		  <Agent AgencyId="1574100" Currency="20" />
		  <Agent AgencyId="11092988" Currency="20" />
		  <Agent AgencyId="16236699" Currency="20" />
		  <Agent AgencyId="44616944" Currency="61" />
		  <Agent AgencyId="836230" Currency="13" />
		</ROOT>';
	END -- sample

	-- TODO: Agency selection
	;WITH AgencySel AS (
		SELECT t.c.value('@AgencyId', 'INT') AS recommend
			,t.c.value('@Currency', 'INT') AS Currency
		FROM @AgentList.nodes('/ROOT/Agent') AS t(c)
	)
	INSERT INTO @AgencySel(recommend, Currency)
	SELECT a.recommend, Currency
	FROM AgencySel a;

	--TODO: Status selection -> include half WON/LOSE if any
	SELECT @StatusCheck = CONCAT(@StatusCheck, IIF(CHARINDEX('112', @StatusCheck) > 0, ',114','')),
		@StatusCheck = CONCAT(@StatusCheck, IIF(CHARINDEX('113', @StatusCheck) > 0, ',115',''))
	WHERE @StatusCheck <> 'ALL';

	--TODO: Platform Check
	DECLARE @PlatformSel TABLE(PlatformId INT, BetFrom VARCHAR(5));

	INSERT INTO @PlatformSel
	SELECT DISTINCT f.PlatformType, f.betfrom
	FROM bodb02.[dbo].[Lrf_f_BetFromType_Sel](@PlatformCheck) AS f
	;
	--select * from @PlatformSel

	--TODO: Event Products, Sports, Bettypes selection
	--Saba sports
	SET @SportCheck = @SportIds;
	IF CHARINDEX('-', @SportCheck) > 0
	BEGIN
		IF NOT ',' + @SportCheck + ',' LIKE '%,1,%'
		BEGIN
			SET @SportCheck += ',1';
		END
	END
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

	DROP TABLE IF EXISTS #tmpBettype;
	CREATE TABLE #tmpBettype (
		ProductId				SMALLINT, 
		Bettype					INT, 
		RefTable				TINYINT, 
		EventType				TINYINT,
		IsUsingOddsSpread		BIT,
		IsContributionBettype	BIT,
		Product3rdId			SMALLINT
	);
	CREATE CLUSTERED INDEX CIX_tmpBettype ON #tmpBettype(Bettype, ProductId);

	;WITH CTE_ExcludePayout AS (
		SELECT e.product3rdId
		FROM (
			SELECT VALUE 
			FROM STRING_SPLIT('32,37,39,42,45,34,66,36,21,74,56', ',') AS t
		) AS e (product3rdId)
	),
	CTE_Product AS (
		SELECT 0 AS ProductID, p.ProductName, p.ProductPrefix AS ProductCode
		FROM bodb02.dbo.Products p WITH(NOLOCK) 
		WHERE p.ProductID = 1
		UNION ALL
		SELECT DISTINCT p3.ProductID, p3.ProductName, p3.ProductPrefix AS ProductCode
		FROM bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK)
			INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd lp WITH(NOLOCK) ON p3.ProductID = lp.ProductID
			LEFT JOIN CTE_ExcludePayout e ON e.product3rdId = p3.productId
		WHERE p3.Enabled = 1
			AND e.product3rdId IS NULL
	)
	INSERT INTO #tmpBettype
	SELECT tbl.ProductId, tbl.Bettype, tbl.RefTable, tbl.EventType,
		CASE WHEN tbl.RefTable IN (1,2) OR tbl.ProductID = 47 THEN 1 ELSE 0 END IsUsingOddsSpread,
		CASE WHEN cont.Bettype IS NOT NULL THEN 1 ELSE 0 END AS IsContributionBettype,
		tbl.Product3rdId
	FROM (
		SELECT DISTINCT p.ProductID, 
			CASE WHEN p.ProductID = 1 THEN @SBBACheck ELSE p3.ProductID END AS Product3rdID,
			m.BetType, 
			m.RefTable,
			m.EventType
		FROM CTE_Product p3 WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Products p WITH(NOLOCK) ON p.ProductPrefix = p3.ProductCode
		INNER JOIN bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK) ON m.ProductID = p.ProductID
		WHERE (@ProductCheck IS NULL OR ',' + @ProductCheck + ',' LIKE '%,' + p3.ProductCode + ',%')
			AND (@SportCheck IS NULL OR ',' + @SportCheck + ',' LIKE '%,' + CAST(m.SportType AS VARCHAR(3)) + ',%')
			AND (@BettypeIDs IS NULL OR ',' + @BettypeIDs + ',' LIKE '%,' + CAST(m.BetType AS VARCHAR(3)) + ',%')
	) AS tbl
	OUTER APPLY 
	(
		SELECT f.Bettype
		FROM bodb02.dbo.f_BettypePrizeGroup() f
		WHERE f.BettypeGroup = 'Contribution'
			AND f.Bettype = tbl.bettype
	) AS cont
	;

	WITH CTE_ProductMap AS (
		SELECT DISTINCT ProductId, Product3rdId
		FROM #tmpBettype t
	)
	INSERT INTO @ProductSel(ProductId, Product3rdId)
	SELECT ProductId, Product3rdId
	FROM CTE_ProductMap t
	WHERE t.ProductId <> 1
	UNION ALL
	SELECT ProductId, ck.Product3rdId
	FROM CTE_ProductMap t
	CROSS APPLY (
		VALUES (IIF(t.Product3rdId & 4 = 4, 0, -1))
			,(IIF(t.Product3rdId & 8 = 8, 3, -1))
	) 
	AS ck (Product3rdId)
	WHERE t.ProductId = 1
	AND ck.Product3rdId <> -1
	;

	--SELECT @ProductCheck AS [@ProductCheck], @SBBACheck AS [@SBBACheck], @BettypeRef AS [@BettypeRef]
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
		BetEffective	MONEY,
		Margin		SMALLMONEY,
		------------BASE
		BaseTurnover	MONEY, 
		BaseNetTurnover MONEY,
		BaseMemWinloss	MONEY, 
		BaseMemComm		MONEY,
		BaseLicWinloss	MONEY, 
		BaseLicComm		MONEY,
		BaseAmtDueToBA	MONEY, 
		BaseBetEffective	MONEY,
	);
	CREATE CLUSTERED INDEX CIX_rptData ON #rptData(GroupBy, BreakBy);

	--TODO: Exchange rate
	DROP TABLE IF EXISTS #tmpExchange;
	CREATE TABLE #tmpExchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT);
	CREATE CLUSTERED INDEX CIX_tmpExchange ON #tmpExchange(ExchangeID);

	INSERT INTO #tmpExchange
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT TOP 1 1 FROM @AgencySel a WHERE a.Currency = e.ExchangeID)

	-- TODO: filter raw data
	IF @ToDate >= @MovebetDay --> get data in bettrans
	BEGIN
		SELECT @rptFromDate = DATEADD(DAY,1,@MovebetDay)--@today
			, @rptToDate	= @ToDate;

		WITH CTE_SabaSporttypeRef AS (
			SELECT t.SportType AS SabaSportType, t.SportType, t.LeagueGroupID
			FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
			CROSS APPLY
			(
				SELECT Sporttype, LeagueGroupID
				FROM OPENJSON(saba.SporttypeRef)
				WITH (Sporttype INT '$.Sporttype',
					LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
				)
				CROSS APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID VARCHAR(20) '$')
			) AS t
			WHERE saba.SporttypeRef IS NOT NULL
		)
		INSERT INTO #rptData (GroupBy, BreakBy, 
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN 
					CASE 
						WHEN s.ProductId = 1 AND s.Product3rdID & 4 = 4 AND ba.IsBA = 0 THEN 0 
						WHEN s.ProductId = 1 AND s.Product3rdID & 8 = 8 AND ba.IsBA = 1 THEN 3
						ELSE s.Product3rdID END
				WHEN @GroupBy = 4 THEN ISNULL(ck.sporttype, -9999) 
				WHEN @GroupBy = 5 THEN s.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				ELSE s.ProductId
			END AS GroupBy, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 THEN 
					CASE 
						WHEN s.ProductId = 1 AND s.Product3rdID & 4 = 4 AND ba.IsBA = 0 THEN 0 
						WHEN s.ProductId = 1 AND s.Product3rdID & 8 = 8 AND ba.IsBA = 1 THEN 3
						ELSE s.Product3rdID END
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE b.currency 
			END AS BreakBy
			----------------------
			,SUM(cal.BetCount) AS BetCount
			,SUM(cal.Turnover) AS Turnover
			,SUM(cal.NetTurnover) AS NetTurnover
			,SUM(cal.MemWinloss) AS MemWinloss
			,SUM(cal.[MemComm]) AS [MemComm]
			,-SUM(cal.MemWinloss) AS LicWinloss
			,SUM(cal.[LicComm]) AS [LicComm]
			,SUM(cal.AmtDueToBA) AS AmtDueToBA
			,SUM(cal.BetEffective) AS BetEffective
			,SUM(cal.MemWinloss)/SUM(IIF(ISNULL(cal.NetTurnover,0)=0, cal.Turnover, cal.NetTurnover)) AS [Margin]
			,---------BASE
			SUM(cal.Turnover * e.Rate) AS BaseTurnover
			,SUM(cal.NetTurnover * e.Rate) AS BaseNetTurnover
			,SUM(cal.MemWinloss * e.Rate) AS BaseMemWinloss
			,SUM(cal.[MemComm] * e.Rate) AS [BaseMemComm]
			,-SUM(cal.MemWinloss * e.Rate) AS BaseLicWinloss
			,SUM(cal.[LicComm] * e.Rate) AS [BaseLicComm]
			,SUM(cal.AmtDueToBA * e.Rate) AS BaseAmtDueToBA
			,SUM(cal.BetEffective * e.Rate) AS BaseBetEffective
		FROM [bodb02].[dbo].[bettrans] b WITH(NOLOCK)
			INNER JOIN @AgencySel a ON a.recommend = b.recommend 
			INNER JOIN #tmpBettype s ON s.bettype = b.bettype 
			LEFT JOIN [bodb02].dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN [bodb02].dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid AND l.LeagueGroupID IN (42,74,108,113,122,151)
			LEFT JOIN [bodb02].dbo.outright o WITH(NOLOCK) ON b.matchid = o.orid
			LEFT JOIN [bodb02].dbo.League lo WITH (NOLOCK) ON lo.leagueid = o.leagueid
			LEFT JOIN [bodb02].dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
			LEFT JOIN [bodb_licensee].dbo.LicenseeBATransaction AS lba WITH (NOLOCK) ON b.transid = lba.transid
			CROSS APPLY (
				SELECT TOP 1 Rate 
				FROM #tmpExchange e 
				WHERE e.exchangeid = b.currency 
					AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
			) AS e
			OUTER APPLY (
				SELECT 
					IIF(lba.TransID IS NOT NULL, 1, 0) AS IsBA
			) AS ba
			OUTER APPLY ( 
				SELECT TOP 1 SabaSportType 
				FROM CTE_SabaSporttypeRef ref 
				WHERE s.ProductId = 1 AND ref.Sporttype = m.Sporttype AND ref.LeagueGroupID = l.LeagueGroupID
			) AS saba
			OUTER APPLY (
				SELECT 
					ABS(b.[stake]) AS Turnover,
					CASE
						WHEN s.RefTable IN (1,2) THEN 0 -- Gaming IN bettransRnG/bettransLC
						WHEN s.ProductID = 1 AND b.statusID IN (111) THEN 0
						WHEN s.ProductID = 1 AND b.statusID IN (112, 113) AND ABS(b.modds) = 0.25 THEN ABS(stake) / 2
						WHEN s.IsUsingOddsSpread = 1 THEN b.oddsspread -- BBIN
						ELSE ABS(b.stake)
					END AS NetTurnover,
					(b.winlost-b.actual_stake) AS MemWinloss,
					-(CASE
						WHEN ba.IsBA = 1 THEN (b.winlost + b.awinlost + b.comm) --COUNT for BA's tickets
						ELSE 0
					END) AS AmtDueToBA,
					CASE 
						WHEN s.EventType = 1 THEN 
							CASE 
								WHEN s.ProductId = 1 AND s.EventType = 1 AND b.betdaqid = -2 THEN -2 --> Castout Sport 
								ELSE ISNULL(saba.SabaSportType, m.sporttype)
							END
						WHEN s.EventType = 2 THEN lo.sporttype
						WHEN s.EventType = 3 THEN vs.SportType
						WHEN s.EventType = 0 THEN
							CASE WHEN b.matchid = 29 THEN -1 --Parlay Sport
							ELSE b.matchid
							END
						ELSE 0
					END AS SportType,
					ISNULL(CASE WHEN b.bettype IN(9,29) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
			) AS ck
			OUTER APPLY (SELECT TOP 1 bf.PlatformId FROM @PlatformSel bf WHERE b.betfrom =  bf.BetFrom) AS bf
			OUTER APPLY (
				SELECT (CASE 
						WHEN s.ProductId <> 1 OR s.Product3rdId & 12 = 12 THEN 1
						WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
						WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
						ELSE 1
					END) AS BetCount
				,(CASE 
						WHEN s.ProductId <> 1 OR s.Product3rdId & 12 = 12 THEN ck.Turnover
						WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
						WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
						ELSE ck.Turnover
					END) AS Turnover
				,(CASE 
						WHEN s.ProductId <> 1 OR s.Product3rdId & 12 = 12 THEN ck.NetTurnover
						WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
						WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
						ELSE ck.NetTurnover
					END) AS NetTurnover
				,(CASE 
						WHEN s.ProductId <> 1 OR s.Product3rdId & 12 = 12 THEN ck.MemWinloss
						WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
						WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
						ELSE ck.MemWinloss
					END) AS MemWinloss
				,(CASE 
						WHEN s.ProductId <> 1 OR s.Product3rdId & 12 = 12 THEN b.[playercomm]
						WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
						WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
						ELSE b.[playercomm]
					END) AS [MemComm]
				,(CASE 
						WHEN s.ProductId <> 1 OR s.Product3rdId & 12 = 12 THEN b.[comm]
						WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
						WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
						ELSE b.[comm]
					END) AS [LicComm]
				,(CASE 
						WHEN s.ProductId <> 1 OR s.Product3rdId & 12 = 12 THEN ck.AmtDueToBA
						WHEN s.Product3rdId & 8 = 0 AND ba.IsBA = 1 THEN 0
						WHEN s.Product3rdId & 8 = 8 AND ba.IsBA = 0 THEN 0
						ELSE ck.AmtDueToBA
					END) AS AmtDueToBA
				,ABS(ck.MemWinloss) AS BetEffective
			) AS cal
		WHERE b.winlostdate BETWEEN @rptFromDate AND @rptToDate
			AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
			AND (',' + @LiveIds + ',' LIKE '%,' + CAST(ck.liveindicator AS VARCHAR(3)) + ',%')
			AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(ck.sporttype AS VARCHAR(3)) + ',%')
			AND (@PlatformCheck='ALL' OR bf.PlatformId > 0)
		
		GROUP BY CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN 
					CASE 
						WHEN s.ProductId = 1 AND s.Product3rdID & 4 = 4 AND ba.IsBA = 0 THEN 0 
						WHEN s.ProductId = 1 AND s.Product3rdID & 8 = 8 AND ba.IsBA = 1 THEN 3
						ELSE s.Product3rdID END
				WHEN @GroupBy = 4 THEN ISNULL(ck.sporttype, -9999) 
				WHEN @GroupBy = 5 THEN s.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId,-1)
				WHEN @GroupBy = 8 THEN b.custid
				ELSE s.ProductId
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 THEN 
					CASE 
						WHEN s.ProductId = 1 AND s.Product3rdID & 4 = 4 AND ba.IsBA = 0 THEN 0 
						WHEN s.ProductId = 1 AND s.Product3rdID & 8 = 8 AND ba.IsBA = 1 THEN 3
						ELSE s.Product3rdID END
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE b.currency 
			END
		HAVING 
			SUM(cal.BetCount) > 0
			

		;----TODO: get data from bettransLC/RnG for 3rd Products
		INSERT INTO #rptData (GroupBy, BreakBy, 
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA,BetEffective
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN b.Product3rdID
				WHEN @GroupBy = 4 THEN ISNULL(b.sporttype, -9999) 
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId,-1)
				WHEN @GroupBy = 8 THEN b.custid
				ELSE 0
			END AS GroupBy, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 THEN b.Product3rdID
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE b.currency 
			END AS BreakBy,
			--------------
			COUNT(1) AS BetCount
			,SUM(ABS(b.stake)) AS Turnover
			,SUM(b.NetTurnover) AS NetTurnover
			,SUM(b.winlost-b.actual_stake) AS MemWinloss
			,SUM(b.playercomm) AS [MemComm]
			,-SUM(b.winlost-b.actual_stake) AS LicWinloss
			,SUM(b.comm) AS [LicComm]
			,0 AS AmtDueToBA
			,SUM(ABS(b.winlost-b.actual_stake)) AS BetEffective
			---------BASE
			,SUM(ABS(b.stake) * e.Rate) AS BaseTurnover
			,SUM(b.NetTurnover * e.Rate) AS BaseNetTurnover
			,SUM((b.winlost-b.actual_stake) * e.Rate) AS BaseMemWinloss
			,SUM(b.playercomm * e.Rate) AS [BaseMemComm]
			,-SUM((b.winlost-b.actual_stake) * e.Rate) AS BaseLicWinloss
			,SUM(b.comm * e.Rate) AS [BaseLicComm]
			,0 AS BaseAmtDueToBA
			,SUM(ABS(b.winlost-b.actual_stake) * e.Rate) AS BaseBetEffective
				
		FROM (
			SELECT b.CustId, b.recommend, a.currency, b.winlostdate, s.Product3rdId, b.productID AS Sporttype, s.Bettype, b.betfrom
				,(CASE WHEN s.IsContributionBettype = 0 THEN b.BetStake ELSE 0 END) AS NetTurnover
				,b.stake, b.actual_stake,b.playercomm,b.comm,b.winlost
			FROM bodb02.dbo.bettransRnG b WITH(NOLOCK)
				INNER JOIN #tmpBettype s ON s.Bettype = b.gameID
				INNER JOIN @AgencySel a ON a.recommend = b.recommend
			WHERE b.winlostdate BETWEEN @rptFromDate AND @rptToDate
				AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'

			UNION ALL 
			SELECT b.CustId, b.recommend, a.currency, b.winlostdate, s.Product3rdId, b.productID AS Sporttype, s.Bettype, b.betfrom
				,(CASE WHEN s.IsContributionBettype = 0 THEN b.NetStake ELSE 0 END) AS NetTurnover
				,b.stake, b.actual_stake,b.playercomm,b.comm,b.winlost
			FROM bodb02.dbo.bettransLC b WITH(NOLOCK)
				INNER JOIN #tmpBettype s ON s.Bettype = b.gameID
				INNER JOIN @AgencySel a ON a.recommend = b.recommend
			WHERE b.winlostdate BETWEEN @rptFromDate AND @rptToDate
				AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				
		) AS b
		CROSS APPLY (
			SELECT TOP 1 Rate 
			FROM #tmpExchange e 
			WHERE e.exchangeid = b.currency 
				AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
		) AS e
		OUTER APPLY (SELECT TOP 1 bf.PlatformId FROM @PlatformSel bf WHERE b.betfrom =  bf.BetFrom) AS bf
		WHERE 
			(@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(b.sporttype AS VARCHAR(3)) + ',%')
			AND (@PlatformCheck='ALL' OR bf.PlatformId > 0)

		GROUP BY
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN b.Product3rdID
				WHEN @GroupBy = 4 THEN ISNULL(b.sporttype, -9999) 
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId,-1)
				WHEN @GroupBy = 8 THEN b.custid
				ELSE 0
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 THEN b.Product3rdID
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE b.currency 
			END
		--HAVING SUM(b.NetTurnover) > 0;

	END

	IF @FromDate <= @MovebetDay -- get sum data from @MovebetDay vs backward
	BEGIN
		SELECT @rptFromDate = @FromDate
			, @rptToDate	= IIF(@ToDate >= @MovebetDay, @MovebetDay, @ToDate);

		INSERT INTO #rptData (GroupBy, BreakBy, 
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN b.Product3rdId
				WHEN @GroupBy = 4 THEN ISNULL(b.Sporttype, -9999) 
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN a.Currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				ELSE 0
			END AS BreakBy, 
			CASE 
				WHEN @BreakBy = 1 THEN a.Currency
				WHEN @BreakBy = 2 THEN b.Product3rdId
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE a.Currency 
			END AS BreakBy
			----------------------
			,SUM(b.BetCount) AS BetCount
			,SUM(b.Turnover) AS Turnover
			,SUM(b.NetTurnover) AS NetTurnover
			,SUM(b.Winlost) AS MemWinloss
			,SUM(b.[PComm]) AS [MemComm]
			,-SUM(b.Winlost) AS LicWinloss
			,SUM(b.[AComm]) AS [LicComm]
			,SUM(cal.AmtDueToBA) AS AmtDueToBA
			,SUM(ABS(b.Winlost)) AS BetEffective
			,---------BASE
			SUM(b.Turnover * e.Rate) AS BaseTurnover
			,SUM(b.NetTurnover * e.Rate) AS BaseNetTurnover
			,SUM(b.Winlost * e.Rate) AS BaseMemWinloss
			,SUM(b.[PComm] * e.Rate) AS [BaseMemComm]
			,-SUM(b.Winlost * e.Rate) AS BaseLicWinloss
			,SUM(b.[AComm] * e.Rate) AS [BaseLicComm]
			,SUM(cal.AmtDueToBA * e.Rate) AS BaseAmtDueToBA
			,SUM(ABS(b.Winlost) * e.Rate) AS BaseBetEffective
		 FROM bodb_LicenseeReport.dbo.rptLicenseeWinloss b WITH(NOLOCK)
			INNER JOIN @AgencySel a ON a.recommend = b.recommend
			INNER JOIN @ProductSel ps ON ps.Product3rdId = b.Product3rdId
			INNER JOIN #tmpBettype bt ON bt.Bettype = b.Bettype
			CROSS APPLY (
				SELECT TOP 1 Rate 
				FROM #tmpExchange e 
				WHERE e.exchangeid = a.Currency 
					AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
			) AS e
			OUTER APPLY (
				SELECT -(CASE
						WHEN b.IsBA = 1 THEN (b.Winlost + b.AWinlost + b.AComm) --COUNT for BA's tickets
						ELSE 0
					END) AS AmtDueToBA
			) AS cal
			OUTER APPLY (SELECT TOP 1 bf.PlatformId FROM @PlatformSel bf WHERE b.betfrom =  bf.BetFrom) AS bf
		WHERE
			b.WinlostDate BETWEEN @rptFromDate AND @rptToDate
			AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
			AND (',' + @LiveIds + ',' LIKE '%,' + CAST(b.liveindicator AS VARCHAR(3)) + ',%')
			AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(b.sporttype AS VARCHAR(3)) + ',%')
			AND (@PlatformCheck='ALL' OR bf.PlatformId > 0)

		GROUP BY 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN b.Product3rdId
				WHEN @GroupBy = 4 THEN ISNULL(b.Sporttype, -9999) 
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN a.Currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				ELSE 0
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN a.Currency
				WHEN @BreakBy = 2 THEN b.Product3rdId
				WHEN @BreakBy = 3 THEN b.recommend 
				ELSE a.Currency 
			END
	END
	
	-- CHECK: @IsExportExcel OR NOT
	SELECT @pageOffset = 0, @PageSize = 2147483647 -- INT.Max
	WHERE @IsExportExcel = 1

	-- TODO: paging
	;WITH paging AS (
		SELECT rIdx, GroupBy, GroupKey
			, rTotal
		FROM (
			SELECT t.GroupBy, t.GroupKey,
				COUNT(1) OVER() AS rTotal,
				ROW_NUMBER() OVER(ORDER BY t.GroupKey ASC) AS rIdx
			FROM (
				SELECT DISTINCT FORMAT(DATEADD(HOUR, rpt.GroupBy, @BaseDate), 'yyyy-MM-dd') AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				WHERE @GroupBy IN(1,2)
				UNION ALL
				SELECT DISTINCT IIF(rpt.GroupBy = 0, 'SB', p3.ProductPrefix) AS GroupBy, rpt.GroupBy AS GroupKey
				FROM #rptData rpt
				LEFT JOIN bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK) ON p3.ProductID = rpt.GroupBy
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
		SELECT p.rIdx, p.rTotal, p.GroupBy, p.GroupKey,	rpt.BreakBy,
			SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
			SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
			SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
			SUM(AmtDueToBA) AS AmtDueToBA, SUM(BetEffective) AS BetEffective, 
			SUM(LicWinloss)/SUM(NetTurnover) AS [Margin]
			,----BASE
			SUM(BaseTurnover) AS BaseTurnover, SUM(BaseNetTurnover) AS BaseNetTurnover, 
			SUM(BaseMemWinloss) AS BaseMemWinloss, SUM(BaseMemComm) AS BaseMemComm, 
			SUM(BaseLicWinloss) AS BaseLicWinloss, SUM(BaseLicComm) AS BaseLicComm,
			SUM(BaseAmtDueToBA) AS BaseAmtDueToBA, SUM(BaseBetEffective) AS BaseBetEffective
		FROM paging p
		INNER JOIN #rptData rpt ON rpt.GroupBy = p.GroupKey
		GROUP BY p.rIdx, p.rTotal, p.GroupBy, p.GroupKey, rpt.BreakBy
	)
	SELECT rIdx, GroupBy, GroupKey, BreakBy, BetCount, 
		Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
		,----BASE
		BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		,rTotal
	INTO #result
	FROM result rs
	
	-- total row
	SELECT TOP(1) @TotalRow = rs.rTotal
	FROM #result rs

	-- TOTO: output GRID
	SELECT rIdx, GroupBy, BreakBy,
		BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
		, ----BASE
		BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
	FROM (
		SELECT rs.rIdx, rs.GroupBy, rs.GroupKey, CAST(ex.Code AS NVARCHAR(100)) AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		FROM #result rs
			LEFT JOIN bodb02.dbo.Exchange ex WITH(NOLOCK) ON ex.exchangeid = rs.BreakBy
		WHERE @BreakBy = 1
		UNION ALL
		SELECT rs.rIdx, rs.GroupBy,	rs.GroupKey, IIF(rs.BreakBy = 0, 'SB', p3.ProductPrefix) AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover,	NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective,Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		FROM #result rs
			LEFT JOIN bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK) ON p3.ProductID = rs.BreakBy
		WHERE @BreakBy = 2
		UNION ALL
		SELECT rs.rIdx, rs.GroupBy,	rs.GroupKey, ci.username AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover,	NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		FROM #result rs
			INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON ci.custid = rs.BreakBy
		WHERE @BreakBy = 3
	) AS rs
	ORDER BY rs.rIdx, rs.GroupKey, rs.BreakOrder

	SELECT rs.rIdx, rs.GroupBy,	
		SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
		SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
		SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(BetEffective) AS BetEffective, SUM(Margin) AS Margin
		,----BASE
		SUM(BaseTurnover) AS BaseTurnover, SUM(BaseNetTurnover) AS BaseNetTurnover, 
		SUM(BaseMemWinloss) AS BaseMemWinloss, SUM(BaseMemComm) AS BaseMemComm, 
		SUM(BaseLicWinloss) AS BaseLicWinloss, SUM(BaseLicComm) AS BaseLicComm
		,SUM(BaseAmtDueToBA) AS BaseAmtDueToBA, SUM(BaseBetEffective) AS BaseBetEffective
	FROM #result rs
	GROUP BY rs.rIdx, rs.GroupBy
	ORDER BY rs.rIdx

	SELECT @TotalRow AS TotalRow,
		SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
		SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
		SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(BetEffective) AS BetEffective, SUM(Margin) AS Margin
		,-----BASE
		SUM(BaseTurnover) AS BaseTurnover, SUM(BaseNetTurnover) AS BaseNetTurnover, 
		SUM(BaseMemWinloss) AS BaseMemWinloss, SUM(BaseMemComm) AS BaseMemComm, 
		SUM(BaseLicWinloss) AS BaseLicWinloss, SUM(BaseLicComm) AS BaseLicComm
		,SUM(BaseAmtDueToBA) AS BaseAmtDueToBA, SUM(BaseBetEffective) AS BaseBetEffective
	FROM #rptData

	SELECT DATEDIFF(MILLISECOND, @startTime, CURRENT_TIMESTAMP) AS Duration_Ms

END