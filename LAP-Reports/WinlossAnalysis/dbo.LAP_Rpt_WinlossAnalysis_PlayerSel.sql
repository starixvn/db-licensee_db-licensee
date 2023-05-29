/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.LAP_Rpt_WinlossAnalysis_PlayerSel
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MovebetDay		SMALLDATETIME,
	@AgentList		XML,

	----------filtering
	@BaseCurrency	VARCHAR(10)		= 'EUR',
	@ProductCodes	VARCHAR(MAX)	= 'ALL', --'SB,NG,etc...'
	@SportIds		VARCHAR(MAX)	= 'ALL',
	@BettypeIds		VARCHAR(MAX)	= 'ALL',
	@StatusIds		VARCHAR(1000)	= 'ALL',
	@PlatformIds	VARCHAR(1000)	= 'ALL',
	@LiveStatusIds	VARCHAR(1000)	= 'ALL',

	------ player 
	@IsVIPOnly		BIT = 0,
	@CustomerClass	VARCHAR(1000) = 'ALL',
	@OddsGroup		VARCHAR(1000) = 'ALL',
	@SearchMode		TINYINT	= 1,
	@SearchUserName	VARCHAR(50) = NULL,

	-- grouping
	@IsViewCOOnly	BIT = 0,
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
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - Player mode
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]

	Param's Explanation:
		- @SortKey: 0:GroupBy, 1:BetCount, 2:Turnover, 3:NetTurnover, 4:MemWinloss, 5:MemComm, 6:LicWinloss, 7:LicComm, 8:AmtDueToBA, 9:BetEffective, 10:Margin
		- @SortType: 0:ASC,1:DESC
		- @SearchMode: TINYINT
			+ 1: Match Precise
			+ 2: Match Case
		
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
		@IsVIPOnlyCheck	BIT,
		@CustClassCheck	VARCHAR(1000),
		@OddsGroupCheck	VARCHAR(1000),
		@SearchModeCheck	INT,
		@SearchUsernameCheck VARCHAR(50),
		@GroupBy		TINYINT,
		@BreakBy		TINYINT,
		@IsExportExcel	BIT,
		@BaseDate		SMALLDATETIME = '2000-01-01',
		@IsViewCOOnlyCheck BIT,
		@BettypeIdsCheck	VARCHAR(MAX),
		@NASporttype	SMALLINT = 0
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

		----------------Default values 
		@ProductCodes	= IIF(@ProductCodes='ALL', NULL, @ProductCodes),
		@SportIds		= IIF(@SportIds='ALL', NULL, @SportIds),
		@BettypeIds		= IIF(@BettypeIds='ALL', NULL, @BettypeIds),
		@StatusCheck	= IIF(@StatusIds='ALL', '111,112,113,114,115', @StatusIds),
		@LiveIds		= IIF(@LiveStatusIds='ALL', '0,1,2', @LiveStatusIds),
		@PlatformCheck	= IIF(@PlatformIds IS NULL, 'ALL', @PlatformIds),
		@CustClassCheck	= IIF(@CustomerClass = 'ALL', NULL, @CustomerClass),
		@OddsGroupCheck	= IIF(@OddsGroup = 'ALL', NULL, @OddsGroup),
		@SearchModeCheck		= @SearchMode,
		@SearchUsernameCheck	= @SearchUsername,
		@IsVIPOnlyCheck	= ISNULL(@IsVIPOnly,0),
		@IsViewCOOnlyCheck = ISNULL(@IsViewCOOnly, 0),
		---- EXPORT
		@IsExportExcel	= IIF(@PageIndex=0 AND @PageSize=0, 1, 0)
		;

	DROP TABLE IF EXISTS #rptData;
	CREATE TABLE #rptData(
		GroupBy INT, BreakBy INT, ParentKey INT,
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
		BaseBetEffective	MONEY
	);
	CREATE CLUSTERED INDEX CIX_rptData ON #rptData(GroupBy, BreakBy);

	-- VALIDATE: Group modes
	DECLARE @IsValidGroupMode BIT = 0;
	SELECT @IsValidGroupMode = CASE 
							WHEN @GroupMode IN (3,4,5) AND @BreakdownMode = 2 THEN 0
							WHEN @GroupMode IN (6) AND @BreakdownMode = 1 THEN 0
							ELSE 1
						END,
			@GroupBy	= @GroupMode,
			@BreakBy	= @BreakdownMode;

	DROP TABLE IF EXISTS #tmpSabaSporttype;
	CREATE TABLE #tmpSabaSporttype (SabaSportType INT, SportType INT, LeagueGroupID INT, SportOrder INT);

	IF @IsValidGroupMode = 0
	BEGIN
		SET @Error = 'Invalid group mode. No data found.'
		GOTO TODO_OUTPUT;
	END

	DROP TABLE IF EXISTS #AgencySel;
	DROP TABLE IF EXISTS #ProductSel;
	CREATE TABLE #AgencySel	(recommend INT PRIMARY KEY, Currency INT);
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
	
	--TODO: Event Products, Sports, Bettypes selection
	INSERT INTO #tmpSabaSporttype
	SELECT saba.SabaSportType, t.SportType, t.LeagueGroupID, saba.SportOrder
	FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
	OUTER APPLY
	(
		SELECT LeagueGroupID, Sporttype
		FROM OPENJSON(saba.SporttypeRef)
		WITH (Sporttype INT '$.Sporttype',
			LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
		)
		OUTER APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID INT '$')
	) AS t

	--TODO: Sports filtering
	SELECT @SportCheck = @SportIds;

	--TODO: BA/SLT/BTC products
	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2) 
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 3)),
			@ProductCheck = @ProductCodes;

	--TODO: Convert GroupBettype
	SELECT @BettypeIdsCheck = @BettypeIds;

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
	SELECT ProductId, Bettype, RefTable, EventType,IsContributionBettype,
		CASE WHEN ProductID = 1 THEN @SBBACheck ELSE Product3rdID END AS Product3rdId,
		IsPriceBettype,
		GroupTypeId
	FROM bodb02.dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductCheck, @SportCheck, @BettypeIdsCheck, @SBBACheck) AS bm

	;WITH CTE_ProductMap AS (
		SELECT DISTINCT ProductId, Product3rdId
		FROM #tmpBettype t
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

	--TODO: Player selection
	DROP TABLE IF EXISTS #playerSel;
	CREATE TABLE #playerSel (custid INT PRIMARY KEY, Currency INT);
	IF (
		@IsVIPOnlyCheck = 1
		OR @CustClassCheck IS NOT NULL
		OR @OddsGroupCheck IS NOT NULL
		OR LEN(@SearchUsernameCheck) > 0
	)
	BEGIN
		-- TODO: Search player
		INSERT INTO #playerSel(custid, Currency)
		SELECT c.CustID, ag.Currency
		FROM bodb02.dbo.vw_Customer c WITH(NOLOCK)
		INNER JOIN #AgencySel ag ON ag.recommend = c.recommend
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid = c.custid
		LEFT JOIN bodb02.dbo.Dep_CustVIP vip ON c.custid = vip.CustID
		WHERE c.roleid = 1
			AND (@SearchUsernameCheck IS NULL OR (
				(@SearchModeCheck = 1 AND (c.username2 LIKE  + '%$' + @SearchUsernameCheck OR c.username LIKE  @SearchUsernameCheck))) OR
				(@SearchModeCheck = 2 AND (c.username2 LIKE  + '%$%' + @SearchUsernameCheck + '%' OR c.username LIKE  '%' + @SearchUsernameCheck + '%'))
			)
			AND (@OddsGroupCheck IS NULL
				OR ',' + @OddsGroupCheck + ',' LIKE '%,' + c.ugroup + ',%')
			AND (@CustClassCheck IS NULL
				OR ',' + @CustClassCheck + ',' LIKE '%,0,%' AND CONVERT(VARCHAR(6), ci.CustomerClass) IS NULL
				OR ',' + @CustClassCheck + ',' LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%')
			AND (@IsVIPOnlyCheck = 0 OR vip.CustID > 0);
	END

	--TODO: Exchange rate
	DROP TABLE IF EXISTS #tmpExchange;
	CREATE TABLE #tmpExchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT);
	CREATE CLUSTERED INDEX CIX_tmpExchange ON #tmpExchange(ExchangeID);

	INSERT INTO #tmpExchange
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT TOP 1 1 FROM #AgencySel a WHERE a.Currency = e.ExchangeID)

	-- TODO: filter raw data
	IF @ToDate > @MovebetDay --> get data in bettrans
	BEGIN
		SELECT @rptFromDate = IIF(@FromDate > @MovebetDay, @Fromdate, DATEADD(DAY, 1, @MovebetDay))
			, @rptToDate	= @ToDate;

		INSERT INTO #rptData (GroupBy, BreakBy, ParentKey,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN ck.Product3rdIdMix
				WHEN @GroupBy = 4 THEN ISNULL(ck.sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN ISNULL(s.GroupTypeId, s.bettype) 
				WHEN @GroupBy = 6 THEN a.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				ELSE 0
			END AS GroupBy, 
			CASE 
				WHEN @BreakBy = 1 THEN a.currency 
				WHEN @BreakBy = 2 THEN ck.Product3rdIdMix
				WHEN @BreakBy = 3 THEN b.custid 
				ELSE a.currency 
			END AS BreakBy,
			CASE WHEN @GroupMode IN (4,5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdIdMix ELSE -1 END
			----------------------
			,COUNT(1) AS BetCount
			,SUM(ck.Turnover) AS Turnover
			,SUM(ck.NetTurnover) AS NetTurnover
			,SUM(ck.MemWinloss) AS MemWinloss
			,SUM(b.playercomm) AS [MemComm]
			,-SUM(ck.MemWinloss) AS LicWinloss
			,SUM(b.comm) AS [LicComm]
			,SUM(ck.AmtDueToBA) AS AmtDueToBA
			,SUM(ABS(ck.MemWinloss)) AS BetEffective
			,---------BASE
			SUM(ck.Turnover * e.Rate) AS BaseTurnover
			,SUM(ck.NetTurnover * e.Rate) AS BaseNetTurnover
			,SUM(ck.MemWinloss * e.Rate) AS BaseMemWinloss
			,SUM(b.playercomm * e.Rate) AS [BaseMemComm]
			,-SUM(ck.MemWinloss * e.Rate) AS BaseLicWinloss
			,SUM(b.comm * e.Rate) AS [BaseLicComm]
			,SUM(ck.AmtDueToBA * e.Rate) AS BaseAmtDueToBA
			,SUM(ABS(ck.MemWinloss) * e.Rate) AS BaseBetEffective
		FROM [bodb02].[dbo].[bettrans] b WITH(NOLOCK)
			INNER JOIN #playerSel a WITH(NOLOCK) on a.custid = b.custid
			INNER JOIN #tmpBettype s ON s.bettype = b.bettype AND s.RefTable NOT IN (1,2)
			INNER JOIN #tmpExchange e on e.ExchangeID =  a.Currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN [bodb02].dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN [bodb02].[dbo].[Match3rd] m3rd WITH(NOLOCK) ON m3rd.Match3rdId = b.matchid
			LEFT JOIN [bodb02].dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid AND l.LeagueGroupID IN (42,74,108,113,122,151)
			LEFT JOIN [bodb02].dbo.outright o WITH(NOLOCK) ON b.matchid = o.orid
			LEFT JOIN [bodb02].dbo.League lo WITH (NOLOCK) ON lo.leagueid = o.leagueid
			LEFT JOIN [bodb02].dbo.VSRaceInfo vs WITH(NOLOCK) ON b.matchid = vs.EventID
			LEFT JOIN [bodb_licensee].dbo.LicenseeBATransaction_active AS lba WITH (NOLOCK) ON b.transid = lba.transid
			LEFT JOIN #tmpSabaSporttype saba ON s.ProductId = 1 AND saba.Sporttype = m.Sporttype AND saba.LeagueGroupID = l.LeagueGroupID
			OUTER APPLY (
				SELECT 
					IIF(lba.TransID IS NOT NULL, 1, 0) AS IsBA,
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
								WHEN b.matchid = 2799 THEN b.oddsid --VS Sports
								ELSE b.matchid
							END
						WHEN s.EventType = 1 THEN ISNULL(saba.SabaSportType, m.sporttype)
						WHEN s.EventType = 2 THEN lo.sporttype
						WHEN s.EventType = 3 THEN vs.SportType
						WHEN s.EventType = 5 THEN m3rd.SportType --175-BTC Sport
						ELSE @NASporttype
					END AS SportType,
					ISNULL(CASE WHEN b.bettype IN(29) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
			) AS ck
			CROSS APPLY (SELECT TOP 1 bf.PlatformId FROM @PlatformSel bf WHERE b.betfrom =  bf.BetFrom) AS bf
			CROSS APPLY (SELECT TOP 1 ps.Product3rdId FROM #ProductSel ps WHERE ck.Product3rdIdMix = ps.Product3rdId) AS ps
		WHERE b.winlostdate BETWEEN @rptFromDate AND @rptToDate
			AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
			AND (',' + @LiveIds + ',' LIKE '%,' + CAST(ck.liveindicator AS VARCHAR(3)) + ',%')
			AND (ck.sporttype <> 0 AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(ck.sporttype AS VARCHAR(10)) + ',%'))
		
		GROUP BY CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN ck.Product3rdIdMix
				WHEN @GroupBy = 4 THEN ISNULL(ck.sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN ISNULL(s.GroupTypeId, s.bettype) 
				WHEN @GroupBy = 6 THEN a.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId,-1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				ELSE 0
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN a.currency 
				WHEN @BreakBy = 2 THEN ck.Product3rdIdMix
				WHEN @BreakBy = 3 THEN b.custid 
				ELSE a.currency 
			END,
			CASE WHEN @GroupMode IN (4,5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdIdMix ELSE -1 END
		HAVING 
			COUNT(1) > 0
		;
			

		;----TODO: get data from bettransLC/RnG for 3rd Products
		INSERT INTO #rptData (GroupBy, BreakBy, ParentKey,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA,BetEffective
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN b.Product3rdID
				WHEN @GroupBy = 4 THEN ISNULL(b.sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId,-1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				ELSE 0
			END AS GroupBy, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 THEN b.Product3rdID
				WHEN @BreakBy = 3 THEN b.custid 
				ELSE b.currency 
			END AS BreakBy,
			CASE WHEN @GroupMode IN (4, 5) OR @IsViewCOOnlyCheck = 1 THEN b.Product3rdId ELSE -1 END AS ParentKey
			--------------
			,SUM(BetCount) AS BetCount
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
			SELECT b.CustId, b.recommend, a.currency, b.winlostdate, s.Product3rdId, b.productID AS Sporttype
				,ISNULL(s.GroupTypeId, s.bettype) AS Bettype, b.betfrom, b.StatusId
				,COUNT(1) AS BetCount
				,SUM(CASE WHEN s.IsContributionBettype = 0 THEN b.BetStake ELSE 0 END) AS NetTurnover
				,SUM(b.stake) AS stake, SUM(b.actual_stake) AS actual_stake, SUM(b.playercomm) AS playercomm, SUM(b.comm) AS comm, SUM(b.winlost) AS winlost
			FROM bodb02.dbo.bettransRnG b WITH(NOLOCK)
				INNER JOIN #tmpBettype s ON s.Bettype = b.gameID AND s.RefTable = 1
				INNER JOIN #playerSel a ON a.custid = b.custid
			WHERE b.winlostdate BETWEEN @rptFromDate AND @rptToDate
				AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (',' + @LiveIds + ',' LIKE '%,0,%')
				AND 1 = CASE 
						WHEN s.Product3rdId IN (42) AND s.Bettype IN (1698,1699) AND b.ProductID <> 150 THEN 1 
						WHEN s.Product3rdId IN (66) AND s.Bettype IN (3898,3899) AND b.ProductID <> 173 THEN 1
						WHEN s.IsPriceBettype > 0 THEN 0
						ELSE 1
					END
			GROUP BY
				b.CustId, b.recommend, a.currency, b.winlostdate, s.Product3rdId, b.productID
				,ISNULL(s.GroupTypeId, s.bettype), b.betfrom, b.StatusId

			UNION ALL 
			SELECT b.CustId, b.recommend, a.currency, b.winlostdate, s.Product3rdId, b.productID AS Sporttype
				,ISNULL(s.GroupTypeId, s.bettype) AS Bettype, b.betfrom, b.statusID
				,COUNT(1) AS BetCount
				,SUM(CASE WHEN s.IsContributionBettype = 0 THEN b.NetStake ELSE 0 END) AS NetTurnover
				,SUM(b.stake) AS stake, SUM(b.actual_stake) AS actual_stake, SUM(b.playercomm) AS playercomm, SUM(b.comm) AS comm, SUM(b.winlost) AS winlost
			FROM bodb02.dbo.bettransLC b WITH(NOLOCK)
				INNER JOIN #tmpBettype s ON s.Bettype = b.gameID AND s.RefTable = 2
				INNER JOIN #playerSel a ON a.custid = b.custid
			WHERE b.winlostdate BETWEEN @rptFromDate AND @rptToDate
				AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
				AND (',' + @LiveIds + ',' LIKE '%,0,%')
			GROUP BY
				b.CustId, b.recommend, a.currency, b.winlostdate, s.Product3rdId, b.productID
				,ISNULL(s.GroupTypeId, s.bettype), b.betfrom, statusID
				
		) AS b
		INNER JOIN #tmpExchange e on e.ExchangeID =  b.Currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
		CROSS APPLY (SELECT TOP 1 bf.PlatformId FROM @PlatformSel bf WHERE b.betfrom =  bf.BetFrom) AS bf
		WHERE 
			(@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(b.sporttype AS VARCHAR(10)) + ',%')

		GROUP BY
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate))  
				WHEN @GroupBy = 3 THEN b.Product3rdID
				WHEN @GroupBy = 4 THEN ISNULL(b.sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN b.bettype 
				WHEN @GroupBy = 6 THEN b.currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId,-1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				ELSE 0
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN b.currency 
				WHEN @BreakBy = 2 THEN b.Product3rdID
				WHEN @BreakBy = 3 THEN b.custid 
				ELSE b.currency 
			END,
			CASE WHEN @GroupMode IN (4, 5) OR @IsViewCOOnlyCheck = 1 THEN b.Product3rdId ELSE -1 END
	END

	IF @FromDate <= @MovebetDay -- get sum data from @MovebetDay
	BEGIN
		SELECT @rptFromDate = @FromDate
			, @rptToDate	= IIF(@ToDate >= @MovebetDay, @MovebetDay, @ToDate);

		INSERT INTO #rptData (GroupBy, BreakBy, ParentKey,
			BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective
			,------BASE
			BaseTurnover, BaseNetTurnover, BaseMemWinloss, BaseMemComm, BaseLicWinloss, BaseLicComm, BaseAmtDueToBA, BaseBetEffective
		)
		SELECT 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN ck.Product3rdIdMix
				WHEN @GroupBy = 4 THEN ISNULL(ck.Sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN ISNULL(bt.GroupTypeId, bt.bettype) 
				WHEN @GroupBy = 6 THEN a.Currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				ELSE 0
			END AS BreakBy, 
			CASE 
				WHEN @BreakBy = 1 THEN a.Currency
				WHEN @BreakBy = 2 THEN ck.Product3rdIdMix
				WHEN @BreakBy = 3 THEN b.custid 
				ELSE a.Currency 
			END AS BreakBy,
			CASE WHEN @GroupMode IN (4,5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdIdMix ELSE -1 END AS ParentKey
			----------------------
			,SUM(b.BetCount) AS BetCount
			,SUM(b.Turnover) AS Turnover
			,SUM(b.NetTurnover) AS NetTurnover
			,SUM(b.Winlost) AS MemWinloss
			,SUM(b.[PComm]) AS [MemComm]
			,SUM(ck.[LicWinloss]) AS LicWinloss
			,SUM(b.[AComm]) AS [LicComm]
			,SUM(ck.AmtDueToBA) AS AmtDueToBA
			,SUM(ABS(b.Winlost)) AS BetEffective
			,---------BASE
			SUM(b.Turnover * e.Rate) AS BaseTurnover
			,SUM(b.NetTurnover * e.Rate) AS BaseNetTurnover
			,SUM(b.Winlost * e.Rate) AS BaseMemWinloss
			,SUM(b.[PComm] * e.Rate) AS [BaseMemComm]
			,SUM(ck.[LicWinloss] * e.Rate) AS BaseLicWinloss
			,SUM(b.[AComm] * e.Rate) AS [BaseLicComm]
			,SUM(ck.AmtDueToBA * e.Rate) AS BaseAmtDueToBA
			,SUM(ABS(b.Winlost) * e.Rate) AS BaseBetEffective
		 FROM bodb_LicenseeReport.dbo.rptLicenseeWinloss b WITH(NOLOCK)
			INNER JOIN #playerSel a ON a.custid = b.CustId
			INNER JOIN #tmpBettype bt ON bt.Bettype = b.Bettype
			INNER JOIN #tmpExchange e on e.ExchangeID =  a.Currency AND b.winlostdate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN #tmpSabaSporttype saba ON saba.Sporttype = b.Sporttype AND saba.LeagueGroupID = b.LeagueGroupId
			OUTER APPLY (
				SELECT -(CASE
						WHEN b.Product3rdId = 3 THEN (b.Winlost + b.AWinlost + b.AComm) --COUNT for BA's tickets
						ELSE 0
					END) AS AmtDueToBA,
					-(CASE WHEN b.Product3rdId = 3 THEN 0 ELSE b.winlost END) AS [LicWinloss],
					ISNULL(saba.SabaSportType, b.Sporttype) AS Sporttype,
					CASE 
						WHEN b.Product3rdId IN (63,69) THEN 0 
						WHEN @IsViewCOOnlyCheck = 1 AND b.Product3rdId = 0 AND @SBBACheck & 4 = 4 AND b.TicketType = 1 THEN -99 --Cashout 
						WHEN @IsViewCOOnlyCheck = 1 AND b.Product3rdId = 3 AND @SBBACheck & 8 = 8 AND b.TicketType = 1 THEN -99 --Cashout 
						ELSE b.Product3rdId 
					END AS Product3rdIdMix
			) AS ck
			CROSS APPLY (SELECT TOP 1 bf.PlatformId FROM @PlatformSel bf WHERE b.betfrom =  bf.BetFrom) AS bf
			CROSS APPLY (SELECT TOP 1 ps.Product3rdId FROM #ProductSel ps WHERE ck.Product3rdIdMix = ps.Product3rdId) AS ps
		WHERE
			b.WinlostDate BETWEEN @rptFromDate AND @rptToDate
			AND ',' + @StatusCheck + ',' LIKE '%,' + CAST(b.statusID AS VARCHAR(3)) + ',%'
			AND (',' + @LiveIds + ',' LIKE '%,' + CAST(b.liveindicator AS VARCHAR(3)) + ',%')
			AND (ck.Sporttype <> 0 AND (@SportIDs IS NULL OR  ',' + @SportIDs + ',' LIKE '%,' + CAST(ck.Sporttype AS VARCHAR(10)) + ',%'))
			AND 1 = CASE 
						WHEN b.Product3rdId IN (42) AND b.Bettype IN (1698,1699) AND b.Sporttype <> 150 THEN 1 
						WHEN b.Product3rdId IN (66) AND b.Bettype IN (3898,3899) AND b.Sporttype <> 173 THEN 1
						WHEN bt.IsPriceBettype > 0 THEN 0
						ELSE 1
					END

		GROUP BY 
			CASE 
				WHEN @GroupBy = 1 THEN DATEDIFF(HOUR, @BaseDate, b.winlostdate)
				WHEN @GroupBy = 2 THEN DATEDIFF(HOUR, @BaseDate, DATEADD(DAY, -DATEPART(DAY, b.Winlostdate) +1, b.Winlostdate)) 
				WHEN @GroupBy = 3 THEN ck.Product3rdIdMix
				WHEN @GroupBy = 4 THEN ISNULL(ck.Sporttype, @NASporttype) 
				WHEN @GroupBy = 5 THEN ISNULL(bt.GroupTypeId, bt.bettype) 
				WHEN @GroupBy = 6 THEN a.Currency
				WHEN @GroupBy = 7 THEN ISNULL(bf.platformId, -1)
				WHEN @GroupBy = 8 THEN b.custid
				WHEN @GroupBy = 9 THEN b.recommend
				ELSE 0
			END, 
			CASE 
				WHEN @BreakBy = 1 THEN a.Currency
				WHEN @BreakBy = 2 THEN ck.Product3rdIdMix
				WHEN @BreakBy = 3 THEN b.custid 
				ELSE a.Currency 
			END,
			CASE WHEN @GroupMode IN (4,5) OR @IsViewCOOnlyCheck = 1 THEN ck.Product3rdIdMix ELSE -1 END
	END
	
	-- TODO: Cashout separate from SB&BA
	DELETE rpt
	FROM #rptData rpt
	WHERE @IsViewCOOnlyCheck = 1 AND ParentKey IN(0,3);

	-- TODO: Sorting all columns
	--BetCount, Turnover, NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
	DROP TABLE IF EXISTS #tmpSortValue;
	CREATE TABLE #tmpSortValue (GroupKey INT PRIMARY KEY, GroupValue VARCHAR(100), SortValue MONEY);

	INSERT INTO #tmpSortValue
	SELECT GroupBy, 
		CASE 
			WHEN @GroupBy = 8 THEN SUBSTRING(c.Username2,CHARINDEX('$',c.Username2)+1,100)	--> Player ExternalId
			WHEN @GroupBy = 9 THEN c.Username	--> Agent SystemId
			ELSE '' END GroupValue,
		(CASE 
			WHEN @SortKey = 1 THEN SUM(BetCount)
			WHEN @SortKey = 2 THEN SUM(Turnover)
			WHEN @SortKey = 3 THEN SUM(NetTurnover)
			WHEN @SortKey = 4 THEN SUM(MemWinloss)
			WHEN @SortKey = 5 THEN SUM(MemComm)
			WHEN @SortKey = 6 THEN SUM(LicWinloss)
			WHEN @SortKey = 7 THEN SUM(LicComm)
			WHEN @SortKey = 8 THEN SUM(AmtDueToBA)
			WHEN @SortKey = 9 THEN SUM(BetEffective)
			WHEN @SortKey = 10 THEN IIF(SUM(NetTurnover)=0, 0, SUM(LicWinloss)/SUM(NetTurnover))
			ELSE GroupBy END
		) AS SortValue
	FROM #rptData rpt
		LEFT JOIN dbo.vw_Customer c WITH(NOLOCK) ON c.custid = rpt.GroupBy AND @GroupBy IN (8,9)
	GROUP BY GroupBy,
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
				INNER JOIN bodb02.dbo.vw_Customer ci WITH(NOLOCK) ON ci.custid = rpt.GroupBy
				CROSS APPLY (SELECT SUBSTRING(ci.username2,CHARINDEX('$',ci.username2)+1,100) AS ExternalID) AS ck
				WHERE @GroupBy = 8
				UNION ALL
				SELECT DISTINCT ci.username AS GroupBy, rpt.GroupBy AS GroupKey, 0 AS ParentKey
					,rpt.GroupBy
				FROM #rptData rpt
				INNER JOIN bodb02.dbo.vw_Customer ci WITH(NOLOCK) ON ci.custid = rpt.GroupBy
				WHERE @GroupBy = 9
			) AS t
			INNER JOIN #tmpSortValue sr ON sr.GroupKey =  t.GroupKey
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
			BetCount, Turnover,	NetTurnover, MemWinloss, MemComm, LicWinloss, LicComm, AmtDueToBA, BetEffective, Margin
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
			INNER JOIN bodb02.dbo.vw_Customer ci WITH(NOLOCK) ON ci.custid = rs.BreakBy
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