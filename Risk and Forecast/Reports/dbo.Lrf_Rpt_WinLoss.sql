/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinLoss]   
	@DrawFilter		SMALLINT = 1,
    @FromDate		DATETIME,
    @ToDate			DATETIME ,
    @showSB			BIT = 0,
    @ShowRB			BIT = 0,
    @showNG			BIT = 0, 
    @ShowBA			BIT = 0,
	@ShowVS			BIT = 0,
	@ShowCS			BIT = 0, -- RNG Casino
	@ShowBG			BIT = 0, -- Bingo
	@ShowKN			BIT = 0,
	@ShowMGCLC		BIT = 0,
	@ShowMGCRnG		BIT = 0,
	@ShowBT			BIT = 0,
	@ShowAGC		BIT = 0,
	@ShowVB			BIT = 0,
	@ShowAB			BIT = 0,
	@ShowFW			BIT	= 0,
	@ShowCO			BIT = 0,
	@ShowVS2		BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT			BIT = 0, -- Lottery
    @MoveBetsDay	DATETIME,
    @PageSize		INT = 1000,
    @PageIndex		INT = 1,
    @IsOld			BIT = 0,
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
			12: AmtDuetoRB
			13: BetCount
			14: CustomerTotalWL
			15: RacingRevenue

		@IsAscSort:
			1: ASC
			2: DESC
*/

BEGIN
	SET NOCOUNT ON

	IF @OrderItem < 1 OR @OrderItem > 15
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

	DECLARE @TempAg			TABLE (CustId INT, Currency INT)
	DECLARE @bettype		TABLE (bettype INT, ProductCode VARCHAR(10))
	DECLARE @sporttype		TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @ProductList	VARCHAR (500)
	DECLARE @Exchange		TABLE
	(
		ExchangeDate SMALLDATETIME,
		ExchangeId	 INT,
		MYR			 FLOAT,
		USD			 FLOAT,
		EUR			 FLOAT,
		GBP			 FLOAT,
		PRIMARY KEY(ExchangeDate, ExchangeId)
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
	
	INSERT INTO @Exchange(ExchangeDate, ExchangeId, MYR, USD, EUR, GBP)
	SELECT ExchangeDate, ExchangeId, MYR, USD, EUR, GBP
	FROM Lrf_f_GetExchangeDaily(@_FromDate, @_ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @TempAg)

	IF @ShowSB = 1 
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')	
	END

	IF @ShowRB = 1 
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'RB', 'RB')	
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

	IF @ShowBG = 1
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'BG', 'BG')
	END

	IF @ShowKN = 1 -- Keno
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')
	END

	IF @ShowMGCLC = 1 -- MicroGamming
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCLC', 'MGCLC')
	END

	IF @ShowMGCRnG = 1 -- MicroGamming
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCRNG', 'MGCRNG')
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
		FROM  bodb_licensee.dbo.LicenseeCustinfo  c WITH (NOLOCK) 
		  
		WHERE   c.recommend		IN (SELECT custid FROM @TempAg)
			AND (
				c.username2 	LIKE '%$%' 	+ @Username + '%'
				OR c.username	LIKE '%' 	+ @Username + '%'
			)
		
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
		WinlossRB		MONEY,
		AmtDueToBA		MONEY,
		AmtDueToRB		MONEY,
		CommBA			MONEY,
		CommRB			MONEY,
		PlayerComm		MONEY,
		betcount		INT,
		currency		INT,
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
					0 AS WinlossRB,
					- SUM (b.winlost - b.actual_stake + awinlost + comm) AS AmountDueToBA,
					0 AS AmountDueToRB,
					SUM (comm) AS CommBA,
					0 AS CommRB,
					SUM(PlayerComm ) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter = 2 AND b.statusid = 111 THEN 0 ELSE 1 END) AS betcount,
					b.currency	
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
					0 AS WinlossRB,
					0 AS AmountDueToBA,
					0 AS AmountDueToRB,
					0 AS CommBA,
					0 AS CommRB,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter = 2 AND b.statusid = 111 THEN 0 ELSE 1 END) AS betcount,
					b.currency	
				FROM    
					Bettrans b WITH (NOLOCK)
					INNER JOIN @TempAg a ON b.recommend = a.custid  AND b.currency=a.Currency
				WHERE   
					winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND
					(
						b.bettype < 31
						OR b.bettype BETWEEN 121 AND 999
						OR b.Bettype BETWEEN 1301 AND 1399
					)
					AND b.statusID IN (111, 112, 113)
					AND b.tpositiontaking <> 0
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
				GROUP BY b.CustID, b.winlostdate, b.currency	 
			END

			IF 1 IN (@ShowNG, @ShowVS, @ShowRB, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowBT, @ShowAGC, @ShowVb,@ShowAB,@ShowFW, @ShowCO, @ShowVS2, @ShowLT)
			BEGIN
				INSERT INTO #TempData
				SELECT
					b.CustID ,
					b.winlostdate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902, 911, 912) THEN 0
							 ELSE 
							 CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END
						END
					) AS Turnover,
					SUM(winlost - actual_stake) AS MemberWinlost ,
					SUM(ABS(winlost - actual_stake)) AS BetEffective,
					- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL,
					SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
					0 AS AmountDueToBA,
					- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END) AS AmountDueToRB,
					0 AS CommBA,
					SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.comm ELSE 0 END) AS CommRB,
					SUM( b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter = 2 AND b.statusid = 111 THEN 0 ELSE 1 END) AS betcount,
					b.currency	
				FROM    
					bettrans b WITH (NOLOCK)
					INNER JOIN @TempAg a   ON b.recommend = a.custid AND b.currency = a.Currency
					INNER JOIN @bettype bt ON b.bettype = bt.bettype	 
				WHERE   
					winlostdate BETWEEN @TempFromDate AND @_ToDate
					AND b.statusID IN (111, 112, 113)			
				GROUP BY b.CustID, b.winlostdate, b.currency	
			END
		END

		IF @_FromDate <= @MoveBetsDay AND @IsOld = 0
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
					0 AS WinlossRB,
					- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
					0 AS AmountDueToRB,
					SUM (comm) AS CommBA,
					0 AS CommRB,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) AS betcount,
					b.currency		 
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
			IF 1 IN (@ShowSB, @ShowRB, @ShowNG, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowAGC, @ShowVB, @ShowAB, @ShowFW, @ShowVS2, @ShowLT)
			BEGIN
				INSERT INTO #TempData
				SELECT
					b.CustID ,
					b.winlostdate AS rptdate,
					SUM(CASE WHEN (@DrawFilter IN (2, 3) AND b.statusid = 111) OR b.bettype IN (901, 902) THEN 0 ELSE b.turnover END) AS Turnover,
					SUM(winlost) MemberWinlost,
					CASE WHEN winlostdate < @BetEffectiveDate THEN 0 ELSE SUM(ISNULL(BetEffective, 0)) END AS BetEffective,
					- SUM(CASE WHEN (b.sporttype <> 151) THEN b.winlost ELSE 0 END) AS LicenseeWL ,
					SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
					0 AS AmountDueToBA,
					- SUM (CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
					0 AS CommBA,
					SUM (CASE WHEN b.sporttype = 151 THEN b.comm ELSE 0 END) AS CommRB,
					SUM(b.PlayerComm) AS PlayerComm,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) as betcount,
					b.currency		 
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
					0 AS WinlossRB,
					0 AS AmountDueToBA,
					0 AS AmountDueToRB,
					0 AS CommBA,
					0 AS CommRB,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) as betcount,
					b.currency		 
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
					0 AS WinlossRB,
					0 AS AmountDueToBA,
					0 AS AmountDueToRB,
					0 AS CommBA,
					0 AS CommRB,
					SUM(b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) as betcount,
					b.currency		 
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
		ELSE IF @IsOld = 1
		BEGIN
			IF @ShowBA = 1
			BEGIN
				INSERT  INTO #TempData
				SELECT  
					b.CustID ,
					b.winlostdate AS rptdate,
					SUM(CASE WHEN @DrawFilter IN (2, 3) AND b.statusid = 111 THEN 0 ELSE b.turnover END) AS Turnover,
					SUM(winlost) MemberWinlost,
					0 AS BetEffective,
					0 AS LicenseeWL,
					0 AS WinlossRB,
					- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
					0 AS AmountDueToRB,
					SUM (comm ) AS CommBA,
					0 AS CommRB,
					SUM( b.PlayerComm) AS PlayerComm ,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) AS betcount,
					b.currency			 
				FROM    
					bodb_licenseereport.dbo.rptLicWinloss_Old b WITH (NOLOCK)
					INNER JOIN @TempAg ag ON ag.custid = b.recommend  
			 
				WHERE   
					b.Winlostdate BETWEEN @_FromDate AND @_ToDate
					AND roleID = 1
					AND b.statusID <> 101 
					AND ISNULL(b.isBA, 0) = 1
					AND b.currency IN (SELECT Currency FROM @TempAg)
					AND b.bettype NOT IN (901, 902, 903,904)
				GROUP BY b.CustID, b.winlostdate, b.currency	
			END
	
			IF 1 IN (@showSB, @ShowRB, @ShowNG, @ShowVS, @ShowCS, @ShowBG, @ShowKN, @ShowMGCLC, @ShowMGCRnG, @ShowVB,@ShowAB,@ShowFW, @ShowVS2)
			BEGIN
				INSERT  INTO #TempData
				SELECT  
					b.CustID ,
					b.winlostdate AS rptdate,
					SUM(CASE WHEN @DrawFilter IN (2,3) AND b.statusid = 111 THEN 0 ELSE b.turnover END) AS Turnover,
					SUM(winlost) MemberWinlost,
					0 AS BetEffective,
					- SUM(CASE WHEN b.sporttype <> 151 THEN b.winlost ELSE 0 END) AS LicenseeWL,
					SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
					0 AS AmountDueToBA,
					- SUM(CASE WHEN b.sporttype = 151 THEN b.winlost+b.awinlost+b.comm ELSE 0 END) AS AmountDueToRB,
					0 AS CommBA,
					SUM(CASE WHEN b.sporttype = 151 THEN b.comm ELSE 0 END) AS CommRB,
					SUM(b.PlayerComm) AS PlayerComm,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) AS betcount,
					b.currency			
				FROM    
					bodb_licenseereport.dbo.rptLicWinloss_Old b WITH (NOLOCK)
					INNER JOIN @TempAg ag   ON ag.custid = b.recommend AND b.Currency = ag.Currency
					INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				WHERE   
					Winlostdate BETWEEN @_FromDate AND @_ToDate
					AND roleID = 1
					AND ISNULL(b.isBA,0) = 0
					AND b.statusID <> 101 
					AND b.bettype NOT IN (901,902,903,904)
				GROUP BY b.CustID,b.winlostdate,b.currency	
			END

			IF @showBT = 1
			BEGIN
				INSERT INTO #TempData
				SELECT  
					b.CustID ,
					b.winlostdate AS rptdate,
					SUM(CASE WHEN @DrawFilter IN (2, 3) AND b.statusid = 111 THEN 0 ELSE b.turnover END) AS Turnover,
					SUM(winlost) MemberWinlost,
					0 AS BetEffective,
					- SUM(b.winlost) AS LicenseeWL ,
					0 AS WinlossRB,
					0 AS AmountDueToBA,
					0 AS AmountDueToRB,
					0 AS CommBA,
					0 AS CommRB,
					SUM(b.PlayerComm) AS PlayerComm,
					SUM(CASE WHEN @DrawFilter IN (2) AND b.statusid = 111 THEN 0 ELSE b.BetCount END) AS betcount,
					b.currency			
				FROM    
					bodb_licenseereport.dbo.rptLicWinloss_Old b WITH ( NOLOCK )
					INNER JOIN @TempAg ag   ON ag.custid = b.recommend AND b.Currency = ag.Currency
					INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				WHERE   
					Winlostdate BETWEEN @_FromDate AND @_ToDate
					AND roleID = 1		
					AND b.statusID <> 101 
					AND b.bettype IN (901, 902)
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
		INNER JOIN bodb_Licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.CustID = c.CustID	

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
					SUM(TurnOver)			 AS TurnOver ,  
					SUM(TurnOver*e.USD)      AS TurnOverUSD ,  
					SUM(TurnOver*e.EUR)      AS TurnOverEUR ,  
					SUM(TurnOver*e.GBP)      AS TurnOverGBP , 
					SUM(MemberWinLost)		 AS MemberWinLost ,
					SUM(MemberWinLost*e.USD) AS MemberWinLostUSD ,  
					SUM(MemberWinLost*e.EUR) AS MemberWinLostEUR , 
					SUM(MemberWinLost*e.GBP) AS MemberWinLostGBP , 
					SUM(BetEffective)		 AS BetEffective,
					SUM(BetEffective*e.USD)  AS BetEffectiveUSD,
					SUM(BetEffective*e.EUR)  AS BetEffectiveEUR,
					SUM(BetEffective*e.GBP)  AS BetEffectiveGBP,
					SUM(LicenseeWL)			 AS LicenseeWL,  
					SUM(LicenseeWL*e.USD) 	 AS LicenseeWLUSD,  
					SUM(LicenseeWL*e.EUR)    AS LicenseeWLEUR,  
					SUM(LicenseeWL*e.GBP)    AS LicenseeWLGBP,  
					SUM(WinlossRB)			 AS WinlossRB,  
					SUM(WinlossRB*e.USD)     AS WinlossRBUSD,  
					SUM(WinlossRB*e.EUR)     AS WinlossRBEUR,  
					SUM(WinlossRB*e.GBP)     AS WinlossRBGBP,
					SUM(CommBA)				 AS CommBA,  
					SUM(CommBA*e.USD)        AS CommBAUSD,  
					SUM(CommBA*e.EUR)        AS CommBAEUR,  
					SUM(CommBA*e.GBP)        AS CommBAGBP,
					SUM(commRB)				 AS commRB,  
					SUM(commRB*e.USD)        AS commRBUSD,  
					SUM(commRB*e.EUR)        AS commRBEUR,  
					SUM(commRB*e.GBP)        AS commRBGBP,
					SUM(playerComm)			 AS PlayerComm,  
					SUM(playerComm*e.USD)    AS PlayerCommUSD,  
					SUM(playerComm*e.EUR)    AS PlayerCommEUR,  
					SUM(playerComm*e.GBP)    AS PlayerCommGBP,
					SUM(AmtDuetoBA)			 AS AmtDuetoBA,  
					SUM(AmtDuetoBA*e.USD)    AS AmtDuetoBAUSD,  
					SUM(AmtDuetoBA*e.EUR)    AS AmtDuetoBAEUR,  
					SUM(AmtDuetoBA*e.GBP)    AS AmtDuetoBAGBP,
					SUM(AmtDuetoRB)			 AS AmtDuetoRB,  
					SUM(AmtDuetoRB*e.USD)    AS AmtDuetoRBUSD,  
					SUM(AmtDuetoRB*e.EUR)    AS AmtDuetoRBEUR,
					SUM(AmtDuetoRB*e.GBP)    AS AmtDuetoRBGBP,
					SUM(w.betcount)			 AS BetCount,
					SUM(MemberWinLost + PlayerComm)				 AS CustomerTotalWL,
					CAST(SUM((MemberWinLost + PlayerComm)*e.USD) AS MONEY) AS CustomerTotalWLUSD,
					CAST(SUM((MemberWinLost + PlayerComm)*e.EUR) AS MONEY) AS CustomerTotalWLEUR,
					CAST(SUM((MemberWinLost + PlayerComm)*e.GBP) AS MONEY) AS CustomerTotalWLGBP,
					SUM(WinlossRB + commRB)						 AS RacingRevenue,
					CAST(SUM((WinlossRB + commRB)*e.USD) AS MONEY) AS RacingRevenueUSD,
					CAST(SUM((WinlossRB + commRB)*e.EUR) AS MONEY) AS RacingRevenueEUR,
					CAST(SUM((WinlossRB + commRB)*e.GBP) AS MONEY) AS RacingRevenueGBP
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.ExchangeDate = w.rptdate AND e.exchangeid = w.currency
				GROUP BY w.CustID, t.username, t.UserName2
			) b
		)
		SELECT *
		FROM PAGING
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15) AND @IsAscSort = 1
	BEGIN
		WITH PAGING AS (
			SELECT	ROW_NUMBER() OVER (
						ORDER BY CASE @OrderItem
							WHEN 3 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN TurnOverUSD
									WHEN 'EUR' THEN TurnOverEUR
									WHEN 'GBP' THEN TurnOverGBP
									ELSE TurnOver
								END
							WHEN 4 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN MemberWinLostUSD
									WHEN 'EUR' THEN MemberWinLostEUR
									WHEN 'GBP' THEN MemberWinLostGBP
									ELSE MemberWinLost
								END
							WHEN 5 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN BetEffectiveUSD
									WHEN 'EUR' THEN BetEffectiveEUR
									WHEN 'GBP' THEN BetEffectiveGBP
									ELSE BetEffective
								END
							WHEN 6 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN LicenseeWLUSD
									WHEN 'EUR' THEN LicenseeWLEUR
									WHEN 'GBP' THEN LicenseeWLGBP
									ELSE LicenseeWL
								END
							WHEN 7 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN WinlossRBUSD
									WHEN 'EUR' THEN WinlossRBEUR
									WHEN 'GBP' THEN WinlossRBGBP
									ELSE WinlossRB
								END
							WHEN 8 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN CommBAUSD
									WHEN 'EUR' THEN CommBAEUR
									WHEN 'GBP' THEN CommBAGBP
									ELSE CommBA
								END
							WHEN 9 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN commRBUSD
									WHEN 'EUR' THEN commRBEUR
									WHEN 'GBP' THEN commRBGBP
									ELSE commRB
								END
							WHEN 10 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN PlayerCommUSD
									WHEN 'EUR' THEN PlayerCommEUR
									WHEN 'GBP' THEN PlayerCommGBP
									ELSE PlayerComm
								END
							WHEN 11 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN AmtDuetoBAUSD
									WHEN 'EUR' THEN AmtDuetoBAEUR
									WHEN 'GBP' THEN AmtDuetoBAGBP
									ELSE AmtDuetoBA
								END
							WHEN 12 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN AmtDuetoRBUSD
									WHEN 'EUR' THEN AmtDuetoRBEUR
									WHEN 'GBP' THEN AmtDuetoRBGBP
									ELSE AmtDuetoRB
								END
							WHEN 13 THEN BetCount
							WHEN 14 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN CustomerTotalWLUSD
									WHEN 'EUR' THEN CustomerTotalWLEUR
									WHEN 'GBP' THEN CustomerTotalWLGBP
									ELSE CustomerTotalWL
								END
							WHEN 15 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN RacingRevenueUSD
									WHEN 'EUR' THEN RacingRevenueEUR
									WHEN 'GBP' THEN RacingRevenueGBP
									ELSE RacingRevenue
								END
						END, b.CustID) AS RowNum,
					b.*
			FROM
			(
				SELECT 
					w.CustID,
					t.username,
					t.UserName2 AS nickname, 
					SUM(TurnOver)			 AS TurnOver ,  
					SUM(TurnOver*e.USD)      AS TurnOverUSD ,  
					SUM(TurnOver*e.EUR)      AS TurnOverEUR ,  
					SUM(TurnOver*e.GBP)      AS TurnOverGBP , 
					SUM(MemberWinLost)		 AS MemberWinLost ,
					SUM(MemberWinLost*e.USD) AS MemberWinLostUSD ,  
					SUM(MemberWinLost*e.EUR) AS MemberWinLostEUR , 
					SUM(MemberWinLost*e.GBP) AS MemberWinLostGBP , 
					SUM(BetEffective)		 AS BetEffective,
					SUM(BetEffective*e.USD)  AS BetEffectiveUSD,
					SUM(BetEffective*e.EUR)  AS BetEffectiveEUR,
					SUM(BetEffective*e.GBP)  AS BetEffectiveGBP,
					SUM(LicenseeWL)			 AS LicenseeWL,  
					SUM(LicenseeWL*e.USD) 	 AS LicenseeWLUSD,  
					SUM(LicenseeWL*e.EUR)    AS LicenseeWLEUR,  
					SUM(LicenseeWL*e.GBP)    AS LicenseeWLGBP,  
					SUM(WinlossRB)			 AS WinlossRB,  
					SUM(WinlossRB*e.USD)     AS WinlossRBUSD,  
					SUM(WinlossRB*e.EUR)     AS WinlossRBEUR,  
					SUM(WinlossRB*e.GBP)     AS WinlossRBGBP,
					SUM(CommBA)				 AS CommBA,  
					SUM(CommBA*e.USD)        AS CommBAUSD,  
					SUM(CommBA*e.EUR)        AS CommBAEUR,  
					SUM(CommBA*e.GBP)        AS CommBAGBP,
					SUM(commRB)				 AS commRB,  
					SUM(commRB*e.USD)        AS commRBUSD,  
					SUM(commRB*e.EUR)        AS commRBEUR,  
					SUM(commRB*e.GBP)        AS commRBGBP,
					SUM(playerComm)			 AS PlayerComm,  
					SUM(playerComm*e.USD)    AS PlayerCommUSD,  
					SUM(playerComm*e.EUR)    AS PlayerCommEUR,  
					SUM(playerComm*e.GBP)    AS PlayerCommGBP,
					SUM(AmtDuetoBA)			 AS AmtDuetoBA,  
					SUM(AmtDuetoBA*e.USD)    AS AmtDuetoBAUSD,  
					SUM(AmtDuetoBA*e.EUR)    AS AmtDuetoBAEUR,  
					SUM(AmtDuetoBA*e.GBP)    AS AmtDuetoBAGBP,
					SUM(AmtDuetoRB)			 AS AmtDuetoRB,  
					SUM(AmtDuetoRB*e.USD)    AS AmtDuetoRBUSD,  
					SUM(AmtDuetoRB*e.EUR)    AS AmtDuetoRBEUR,
					SUM(AmtDuetoRB*e.GBP)    AS AmtDuetoRBGBP,
					SUM(w.betcount)			 AS BetCount,
					SUM(MemberWinLost + PlayerComm)				 AS CustomerTotalWL,
					CAST(SUM((MemberWinLost + PlayerComm)*e.USD) AS MONEY) AS CustomerTotalWLUSD,
					CAST(SUM((MemberWinLost + PlayerComm)*e.EUR) AS MONEY) AS CustomerTotalWLEUR,
					CAST(SUM((MemberWinLost + PlayerComm)*e.GBP) AS MONEY) AS CustomerTotalWLGBP,
					SUM(WinlossRB + commRB)						 AS RacingRevenue,
					CAST(SUM((WinlossRB + commRB)*e.USD) AS MONEY) AS RacingRevenueUSD,
					CAST(SUM((WinlossRB + commRB)*e.EUR) AS MONEY) AS RacingRevenueEUR,
					CAST(SUM((WinlossRB + commRB)*e.GBP) AS MONEY) AS RacingRevenueGBP
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.ExchangeDate = w.rptdate AND e.exchangeid = w.currency
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
					t.UserName2 AS nickname, 
					SUM(TurnOver)			 AS TurnOver ,  
					SUM(TurnOver*e.USD)      AS TurnOverUSD ,  
					SUM(TurnOver*e.EUR)      AS TurnOverEUR ,  
					SUM(TurnOver*e.GBP)      AS TurnOverGBP , 
					SUM(MemberWinLost)		 AS MemberWinLost ,
					SUM(MemberWinLost*e.USD) AS MemberWinLostUSD ,  
					SUM(MemberWinLost*e.EUR) AS MemberWinLostEUR , 
					SUM(MemberWinLost*e.GBP) AS MemberWinLostGBP , 
					SUM(BetEffective)		 AS BetEffective,
					SUM(BetEffective*e.USD)  AS BetEffectiveUSD,
					SUM(BetEffective*e.EUR)  AS BetEffectiveEUR,
					SUM(BetEffective*e.GBP)  AS BetEffectiveGBP,
					SUM(LicenseeWL)			 AS LicenseeWL,  
					SUM(LicenseeWL*e.USD) 	 AS LicenseeWLUSD,  
					SUM(LicenseeWL*e.EUR)    AS LicenseeWLEUR,  
					SUM(LicenseeWL*e.GBP)    AS LicenseeWLGBP,  
					SUM(WinlossRB)			 AS WinlossRB,  
					SUM(WinlossRB*e.USD)     AS WinlossRBUSD,  
					SUM(WinlossRB*e.EUR)     AS WinlossRBEUR,  
					SUM(WinlossRB*e.GBP)     AS WinlossRBGBP,
					SUM(CommBA)				 AS CommBA,  
					SUM(CommBA*e.USD)        AS CommBAUSD,  
					SUM(CommBA*e.EUR)        AS CommBAEUR,  
					SUM(CommBA*e.GBP)        AS CommBAGBP,
					SUM(commRB)				 AS commRB,  
					SUM(commRB*e.USD)        AS commRBUSD,  
					SUM(commRB*e.EUR)        AS commRBEUR,  
					SUM(commRB*e.GBP)        AS commRBGBP,
					SUM(playerComm)			 AS PlayerComm,  
					SUM(playerComm*e.USD)    AS PlayerCommUSD,  
					SUM(playerComm*e.EUR)    AS PlayerCommEUR,  
					SUM(playerComm*e.GBP)    AS PlayerCommGBP,
					SUM(AmtDuetoBA)			 AS AmtDuetoBA,  
					SUM(AmtDuetoBA*e.USD)    AS AmtDuetoBAUSD,  
					SUM(AmtDuetoBA*e.EUR)    AS AmtDuetoBAEUR,  
					SUM(AmtDuetoBA*e.GBP)    AS AmtDuetoBAGBP,
					SUM(AmtDuetoRB)			 AS AmtDuetoRB,  
					SUM(AmtDuetoRB*e.USD)    AS AmtDuetoRBUSD,  
					SUM(AmtDuetoRB*e.EUR)    AS AmtDuetoRBEUR,
					SUM(AmtDuetoRB*e.GBP)    AS AmtDuetoRBGBP,
					SUM(w.betcount)			 AS BetCount,
					SUM(MemberWinLost + PlayerComm)				 AS CustomerTotalWL,
					CAST(SUM((MemberWinLost + PlayerComm)*e.USD) AS MONEY) AS CustomerTotalWLUSD,
					CAST(SUM((MemberWinLost + PlayerComm)*e.EUR) AS MONEY) AS CustomerTotalWLEUR,
					CAST(SUM((MemberWinLost + PlayerComm)*e.GBP) AS MONEY) AS CustomerTotalWLGBP,
					SUM(WinlossRB + commRB)						 AS RacingRevenue,
					CAST(SUM((WinlossRB + commRB)*e.USD) AS MONEY) AS RacingRevenueUSD,
					CAST(SUM((WinlossRB + commRB)*e.EUR) AS MONEY) AS RacingRevenueEUR,
					CAST(SUM((WinlossRB + commRB)*e.GBP) AS MONEY) AS RacingRevenueGBP
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.ExchangeDate = w.rptdate AND e.exchangeid = w.currency
				GROUP BY w.CustID, t.username, t.UserName2
			) b
		)
		SELECT *
		FROM PAGING
		WHERE RowNum BETWEEN @RowStart AND @RowEnd
	END

	IF @OrderItem IN (3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15) AND @IsAscSort = 0
	BEGIN
		WITH PAGING AS (
			SELECT	ROW_NUMBER() OVER (
						ORDER BY CASE @OrderItem
							WHEN 3 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN TurnOverUSD
									WHEN 'EUR' THEN TurnOverEUR
									WHEN 'GBP' THEN TurnOverGBP
									ELSE TurnOver
								END
							WHEN 4 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN MemberWinLostUSD
									WHEN 'EUR' THEN MemberWinLostEUR
									WHEN 'GBP' THEN MemberWinLostGBP
									ELSE MemberWinLost
								END
							WHEN 5 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN BetEffectiveUSD
									WHEN 'EUR' THEN BetEffectiveEUR
									WHEN 'GBP' THEN BetEffectiveGBP
									ELSE BetEffective
								END
							WHEN 6 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN LicenseeWLUSD
									WHEN 'EUR' THEN LicenseeWLEUR
									WHEN 'GBP' THEN LicenseeWLGBP
									ELSE LicenseeWL
								END
							WHEN 7 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN WinlossRBUSD
									WHEN 'EUR' THEN WinlossRBEUR
									WHEN 'GBP' THEN WinlossRBGBP
									ELSE WinlossRB
								END
							WHEN 8 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN CommBAUSD
									WHEN 'EUR' THEN CommBAEUR
									WHEN 'GBP' THEN CommBAGBP
									ELSE CommBA
								END
							WHEN 9 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN commRBUSD
									WHEN 'EUR' THEN commRBEUR
									WHEN 'GBP' THEN commRBGBP
									ELSE commRB
								END
							WHEN 10 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN PlayerCommUSD
									WHEN 'EUR' THEN PlayerCommEUR
									WHEN 'GBP' THEN PlayerCommGBP
									ELSE PlayerComm
								END
							WHEN 11 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN AmtDuetoBAUSD
									WHEN 'EUR' THEN AmtDuetoBAEUR
									WHEN 'GBP' THEN AmtDuetoBAGBP
									ELSE AmtDuetoBA
								END
							WHEN 12 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN AmtDuetoRBUSD
									WHEN 'EUR' THEN AmtDuetoRBEUR
									WHEN 'GBP' THEN AmtDuetoRBGBP
									ELSE AmtDuetoRB
								END
							WHEN 13 THEN BetCount
							WHEN 14 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN CustomerTotalWLUSD
									WHEN 'EUR' THEN CustomerTotalWLEUR
									WHEN 'GBP' THEN CustomerTotalWLGBP
									ELSE CustomerTotalWL
								END
							WHEN 15 THEN
								CASE @BaseCurrency
									WHEN 'USD' THEN RacingRevenueUSD
									WHEN 'EUR' THEN RacingRevenueEUR
									WHEN 'GBP' THEN RacingRevenueGBP
									ELSE RacingRevenue
								END
						END DESC, b.CustID) AS RowNum,
					b.*
			FROM
			(
				SELECT 
					w.CustID,
					t.username,
					t.UserName2 AS nickname, 
					SUM(TurnOver)			 AS TurnOver ,  
					SUM(TurnOver*e.USD)      AS TurnOverUSD ,  
					SUM(TurnOver*e.EUR)      AS TurnOverEUR ,  
					SUM(TurnOver*e.GBP)      AS TurnOverGBP , 
					SUM(MemberWinLost)		 AS MemberWinLost ,
					SUM(MemberWinLost*e.USD) AS MemberWinLostUSD ,  
					SUM(MemberWinLost*e.EUR) AS MemberWinLostEUR , 
					SUM(MemberWinLost*e.GBP) AS MemberWinLostGBP , 
					SUM(BetEffective)		 AS BetEffective,
					SUM(BetEffective*e.USD)  AS BetEffectiveUSD,
					SUM(BetEffective*e.EUR)  AS BetEffectiveEUR,
					SUM(BetEffective*e.GBP)  AS BetEffectiveGBP,
					SUM(LicenseeWL)			 AS LicenseeWL,  
					SUM(LicenseeWL*e.USD) 	 AS LicenseeWLUSD,  
					SUM(LicenseeWL*e.EUR)    AS LicenseeWLEUR,  
					SUM(LicenseeWL*e.GBP)    AS LicenseeWLGBP,  
					SUM(WinlossRB)			 AS WinlossRB,  
					SUM(WinlossRB*e.USD)     AS WinlossRBUSD,  
					SUM(WinlossRB*e.EUR)     AS WinlossRBEUR,  
					SUM(WinlossRB*e.GBP)     AS WinlossRBGBP,
					SUM(CommBA)				 AS CommBA,  
					SUM(CommBA*e.USD)        AS CommBAUSD,  
					SUM(CommBA*e.EUR)        AS CommBAEUR,  
					SUM(CommBA*e.GBP)        AS CommBAGBP,
					SUM(commRB)				 AS commRB,  
					SUM(commRB*e.USD)        AS commRBUSD,  
					SUM(commRB*e.EUR)        AS commRBEUR,  
					SUM(commRB*e.GBP)        AS commRBGBP,
					SUM(playerComm)			 AS PlayerComm,  
					SUM(playerComm*e.USD)    AS PlayerCommUSD,  
					SUM(playerComm*e.EUR)    AS PlayerCommEUR,  
					SUM(playerComm*e.GBP)    AS PlayerCommGBP,
					SUM(AmtDuetoBA)			 AS AmtDuetoBA,  
					SUM(AmtDuetoBA*e.USD)    AS AmtDuetoBAUSD,  
					SUM(AmtDuetoBA*e.EUR)    AS AmtDuetoBAEUR,  
					SUM(AmtDuetoBA*e.GBP)    AS AmtDuetoBAGBP,
					SUM(AmtDuetoRB)			 AS AmtDuetoRB,  
					SUM(AmtDuetoRB*e.USD)    AS AmtDuetoRBUSD,  
					SUM(AmtDuetoRB*e.EUR)    AS AmtDuetoRBEUR,
					SUM(AmtDuetoRB*e.GBP)    AS AmtDuetoRBGBP,
					SUM(w.betcount)			 AS BetCount,
					SUM(MemberWinLost + PlayerComm)				 AS CustomerTotalWL,
					CAST(SUM((MemberWinLost + PlayerComm)*e.USD) AS MONEY) AS CustomerTotalWLUSD,
					CAST(SUM((MemberWinLost + PlayerComm)*e.EUR) AS MONEY) AS CustomerTotalWLEUR,
					CAST(SUM((MemberWinLost + PlayerComm)*e.GBP) AS MONEY) AS CustomerTotalWLGBP,
					SUM(WinlossRB + commRB)						 AS RacingRevenue,
					CAST(SUM((WinlossRB + commRB)*e.USD) AS MONEY) AS RacingRevenueUSD,
					CAST(SUM((WinlossRB + commRB)*e.EUR) AS MONEY) AS RacingRevenueEUR,
					CAST(SUM((WinlossRB + commRB)*e.GBP) AS MONEY) AS RacingRevenueGBP
				FROM		
					#TempData w
					INNER JOIN #TempCustID t ON w.CustID = t.CustID
					LEFT JOIN @Exchange e  ON e.ExchangeDate = w.rptdate AND e.exchangeid = w.currency
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
		SUM(TurnOver) 								 AS SumTurnOver ,
		CAST(SUM(TurnOver*e.USD)		AS MONEY)	 AS SumTurnOverUSD ,
		CAST(SUM(TurnOver*e.EUR)        AS MONEY)	 AS SumTurnOverEUR ,
		CAST(SUM(TurnOver*e.GBP)        AS MONEY)	 AS SumTurnOverGBP ,
		SUM(MemberWinLost) 							 AS SumMemberWinLost ,
		SUM(BetEffective)						     AS SumBetEffective,
		CAST(SUM(MemberWinLost*e.USD)   AS MONEY)	 AS SumMemberWinLostUSD ,
		CAST(SUM(BetEffective*e.USD)    AS MONEY)	 AS SumBetEffectiveUSD ,
		CAST(SUM(MemberWinLost*e.EUR)   AS MONEY)	 AS SumMemberWinLostEUR,
		CAST(SUM(BetEffective*e.EUR) 	AS MONEY)	 AS SumBetEffectiveEUR  ,
		CAST(SUM(MemberWinLost*e.GBP)   AS MONEY)	 AS SumMemberWinLostGBP,
		CAST(SUM(BetEffective*e.GBP) 	AS MONEY)	 AS SumBetEffectiveGBP,
		SUM(LicenseeWL) 							 AS SumLicenseeWL,
		CAST(SUM(LicenseeWL*e.USD) 	    AS MONEY)	 AS SumLicenseeWLUSD,
		CAST(SUM(LicenseeWL*e.EUR)      AS MONEY)	 AS SumLicenseeWLEUR,
		CAST(SUM(LicenseeWL*e.GBP)      AS MONEY)	 AS SumLicenseeWLGBP,
		SUM(WinlossRB) 								 AS SumWinlossRB,
		CAST(SUM(WinlossRB*e.USD) 	    AS MONEY)	 AS SumWinlossRBUSD,
		CAST(SUM(WinlossRB*e.EUR)       AS MONEY)	 AS SumWinlossRBEUR,
		CAST(SUM(WinlossRB*e.GBP)       AS MONEY)	 AS SumWinlossRBGBP,
		SUM(CommBA) 								 AS SumCommBA,
		CAST(SUM(CommBA*e.USD) 		    AS MONEY)	 AS SumCommBAUSD,
		CAST(SUM(CommBA*e.EUR) 		    AS MONEY)	 AS SumCommBAEUR,
		CAST(SUM(CommBA*e.GBP) 		    AS MONEY)	 AS SumCommBAGBP,
		SUM(commRB) 								 AS SumcommRB,
		CAST(SUM(commRB*e.USD) 		    AS MONEY)	 AS SumcommRBUSD,
		CAST(SUM(commRB*e.EUR) 		    AS MONEY)	 AS SumcommRBEUR,
		CAST(SUM(commRB*e.GBP) 		    AS MONEY)	 AS SumcommRBGBP,
		SUM(PlayerComm)       						 AS SumPlayerComm,
		CAST(SUM(PlayerComm*e.USD)      AS MONEY)	 AS SumPlayerCommUSD,
		CAST(SUM(PlayerComm*e.EUR)      AS MONEY)	 AS SumPlayerCommEUR,
		CAST(SUM(PlayerComm*e.GBP)      AS MONEY)	 AS SumPlayerCommGBP,
		SUM(AmtDuetoBA) 				    		 AS SumAmtDuetoBA,
		CAST(SUM(AmtDuetoBA*e.USD)      AS MONEY)	 AS SumAmtDuetoBAUSD,
		CAST(SUM(AmtDuetoBA*e.EUR)      AS MONEY)	 AS SumAmtDuetoBAEUR,
		CAST(SUM(AmtDuetoBA*e.GBP)      AS MONEY)	 AS SumAmtDuetoBAGBP,
		SUM(AmtDuetoRB)		 						 AS SumAmtDuetoRB,
		CAST(SUM(AmtDuetoRB*e.USD)      AS MONEY)	 AS SumAmtDuetoRBUSD,
		CAST(SUM(AmtDuetoRB*e.EUR)      AS MONEY)	 AS SumAmtDuetoRBEUR,
		CAST(SUM(AmtDuetoRB*e.GBP)      AS MONEY)	 AS SumAmtDuetoRBGBP,
		@TotalRow 									 AS TotalRows,
		SUM(b.betcount) 							 AS SumBetCount,
		SUM(MemberWinLost + PlayerComm)				 AS SumCustomerTotalWL,
		CAST(SUM((MemberWinLost + PlayerComm)*e.USD) AS MONEY) AS SumCustomerTotalWLUSD,
		CAST(SUM((MemberWinLost + PlayerComm)*e.EUR) AS MONEY) AS SumCustomerTotalWLEUR,
		CAST(SUM((MemberWinLost + PlayerComm)*e.GBP) AS MONEY) AS SumCustomerTotalWLGBP,
		SUM(WinlossRB + commRB)						 AS SumRacingRevenue,
		CAST(SUM((WinlossRB + commRB)*e.USD) AS MONEY) AS SumRacingRevenueUSD,
		CAST(SUM((WinlossRB + commRB)*e.EUR) AS MONEY) AS SumRacingRevenueEUR,
		CAST(SUM((WinlossRB + commRB)*e.GBP) AS MONEY) AS SumRacingRevenueGBP
	FROM
		#TempData b
		LEFT JOIN @Exchange e ON e.ExchangeDate = b.rptdate AND e.exchangeid = b.currency

	DROP TABLE #TempData    
	DROP TABLE #TempCustID
	DROP TABLE #TempCustIDFull
	DROP TABLE #tmpCust

	SET NOCOUNT OFF;
END
GO