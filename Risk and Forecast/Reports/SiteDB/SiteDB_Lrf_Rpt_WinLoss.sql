/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[SiteDB_Lrf_Rpt_WinLoss]
	@AgentList		VARCHAR(MAX),
	@UserName		VARCHAR(50)	= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@showSB			BIT = 0,
	@showNG			BIT = 0,
	@ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0,	-- RNG Casino
	@ShowKN			BIT = 0,
	@ShowBT			BIT = 0,
	@ShowAGC		BIT = 0,
	@ShowVB			BIT = 0,
	@ShowAB			BIT = 0,
	@ShowFW			BIT = 0,
	@ShowCO			BIT = 0,
	@ShowVS2		BIT = 0,	-- Bet Radar Virtual Sports
	@ShowLT			BIT = 0,	-- Lottery
	@ShowPP			BIT = 0,	-- PP
	@ShowCC			BIT = 0,	-- Card club
	@ShowSG			BIT = 0,	-- SpadeGaming
	@ShowVRG		BIT = 0,	-- Virtual Games
	@ShowTG			BIT = 0,	-- Table Games
	@ShowI4D		BIT = 0,	-- Indo 4D
	@ShowSXG		BIT = 0,	-- Sexy Gaming
	@ShowSBC		BIT = 0,	-- Saba club
	@ShowSAG		BIT = 0,	-- SA Gaming
	@ShowPGS		BIT = 0,	-- PG Soft
	@ShowJK			BIT = 0,	-- Joker
	@ShowGDG		BIT = 0,	-- GDG
	@ShowSLT		BIT = 0,	-- SLT
	@ShowHB			BIT = 0,	-- Habanero
	@ShowWM			BIT = 0,	-- WM Live Casino
	@ShowBGG		BIT = 0,	-- Big Gaming
	@ShowVGA		BIT = 0,	-- Vgaming
	@ShowCG			BIT = 0,	-- Creative Gaming
	@ShowAP			BIT = 0,	-- AdvantPlay
	@ShowAPM		BIT = 0,	-- AdvantPlay Mini
	@ShowVS3		BIT = 0,	-- Virtual Sports 3
	@ShowBTC		BIT = 0, 	-- Bitcoin
	@ShowFGGL		BIT = 0,	-- FGG Guaranteed Gaming
	@ShowMXG		BIT = 0, 	-- MaxGame
	@DrawFilter				SMALLINT		= 1,
	@CustomerClass			VARCHAR(MAX)	= 'All',
	@OddsGroup				VARCHAR(100)	= 'All',
	@CheckPromotionPrize	BIT				= 0,
	@PageSize				INT				= 1000,
	@PageIndex				INT				= 1,
	@OrderItem				TINYINT			= 1,
	@IsAscSort				BIT				= 1,
	@BaseCurrency			VARCHAR(12)		= '',
	@ErrCode				INT				= 0 OUTPUT,
	@ErrMsg					NVARCHAR(200)	= '' OUTPUT
AS

/*
	Created by: [20220801@Sol]
	Task: Customer Reports - Customer Winloss
	DB: DBSID/bodb02

	Revisions:
		- 20220801@Sol: initial sp - [Redmine: #175297]
   		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

	Param's Explanation:
		@OrderItem:
			1: username
			2: UserName2
			3: TurnOver
			4: MemberWinLost
			5: BetEffective
			6: LicenseeWL
			7: WinlossRB
			8: CommBA
			9: commRB
			10: PlayerComm
			11: AmtDuetoBA
			13: BetCount
			14: CustomerTotalWL

		@IsAscSort:
			1: ASC
			2: DESC

		@CheckPromotionPrize: = 1 if want to check whether have promotion prize ticket or not

		+ @DrawFilter:	1 - Filter Nomal (Win, Lose, Draw)
						2 - Filter bets No Draw (Win, Draw)
						3 - Filter No Draw For turnover only: include betcount, exclude stake 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT PRIMARY KEY, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;
	-------End Get AgentList

	IF @OrderItem < 1 OR @OrderItem > 14
	BEGIN
		SET @OrderItem = 1
	END

	DECLARE @_FromDate		SMALLDATETIME,
			@_ToDate		SMALLDATETIME,
			@_ShowBA		BIT,
			@_ShowSB		BIT,
			@_ShowBT		BIT,
			@_ShowCO		BIT,
			@_DrawFilter	SMALLINT,
			@RowStart		INT,
			@RowEnd			INT,
			@TempFromDate	SMALLDATETIME,
			@TempToDate		SMALLDATETIME,
			@ProductList	VARCHAR(MAX)

	DECLARE @IsTest				BIT = 0
	DECLARE @isSearchCust		BIT = 0

	DECLARE @Products		TABLE (Code VARCHAR(10))
	
	DECLARE @BetType		TABLE (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @SportType		TABLE (SportType INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE	@PromotionPrize	INT = 0
	
	-- SEARCH by username
	CREATE TABLE #tmpCust (CustID INT PRIMARY KEY)
	-- SEARCH result
	CREATE TABLE #TempData (
		CustId			INT,
		WinLostDate		SMALLDATETIME,
		Currency		INT,
		Turnover		MONEY,
		MemberWinLost	MONEY ,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		AmtDueToBA		MONEY,
		CommBA			MONEY,
		PlayerComm		MONEY,
		BetCount		INT,
		PromotionPrize	INT
	)
	CREATE CLUSTERED INDEX IX_TempData_cl ON #TempData(custID)

	SELECT	@_FromDate			= @FromDate,
			@_ToDate			= @ToDate,
			@_ShowBA			= ISNULL(@ShowBA, 0),
			@_ShowSB			= ISNULL(@ShowSB, 0),
			@_ShowBT			= ISNULL(@ShowBT, 0),
			@_ShowCO			= ISNULL(@ShowCO, 0),
			@_DrawFilter		= ISNULL(@DrawFilter, 1)

	SELECT  @PageIndex	= @PageIndex - 1, 
			@RowStart	= @PageSize * @PageIndex + 1,
			@RowEnd		= @RowStart + @PageSize - 1

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Start searching by username
	SELECT @Username = LTRIM(RTRIM(ISNULL(@Username, '')))

	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

	IF @Username <> ''
	BEGIN
		INSERT INTO #tmpCust
		SELECT c.custid
		FROM CustDB.dbo.Customer c WITH (NOLOCK)
		WHERE EXISTS(SELECT TOP 1 1 FROM @TempAg t WHERE c.recommend = t.CustId)
			AND (
				c.username2 	LIKE '%$%' 	+ @Username + '%'
				OR c.username	LIKE '%' 	+ @Username + '%'
			) AND c.roleid = 1
		
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 102
				,@ErrMsg = N'Username was not found.'

			RETURN
		END

		SET @isSearchCust = 1
	END
	-- End searching by username

	--Start product list
	INSERT INTO @Products(Code)
	SELECT 'SB' AS Code WHERE @ShowSB = 1 OR @ShowBA = 1
	UNION ALL
	SELECT 'NG' AS Code WHERE @ShowNG = 1
	UNION ALL
	SELECT 'VS' AS Code WHERE @ShowVS = 1
	UNION ALL
	SELECT 'CS' AS Code WHERE @ShowCS = 1
	UNION ALL
	SELECT 'KN' AS Code WHERE @ShowKN = 1
	UNION ALL
	SELECT 'BT' AS Code WHERE @ShowBT = 1
	UNION ALL
	SELECT 'AGC' AS Code WHERE @ShowAGC = 1
	UNION ALL
	SELECT 'VB' AS Code WHERE @ShowVB = 1
	UNION ALL
	SELECT 'AB' AS Code WHERE @ShowAB = 1
	UNION ALL
	SELECT 'FW' AS Code WHERE @ShowFW = 1
	UNION ALL
	SELECT 'CO' AS Code WHERE @ShowCO = 1
	UNION ALL
	SELECT 'VS2' AS Code WHERE @ShowVS2 = 1
	UNION ALL
	SELECT 'LT' AS Code WHERE @ShowLT = 1
	UNION ALL
	SELECT 'PP' AS Code WHERE @ShowPP = 1
	UNION ALL
	SELECT 'CC' AS Code WHERE @ShowCC = 1
	UNION ALL
	SELECT 'SG' AS Code WHERE @ShowSG = 1
	UNION ALL
	SELECT 'VRG' AS Code WHERE @ShowVRG = 1
	UNION ALL
	SELECT 'TG' AS Code WHERE @ShowTG = 1
	UNION ALL
	SELECT 'I4D' AS Code WHERE @ShowI4D = 1
	UNION ALL
	SELECT 'SXG' AS Code WHERE @ShowSXG = 1
	UNION ALL
	SELECT 'SBC' AS Code WHERE @ShowSBC = 1
	UNION ALL
	SELECT 'SAG' AS Code WHERE @ShowSAG = 1
	UNION ALL
	SELECT 'PGS' AS Code WHERE @ShowPGS = 1
	UNION ALL
	SELECT 'JK' AS Code WHERE @ShowJK = 1
	UNION ALL
	SELECT 'GDG' AS Code WHERE @ShowGDG = 1
	UNION ALL
	SELECT 'SLT' AS Code WHERE @ShowSLT = 1
	UNION ALL
	SELECT 'HB' AS Code WHERE @ShowHB = 1
	UNION ALL
	SELECT 'WM' AS Code WHERE @ShowWM = 1
	UNION ALL
	SELECT 'BGG' AS Code WHERE @ShowBGG = 1
	UNION ALL
	SELECT 'VGA' AS Code WHERE @ShowVGA = 1
	UNION ALL
	SELECT 'CG' AS Code WHERE @ShowCG = 1
	UNION ALL
	SELECT 'AP' AS Code WHERE @ShowAP = 1
	UNION ALL
	SELECT 'APM' AS Code WHERE @ShowAPM = 1
	UNION ALL
	SELECT 'VS3' AS Code WHERE @ShowVS3 = 1
	UNION ALL
	SELECT 'BTC' AS Code WHERE @ShowBTC = 1
	UNION ALL
	SELECT 'FGGL' AS Code WHERE @ShowFGGL = 1
	UNION ALL
	SELECT 'MXG' AS Code WHERE @ShowMXG = 1

	-- BT & CO belong to SB
	SELECT @ProductList = COALESCE(@ProductList + ',' + Code, Code)
	FROM @Products
	WHERE Code NOT IN ('BT', 'CO')

	-- Insert Bettype
	INSERT INTO @bettype ( bettype, ProductCode )
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (SELECT BetType FROM @ExcludedBetType e WHERE e.ProductCode = ProductPrefix)

	-- bettrade
	INSERT INTO @bettype(bettype, ProductCode)
	SELECT bt.bettype, p.Code 
	FROM @Products p
		CROSS APPLY (
			SELECT 901 AS bettype
			UNION ALL
			SELECT 902
		) AS bt
	WHERE Code IN ('BT')
		AND NOT EXISTS (SELECT 1 FROM @bettype t WHERE bt.bettype = t.bettype)

	-- Cast out
	INSERT INTO @BetType (BetType, ProductCode)
	SELECT bt.bettype, p.Code 
	FROM @Products p
		CROSS APPLY (
			SELECT 911 AS bettype
			UNION ALL
			SELECT 912
		) AS bt
	WHERE Code IN ('CO')
		AND NOT EXISTS (SELECT 1 FROM @bettype t WHERE bt.bettype = t.bettype)

	-- Insert Sport Type
	INSERT INTO @SportType (SportType, ProductCode)
	SELECT DISTINCT t.SportType, t.ProductCode
	FROM (
		SELECT SportType, ProductCode
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
		WHERE SportType NOT IN (150, 173)
		UNION
		SELECT 0, 'SB' 
		FROM @Products p
		WHERE Code IN ('CO', 'BT')
	) AS t

	--End bettype/sporttype/product list

	-- Optimze for reducing IO/CPU/Elapsed times
	CREATE TABLE #bettrans_temp (
		CustId		INT NOT NULL,
		WinLostDate	SMALLDATETIME NULL,
		StatusId	TINYINT NULL,
		BetType		SMALLINT NULL,
		Turnover	MONEY NOT NULL,
		WinLost		MONEY NULL,
		Comm		MONEY NULL,
		PlayerComm	MONEY NULL,
		AWinLost	MONEY NULL,
		Currency	TINYINT NULL,
		IsBA		BIT NULL,
		BetCount	INT NULL
	)

	-- bettrans range
	IF @_Todate > @MoveBetsDay
	BEGIN
		IF @_FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @_FromDate

		INSERT INTO #bettrans_temp ([custid]
			,[winlostdate]
			,[statusid]
			,[bettype]
			,[turnover]
			,[winlost]
			,[comm]
			,[playercomm]
			,[awinlost]
			,[currency]
			,[IsBA]
			,[BetCount])
		SELECT b.custid, b.winlostdate, b.statusid,b.bettype
			,b.stake
			,b.winlost - b.actual_stake
			,b.comm
			,b.playercomm
			,b.awinlost
			,b.currency
			,ba.IsBA
			,1 AS BetCount
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TempAg AS ta ON ta.CustId = b.recommend
			INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
			INNER JOIN CustDB.dbo.custinfo AS ci WITH (NOLOCK) ON ci.custid = b.custid
			INNER JOIN @BetType AS bt ON b.bettype = bt.bettype
			CROSS APPLY (
				SELECT CAST(
					CASE
						WHEN bt.ProductCode = 'SB' THEN
							CASE
								WHEN b.tpositiontaking = 0 AND b.bettype NOT IN (901,902,911,912) THEN 1
								ELSE 0 
							END
						ELSE 0
					END AS BIT) AS IsBA
			) AS ba
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID IN (111, 112, 113)
			-- CHECK for BA & SB
			AND 1 = (CASE 
						WHEN bt.ProductCode = 'SB' THEN 
							CASE
								WHEN @_ShowBA = 1 AND ba.IsBA = 1 THEN 1 -- BA ticket
								WHEN @_ShowSB = 1 AND ba.IsBA = 0 THEN 1 -- NOT BA ticket
								ELSE 0 END
						ELSE 1
					END)
			AND (b.bettype NOT BETWEEN 1611 AND 1699 OR b.matchid <> 150)
			AND (b.bettype NOT BETWEEN 3801 AND 3899 OR b.matchid <> 173)
			AND (@OddsGroup = 'All'
				OR ',' + @OddsGroup + ',' LIKE '%,' + c.ugroup + ',%')
			AND (@CustomerClass = 'All'
				OR ',' + @CustomerClass + ',' LIKE '%,0,%' AND CONVERT(VARCHAR(6), ci.CustomerClass) IS NULL
				OR ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), ci.CustomerClass) + ',%')

		-- check promotion prize - PP promotion prize and NPH Promotion prize and Tips --
		IF @CheckPromotionPrize = 1
			AND EXISTS (	SELECT TOP(1) 1
							FROM dbo.bettrans b WITH (NOLOCK)
							WHERE EXISTS(SELECT TOP (1) 1 FROM @TempAg c WHERE c.CustID = b.recommend)
								AND b.winlostdate BETWEEN @TempFromDate AND @_ToDate
								AND ((b.bettype IN (SELECT Bettype FROM @ExcludedBetType WHERE ProductCode <> 'SB') 
									OR (b.bettype BETWEEN 1611 AND 1699 AND b.matchid = 150)
									OR (b.bettype BETWEEN 3801 AND 3899 AND b.matchid = 173)) 
									AND b.statusID IN (111,112,113))
								AND (@isSearchCust = 0 OR EXISTS (SELECT TOP 1 1 FROM #tmpCust tc WHERE tc.CustID = b.CustID)))
		BEGIN
			SET @PromotionPrize = 1
		END
	END
	-- END bettrans range
	
	IF @isSearchCust = 1
	BEGIN
		DELETE b
		FROM #bettrans_temp b
		WHERE NOT EXISTS(SELECT TOP(1) 1 FROM #tmpCust c WHERE c.CustID = b.CustID)
	END

	-- Apply bussiness rules
	INSERT INTO #TempData(CustID, winlostdate, currency, Turnover, MemberWinlost, BetEffective, LicenseeWL, AmtDueToBA, CommBA, PlayerComm, betcount)
	SELECT b.CustID
		, b.winlostdate
		, b.currency
		, SUM(CASE 
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0 --DONT count BA ticket's
				ELSE CASE
						WHEN (@_DrawFilter IN (2, 3) AND b.statusid = 111)
							OR b.bettype IN (901, 902, 911, 912)
							THEN 0
						ELSE b.turnover
					END
				END) AS Turnover
		, SUM(CASE
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE (b.winlost)
			END) AS MemberWinlost
		, SUM(CASE
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE ABS(b.winlost)
			END) AS BetEffective 
		, - SUM(CASE
				WHEN b.IsBA = 1 THEN 0 --exclude BA ticket's
				ELSE (b.winlost)
			END) AS LicenseeWL
		, - SUM(CASE
				WHEN @_ShowBA = 1 AND b.IsBA = 1 THEN (b.winlost + b.awinlost + b.comm) --COUNT for BA's tickets
				ELSE 0
			END) AS AmtDueToBA
		, SUM(CASE
				WHEN @_ShowBA = 1 AND b.IsBA = 1 THEN b.comm
				ELSE 0
			END) AS CommBA
		, SUM(CASE
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE b.PlayerComm
			END) AS PlayerComm
		, SUM(CASE
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE CASE
						WHEN @_DrawFilter = 2 AND b.statusid = 111 THEN 0
						ELSE b.BetCount
					END
			END) AS BetCount
	FROM #bettrans_temp b
	GROUP BY b.CustID
		, b.winlostdate
		, b.currency

	-- DROP temp raw data
	DROP TABLE #bettrans_temp

	CREATE TABLE #tempPaging (custid INT PRIMARY KEY, RowNum INT)

	-- Start pagination
	IF @OrderItem IN (1, 2)
	BEGIN
		WITH CTE_TempCustIDFull AS (
			SELECT DISTINCT b.CustID FROM #TempData b
		),
		CTE_TempCustID AS (
			SELECT
				w.CustID,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
			FROM 
				CTE_TempCustIDFull w
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON w.CustID = c.CustID
		),
		CTE_OrderColumn AS (
			SELECT w.custid,
				CASE 
					WHEN @OrderItem = 1 THEN c.username
					WHEN @OrderItem = 2 THEN c.nickname
				END AS OrderCol
			FROM #TempData w
			INNER JOIN CTE_TempCustID c ON w.CustID = c.CustID
		)
		INSERT INTO #tempPaging
		SELECT t.custid, t.RowNum
		FROM (
			SELECT col.custid,
				ROW_NUMBER() OVER (
					ORDER BY 
						CASE WHEN @IsAscSort = 1 THEN OrderCol END ASC
						,CASE WHEN @IsAscSort = 0 THEN OrderCol END DESC
				) AS RowNum
			FROM CTE_OrderColumn col
			GROUP BY col.custid, col.OrderCol
		) AS t
		WHERE t.RowNum BETWEEN @RowStart AND @RowEnd
	END

	-- Get exchange rate
	DECLARE @Exchange TABLE
	(
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT
	)

	INSERT INTO @Exchange(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeID)

	IF @OrderItem IN (3, 4, 5, 6, 8, 10, 11, 13, 14)
	BEGIN
		WITH CTE_OrderColumn AS (
			SELECT w.custid,
				SUM(CASE 
					WHEN @OrderItem = 3 THEN w.TurnOver
					WHEN @OrderItem = 4 THEN w.MemberWinLost
					WHEN @OrderItem = 5 THEN w.BetEffective
					WHEN @OrderItem = 6 THEN w.LicenseeWL
					WHEN @OrderItem = 8 THEN w.CommBA
					WHEN @OrderItem = 10 THEN w.PlayerComm
					WHEN @OrderItem = 11 THEN w.AmtDuetoBA
					WHEN @OrderItem = 13 THEN w.BetCount
					WHEN @OrderItem = 14 THEN (w.MemberWinLost + w.PlayerComm)
				END * CASE 
					WHEN @OrderItem = 13 THEN 1 -- BetCount
					ELSE e.Rate 
				END) AS OrderCol
			FROM #TempData w
				INNER JOIN @Exchange e ON e.exchangeid = w.currency AND w.winlostdate BETWEEN e.FromDate AND e.ToDate
			GROUP BY w.custid
		)
		INSERT INTO #tempPaging
		SELECT t.custid, t.RowNum
		FROM (
			SELECT col.custid,
				ROW_NUMBER() OVER (
					ORDER BY 
						CASE WHEN @IsAscSort = 1 THEN OrderCol END ASC
						,CASE WHEN @IsAscSort = 0 THEN OrderCol END DESC
				) AS RowNum
			FROM CTE_OrderColumn col
		) AS t
		WHERE t.RowNum BETWEEN @RowStart AND @RowEnd
	END
	-- End pagination

	-- Start result output
	SELECT p.RowNum,
		w.CustID,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
		SUM(w.BetCount)					AS BetCount,
		SUM(w.Turnover		* e.Rate)	AS TurnOver, 
		SUM(w.MemberWinLost	* e.Rate)	AS MemberWinLost,
		SUM(w.BetEffective	* e.Rate)	AS BetEffective,
		SUM(w.LicenseeWL	* e.Rate)	AS LicenseeWL,
		SUM(w.CommBA		* e.Rate)	AS CommBA,
		SUM(w.PlayerComm	* e.Rate)	AS PlayerComm,
		SUM(w.AmtDuetoBA	* e.Rate)	AS AmtDuetoBA,
		CAST(SUM((w.MemberWinLost + w.PlayerComm) * e.Rate) AS MONEY) AS CustomerTotalWL
	FROM #tempPaging AS p
		INNER JOIN #TempData AS w ON p.custid = w.CustID
		INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON p.CustID = c.CustID
		INNER JOIN @Exchange AS e ON e.ExchangeId = w.Currency AND w.WinLostDate BETWEEN e.FromDate AND e.ToDate
	GROUP BY w.CustID,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)),
		p.RowNum
	ORDER BY p.RowNum ASC

	SELECT
		COUNT(DISTINCT w.CustId)	AS TotalRows,
		SUM(w.BetCount) 			AS SumBetCount,
		CAST(SUM(w.Turnover			* e.Rate) AS MONEY)	AS SumTurnOver,
		CAST(SUM(w.MemberWinLost	* e.Rate) AS MONEY)	AS SumMemberWinLost,
		CAST(SUM(w.BetEffective		* e.Rate) AS MONEY)	AS SumBetEffective,
		CAST(SUM(w.LicenseeWL		* e.Rate) AS MONEY)	AS SumLicenseeWL,
		CAST(SUM(w.CommBA			* e.Rate) AS MONEY)	AS SumCommBA,
		CAST(SUM(w.PlayerComm		* e.Rate) AS MONEY)	AS SumPlayerComm,
		CAST(SUM(w.AmtDueToBA		* e.Rate) AS MONEY)	AS SumAmtDuetoBA,
		CAST(SUM((w.MemberWinLost + w.PlayerComm) * e.Rate) AS MONEY) AS SumCustomerTotalWL,
		@PromotionPrize AS PromotionPrize
	FROM
		#TempData w
		INNER JOIN @Exchange e ON e.ExchangeId = w.Currency AND w.WinLostDate BETWEEN e.FromDate AND e.ToDate

	-- End result output

	DROP TABLE #TempData
	DROP TABLE #tempPaging
	DROP TABLE #tmpCust
END
GO