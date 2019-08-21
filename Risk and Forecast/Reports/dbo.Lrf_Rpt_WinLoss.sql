/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLoss]   
	@DrawFilter		SMALLINT = 1,
    @FromDate		DATETIME,
    @ToDate			DATETIME ,
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
	@ShowCC			BIT = 0, -- Card club
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
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
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
			@BetEffectiveDate	SMALLDATETIME,
			@RowStart			INT,
			@RowEnd				INT,
			@Today				SMALLDATETIME,
			@TempFromDate		DATETIME,
			@TempToDate			DATETIME

	DECLARE @TempAg			TABLE (CustId INT PRIMARY KEY, Currency INT)
	DECLARE @bettype		TABLE (bettype INT, ProductCode VARCHAR(10))
	DECLARE @sporttype		TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @ProductList	VARCHAR (500)
	DECLARE @Exchange		TABLE
	(
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT
	)

	SELECT	@_FromDate		  = @FromDate,
			@_ToDate		  = @ToDate,
			@BetEffectiveDate = '2014-09-01'
	SELECT  @PageIndex	= @PageIndex - 1, 
			@RowStart	= @PageSize * @PageIndex + 1,
			@RowEnd		= @RowStart + @PageSize - 1
	SELECT	@Today = CONVERT(DATE, GETDATE())

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-------- Get AgentList 	
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
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
	
	INSERT INTO @Exchange(FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeID)

	IF @ShowSB = 1 
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')	
	END

	IF @ShowNG = 1  
	BEGIN  
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')	
	END	

	IF @ShowVS = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')
	END

	IF @ShowCS = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CS', 'CS')
	END

	IF @ShowKN = 1 -- Keno
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')
	END

	IF @ShowBT = 1 -- bettrade
	BEGIN
		INSERT INTO @bettype(bettype, ProductCode)
		VALUES (901, 'BT'), (902, 'BT')	
	END

	IF @ShowAGC = 1 -- AG Casino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AGC', 'AGC')
	END

	IF @ShowVB = 1 -- Voidbridge
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VB', 'VB')
	END

	IF @ShowAB = 1 -- Allbet
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AB', 'AB')
	END

	IF @ShowFW = 1 -- Fishing World
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'FW', 'FW')
	END

	IF @ShowCO = 1 -- Cash Out
	BEGIN
		INSERT INTO @bettype(bettype, ProductCode)
		VALUES (911, 'CO'), (912, 'CO')	
	END

	IF @ShowVS2 = 1 -- Betradar Virtual Sports
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
	END
	
	IF @ShowLT = 1 -- Lottery
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'LT', 'LT')
	END
	
	IF @ShowPP = 1 -- PP
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'PP', 'PP')
	END
	
	IF @ShowCC = 1 -- CC
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CC', 'CC')
	END

	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @bettype ( bettype, ProductCode )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
		
		IF CHARINDEX('CS', @ProductList) > 0
			DELETE @bettype
			WHERE bettype = 72 AND ProductCode = 'CS'

		IF CHARINDEX('SB', @ProductList) > 0
			DELETE @bettype
			WHERE ProductCode IN ('SB')
		
		-- Insert Sport Type
		INSERT INTO @sporttype ( sporttype, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)

	END

	CREATE TABLE #tmpCust (CustID INT)
	DECLARE @isSearchCust BIT = 0

	SELECT @Username = LTRIM(RTRIM(ISNULL(@Username, '')))

	IF @Username <> ''
	BEGIN
		INSERT INTO #tmpCust
		SELECT c.custid
		FROM  Customer  c WITH (NOLOCK) 
		  
		WHERE   c.recommend		IN (SELECT custid FROM @TempAg)
			AND (
				c.username2 	LIKE '%$%' 	+ @Username + '%'
				OR c.username	LIKE '%' 	+ @Username + '%'
			) And c.roleid = 1
		
		SELECT @isSearchCust = 1
	END
	
	CREATE TABLE #TempData
	(
		CustID			INT,
		rptDate			DATETIME,
		TurnOver		MONEY,
		MemberWinLost	MONEY ,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		AmtDueToBA		MONEY,
		CommBA			MONEY,
		PlayerComm		MONEY,
		betcount		INT,
		currency		INT,
		PromotionPrize  INT
	)

	CREATE TABLE #TempCustID
	(
		CustID		INT	PRIMARY KEY,
		UserName	VARCHAR(50),
		UserName2	VARCHAR(50)
	)

	CREATE TABLE #TempCustIDFull
	(
		CustID INT PRIMARY KEY
	)

	IF @isSearchCust = 0 OR EXISTS (SELECT custid FROM #tmpCust)
	BEGIN
		IF @_Todate > @MoveBetsDay 
		BEGIN 
			IF @_FromDate <= @MoveBetsDay 
				SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
			ELSE
				SET @TempFromDate = @_FromDate
	
			IF @ShowBA = 1 
			BEGIN	
				INSERT INTO #TempData
				SELECT  
					b.CustID ,
					b.winlostdate AS rptDate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902) THEN 0 ELSE stake END) AS Turnover,
					SUM(winlost - actual_stake) AS MemberWinlost,
					SUM(ABS(winlost - actual_stake)) AS BetEffective,
					0 AS LicenseeWL,
					- SUM (b.winlost - b.actual_stake + awinlost + comm) AS AmountDueToBA,
					SUM (comm) AS CommBA,
					SUM(PlayerComm ) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter = 2 AND b.statusid = 111 THEN 0 ELSE 1 END) AS betcount,
					b.currency,
					0 AS PromotionPrize	
				FROM    
					bettrans b WITH (NOLOCK)   
					INNER JOIN @TempAg ag ON b.recommend = ag.CustId AND b.currency=ag.Currency
				WHERE
					transid IN (SELECT transid FROM bodb_Licensee.dbo.LicenseeBATransaction_active WITH (NOLOCK))
					AND winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.statusID  IN (111, 112, 113)
					and bettype < 19999
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
				GROUP BY b.CustID, b.winlostdate, b.currency	
			END

			IF @ShowSB = 1
			BEGIN
				INSERT INTO #TempData
				SELECT  
					b.CustID ,
					b.winlostdate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902) THEN 0 ELSE stake END) AS Turnover,
					SUM(winlost - actual_stake) AS MemberWinlost,
					SUM(ABS(winlost - actual_stake)) AS BetEffective,
					- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
					0 AS AmountDueToBA,
					0 AS CommBA,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter = 2 AND b.statusid = 111 THEN 0 ELSE 1 END) AS betcount,
					b.currency,
					0 AS PromotionPrize
				FROM    
					Bettrans b WITH (NOLOCK)
					INNER JOIN @TempAg a ON b.recommend = a.custid  AND b.currency=a.Currency
				WHERE   
					winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND
					(
						b.bettype <= 30
						OR b.bettype BETWEEN 121 AND 999
						OR b.Bettype BETWEEN 1301 AND 1399
						OR b.Bettype BETWEEN 9001 AND 9086 -- E-Sports 2.0
					)
					AND b.statusID IN (111, 112, 113)
					AND b.tpositiontaking <> 0
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
				GROUP BY b.CustID, b.winlostdate, b.currency	 
			END

			IF 1 IN (@ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowBT, @ShowAGC, @ShowVb,@ShowAB,@ShowFW, @ShowCO, @ShowVS2, @ShowLT, @ShowPP, @ShowCC)
			BEGIN
				WITH CTE_Bettype AS (
					SELECT DISTINCT bettype FROM @bettype
				)
				INSERT INTO #TempData
				SELECT
					b.CustID ,
					b.winlostdate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902, 911, 912) THEN 0
							 ELSE b.stake
						END
					) AS Turnover,
					SUM(winlost - actual_stake) AS MemberWinlost ,
					SUM(CASE WHEN b.bettype = 4300 THEN 0 ELSE ABS(winlost - actual_stake) END) AS BetEffective, -- exclude Promotion Prize from BetEffective
					- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
					0 AS AmountDueToBA,
					0 AS CommBA,
					SUM( b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter = 2 AND b.statusid = 111 THEN 0 ELSE 1 END) AS betcount,
					b.currency,
					SUM(CASE WHEN b.bettype = 4300 THEN 1 ELSE 0 END) AS PromotionPrize	
				FROM    
					dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @TempAg a   ON b.recommend = a.custid AND b.currency = a.Currency
				WHERE   
					b.winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.statusID IN (111, 112, 113)			
					AND EXISTS(SELECT TOP 1 1 FROM CTE_Bettype bt WHERE bt.bettype = b.bettype)
				GROUP BY b.CustID, b.winlostdate, b.currency		
			END
		END

		IF @_FromDate <= @MoveBetsDay
		BEGIN
			IF @_ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @_ToDate
	
			IF @ShowBA = 1
			BEGIN
				INSERT INTO #TempData
				SELECT
					b.CustID,
					b.winlostdate AS rptDate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902) THEN 0 ELSE b.turnover END) AS Turnover,
					SUM(winlost) MemberWinlost,
					CASE WHEN winlostdate < @BetEffectiveDate THEN 0 ELSE SUM(ISNULL(BetEffective, 0)) END AS BetEffective,
					0 AS LicenseeWL,
					- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
					SUM (comm) AS CommBA,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) AS betcount,
					b.currency,
					0 AS PromotionPrize		 
				FROM    
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @TempAg ag ON ag.custid = b.recommend AND b.Currency = ag.Currency
				WHERE   
					Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND roleID = 1
					AND b.statusID <> 101
					AND ISNULL(b.isBA, 0) = 1
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
				GROUP BY b.CustID, b.winlostdate, b.currency
			END

			--exclude BA tickets
			IF 1 IN (@ShowSB, @ShowNG, @ShowVS, @ShowCS, @ShowKN, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT, @ShowPP, @ShowCC)
			BEGIN
				INSERT INTO #TempData
				SELECT
					b.CustID ,
					b.winlostdate AS rptdate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902) THEN 0 ELSE b.turnover END) AS Turnover,
					SUM(winlost) MemberWinlost,
					CASE WHEN winlostdate < @BetEffectiveDate THEN 0 ELSE SUM(ISNULL(BetEffective, 0)) END AS BetEffective,
					- SUM(b.winlost) AS LicenseeWL ,
					0 AS AmountDueToBA,
					0 AS CommBA,
					SUM(b.PlayerComm) AS PlayerComm,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) as betcount,
					b.currency,
					SUM(CASE WHEN b.bettype =  4300 THEN 1 ELSE 0 END) AS PromotionPrize	 
				FROM    
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @TempAg ag   ON ag.custid = b.recommend AND b.Currency = ag.Currency
					INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				WHERE   
					Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND roleID = 1
					AND ISNULL(b.isBA, 0) = 0
					AND b.statusID <> 101 
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
				GROUP BY b.CustID, b.winlostdate, b.currency	
			END 

			--bettrade
			IF @ShowBT = 1
			BEGIN
				INSERT INTO #TempData
				SELECT
					b.CustID ,
					b.winlostdate AS rptdate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902) THEN 0 ELSE b.turnover END) AS Turnover,
					SUM(winlost) MemberWinlost,
					CASE WHEN winlostdate < @BetEffectiveDate  THEN 0 ELSE SUM(ISNULL(BetEffective,0)) END AS BetEffective,
					- SUM(b.winlost) AS LicenseeWL ,
					0 AS AmountDueToBA,
					0 AS CommBA,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) as betcount,
					b.currency,
					0 AS PromotionPrize
				FROM    
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @TempAg ag ON ag.custid = b.recommend AND b.Currency = ag.Currency			
				WHERE   
					Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND roleID = 1			
					AND b.statusID <> 101 
					AND b.bettype IN (901, 902)
				GROUP BY b.CustID, b.winlostdate, b.currency	
			END    
	
			--Cash Out
			IF @ShowCO = 1
			BEGIN
				INSERT INTO #TempData
				SELECT
					b.CustID ,
					b.winlostdate AS rptdate,
					0 AS Turnover,
					SUM(winlost) MemberWinlost,
					CASE WHEN winlostdate < @BetEffectiveDate  THEN 0 ELSE SUM(ISNULL(BetEffective,0)) END AS BetEffective,
					- SUM(b.winlost) AS LicenseeWL ,
					0 AS AmountDueToBA,
					0 AS CommBA,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) as betcount,
					b.currency,
					0 AS PromotionPrize	 
				FROM    
					bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
					INNER JOIN @TempAg ag ON ag.custid = b.recommend AND b.Currency = ag.Currency			
				WHERE   
					Winlostdate BETWEEN @_FromDate AND @TempToDate
					AND roleID = 1			
					AND b.statusID <> 101 
					AND b.bettype IN (911, 912)
				GROUP BY b.CustID, b.winlostdate, b.currency	
			END      
		END

		IF @isSearchCust = 1
		BEGIN
			DELETE d
			FROM #TempData d
				LEFT JOIN #tmpCust c ON d.custid = c.custid
			WHERE c.custid IS NULL
		END

		INSERT INTO #TempCustIDFull (CustID)
		SELECT DISTINCT b.CustID FROM #TempData b
	END

	INSERT INTO #TempCustID(CustID, UserName, UserName2)
	SELECT    
		w.CustID,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
	FROM      
		#TempCustIDFull w
		INNER JOIN Customer c WITH (NOLOCK) ON w.CustID = c.CustID	

	CREATE CLUSTERED INDEX IX_TempData_cl ON #TempData(custID, rptdate, currency)

	IF @OrderItem IN (1, 2) AND @IsAscSort = 1
	BEGIN
		WITH PAGING AS (
			SELECT	ROW_NUMBER() OVER (
						ORDER BY CASE @OrderItem
							WHEN 1 THEN b.username
							WHEN 2 THEN b.nickname
						END) AS RowNum,
					b.*
			FROM
			(
				SELECT 
					w.CustID,
					t.username,
					t.UserName2 AS nickname,  
					SUM(TurnOver		*e.Rate)    AS TurnOver, 
					SUM(MemberWinLost	*e.Rate)	AS MemberWinLost, 
					SUM(BetEffective	*e.Rate)	AS BetEffective,
					SUM(LicenseeWL		*e.Rate) 	AS LicenseeWL,  
					SUM(CommBA			*e.Rate)	AS CommBA,
					SUM(playerComm		*e.Rate)    AS PlayerComm,
					SUM(AmtDuetoBA		*e.Rate)    AS AmtDuetoBA,
					SUM(w.betcount)					AS BetCount,
					CAST(SUM((MemberWinLost + PlayerComm)*e.Rate) AS MONEY) AS CustomerTotalWL
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.exchangeid = w.currency AND w.rptdate BETWEEN e.FromDate AND e.ToDate
				GROUP BY w.CustID, t.username, t.UserName2
			) b
		)
		SELECT *
		FROM PAGING
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (3, 4, 5, 6, 8, 10, 11, 13, 14) AND @IsAscSort = 1
	BEGIN
		WITH PAGING AS (
			SELECT	ROW_NUMBER() OVER (
						ORDER BY CASE @OrderItem
							WHEN 3 THEN TurnOver
							WHEN 4 THEN MemberWinLost
							WHEN 5 THEN BetEffective
							WHEN 6 THEN LicenseeWL
							WHEN 8 THEN CommBA
							WHEN 10 THEN PlayerComm
							WHEN 11 THEN AmtDuetoBA
							WHEN 13 THEN BetCount
							WHEN 14 THEN CustomerTotalWL
						END, b.CustID) AS RowNum,
					b.*
			FROM
			(
				SELECT 
					w.CustID,
					t.username,
					t.UserName2 AS nickname, 
					SUM(TurnOver		*e.Rate)	AS TurnOver, 
					SUM(MemberWinLost	*e.Rate)	AS MemberWinLost,
					SUM(BetEffective	*e.Rate)	AS BetEffective,  
					SUM(LicenseeWL		*e.Rate) 	AS LicenseeWL,  
					SUM(CommBA			*e.Rate)	AS CommBA,  
					SUM(playerComm		*e.Rate)	AS PlayerComm,  
					SUM(AmtDuetoBA		*e.Rate)	AS AmtDuetoBA,
					SUM(w.betcount)					AS BetCount,
					CAST(SUM((MemberWinLost + PlayerComm)*e.Rate) AS MONEY) AS CustomerTotalWL
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.exchangeid = w.currency AND w.rptdate BETWEEN e.FromDate AND e.ToDate
				GROUP BY w.CustID, t.username, t.UserName2
			) b
		)
		SELECT *
		FROM PAGING
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (1, 2) AND @IsAscSort = 0
	BEGIN
		WITH PAGING AS (
			SELECT	ROW_NUMBER() OVER (
						ORDER BY CASE @OrderItem
							WHEN 1 THEN b.username
							WHEN 2 THEN b.nickname
						END DESC) AS RowNum,
					b.*
			FROM
			(
				SELECT 
					w.CustID,
					t.username,
					t.UserName2						AS nickname,  
					SUM(TurnOver		*e.Rate)    AS TurnOver,
					SUM(MemberWinLost	*e.Rate)	AS MemberWinLost,
					SUM(BetEffective	*e.Rate)	AS BetEffective,  
					SUM(LicenseeWL		*e.Rate) 	AS LicenseeWL,  
					SUM(CommBA			*e.Rate)    AS CommBA,  
					SUM(playerComm		*e.Rate)    AS PlayerComm,  
					SUM(AmtDuetoBA		*e.Rate)    AS AmtDuetoBA,
					SUM(w.betcount)					AS BetCount,
					CAST(SUM((MemberWinLost + PlayerComm)*e.Rate) AS MONEY) AS CustomerTotalWL
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.exchangeid = w.currency AND w.rptdate BETWEEN e.FromDate AND e.ToDate
				GROUP BY w.CustID, t.username, t.UserName2
			) b
		)
		SELECT *
		FROM PAGING
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (3, 4, 5, 6, 8, 10, 11, 13, 14) AND @IsAscSort = 0
	BEGIN
		WITH PAGING AS (
			SELECT	ROW_NUMBER() OVER (
						ORDER BY CASE @OrderItem
							WHEN 3 THEN TurnOver
							WHEN 4 THEN MemberWinLost
							WHEN 5 THEN BetEffective
							WHEN 6 THEN LicenseeWL
							WHEN 8 THEN CommBA
							WHEN 10 THEN PlayerComm
							WHEN 11 THEN AmtDuetoBA
							WHEN 13 THEN BetCount
							WHEN 14 THEN CustomerTotalWL
						END DESC, b.CustID) AS RowNum,
					b.*
			FROM
			(
				SELECT 
					w.CustID,
					t.username,
					t.UserName2 AS nickname,   
					SUM(TurnOver		*e.Rate)	AS TurnOver,
					SUM(MemberWinLost	*e.Rate)	AS MemberWinLost,
					SUM(BetEffective	*e.Rate)	AS BetEffective,  
					SUM(LicenseeWL		*e.Rate) 	AS LicenseeWL,  
					SUM(CommBA			*e.Rate)    AS CommBA,  
					SUM(playerComm		*e.Rate)    AS PlayerComm,  
					SUM(AmtDuetoBA		*e.Rate)    AS AmtDuetoBA,
					SUM(w.betcount)					AS BetCount,
					CAST(SUM((MemberWinLost + PlayerComm)*e.Rate) AS MONEY) AS CustomerTotalWL
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.exchangeid = w.currency AND w.rptdate BETWEEN e.FromDate AND e.ToDate
				GROUP BY w.CustID, t.username, t.UserName2
			) b
		)
		SELECT *
		FROM PAGING
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	DECLARE @TotalRow INT 
	SELECT @TotalRow = COUNT(DISTINCT b.custid) FROM #TempData b
 
	--- return data
	SELECT
		CAST(SUM(TurnOver		*e.Rate)	AS MONEY)	AS SumTurnOver,
		CAST(SUM(MemberWinLost	*e.Rate)	AS MONEY)	AS SumMemberWinLost,
		CAST(SUM(BetEffective	*e.Rate)    AS MONEY)	AS SumBetEffective,
		CAST(SUM(LicenseeWL		*e.Rate) 	AS MONEY)	AS SumLicenseeWL,
		CAST(SUM(CommBA			*e.Rate) 	AS MONEY)	AS SumCommBA,
		CAST(SUM(PlayerComm		*e.Rate)    AS MONEY)	AS SumPlayerComm,
		CAST(SUM(AmtDuetoBA		*e.Rate)    AS MONEY)	AS SumAmtDuetoBA,
		@TotalRow										AS TotalRows,
		SUM(b.betcount) 								AS SumBetCount,
		CAST(SUM((MemberWinLost + PlayerComm)*e.Rate) AS MONEY) AS SumCustomerTotalWL,
		SUM(PromotionPrize)								AS SumPromotionPrize
	FROM
		#TempData b
		LEFT JOIN @Exchange e ON e.exchangeid = b.currency AND b.rptdate BETWEEN e.FromDate AND e.ToDate

	DROP TABLE #TempData    
	DROP TABLE #TempCustID
	DROP TABLE #TempCustIDFull
	DROP TABLE #tmpCust

	SET NOCOUNT OFF;
END
GO