/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLoss]   
	@DrawFilter		SMALLINT = 1,
    @FromDate		DATETIME,
    @ToDate			DATETIME,
    @showSB			BIT = 0,
    @showNG			BIT = 0, 
    @ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0, -- RNG Casino
	@ShowKN			BIT = 0,
	@ShowBT			BIT = 0,
	@ShowAGC		BIT = 0,
	@ShowVB			BIT = 0,
	@ShowAB			BIT = 0,
	@ShowFW			BIT	= 0,
	@ShowCO			BIT = 0,
	@ShowVS2		BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT			BIT = 0, -- Lottery
	@ShowPP			BIT = 0, -- PP
    @MoveBetsDay	DATETIME,
    @PageSize		INT = 1000,
    @PageIndex		INT = 1,
	@AgentList		VARCHAR(MAX),
    @UserName		VARCHAR(50) = '',
	@OrderItem		TINYINT = 1,
	@IsAscSort		BIT = 1,
	@BaseCurrency	VARCHAR(5) = ''
AS
/*
    Created: 20101201@Jacob
    Task: Customer Reports - Customer Winloss
    DB: DBEXT.bodb02
    Original SP:Age_Rpt_WinLoss_Ag

    Param's Explanation:
		+ @IsOld: 0 - query IN table rptLicWinloss, 1 - query IN table rptLicWinloss_old. 
		+ @DrawFilter:	1 - Filter Nomal (Win, Lose, Draw)
						2 - Filter bets No Draw (Win, Draw)
						3 - Filter No Draw For turnover only: include betcount, exclude stake 
	  
    Revisions:
        - 20101201@Jacob: Copy code FROM Age_Rpt_WinLoss, remove redundant column
        - 2011216@Alex:Add UserName2
        - 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport bASed currency
        - 20110519@Henry: Allow number game
        - 20110609@Henry: change rptLicWinlost to rptLicWinloss
        - 20110616@Henry: Add column Comm, add param @BAFilter
        - 20110707@Henry: show Comm, Amt Due to for each 3rd party product: BA, Racing
        - 20110729@Henry: offer 3 new bettypes for Number Game
        - 20111013@Henry: change to use rptLicWinloss2
        - 20111208@Jim: change bettype condition
        - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
        - 20120403@Henry: enhance performance
        - 20120731@Jim: add playercomm value 
        - 20120815@Jim: add live casino 
		- 20120905@Jim: add virtual sport 
		- 20121004@Jim: replace @CurrencyName input param by @CurrencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130225@Jim: support RNG Casino, Bingo 
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130729@Viet: enhance sp
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: offer Virtual Tennis
		- 20140225@Florent: add filter Show Draw for betcount, stake
		- 20140326@Jim: offer Keno
		- 20140604@Victor: Enhance performance
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20140819@Jim: add more column BetEffective in the result
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20141225@Jim: improve performance
		- 20150129@Jim : add base on curreny GBP
		- 20150612@Jim: support MicroGaming
		- 20150625@Winnie: support BetTrade
		- 20150826@Winnie: Fix bug KeenOcean #42464
		- 20150910@Jim: Integrate Microgaming RNG games (feature #43078)
		- 20150917@Florent: Change datasource for AG Casino (#Redmine 43172)
		- 20151108@Jim: Separated MicroGaming into 2 product
		- 20151228@Patrick: Exclude 901 & 902 for turnover
		- 20151228@Bobby: Implement RNG Casino sporttype(208, 209, 210)
		- 20160401@Percy: Support Voidbridge single wallet [Redmine: #55057]
		- 20160519@Jim: add more parameter  @excludeTest (#57836)
		- 20160619@Jim: Allbet - Live Casino Integration for Licensees [Redmine: #59624]
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
		- 20170215@Sophia: Get @AgentList by web instead of @UserId, @LicenseeID, @CurrencyID, remove @excludeTest [Redmine: #71679]
		- 20170320@Paul: Implement Cash Out [RedmineID :#71727]
		- 20170706@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20171009@Percy: Add @Username filter [RedmineID: #84551]
		- 20171109@Paul: Support sorting [RedmineID: #86214]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180418@Amanda: LAP - Integrate PP [RedmineID: #92318]
		- 20180809@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]
		- 20180808@Amanda: Remove Racing, Bingo and Old(@IsOld) data [RedmineID: #99378]
		- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
		- 20190304@Amanda: Integrate PP Promotion Prize [RedmineID: #109471]
		- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
		- 20190620@Amanda: Centralize function to get exchange rate [Redmine: #112531]
		- 20190821@Bobby: Do optimization for SQL code [Redmine: #118990]
		

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
*/

BEGIN
	SET NOCOUNT ON

	IF @OrderItem < 1 OR @OrderItem > 14
	BEGIN
		SET @OrderItem = 1
	END

	DECLARE @_FromDate			SMALLDATETIME,
			@_ToDate			SMALLDATETIME,
			@_AgentList			VARCHAR(MAX),
			@_ShowBA			BIT,
			@_ShowSB			BIT,
			@_DrawFilter		SMALLINT,
			@BetEffectiveDate	SMALLDATETIME,
			@RowStart			INT,
			@RowEnd				INT,
			@Today				SMALLDATETIME,
			@TempFromDate		DATETIME,
			@TempToDate			DATETIME,
			@ProductList		VARCHAR(MAX),
			@bettypeList		VARCHAR(MAX),
			@TotalRow			INT
	
	DECLARE @IsTest				BIT = 0
	DECLARE @isSearchCust		BIT = 0

	DECLARE @Products		TABLE (Code VARCHAR(10))
	DECLARE @TempAg			TABLE (CustId INT PRIMARY KEY, Currency INT)
	DECLARE @bettype		TABLE (bettype SMALLINT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype		TABLE (sporttype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @Exchange		TABLE
	(
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT
	)
	-- SEARCH by username
	CREATE TABLE #tmpCust (CustID INT PRIMARY KEY)
	-- SEARCH result
	CREATE TABLE #TempData
	(
		CustID			INT,
		winlostdate		SMALLDATETIME,
		currency		INT,
		TurnOver		MONEY,
		MemberWinLost	MONEY ,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		AmtDueToBA		MONEY,
		CommBA			MONEY,
		PlayerComm		MONEY,
		betcount		INT,
		PromotionPrize  INT
	)
	CREATE CLUSTERED INDEX IX_TempData_cl ON #TempData(custID)

	SELECT	@_FromDate			= @FromDate,
			@_ToDate			= @ToDate,
			@_AgentList			= @AgentList,
			@_ShowBA			= ISNULL(@ShowBA, 0),
			@_ShowSB			= @ShowSB,
			@_DrawFilter		= ISNULL(@DrawFilter, 1),
			@BetEffectiveDate	= '2014-09-01'

	SELECT  @PageIndex	= @PageIndex - 1, 
			@RowStart	= @PageSize * @PageIndex + 1,
			@RowEnd		= @RowStart + @PageSize - 1,
			@TotalRow	= 0

	SELECT	@Today = CONVERT(DATE, GETDATE())

	
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-------- Get AgentList 	
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@_AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	-------End Get AgentList
	
	-- Start searching by username
	SELECT @Username = LTRIM(RTRIM(ISNULL(@Username, '')))
	IF @Username <> ''
	BEGIN
		INSERT INTO #tmpCust
		SELECT c.custid
		FROM dbo.Customer  c WITH (NOLOCK) 
		  
		WHERE
			EXISTS(SELECT TOP 1 1 FROM @TempAg t WHERE c.recommend = t.CustId)
			AND (
				c.username2 	LIKE '%$%' 	+ @Username + '%'
				OR c.username	LIKE '%' 	+ @Username + '%'
			) And c.roleid = 1
		
		IF (@@ROWCOUNT = 0)
		BEGIN
			SELECT ErrCode = 102
				,ErrMsg = N'Username was not found.'

			RETURN
		END

		SET @isSearchCust = 1
	END
	-- End searching by username

	INSERT INTO @Exchange(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeID)

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

	SELECT @ProductList = COALESCE(@ProductList + ',' + Code, Code)
	FROM @Products
	WHERE Code NOT IN ('BT', 'CO')

	-- Insert Bettype
	INSERT INTO @bettype ( bettype, ProductCode )
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
		
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
	INSERT INTO @bettype(bettype, ProductCode)
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
	INSERT INTO @sporttype ( sporttype, ProductCode )
	SELECT DISTINCT sporttype, ProductCode
	FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
	
	--End bettype/sporttype/product list

	-- Optimze for reducing IO/CPU/Elapsed times
	CREATE TABLE #bettrans_temp (
		[custid] [int] NOT NULL
		, [winlostdate] [smalldatetime] NULL
		, [statusid] [tinyint] NULL
		, [bettype] [smallint] NULL
		, [stake] [money] NOT NULL
		, [actual_stake] [money] NULL
		, [winlost] [money] NULL
		, [comm] [money] NULL
		, [playercomm] [money] NULL
		, [awinlost] [money] NULL
		, [currency] [tinyint] NULL
		, [IsBA] [bit] NULL
	)

	-- PROCESS bettrans range
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
           ,[stake]
           ,[actual_stake]
           ,[winlost]
           ,[comm]
           ,[playercomm]
           ,[awinlost]
           ,[currency]
           ,[IsBA])
		SELECT b.custid, b.winlostdate, b.statusid,b.bettype,b.stake,b.actual_stake,b.winlost,b.comm,b.playercomm,b.awinlost,b.currency
			,CAST(CASE WHEN b.tpositiontaking = 0 THEN 1 ELSE 0 END AS BIT) IsBA -- total positiontaking

		FROM 
			dbo.bettrans b WITH (NOLOCK)
		INNER JOIN @bettype bt 
			ON b.bettype = bt.bettype

		WHERE 
			EXISTS(SELECT TOP 1 1 FROM @TempAg c WHERE c.CustID = b.recommend)
			AND b.winlostdate >= @TempFromDate AND b.winlostdate <= @_ToDate
			AND b.statusID IN (111, 112, 113)
			-- CHECK for BA & SB
			AND 1 = (CASE 
						WHEN bt.ProductCode = 'SB' THEN 
							CASE 
								WHEN @_ShowBA = 1 AND b.tpositiontaking = 0 THEN 1 -- BA ticket
								WHEN @_ShowSB = 1 AND b.tpositiontaking <> 0 THEN 1 -- NOT BA ticket
								ELSE 0 END
						ELSE 1
					END)

		
	END
	-- END bettrans range

	-- PROCESS MoveBets range
	IF @_FromDate <= @MoveBetsDay
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @_ToDate

		INSERT INTO #bettrans_temp ([custid]
           ,[winlostdate]
           ,[statusid]
           ,[bettype]
           ,[stake]
           ,[actual_stake]
           ,[winlost]
           ,[comm]
           ,[playercomm]
           ,[awinlost]
           ,[currency]
           ,[IsBA])
		SELECT b.custid, b.winlostdate, b.statusid,b.bettype,b.turnover AS stake,0 AS actual_stake,b.winlost,b.comm,b.playercomm,b.awinlost,b.currency
			,ISNULL(b.isBA, 0) AS isBA
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)

		WHERE 
			EXISTS(SELECT TOP 1 1 FROM @TempAg c WHERE c.CustID = b.recommend)
			AND b.roleid = 1
			AND b.Winlostdate >= @_FromDate AND b.Winlostdate <= @TempToDate
			AND b.statusID <> 101
			AND EXISTS(SELECT TOP 1 1 FROM @sporttype bt WHERE bt.sporttype = b.sporttype)
			-- CHECK for BA & SB
			AND 1 = (CASE 
						WHEN b.sporttype = 0 THEN -- Is SB 
							CASE 
								WHEN @_ShowBA = 1 AND ISNULL(b.isBA, 0) = 1 THEN 1 
								WHEN @_ShowSB = 1 AND ISNULL(b.isBA, 0) = 0 THEN 1
								ELSE 0 END
						ELSE 1
					END)
	END
	-- END MoveBets range

	IF (@isSearchCust = 1)
	BEGIN
		DELETE b
		FROM #bettrans_temp b
		WHERE NOT EXISTS(SELECT TOP 1 1 FROM #tmpCust c WHERE c.CustID = b.CustID)
	END

	-- Apply bussiness rules
	
	INSERT INTO #TempData(CustID, winlostdate, currency, Turnover, MemberWinlost, BetEffective, LicenseeWL, AmtDueToBA, CommBA, PlayerComm, betcount, PromotionPrize)
	SELECT b.CustID
		, b.winlostdate
		, b.currency
		, SUM(CASE 
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0 --DONT count BA ticket's
				ELSE CASE 
						WHEN (
								@_DrawFilter IN (2, 3)
								AND b.statusid = 111
								)
							OR b.bettype IN (901, 902, 911, 912)
							THEN 0
						ELSE b.stake
						END
				END) AS Turnover
		, SUM(CASE 
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE (b.winlost - b.actual_stake)
				END) AS MemberWinlost
		, SUM(CASE 
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE CASE 
						WHEN b.bettype = 4300 -- exclude Promotion Prize from BetEffective
							THEN 0
						ELSE ABS(winlost - actual_stake)
						END
				END) AS BetEffective 
		, - SUM(CASE 
				WHEN b.IsBA = 1 THEN 0 --exclude BA ticket's
				ELSE (b.winlost - b.actual_stake)
				END) AS LicenseeWL
		, - SUM(CASE 
				WHEN @_ShowBA = 1 AND b.IsBA = 1 THEN (b.winlost - b.actual_stake + b.awinlost + b.comm) --COUNT for BA's tickets
				ELSE 0
				END) AS AmtDueToBA
		, SUM(CASE 
				WHEN @_ShowBA = 1 AND b.IsBA = 1 THEN b.comm
				ELSE 0
				END) AS CommBA
		, SUM(CASE 
				WHEN @ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE b.PlayerComm
				END) AS PlayerComm
		, SUM(CASE 
				WHEN @_ShowBA = 0 AND b.IsBA = 1 THEN 0
				ELSE CASE 
						WHEN @_DrawFilter = 2
							AND b.statusid = 111
							THEN 0
						ELSE 1
						END
				END) AS betcount
		, SUM(CASE 
				WHEN b.bettype = 4300 THEN 1
				ELSE 0
				END) AS PromotionPrize
	FROM 
		#bettrans_temp b
		

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
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustID = c.CustID
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
				END * e.Rate) AS OrderCol
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
		SUM(w.TurnOver * e.Rate)			AS TurnOver, 
		SUM(w.MemberWinLost * e.Rate)	AS MemberWinLost, 
		SUM(w.BetEffective * e.Rate)		AS BetEffective,
		SUM(w.LicenseeWL * e.Rate) 		AS LicenseeWL,  
		SUM(w.CommBA * e.Rate)			AS CommBA,
		SUM(w.playerComm * e.Rate)		AS PlayerComm,
		SUM(w.AmtDuetoBA * e.Rate)		AS AmtDuetoBA,
		SUM(w.betcount * e.Rate)			AS BetCount,
		CAST(SUM((w.MemberWinLost + w.PlayerComm)) AS MONEY) AS CustomerTotalWL
	FROM #tempPaging p
		INNER JOIN #TempData w ON p.CustID = w.CustID
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON p.CustID = c.CustID
		INNER JOIN @Exchange e ON e.exchangeid = w.currency AND w.winlostdate BETWEEN e.FromDate AND e.ToDate

	GROUP BY w.CustID,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)),
		p.RowNum

	ORDER BY p.RowNum
	
	SELECT
		CAST(SUM(TurnOver * e.Rate) AS MONEY)		AS SumTurnOver,
		CAST(SUM(MemberWinLost * e.Rate)	AS MONEY)	AS SumMemberWinLost,
		CAST(SUM(BetEffective * e.Rate) AS MONEY)	AS SumBetEffective,
		CAST(SUM(LicenseeWL * e.Rate) AS MONEY)		AS SumLicenseeWL,
		CAST(SUM(CommBA * e.Rate) AS MONEY)			AS SumCommBA,
		CAST(SUM(PlayerComm * e.Rate) AS MONEY)		AS SumPlayerComm,
		CAST(SUM(AmtDuetoBA * e.Rate) AS MONEY)		AS SumAmtDuetoBA,
		COUNT(DISTINCT w.custid)			AS TotalRows,
		SUM(w.betcount) 					AS SumBetCount,
		CAST(SUM((MemberWinLost + PlayerComm) * e.Rate) AS MONEY) AS SumCustomerTotalWL,
		SUM(PromotionPrize)					AS SumPromotionPrize
	FROM
		#TempData w
		INNER JOIN @Exchange e ON e.exchangeid = w.currency AND w.winlostdate BETWEEN e.FromDate AND e.ToDate
	
	-- End result output

	DROP TABLE #TempData    
	DROP TABLE #tempPaging
	DROP TABLE #tmpCust

	SET NOCOUNT OFF;
END
GO