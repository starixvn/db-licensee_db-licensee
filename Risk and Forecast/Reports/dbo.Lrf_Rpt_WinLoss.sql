/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLoss]
	@DrawFilter		SMALLINT = 1,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
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
	@ShowSLT		BIT = 0, 	-- SLT
	@ShowHB			BIT = 0,	-- Habanero
	@ShowWM			BIT = 0, -- WM Live Casino
	@MoveBetsDay	DATETIME,
	@PageSize		INT = 1000,
	@PageIndex		INT = 1,
	@AgentList		VARCHAR(MAX),
	@UserName		VARCHAR(50)	= '',
	@OrderItem		TINYINT		= 1,
	@IsAscSort		BIT			= 1,
	@BaseCurrency	VARCHAR(5)	= '',
	@CheckPromotionPrize	BIT = 0,
	@ErrCode		INT				= 0 OUTPUT,
	@ErrMsg			NVARCHAR(200)	= '' OUTPUT
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
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
		- 20190821@Bobby: Do optimization for SQL code [Redmine: #118990]
		- 20191118@Amanda: Use outparam to get error instead of returned table [Redmine: #118874]
		- 20191017@Amanda: Integrate NPH Promotion [RedmineID: #120333]
		- 20191121@Amanda: Integrate PP Tournament Prize and exclude PP Promotion, Tournament Prize from result [RedmineID: #123804]
		- 20191230@Amanda: Integrate SpadeGaming [RedmineID: #124103]
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200724@Hogan: Get correct status for bettype Contribution (4297) [RedmineID: #138271]
		- 20200803@Kos: Support Saba Loyalty [RedmineID: #138493]
		- 20201013@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201022@Louis: Integrate PG Soft [RedmineID: #139182]
		- 20201126@Hogan: Integrate Joker [RedmineID: #141408]
		- 20201202@Louis: Licensee Spread Setting [RedmineID: #142532]	
		- 20201202@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369]
		- 20201224@Hogan: Integrate GDG [RedmineID: #147267]
		- 20210203@Louis: Saba Red Envelope [RedmineID: #149923]
		- 20210208@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]
		- 20210416@Hogan: Integrate Habanero RNG Games [RedmineID: #150843]
		- 20210511@Kos: Split data of God Of Fortune in rptLicWinloss2 [RedmineID: #152908]
		- 20210513@Hogan: Integrate WM Live Casino [RedmineID: #140944]

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
			@_ShowBT			BIT,
			@_ShowCO			BIT,
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
	DECLARE @bettype		TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype		TABLE (sporttype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE	@PromotionPrize	INT = 0
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
		PromotionPrize	INT
	)
	CREATE CLUSTERED INDEX IX_TempData_cl ON #TempData(custID)

	SELECT	@_FromDate			= @FromDate,
			@_ToDate			= @ToDate,
			@_AgentList			= @AgentList,
			@_ShowBA			= ISNULL(@ShowBA, 0),
			@_ShowSB			= ISNULL(@ShowSB, 0),
			@_ShowBT			= ISNULL(@ShowBT, 0),
			@_ShowCO			= ISNULL(@ShowCO, 0),
			@_DrawFilter		= ISNULL(@DrawFilter, 1),
			@BetEffectiveDate	= '2014-09-01'

	SELECT  @PageIndex	= @PageIndex - 1, 
			@RowStart	= @PageSize * @PageIndex + 1,
			@RowEnd		= @RowStart + @PageSize - 1,
			@TotalRow	= 0

	SELECT	@Today = CONVERT(DATE, GETDATE())

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @_AgentList
	
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
		FROM dbo.Customer c WITH (NOLOCK)
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
	FROM (
		SELECT sporttype, ProductCode
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
		WHERE sporttype <> 150
		UNION
		SELECT 0, 'SB' 
		FROM @Products p
		WHERE Code IN ('CO', 'BT')
	) AS t

	--End bettype/sporttype/product list

	-- Optimze for reducing IO/CPU/Elapsed times
	CREATE TABLE #bettrans_temp (
		[custid]		INT NOT NULL
		, [winlostdate] SMALLDATETIME NULL
		, [statusid]	TINYINT NULL
		, [bettype]		SMALLINT NULL
		, [turnover]	MONEY NOT NULL
		, [winlost]		MONEY NULL
		, [comm]		MONEY NULL
		, [playercomm]	MONEY NULL
		, [awinlost]	MONEY NULL
		, [currency]	TINYINT NULL
		, [IsBA]		BIT NULL
		, [BetCount]	INT NULL
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
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
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
			EXISTS(SELECT TOP 1 1 FROM @TempAg c WHERE c.CustID = b.recommend)
			AND b.winlostdate >= @TempFromDate AND b.winlostdate <= @_ToDate
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

		-- check promotion prize - PP promotion prize and NPH Promotion prize and Tips --
		IF @CheckPromotionPrize = 1 AND EXISTS (
			SELECT TOP(1) 1
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE 
				EXISTS(SELECT TOP (1) 1 FROM @TempAg c WHERE c.CustID = b.recommend)
				AND b.winlostdate >= @TempFromDate AND b.winlostdate <= @_ToDate
				AND ((b.bettype IN (SELECT Bettype FROM @ExcludedBetType WHERE ProductCode <> 'SB') OR (b.bettype BETWEEN 1611 AND 1699 AND b.matchid = 150)) AND b.statusID IN (111,112,113)))
			BEGIN
			SET @PromotionPrize = 1
		END
	END
	-- END bettrans range

	-- PROCESS MoveBets range
	IF @_FromDate <= @MoveBetsDay
	BEGIN
		IF @_ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @_ToDate

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
		SELECT
			b.custid,
			b.winlostdate,
			b.statusid,
			b.bettype,
			b.turnover,
			b.winlost,
			b.comm,
			b.playercomm,
			b.awinlost,
			b.currency,
			ba.IsBA,
			ISNULL(b.BetCount, 0) AS BetCount
		FROM 
			bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
			INNER JOIN @sporttype st ON b.sporttype = st.sporttype
			CROSS APPLY (
					SELECT 
						ISNULL(b.isBA, 0) AS IsBA
				) AS ba
		WHERE 
			EXISTS(SELECT TOP(1) 1 FROM @TempAg c WHERE c.CustID = b.recommend)
			AND b.roleid = 1
			AND b.Winlostdate >= @_FromDate AND b.Winlostdate <= @TempToDate
			AND b.statusID <> 101
			-- CHECK for BA & SB
			AND 1 = (CASE 
						WHEN st.ProductCode = 'SB' THEN -- Is SB 
							CASE 
								WHEN @_ShowBA = 1 AND ba.IsBA = 1 THEN 1
								WHEN @_ShowSB = 1 AND ba.IsBA = 0 AND b.bettype IN (0, -29) THEN 1		-- -29: God Of Fortune
								WHEN @_ShowBT = 1 AND b.bettype IN (901, 902) THEN 1
								WHEN @_ShowCO = 1 AND b.bettype IN (911, 912) THEN 1
								ELSE 0 END
						ELSE 1
					END)
			-- Exclude PP Prize, SAG Tip ticket
			AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)

		-- check promotion prize - PP promotion prize and NPH Promotion prize and Tips --
		IF @CheckPromotionPrize = 1 AND @PromotionPrize = 0 AND EXISTS (
			SELECT TOP(1) 1
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			WHERE EXISTS(SELECT TOP (1) 1 FROM @TempAg c WHERE c.CustID = b.recommend)
				AND b.Winlostdate BETWEEN @_FromDate AND @TempToDate
				AND ((b.bettype IN (SELECT Bettype FROM @ExcludedBetType WHERE ProductCode <> 'SB') OR b.sporttype = 150) AND b.statusID IN (111,112,113))
				AND b.roleid = 2)
		BEGIN
			SET @PromotionPrize = 1
		END
	END
	-- END MoveBets range

	IF @isSearchCust = 1
	BEGIN
		DELETE b
		FROM #bettrans_temp b
		WHERE NOT EXISTS(SELECT TOP 1 1 FROM #tmpCust c WHERE c.CustID = b.CustID)
	END

	-- Apply bussiness rules
	INSERT INTO #TempData(CustID, winlostdate, currency, Turnover, MemberWinlost, BetEffective, LicenseeWL, AmtDueToBA, CommBA, PlayerComm, betcount)
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
						WHEN @_DrawFilter = 2
							AND b.statusid = 111
							THEN 0
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
		SUM(w.TurnOver * e.Rate)		AS TurnOver, 
		SUM(w.MemberWinLost * e.Rate)	AS MemberWinLost,
		SUM(w.BetEffective * e.Rate)	AS BetEffective,
		SUM(w.LicenseeWL * e.Rate)		AS LicenseeWL,
		SUM(w.CommBA * e.Rate)			AS CommBA,
		SUM(w.playerComm * e.Rate)		AS PlayerComm,
		SUM(w.AmtDuetoBA * e.Rate)		AS AmtDuetoBA,
		SUM(w.betcount)					AS BetCount,
		CAST(SUM((w.MemberWinLost + w.PlayerComm) * e.Rate) AS MONEY) AS CustomerTotalWL
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
		CAST(SUM(MemberWinLost * e.Rate) AS MONEY)	AS SumMemberWinLost,
		CAST(SUM(BetEffective * e.Rate) AS MONEY)	AS SumBetEffective,
		CAST(SUM(LicenseeWL * e.Rate) AS MONEY)		AS SumLicenseeWL,
		CAST(SUM(CommBA * e.Rate) AS MONEY)			AS SumCommBA,
		CAST(SUM(PlayerComm * e.Rate) AS MONEY)		AS SumPlayerComm,
		CAST(SUM(AmtDuetoBA * e.Rate) AS MONEY)		AS SumAmtDuetoBA,
		COUNT(DISTINCT w.custid)					AS TotalRows,
		SUM(w.betcount) 							AS SumBetCount,
		CAST(SUM((MemberWinLost + PlayerComm) * e.Rate) AS MONEY) AS SumCustomerTotalWL,
		@PromotionPrize								AS PromotionPrize
	FROM
		#TempData w
		INNER JOIN @Exchange e ON e.exchangeid = w.currency AND w.winlostdate BETWEEN e.FromDate AND e.ToDate

	-- End result output

	DROP TABLE #TempData
	DROP TABLE #tempPaging
	DROP TABLE #tmpCust
END
GO