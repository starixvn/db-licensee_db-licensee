/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.LAP_Rpt_WinlossAnalysis_SettleTimeSel
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MovebetDay		SMALLDATETIME,
	@AgentList		XML,
	@HourParts		VARCHAR(1000)	= 'ALL',

	----------filtering
	@BaseCurrency	VARCHAR(10)		= 'EUR',
	@ProductCodes	VARCHAR(MAX)	= 'ALL', --'SB,NG,VS'
	@SportIds		VARCHAR(MAX)	= 'ALL',
	@BettypeIds		XML,
	@StatusIds		VARCHAR(1000)	= 'ALL',
	@PlatformIds	VARCHAR(1000)	= 'ALL',
	@LiveStatusIds	VARCHAR(1000)	= 'ALL',
	@SpecialPlatform	TINYINT	= 0,

	------ player 
	@IsVIPOnly		BIT = 0,
	@CustomerClass	VARCHAR(1000) = 'ALL',
	@FullCustomerClass VARCHAR(1000) = 'ALL',
	@OddsGroup		VARCHAR(1000) = 'ALL',
	@SearchMode		TINYINT	= 1,
	@SearchUserName	VARCHAR(50) = NULL,

	-- grouping
	@CashoutMode	TINYINT = 0,
	@GroupMode		TINYINT = 1,
	@BreakdownMode	TINYINT = 1,

	--sorting
	@SortKey		TINYINT = 0,
	@SortType		BIT = 0,

	----------paging
	@PageIndex		INT = 1,
	@PageSize		INT = 5,
	@Error			VARCHAR(250) = '' OUTPUT
AS
/*
	Created: 20240915@Bobby
	Task: 209631 - LAP - Winloss Analysis - SettleTime
	DB: DBACC/bodb02

	Revisions:
		- 20240915@Bobby: Created [RedmineID: #209631]
		

	Param's Explanation:
		- @SortKey: 0:GroupBy, 1:BetCount, 2:Turnover, 3:NetTurnover, 4:MemWinloss, 5:MemComm, 6:LicWinloss, 7:LicComm, 8:AmtDueToBA, 9:BetEffective, 10:Margin
		- @SortType: 0:ASC, 1:DESC
		- @BettypeIds: <ROOT><Bettype pc="SB" bt="1,3,4,5"/><Bettype pc="VS" bt="1,3,4,5"/></ROOT>
		- @CashoutMode: 0-include, 1-exclude, 2-view CO only 
		- @HoursParts: [0-23]
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
		@SportCheck		VARCHAR(MAX),
		@ProductCheck	VARCHAR(MAX),
		@StatusCheck	VARCHAR(1000),
		@PlatformCheck	VARCHAR(1000),
		@GroupBy		TINYINT,
		@BreakBy		TINYINT,
		@IsExportExcel	BIT,
		@BaseDate			SMALLDATETIME = '2000-01-01',
		@CashoutModeCheck	TINYINT,
		@IsViewCOOnlyCheck	BIT,
		@BettypeIdsCheck	VARCHAR(MAX),
		@NASporttype		SMALLINT = 0,
		@SettleToDate		SMALLDATETIME,
		@SettleFromDate		SMALLDATETIME,
		@SettleToTime		DATETIME
		;

	DECLARE @IsVIPOnlyCheck		BIT,
		@CustClassCheck			VARCHAR(1000),
		@FullCustomerClassCheck VARCHAR(1000),
		@OddsGroupCheck			VARCHAR(1000),
		@SearchModeCheck		INT,
		@SearchUsernameCheck	VARCHAR(50)
	;

	-- INPUT: validation
	SELECT @TotalRow	= 0,
		@PageIndex		= IIF(@PageIndex < 0, 1, @PageIndex),
		@PageSize		= IIF(@PageSize < 0, 100, @PageSize),
		@pageOffset		= (@PageIndex - 1) * @PageSize,
		@startTime		= CURRENT_TIMESTAMP,
		@today			= CAST(@startTime AS DATE),
		@yesterday		= DATEADD(DAY, -1, @today),
		@FromDate		= IIF(@FromDate IS NULL, @yesterday, @FromDate),
		@ToDate			= IIF(@ToDate IS NULL, @today, @ToDate),
		@SettleFromDate	= IIF(@FromDate >= @MovebetDay, DATEADD(DAY, -1, @FromDate), @FromDate),

		----------------Default values 
		@ProductCodes	= IIF(@ProductCodes='ALL', NULL, @ProductCodes),
		@SportIds		= IIF(@SportIds='ALL', NULL, @SportIds),
		@StatusCheck	= IIF(@StatusIds='ALL', '111,112,113,114,115', @StatusIds),
		@LiveIds		= IIF(@LiveStatusIds='ALL', '0,1,2', @LiveStatusIds),
		@PlatformCheck	= IIF(@PlatformIds IS NULL, 'ALL', @PlatformIds),
		--- Cashout Mode
		@CashoutModeCheck	= ISNULL(@CashoutMode, 0),
		@IsViewCOOnlyCheck	= IIF(@CashoutModeCheck = 2, 1, 0),
		---- EXPORT
		@IsExportExcel	= IIF(@PageIndex=0 AND @PageSize=0, 1, 0)
		;

	SELECT @CustClassCheck		= IIF(@CustomerClass = 'ALL', NULL, @CustomerClass),
		@FullCustomerClassCheck = IIF(@FullCustomerClass = 'ALL', NULL, @FullCustomerClass),
		@OddsGroupCheck			= IIF(@OddsGroup = 'ALL', NULL, @OddsGroup),
		@SearchModeCheck		= @SearchMode,
		@SearchUsernameCheck	= @SearchUsername,
		@IsVIPOnlyCheck			= ISNULL(@IsVIPOnly,0)
	;

	DROP TABLE IF EXISTS #rptData;
	CREATE TABLE #rptData(
		GroupBy INT, BreakBy INT, ParentKey INT,
		BetCount	INT,
		Turnover	DECIMAL(19,8), 
		NetTurnover DECIMAL(19,8),
		MemWinloss	DECIMAL(19,8), 
		MemComm		DECIMAL(19,8),
		LicWinloss	DECIMAL(19,8), 
		LicComm		DECIMAL(19,8),
		AmtDueToBA	DECIMAL(19,8), 
		BetEffective	DECIMAL(19,8),
		Margin		SMALLMONEY,
		------------BASE
		BaseTurnover	DECIMAL(19,8), 
		BaseNetTurnover DECIMAL(19,8),
		BaseMemWinloss	DECIMAL(19,8), 
		BaseMemComm		DECIMAL(19,8),
		BaseLicWinloss	DECIMAL(19,8), 
		BaseLicComm		DECIMAL(19,8),
		BaseAmtDueToBA	DECIMAL(19,8), 
		BaseBetEffective	DECIMAL(19,8)
	);
	CREATE CLUSTERED INDEX CIX_rptData ON #rptData(GroupBy, BreakBy);

	---Sorting values
	DROP TABLE IF EXISTS #tmpSortValue;
	CREATE TABLE #tmpSortValue (ParentKey INT, GroupKey INT, GroupValue VARCHAR(100), SortValue MONEY, PRIMARY KEY(ParentKey, GroupKey)) ;

	-- VALIDATE: Group modes
	DECLARE @IsValidGroupMode BIT = 0;
	SELECT @IsValidGroupMode = CASE 
							WHEN @GroupMode IN (3,4,5) AND @BreakdownMode = 2 THEN 0
							WHEN @GroupMode IN (6) AND @BreakdownMode = 1 THEN 0
							WHEN @BreakdownMode NOT IN (1,2,3) THEN 0
							ELSE 1
						END,
			@GroupBy	= @GroupMode,
			@BreakBy	= @BreakdownMode;

	DROP TABLE IF EXISTS #tmpSabaSporttype;
	CREATE TABLE #tmpSabaSporttype (SabaSportType INT, SportType INT, LeagueGroupID INT, SportOrder INT, CutOffDate SMALLDATETIME);

	IF @IsValidGroupMode = 0
	BEGIN
		SET @Error = 'Invalid group mode. No data found.'
		GOTO TODO_OUTPUT;
	END

	DROP TABLE IF EXISTS #AgencySel;
	DROP TABLE IF EXISTS #BetTypeSel;
	DROP TABLE IF EXISTS #ProductSel;
	CREATE TABLE #AgencySel	(recommend INT PRIMARY KEY, Currency INT);
	CREATE TABLE #BetTypeSel (ProductCode VARCHAR(10), Bettype INT, ProductId INT);
	CREATE TABLE #ProductSel (ProductId INT, Product3rdId INT);

	-- TODO: Agency selection
	;WITH AgencySel AS (
		SELECT t.c.value('@AgentId', 'INT') AS recommend
			,t.c.value('@Currency', 'INT') AS Currency
		FROM @AgentList.nodes('/ROOT/Agent') AS t(c)
	)
	INSERT INTO #AgencySel(recommend, Currency)
	SELECT a.recommend, Currency
	FROM AgencySel a;

	--TODO: Check max winlostdate in bettrans
	SELECT @SettleToTime = DATEADD(DAY, 1, @ToDate);
	SELECT @SettleToDate = MAX(b.winlostdate)
	FROM dbo.bettrans b (NOLOCK)
		INNER JOIN #AgencySel a ON a.recommend = b.recommend
	WHERE b.statusID in (111,112,113)
		AND b.SettlementTime < @SettleToTime
	;
	SET @SettleToDate = ISNULL(@SettleToDate, @ToDate)

	--TODO: Settle Time
	DROP TABLE IF EXISTS #tmpSettleTime;
	CREATE TABLE #tmpSettleTime (SettlementTime DATETIME PRIMARY KEY, SettlementTimeEnd DATETIME);
	IF @HourParts = 'ALL'
	BEGIN
		;WITH CTE_HourCheck(HourPart) AS (
			SELECT 0
			UNION ALL
			SELECT HourPart = HourPart+1
			FROM CTE_HourCheck
			WHERE HourPart < 23
		)
		SELECT @HourParts = STRING_AGG(HourPart, ',')
		FROM CTE_HourCheck
	END
	--TODO: Parser Settle Time
	;WITH CTE_SettleTime (HourPart) AS (
		SELECT [value]  
		FROM STRING_SPLIT(@HourParts, ',') f
	),
	CTE_SettleDate (SettleDate) AS (
		SELECT @FromDate
		UNION ALL
		SELECT DATEADD(DAY, 1, SettleDate)
		FROM CTE_SettleDate
		WHERE SettleDate < @ToDate
	) 
	INSERT INTO #tmpSettleTime(SettlementTime, SettlementTimeEnd)
	SELECT st.SettlementTime, DATEADD(HOUR, 1, st.SettlementTime) AS SettlementTimeEnd
	FROM CTE_SettleDate ft
	CROSS JOIN CTE_SettleTime a
	CROSS APPLY (SELECT CAST(CONCAT(FORMAT(ft.SettleDate, 'yyyy-MM-dd'), ' ', a.HourPart, ':00:00') AS DATETIME)) AS st (SettlementTime)

	--TODO: Player selection
	DECLARE @checkPlayer BIT = 0;
	DROP TABLE IF EXISTS #playerSel;
	CREATE TABLE #playerSel (custid INT PRIMARY KEY, Currency INT);
	IF (
		@IsVIPOnlyCheck = 1
		OR @CustClassCheck IS NOT NULL
		OR @OddsGroupCheck IS NOT NULL
		OR LEN(@SearchUsernameCheck) > 0
	)
	BEGIN
		SET @SearchUsernameCheck = IIF(LEN(@SearchUsernameCheck) > 0, REPLACE(@SearchUsernameCheck, '_', '[_]'), @SearchUsernameCheck);
		-- TODO: Search player
		INSERT INTO #playerSel(custid, Currency)
		SELECT c.CustID, ag.Currency
		FROM dbo.Customer c WITH(NOLOCK)
		INNER JOIN #AgencySel ag ON ag.recommend = c.recommend
		INNER JOIN dbo.custInfo ci WITH(NOLOCK) ON ci.custid = c.custid
		LEFT JOIN dbo.Dep_CustVIP vip ON c.custid = vip.CustID
		WHERE c.roleid = 1
			AND (@SearchUsernameCheck IS NULL OR (
				(@SearchModeCheck = 1 AND (c.username2 LIKE  + '%$' + @SearchUsernameCheck OR c.username LIKE  @SearchUsernameCheck))) OR
				(@SearchModeCheck = 2 AND (c.username2 LIKE  + '%$%' + @SearchUsernameCheck + '%' OR c.username LIKE  '%' + @SearchUsernameCheck + '%')) OR
				(@SearchModeCheck = 3 AND (c.username2 LIKE  + '%$' + @SearchUsernameCheck + '%' OR c.username LIKE  @SearchUsernameCheck + '%'))
			)
			AND (@OddsGroupCheck IS NULL
				OR ',' + @OddsGroupCheck + ',' LIKE '%,' + c.ugroup + ',%')
			AND (@CustClassCheck IS NULL
				OR (',' + @CustClassCheck + ',' LIKE '%,0,%' AND (ISNULL(ci.CustomerClass, 0) = 0 OR  ',' + @FullCustomerClassCheck + ',' NOT LIKE  '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%' ))
				OR (',' + @CustClassCheck + ',' LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%')
			)
			AND (@IsVIPOnlyCheck = 0 OR vip.CustID > 0)
		;

		IF @@ROWCOUNT = 0
			GOTO TODO_OUTPUT;

		SET @checkPlayer = 1;
	END

	-- TODO: Bettype selection
	;WITH BettypeSel AS (
		SELECT t.c.value('@pc', 'VARCHAR(10)') AS ProductCode
			,t.c.value('@bt', 'VARCHAR(MAX)') AS Bettype
		FROM @BettypeIds.nodes('/ROOT/Bettype') AS t(c)
		)
	INSERT INTO #BetTypeSel(ProductCode, Bettype)
	SELECT a.ProductCode, b.value
	FROM BettypeSel a
	CROSS APPLY (
		SELECT value FROM STRING_SPLIT (a.Bettype,',') 
	) b;

	UPDATE a
	SET a.ProductId = IIF(a.ProductCode = 'VS', 5, t.ProductId)
	FROM #BetTypeSel a
		CROSS APPLY (
			SELECT TOP 1 p.ProductID AS ProductID
			FROM SportBettypeMatrix p WITH (NOLOCK)
			WHERE p.BetType = a.Bettype
		) AS t

	--TODO: Status selection -> include half WON/LOSE if any
	SELECT @StatusCheck = CONCAT(@StatusCheck, IIF(CHARINDEX('112', @StatusCheck) > 0, ',114','')),
		@StatusCheck	= CONCAT(@StatusCheck, IIF(CHARINDEX('113', @StatusCheck) > 0, ',115',''))
	WHERE @StatusCheck <> 'ALL';

	--TODO: Platform Check
	DECLARE @PlatformSel TABLE(PlatformId INT, BetFrom VARCHAR(5));

	INSERT INTO @PlatformSel
	SELECT DISTINCT f.PlatformType, f.betfrom
	FROM [dbo].[Lrf_f_BetFromType_Sel](@PlatformCheck) AS f
	WHERE SpecialPlatform = @SpecialPlatform
	
	--TODO: Event Products, Sports, Bettypes selection
	INSERT INTO #tmpSabaSporttype
	SELECT saba.SabaSportType, t.SportType, t.LeagueGroupID, saba.SportOrder, saba.CutOffDate
	FROM [dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
	OUTER APPLY
	(
		SELECT Sporttype, LeagueGroupID
		FROM OPENJSON(saba.SporttypeRef)
		WITH (Sporttype INT '$.Sporttype', 
			LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
		)
		OUTER APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID INT '$')
	) AS t
	WHERE saba.IsShowUI = 1

	--TODO: Sports filtering
	SELECT @SportCheck = @SportIds;

	--TODO: BA/SLT/BTC products
	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2) 
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 3)),
			@ProductCheck = @ProductCodes;

	--TODO: Bettype filtering
	SELECT @BettypeIdsCheck = STRING_AGG(CAST(BetType AS VARCHAR(MAX)), ',') 
	FROM (SELECT DISTINCT bettype FROM #BetTypeSel) a;

	DROP TABLE IF EXISTS #tmpBettype;
	CREATE TABLE #tmpBettype (
		ProductId				SMALLINT, 
		Bettype					INT, 
		RefTable				TINYINT, 
		EventType				TINYINT,
		IsContributionBettype	BIT,
		Product3rdId			SMALLINT,
		IsPriceBettype			BIT,
		GroupTypeId				INT
	);
	CREATE CLUSTERED INDEX CIX_tmpBettype ON #tmpBettype(Bettype, ProductId);

	INSERT INTO #tmpBettype 
	SELECT bm.ProductId, bm.Bettype, bm.RefTable, bm.EventType, bm.IsContributionBettype,
		CASE WHEN bm.ProductID = 1 THEN @SBBACheck ELSE bm.Product3rdID END AS Product3rdId,
		bm.IsPriceBettype,
		bm.GroupTypeId
	FROM dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductCheck, @SportCheck, @BettypeIdsCheck, @SBBACheck) AS bm
		INNER JOIN dbo.LAP_f_SettlementTime_ProductSel () ps ON ps.ProductId = bm.ProductId
		INNER JOIN #BetTypeSel bts ON bts.ProductId = bm.ProductId AND bts.Bettype = ISNULL(bm.GroupTypeId, bm.Bettype)

	;WITH CTE_ProductMap AS (
		SELECT DISTINCT ISNULL(lf.ProductId,t.ProductId) AS ProductId
					  , ISNULL(lf.ProductId,t.Product3rdId) AS Product3rdId
		FROM #tmpBettype t	
		LEFT JOIN dbo.Lrf_f_GroupProduct() lf ON t.ProductId = lf.GroupProductId
	)
	INSERT INTO #ProductSel(ProductId, Product3rdId)
	SELECT ProductId, Product3rdId
	FROM CTE_ProductMap t
	WHERE t.ProductId NOT IN (1, 63, 69)
	UNION ALL
	SELECT ProductId, ck.Product3rdId
	FROM CTE_ProductMap t
	CROSS APPLY (
		VALUES (IIF(@SBBACheck & 4 = 4, 0, -1))
			,(IIF(@SBBACheck & 8 = 8, 3, -1))
	) 
	AS ck (Product3rdId)
	WHERE t.ProductId IN (1, 63, 69)
	AND ck.Product3rdId <> -1
	UNION ALL -- Cashout
	SELECT -99, -99
	WHERE @IsViewCOOnlyCheck = 1
	;

	--TODO: Exchange rate
	DROP TABLE IF EXISTS #tmpExchange;
	CREATE TABLE #tmpExchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT);
	CREATE CLUSTERED INDEX CIX_tmpExchange ON #tmpExchange(ExchangeID);

	INSERT INTO #tmpExchange
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@SettleFromDate, @SettleToDate, @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT TOP 1 1 FROM #AgencySel a WHERE a.Currency = e.ExchangeID)

	-- TODO: filter raw data
	IF @SettleToDate > @MovebetDay --> get data in bettrans
	BEGIN
		SELECT @rptFromDate = IIF(@SettleFromDate > @MovebetDay, @SettleFromDate, DATEADD(DAY, 1, @MovebetDay))
			, @rptToDate	= @SettleToDate;

		--select @rptFromDate , @rptToDate
		-- TODO: full filtering
		DECLARE @strProduct3rd VARCHAR(4000);
		SELECT @strProduct3rd = STRING_AGG(Product3rdId,',') FROM ( SELECT DISTINCT Product3rdId FROM #ProductSel ps ) AS t

		INSERT INTO #rptData (GroupBy, BreakBy, ParentKey,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			--st.SettlementTime,
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, st.SettlementTime), st.SettlementTime))
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, st.SettlementTime), DATEADD(DAY, -DATEPART(DAY, st.SettlementTime) +1, st.SettlementTime))) 
				WHEN @GroupBy = 3 THEN ck.Product3rdIdMix
				WHEN @GroupBy = 4 THEN ISNULL(ck.sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN ISNULL(s.GroupTypeId, s.bettype)
				WHEN @GroupBy = 6 THEN a.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				WHEN @GroupBy = 10 THEN DATEDIFF(HOUR, @BaseDate, st.SettlementTime) -- group by Hour of SettlementTime
			END AS GroupBy, 
			CASE 
				WHEN @BreakBy = 1 THEN a.currency 
				WHEN @BreakBy = 2 THEN ck.Product3rdIdMix
				WHEN @BreakBy = 3 THEN b.custid 
			END AS BreakBy,
			CASE WHEN @GroupMode IN (4, 5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdIdMix ELSE -1 END AS ParentKey
			----------------------
			,COUNT(1) AS BetCount
			,SUM(ck.Turnover) AS Turnover
			,SUM(ck.NetTurnover) AS NetTurnover
			,SUM(ck.MemWinloss) AS MemWinloss
			,SUM(b.playercomm) AS [MemComm]
			,SUM(ck.LicWinloss) AS LicWinloss
			,SUM(b.comm) AS [LicComm]
			,SUM(ck.AmtDueToBA) AS AmtDueToBA
			,SUM(ABS(ck.MemWinloss)) AS BetEffective
			,---------BASE
			SUM(ck.Turnover * e.Rate) AS BaseTurnover
			,SUM(ck.NetTurnover * e.Rate) AS BaseNetTurnover
			,SUM(ck.MemWinloss * e.Rate) AS BaseMemWinloss
			,SUM(b.playercomm * e.Rate) AS [BaseMemComm]
			,SUM(ck.LicWinloss * e.Rate) AS BaseLicWinloss
			,SUM(b.comm * e.Rate) AS [BaseLicComm]
			,SUM(ck.AmtDueToBA * e.Rate) AS BaseAmtDueToBA
			,SUM(ABS(ck.MemWinloss) * e.Rate) AS BaseBetEffective
		FROM [dbo].[bettrans] b WITH(NOLOCK)
			INNER JOIN #AgencySel a ON a.recommend = b.recommend 
			INNER JOIN #tmpBettype s ON s.bettype = b.bettype AND s.RefTable NOT IN (1,2)
			INNER JOIN #tmpExchange e on e.ExchangeID =  a.Currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN dbo.[match] m WITH(NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN [dbo].[Match3rd] m3rd WITH(NOLOCK) ON m3rd.Match3rdId = b.matchid
			LEFT JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			LEFT JOIN dbo.outright o WITH(NOLOCK) ON b.matchid = o.orid
			LEFT JOIN dbo.League lo WITH (NOLOCK) ON lo.leagueid = o.leagueid
			LEFT JOIN dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
			LEFT JOIN #tmpSabaSporttype saba ON s.ProductId = 1 AND saba.Sporttype = l.Sporttype AND saba.LeagueGroupID = l.LeagueGroupID
			OUTER APPLY (
				SELECT 
					0 AS IsBA, -- ignore BA
					CASE
						WHEN s.ProductId = 1 AND s.EventType = 1 AND b.betdaqid = -2 THEN 1 -- Castout
						ELSE 0
					END AS TicketType
			) AS ba
			OUTER APPLY (
				SELECT 
					ABS(b.[stake]) AS Turnover,
					CASE
						WHEN s.RefTable IN (1,2) THEN 0 -- Gaming IN bettransRnG/bettransLC
						WHEN s.ProductID = 1 AND b.statusID IN (111) THEN 0
						WHEN s.ProductID = 1 AND b.statusID IN (112, 113) AND ABS(b.modds) = 0.25 THEN ABS(stake) / 2
						ELSE ABS(b.stake)
					END AS NetTurnover,
					(b.winlost-b.actual_stake) AS MemWinloss,
					CASE WHEN ba.IsBA = 0 THEN -(b.winlost-b.actual_stake) ELSE 0 END AS LicWinloss,
					-(CASE
						WHEN ba.IsBA = 1 THEN (b.winlost - b.actual_stake + b.awinlost + b.comm) --COUNT for BA's tickets
						ELSE 0
					END) AS AmtDueToBA,
					CASE 
						WHEN s.ProductId NOT IN (1,63,69) THEN s.Product3rdID
						WHEN @IsViewCOOnlyCheck = 1 AND s.ProductId = 1 AND @SBBACheck & 4 = 4 AND ba.IsBA = 0 AND ba.TicketType = 1 THEN -99 --Cashout 
						WHEN @IsViewCOOnlyCheck = 1 AND s.ProductId = 1 AND @SBBACheck & 8 = 8 AND ba.IsBA = 1 AND ba.TicketType = 1 THEN -99 --Cashout  
						WHEN s.ProductId IN (1,63,69) AND @SBBACheck & 4 = 4 AND ba.IsBA = 0 THEN 0 
						WHEN s.ProductId IN (1,63,69) AND @SBBACheck & 8 = 8 AND ba.IsBA = 1 THEN 3
						END AS Product3rdIdMix,
					CASE 
						WHEN s.EventType = 0 THEN
							CASE 
								WHEN b.matchid = 29 THEN -1 --Parlay Sport
								WHEN b.matchid IN (2799,10449,11099) THEN b.oddsid --VS Sports
								ELSE ISNULL(b.matchid, @NASporttype)
							END
						WHEN s.EventType = 1 THEN ISNULL(saba.SabaSportType, m.sporttype)
						WHEN s.EventType = 2 THEN lo.sporttype
						WHEN s.EventType = 3 THEN vs.SportType
						WHEN s.EventType = 5 THEN m3rd.SportType --175-BTC Sport
						ELSE @NASporttype
					END AS SportType,
					ISNULL(CASE WHEN b.bettype IN(29,2799,10449) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
			) AS ck
			INNER JOIN @PlatformSel bf ON bf.betfrom =  b.BetFrom
			INNER JOIN #tmpSettleTime st ON b.SettlementTime >= st.SettlementTime AND b.SettlementTime < st.SettlementTimeEnd
			LEFT JOIN #playerSel psl ON psl.custid = b.custid
		WHERE b.winlostdate BETWEEN @rptFromDate AND @rptToDate
			AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
			AND (',' + @LiveIds + ',' LIKE '%,' + CAST(ck.liveindicator AS VARCHAR(3)) + ',%')
			AND (ck.sporttype <> 0 AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(ck.sporttype AS VARCHAR(10)) + ',%'))
			AND (',' + @strProduct3rd + ',' LIKE '%,' + CAST(ck.Product3rdIdMix AS VARCHAR(3)) + ',%')
			AND NOT (ck.Product3rdIdMix IN (0, 3) AND ba.TicketType = 1 AND @CashoutModeCheck = 1) --- exclude CO from SB & BA
			AND (@checkPlayer = 0 OR psl.custid > 0)
		
		GROUP BY --st.SettlementTime,
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, st.SettlementTime), st.SettlementTime))
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, st.SettlementTime), DATEADD(DAY, -DATEPART(DAY, st.SettlementTime) +1, st.SettlementTime))) 
				WHEN @GroupBy = 3 THEN ck.Product3rdIdMix
				WHEN @GroupBy = 4 THEN ISNULL(ck.sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN ISNULL(s.GroupTypeId, s.bettype) 
				WHEN @GroupBy = 6 THEN a.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId,-1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				WHEN @GroupBy = 10 THEN DATEDIFF(HOUR, @BaseDate, st.SettlementTime) -- group by Hour of SettlementTime
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN a.currency 
				WHEN @BreakBy = 2 THEN ck.Product3rdIdMix
				WHEN @BreakBy = 3 THEN b.custid 
			END,
			CASE WHEN @GroupMode IN (4, 5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdIdMix ELSE -1 END
		HAVING 
			COUNT(1) > 0

	END

	IF @SettleFromDate <= @MovebetDay -- get sum data from @MovebetDay vs backward
	BEGIN
		--SELECT @rptFromDate = @FromDate
		--	, @rptToDate	= IIF(@SettleToDate >= @MovebetDay, @MovebetDay, @SettleToDate);
			
		INSERT INTO #rptData (GroupBy, BreakBy, ParentKey,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, b.SettlementTime), b.SettlementTime))
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, b.SettlementTime), DATEADD(DAY, -DATEPART(DAY, b.SettlementTime) +1, b.SettlementTime))) 
				WHEN @GroupBy = 3 THEN ck.Product3rdId
				WHEN @GroupBy = 4 THEN ISNULL(ISNULL(saba.SabaSportType, b.Sporttype), @NASporttype)
				WHEN @GroupBy = 5 THEN ISNULL(bt.GroupTypeId, bt.bettype) 
				WHEN @GroupBy = 6 THEN a.Currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				WHEN @GroupBy = 10 THEN DATEDIFF(HOUR, @BaseDate, b.SettlementTime) -- group by Hour of SettlementTime
				ELSE 0
			END AS GroupBy, 
			CASE 
				WHEN @BreakBy = 1 THEN a.Currency
				WHEN @BreakBy = 2 THEN ck.Product3rdId
				WHEN @BreakBy = 3 THEN b.custid 
				ELSE a.Currency 
			END AS BreakBy,
			CASE WHEN @GroupMode IN (4,5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdId ELSE -1 END AS ParentKey
			----------------------
			,SUM(b.BetCount) AS BetCount
			,SUM(b.Turnover) AS Turnover
			,SUM(b.NetTurnover) AS NetTurnover
			,SUM(b.Winlost) AS MemWinloss
			,SUM(b.[PComm]) AS [MemComm]
			,-SUM(IIF(b.Product3rdId = 3, 0, b.Winlost)) AS LicWinloss
			,SUM(b.[AComm]) AS [LicComm]
			,-SUM(IIF(b.Product3rdId = 3, (b.Winlost + b.AWinlost + b.AComm), 0)) AS AmtDueToBA
			,SUM(ABS(b.Winlost)) AS BetEffective
			,---------BASE
			SUM(b.Turnover * e.Rate) AS BaseTurnover
			,SUM(b.NetTurnover * e.Rate) AS BaseNetTurnover
			,SUM(b.Winlost * e.Rate) AS BaseMemWinloss
			,SUM(b.[PComm] * e.Rate) AS [BaseMemComm]
			,-SUM(IIF(b.Product3rdId = 3, 0, b.Winlost) * e.Rate) AS BaseLicWinloss
			,SUM(b.[AComm] * e.Rate) AS [BaseLicComm]
			,-SUM(IIF(b.Product3rdId = 3, (b.Winlost + b.AWinlost + b.AComm), 0) * e.Rate) AS BaseAmtDueToBA
			,SUM(ABS(b.Winlost) * e.Rate) AS BaseBetEffective
		 FROM bodb_LicenseeSummary.dbo.rptLicenseeSumWinloss b WITH(NOLOCK)
			INNER JOIN #AgencySel a ON a.recommend = b.recommend
			INNER JOIN #tmpBettype bt ON bt.Bettype = b.Bettype
			INNER JOIN #tmpExchange e on e.ExchangeID =  a.Currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN #tmpSabaSporttype saba ON saba.Sporttype = b.Sporttype AND saba.LeagueGroupID = b.LeagueGroupId AND b.winlostdate >= ISNULL(saba.CutOffDate,b.winlostdate)
			CROSS APPLY (
				SELECT CASE 
					WHEN b.Product3rdId IN (63,69) THEN 0
					WHEN @IsViewCOOnlyCheck = 1 AND b.Product3rdId = 0 AND @SBBACheck & 4 = 4 AND b.TicketType = 1 THEN -99 --Cashout 
					WHEN @IsViewCOOnlyCheck = 1 AND b.Product3rdId = 3 AND @SBBACheck & 8 = 8 AND b.TicketType = 1 THEN -99 --Cashout  
					WHEN bt.ProductId = 1 THEN b.Product3rdId
					ELSE bt.Product3rdId 
				END AS Product3rdId
			) AS ck
			INNER JOIN @PlatformSel bf ON bf.betfrom =  b.BetFrom
			INNER JOIN (
				SELECT DISTINCT Product3rdId FROM #ProductSel
			) AS ps ON ps.Product3rdId = ck.Product3rdId
			INNER JOIN #tmpSettleTime tmpst ON tmpst.SettlementTime = b.SettlementTime
			LEFT JOIN #playerSel psl ON psl.custid = b.custid
		WHERE
			b.WinlostDate <= @MoveBetDay -- avoid reading bettrans before/after MB in twice
			AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
			AND (',' + @LiveIds + ',' LIKE '%,' + CAST(b.liveindicator AS VARCHAR(3)) + ',%')
			AND (b.sporttype <> 0 AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(ISNULL(saba.SabaSportType, b.Sporttype) AS VARCHAR(10)) + ',%'))
			AND NOT (b.Product3rdId IN (0, 3) AND b.TicketType = 1 AND @CashoutModeCheck = 1) --- exclude CO from SB & BA
			AND (@checkPlayer = 0 OR psl.custid > 0)

		GROUP BY 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, b.SettlementTime), b.SettlementTime))
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(HOUR, -DATEPART(HOUR, b.SettlementTime), DATEADD(DAY, -DATEPART(DAY, b.SettlementTime) +1, b.SettlementTime))) 
				WHEN @GroupBy = 3 THEN ck.Product3rdId 
				WHEN @GroupBy = 4 THEN ISNULL(ISNULL(saba.SabaSportType, b.Sporttype), @NASporttype)
				WHEN @GroupBy = 5 THEN ISNULL(bt.GroupTypeId, bt.bettype) 
				WHEN @GroupBy = 6 THEN a.Currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				WHEN @GroupBy = 10 THEN DATEDIFF(HOUR, @BaseDate, b.SettlementTime) -- group by Hour of SettlementTime
				ELSE 0
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN a.Currency
				WHEN @BreakBy = 2 THEN ck.Product3rdId
				WHEN @BreakBy = 3 THEN b.custid
				ELSE a.Currency 
			END,
			CASE WHEN @GroupMode IN (4,5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdId ELSE -1 END
			OPTION (MAXDOP 8)
	END
	
	-- TODO: Cashout separate from SB&BA
	DELETE rpt
	FROM #rptData rpt
	WHERE @IsViewCOOnlyCheck = 1 AND ParentKey IN(0,3); --> 0.SB,3.BA Product3rdId

	-- TODO: Sorting all columns
	--BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
	INSERT INTO #tmpSortValue
	SELECT ParentKey, GroupBy, 
		CASE 
			WHEN @GroupBy = 8 THEN SUBSTRING(c.Username2,CHARINDEX('$',c.Username2)+1,100)	--> Player ExternalId
			WHEN @GroupBy = 9 THEN c.Username	--> Agent SystemId
			ELSE '' END GroupValue,
		(CASE 
			WHEN @SortKey = 1 THEN SUM(BetCount)
			WHEN @SortKey = 2 THEN SUM(BaseTurnover)
			WHEN @SortKey = 3 THEN SUM(BaseNetTurnover)
			WHEN @SortKey = 4 THEN SUM(BaseMemWinloss)
			WHEN @SortKey = 5 THEN SUM(BaseMemComm)
			WHEN @SortKey = 6 THEN SUM(BaseLicWinloss)
			WHEN @SortKey = 7 THEN SUM(BaseLicComm)
			WHEN @SortKey = 8 THEN SUM(BaseAmtDueToBA)
			WHEN @SortKey = 9 THEN SUM(BaseBetEffective)
			WHEN @SortKey = 10 THEN IIF(SUM(BaseNetTurnover)=0, 0, SUM(BaseLicWinloss)/SUM(BaseNetTurnover))
			ELSE GroupBy END
		) AS SortValue
		
	FROM #rptData rpt
		LEFT JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = rpt.GroupBy AND @GroupBy IN (8,9)
	GROUP BY ParentKey, GroupBy,
		CASE 
			WHEN @GroupBy = 8 THEN SUBSTRING(c.Username2,CHARINDEX('$',c.Username2)+1,100) 
			WHEN @GroupBy = 9 THEN c.Username
			ELSE '' END
	;

	TODO_OUTPUT:
	DROP TABLE IF EXISTS #result;
	-- CHECK: @IsExportExcel OR NOT
	SELECT @pageOffset = 0, @PageSize = 2147483647 -- INT.Max
	WHERE @IsExportExcel = 1;
	
	-- TODO: paging
	;WITH paging AS (
		SELECT rIdx, GroupBy, GroupKey, ParentKey
			, rTotal
		FROM (
			SELECT t.GroupBy, t.GroupKey, t.ParentKey,
				COUNT(1) OVER() AS rTotal,
				ROW_NUMBER() OVER(
					ORDER BY 
						CASE WHEN @SortKey	= 0 AND @GroupBy IN (4,5) THEN t.ParentKey ELSE 0 END ASC,
						CASE WHEN @SortKey	= 0 AND @GroupBy IN (8,9) THEN sr.GroupValue ELSE '' END ASC,
						CASE WHEN @SortKey <> 0 AND @SortType = 1 THEN sr.SortValue ELSE 0 END DESC,
						CASE WHEN @SortKey <> 0 AND @SortType = 0 THEN sr.SortValue ELSE 0 END ASC,
					t.GroupOrder ASC
			) AS rIdx
			FROM (
				SELECT DISTINCT FORMAT(DATEADD(HOUR, rpt.GroupBy, @BaseDate), 'yyyy-MM-dd') AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy AS GroupOrder
				FROM #rptData rpt
				WHERE @GroupBy IN(1,2)
				UNION ALL
				SELECT DISTINCT IIF(rpt.GroupBy = 0, 'SB', IIF(rpt.GroupBy = -99,'CO',p3.ProductPrefix)) AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy
				FROM #rptData rpt
				LEFT JOIN bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK) ON p3.ProductID = rpt.GroupBy
				WHERE @GroupBy = 3
				UNION ALL
				SELECT DISTINCT CONCAT(ISNULL(p3.ProductPrefix, IIF(rpt.ParentKey=0,IIF(@SBBACheck=14, 'SB,BA','SB'),IIF(rpt.ParentKey=-99,'CO','N/A'))), '#', rpt.GroupBy) AS GroupBy, rpt.GroupBy AS GroupKey, rpt.ParentKey
					,ISNULL(saba.SportOrder, rpt.GroupBy)
				FROM #rptData rpt
				LEFT JOIN bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK) ON p3.ProductID = rpt.ParentKey
				LEFT JOIN #tmpSabaSporttype saba ON saba.SabaSportType = rpt.GroupBy
				WHERE @GroupBy = 4
				UNION ALL
				SELECT DISTINCT CONCAT(ISNULL(p3.ProductPrefix, IIF(rpt.ParentKey=0,IIF(@SBBACheck=14, 'SB,BA','SB'),IIF(rpt.ParentKey=-99,'CO','N/A'))), '#', rpt.GroupBy) AS GroupBy, rpt.GroupBy AS GroupKey, rpt.ParentKey
					,rpt.GroupBy
				FROM #rptData rpt
				LEFT JOIN bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK) ON p3.ProductID = rpt.ParentKey
				WHERE @GroupBy = 5
				UNION ALL
				SELECT DISTINCT CAST(rpt.GroupBy AS NVARCHAR(100)) AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy
				FROM #rptData rpt
				WHERE @GroupBy = 6
				UNION ALL
				SELECT DISTINCT CAST(rpt.GroupBy AS NVARCHAR(100)) AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy
				FROM #rptData rpt
				WHERE @GroupBy = 7
				UNION ALL
				SELECT DISTINCT CONCAT(ci.username,'#',ck.ExternalID) AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy
				FROM #rptData rpt
				INNER JOIN dbo.Customer ci WITH(NOLOCK) ON ci.custid = rpt.GroupBy
				CROSS APPLY (SELECT SUBSTRING(ci.username2,CHARINDEX('$',ci.username2)+1,100) AS ExternalID) AS ck
				WHERE @GroupBy = 8
				UNION ALL
				SELECT DISTINCT ci.username AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy
				FROM #rptData rpt
				INNER JOIN dbo.Customer ci WITH(NOLOCK) ON ci.custid = rpt.GroupBy
				WHERE @GroupBy = 9
				UNION ALL
				SELECT DISTINCT FORMAT(DATEADD(HOUR, rpt.GroupBy, @BaseDate), 'yyyy-MM-dd > HH:00 - HH:59') AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy AS GroupOrder
				FROM #rptData rpt
				WHERE @GroupBy = 10
				
			) AS t
			INNER JOIN #tmpSortValue sr ON sr.GroupKey = t.GroupKey AND 1 = CASE WHEN @GroupMode IN (4,5) AND sr.ParentKey <> t.ParentKey THEN 0 ELSE 1 END
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
			IIF(SUM(BaseNetTurnover)=0,0,SUM(BaseLicWinloss)/SUM(BaseNetTurnover)) AS [Margin]
			,----BASE
			SUM(BaseTurnover) AS BaseTurnover, SUM(BaseNetTurnover) AS BaseNetTurnover, 
			SUM(BaseMemWinloss) AS BaseMemWinloss, SUM(BaseMemComm) AS BaseMemComm, 
			SUM(BaseLicWinloss) AS BaseLicWinloss, SUM(BaseLicComm) AS BaseLicComm,
			SUM(BaseAmtDueToBA) AS BaseAmtDueToBA, SUM(BaseBetEffective) AS BaseBetEffective
		FROM paging p
		INNER JOIN #rptData rpt ON rpt.GroupBy = p.GroupKey AND 1 = CASE WHEN @GroupMode IN (4,5) AND rpt.ParentKey <> p.ParentKey THEN 0 ELSE 1 END
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
		SELECT rs.rIdx, rs.GroupBy, rs.GroupKey, CAST(rs.BreakBy AS NVARCHAR(100)) AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		FROM #result rs
		WHERE @BreakBy = 1
		UNION ALL
		SELECT rs.rIdx, rs.GroupBy,	rs.GroupKey, IIF(rs.BreakBy = 0, 'SB', IIF(rs.BreakBy = -99, 'CO', p3.ProductPrefix)) AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover,	NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective,Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		FROM #result rs
			LEFT JOIN bodb_licensee.dbo.Product3rd p3 WITH(NOLOCK) ON p3.ProductID = rs.BreakBy
		WHERE @BreakBy = 2
		UNION ALL
		SELECT rs.rIdx, rs.GroupBy,	rs.GroupKey, CONCAT(ci.username,'#',ck.ExternalID) AS BreakBy, rs.BreakBy AS BreakOrder,
			BetCount, Turnover,	NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
			,-----BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		FROM #result rs
			INNER JOIN dbo.Customer ci WITH(NOLOCK) ON ci.custid = rs.BreakBy
			CROSS APPLY (SELECT SUBSTRING(ci.username2,CHARINDEX('$',ci.username2)+1,100) AS ExternalID) AS ck
		WHERE @BreakBy = 3
	) AS rs
	ORDER BY rs.rIdx, rs.GroupKey, 
		CASE 
			WHEN @BreakBy = 3 THEN SUBSTRING(rs.BreakBy,CHARINDEX('#',rs.BreakBy)+1,100) 
			ELSE '' END ASC,
		rs.BreakOrder ASC

	SELECT rs.rIdx, rs.GroupBy,	
		SUM(BetCount) AS BetCount, SUM(Turnover) AS Turnover, SUM(NetTurnover) AS NetTurnover, 
		SUM(MemWinloss) AS MemWinloss, SUM(MemComm) AS MemComm, 
		SUM(LicWinloss) AS LicWinloss, SUM(LicComm) AS LicComm, 
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(BetEffective) AS BetEffective, 
		IIF(SUM(BaseNetTurnover)=0,0,SUM(BaseLicWinloss)/SUM(BaseNetTurnover)) AS [Margin]
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
		SUM(AmtDueToBA) AS AmtDueToBA, SUM(BetEffective) AS BetEffective, 
		IIF(SUM(BaseNetTurnover)=0,0,SUM(BaseLicWinloss)/SUM(BaseNetTurnover)) AS [Margin]
		,-----BASE
		SUM(BaseTurnover) AS BaseTurnover, SUM(BaseNetTurnover) AS BaseNetTurnover, 
		SUM(BaseMemWinloss) AS BaseMemWinloss, SUM(BaseMemComm) AS BaseMemComm, 
		SUM(BaseLicWinloss) AS BaseLicWinloss, SUM(BaseLicComm) AS BaseLicComm,
		SUM(BaseAmtDueToBA) AS BaseAmtDueToBA, SUM(BaseBetEffective) AS BaseBetEffective
	FROM #rptData

	SELECT DATEDIFF(MILLISECOND, @startTime, CURRENT_TIMESTAMP) AS Duration_Ms

END
GO
