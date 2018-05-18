/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_PlatformWinlossDetail]   
	@FromDate	SMALLDATETIME,  
	@ToDate		SMALLDATETIME,   
	@showSB		BIT=0,  
	@ShowRB		BIT=0,  
	@ShowNG		BIT=0, 
	@ShowBA		BIT=0,
	@ShowVS		BIT=0,
	@ShowKN		BIT=0,
	@ShowCS		BIT=0,
	@ShowMGCLC	BIT=0,
	@ShowMGCRNG	BIT=0,
	@ShowVB		BIT=0,		
	@ShowAB		BIT=0,	
	@ShowFW		BIT=0,
	@ShowVS2	BIT = 0, -- Bet Radar Virtual Sports
	@ShowLT		BIT = 0, -- Lottery
	@PlatformType	TINYINT=0, 
	@MoveBetsDay	SMALLDATETIME,
	@drawfilter		SMALLINT = 1,
	@AgentList		VARCHAR(MAX)
AS

/*  Created: 20160406@Victor
    Task : Platform WinLoss Report - Detail view
    DB: DBEXT/bodb02  
   
    Revisions:  
		- 20160719@Jim: Allbet - Live Casino Integration for Licensees (#59624)
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
		- 20170301@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20170329@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170706@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170802@Sophia: Add new betfrom [redmine: #80687]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20171020@Harper: LRF - Add "New Asia" in platform list [RedmineID: #85203]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]

	Param's Explanation:  
	  + @PlatformType:  0: All  
						1: Asia (d, g)  
						2: China (a, z)
						3: Euro (e, u , y) (and Euro 12bet (u))
						4: WAP (m)    
						5: SMART SITE (s,l)  
						6: TABLET (r)   
						7: New Asia (x)
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover onlly)
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined WITH Sportsbook or Number Game)
	  + @ShowCS: Show RNG Casino (OneRNG)
	  + @ShowMGCLC: Show MicroGamming Live Casino
	  + @ShowMGCRNG: Show MicroGamming RNG Casino
	  + @ShowKN: Show Keno
	  + @ShowVB: Show Voidbridge
	  + @ShowAB: Show Allbet
	  + @ShowFW : Show Fishing World
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/
    
BEGIN      

	SET NOCOUNT ON

	IF DATEDIFF(MONTH,@FromDate,@ToDate) > 1
		RETURN

	CREATE TABLE #WinLoss (
		Winlostdate	DATE,
		CustID		INT,
		Currency	INT,
		Turnover	MONEY, 
		Winlost		MONEY, 
		LicenseeWL	MONEY,
		playercomm	MONEY,
		WinlossRB	MONEY,
		AmtDueToBA	MONEY,
		AmtDueToRB	MONEY,
		CommBA		MONEY,
		CommRB		MONEY,
		Company		MONEY,
		BetCount	BIGINT
		)

	DECLARE @TempFromDate	DATETIME 
	DECLARE @TempToDate		DATETIME 
	DECLARE @MaxOldDate		DATETIME
	DECLARE @FDate			DATETIME
	DECLARE @TDate			DATETIME
	DECLARE @ProductList	VARCHAR (500)

	CREATE TABLE #sporttype (sporttype INT, ProductPrefix VARCHAR(10))
	CREATE TABLE #bettype (bettype INT PRIMARY KEY, ProductPrefix VARCHAR(10))
	CREATE TABLE #tempAg (custID INT, Currency INT)

	--to Deal WITH Parameter Sniffing
	SELECT @FDate=@FromDate,@TDate=@ToDate 

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #tempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #PlatformList (betfrom NVARCHAR(1), PlatformType TINYINT)
	INSERT INTO #PlatformList (betfrom, PlatformType)
	SELECT	d.betfrom, d.PlatformType
	FROM (
		VALUES	(1, 'd'),
				(2, 'a'),
				(3, 'e'),
				(4, 'm'),
				(5, 's'),
				(3, 'u'),
				(5, 'l'),
				(1, 'g'),
				(6, 'r'),
				(7, 'x'),
				(3, 'y'),
				(2, 'z')
	) d(PlatformType, betfrom)
	WHERE d.PlatformType = @PlatformType OR @PlatformType = 0

	CREATE TABLE #Exchange (ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))

	IF @ShowSB = 1  
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'SB', 'SB')	

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

	IF @ShowCS=1 -- RNG Casino
	BEGIN
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'CS', 'CS')
	END

	IF @ShowKN=1 -- Keno
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'KN', 'KN')
	END 

	IF @showMGCLC =1 -- MicroGamming LC
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCLC', 'MGCLC')
	END 

	IF @showMGCRnG =1 -- MicroGamming RNG
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'MGCRNG', 'MGCRNG')
	END

	IF @showVB = 1 -- Voidbridge
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'VB', 'VB')
	END

	IF @showAB = 1 -- Allbet
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'AB', 'AB')
	END

	IF @showFW = 1 -- Fishing World. 
	BEGIN 
		SELECT @ProductList = COALESCE(@ProductList + ',' + 'FW', 'FW')
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
		INSERT INTO #bettype ( bettype, ProductPrefix )		
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)

		IF CHARINDEX('CS', @ProductList) > 0
			DELETE #bettype
			WHERE bettype = 72 AND ProductPrefix = 'CS'

		IF CHARINDEX('SB', @ProductList) > 0
			DELETE #bettype
			WHERE ProductPrefix IN ('SB')
		
		-- Insert Sport Type
		INSERT INTO #sporttype ( sporttype, ProductPrefix )
		SELECT DISTINCT sporttype, ProductCode
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)

	END	

	INSERT INTO #Exchange (exchangedate,exchangeid,eur,usd,gbp,code)
	SELECT exchangedate,exchangeid,eur,usd,gbp,code
		FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
		WHERE exchangeid IN (SELECT Currency FROM #tempAg)	

	IF @TDate>@MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate
	
		IF @ShowBA=1
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.CustID,
				b.currency,
			
				SUM( stake
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,	
				0 as LicenseeWL,
				SUM(b.playercomm  ) as PlayerComm,
				0 as WinlossRB,
				- SUM (b.winlost - b.actual_stake + b.awinlost + b.comm ) as AmountDueToBA,
				0 as AmountDueToRB,
				SUM (b.comm ) as CommBA,
				0 as CommRB,
				0 as Company,	
				--------BetCount-----------		
				COUNT(b.transid) 
					* CASE WHEN @drawfilter = 2 THEN
							CASE WHEN b.statusID = 111 THEN 0
							ELSE 1 END
						ELSE 1 END
					   BetCount
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #tempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID  IN (111, 112, 113)
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			GROUP BY   b.winlostdate, b.custid, b.currency, b.statusID
		END
	
		IF (@ShowSB = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.CustID,
				tma.currency,
			
				SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END) AS LicenseeWL ,
				SUM (   b.playercomm ) as PlayerComm,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
				0 as AmountDueToBA,
				- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) as AmountDueToRB,
				0 as CommBA,
				SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END)as CommRB,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END)  as Company,
				--------BetCount-----------
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #tempAg tma ON tma.CustID=b.recommend  AND b.currency = tma.currency
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID  IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
				AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
								  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
				) 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.tpositiontaking <>0
			GROUP BY  b.winlostdate, b.CustID, tma.currency, b.statusID
		END
	
	
		IF (@ShowRB = 1 or @ShowNG = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW = 1 OR @ShowVS2 = 1 OR @ShowLT = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.CustID,
				tma.currency,
				SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
						*
						CASE WHEN @drawfilter IN (2,3) THEN
							CASE WHEN b.statusID = 111 THEN 0
							WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
							ELSE 1 END
						ELSE 1 END
					) turnover,
				SUM(b.winlost-b.actual_stake) AS Winlost,	
				- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END) AS LicenseeWL ,
				SUM (   b.playercomm ) as PlayerComm,
				SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
				0 as AmountDueToBA,
				- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) as AmountDueToRB,
				0 as CommBA,
				SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END)as CommRB,
				- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END)  as Company ,
				--------BetCount-----------
				COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #tempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE
				b.statusID  IN (111, 112, 113)
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			GROUP BY  b.winlostdate, b.CustID, tma.currency, b.statusID

		END
	END		
				
	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @TDate

		IF @ShowBA = 1 
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.custid,
				b.currency,
				SUM(b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				),     
				SUM(b.winlost),  
				0 as LicenseeWL,
				SUM(b.playercomm ) AS PlayerComm, 
				0 as WinlossRB,
				- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
				0 as AmountDueToRB,
				SUM (comm ) AS CommBA,
				0 AS CommRB,
				0 AS Company,
				--------BetCount-----------
				SUM(b.betcount)
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )
				INNER JOIN 	#tempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND ISNULL(b.isBA,0) = 1	
			GROUP BY b.winlostdate, b.CustID, b.currency, b.statusID
			
		END

		IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW =1 OR @ShowVS2 = 1 OR @ShowLT = 1)
		BEGIN
			INSERT INTO #WinLoss (Winlostdate, CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company, BetCount)
			SELECT 
				b.winlostdate,
				b.custid, 
				b.currency,
				SUM(b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				),
				SUM(b.winlost),
				- SUM(CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
				SUM ( b.playercomm ) as PlayerComm,
				SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
				0 as AmtDueToBA,
				- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmtDueToRB,
				0 as CommBA,
				SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END) as CommRB,
				- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END)  as Company,
				--------BetCount-----------
				SUM(b.betcount)
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )
				INNER JOIN 	#tempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
				INNER JOIN #sporttype t ON b.sporttype = t.sporttype
				INNER JOIN #PlatformList pl ON pl.betfrom = b.betfrom
			WHERE 		
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND ISNULL(b.isBA,0) = 0	
			GROUP BY b.winlostdate, b.CustID, b.currency, b.statusID
		END
	END			

	----Delete zero data 
	DELETE #WinLoss 
	WHERE 	Betcount = 0 
			AND Turnover = 0 
			AND Winlost = 0 
			AND LicenseeWL = 0 
			AND PlayerComm = 0 
			AND WinlossRB = 0 
			AND CommBA = 0 
			AND CommRB = 0 
			AND AmtDuetoBA = 0 
			AND AmtDuetoRB = 0 
			AND Company = 0

	SELECT 
		w.CustID,
		c.username, 
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
		w.Currency,
		SUM(Betcount)	AS Betcount,

		SUM(TurnOver)	AS Turnover,
		SUM(Winlost)		AS Winlost,
		SUM(LicenseeWL) AS LicenseeWL,
		SUM(PlayerComm) AS PlayerComm,
		SUM(WinlossRB)	AS WinlossRB,
		SUM(CommBA) AS CommBA,
		SUM(CommRB) AS CommRB,	
		SUM(AmtDuetoBA) AS AmtDuetoBA,
		SUM(AmtDuetoRB) AS AmtDuetoRB,
		SUM(Company) AS Company,
			
		--BASE EUR
		SUM(TurnOver * e.EUR)	AS TurnoverEUR,
		SUM(Winlost * e.EUR)		AS WinlostEUR,
		SUM(LicenseeWL * e.EUR) AS LicenseeWLEUR,
		SUM(PlayerComm * e.EUR) AS PlayerCommEUR,
		SUM(WinlossRB * e.EUR)	AS WinlossRBEUR,
		SUM(CommBA * e.EUR) AS CommBAEUR,
		SUM(CommRB * e.EUR) AS CommRBEUR,	
		SUM(AmtDuetoBA * e.EUR) AS AmtDuetoBAEUR,
		SUM(AmtDuetoRB * e.EUR) AS AmtDuetoRBEUR,
		SUM(Company * e.EUR) AS CompanyEUR,
	
		--BASE USD
		SUM(TurnOver * e.USD)	AS TurnoverUSD,
		SUM(Winlost * e.USD)		AS WinlostUSD,
		SUM(LicenseeWL * e.USD) AS LicenseeWLUSD,
		SUM(PlayerComm * e.USD) AS PlayerCommUSD,
		SUM(WinlossRB * e.USD)	AS WinlossRBUSD,
		SUM(CommBA * e.USD) AS CommBAUSD,
		SUM(CommRB * e.USD) AS CommRBUSD,	
		SUM(AmtDuetoBA * e.USD) AS AmtDuetoBAUSD,
		SUM(AmtDuetoRB * e.USD) AS AmtDuetoRBUSD,
		SUM(Company * e.USD) AS CompanyUSD,
		--BASE GBP
		SUM(TurnOver * e.GBP)	AS TurnoverGBP,
		SUM(Winlost * e.GBP)		AS WinlostGBP,
		SUM(LicenseeWL * e.GBP) AS LicenseeWLGBP,
		SUM(PlayerComm * e.GBP) AS PlayerCommGBP,
		SUM(WinlossRB * e.GBP)	AS WinlossRBGBP,
		SUM(CommBA * e.GBP) AS CommBAGBP,
		SUM(CommRB * e.GBP) AS CommRBGBP,	
		SUM(AmtDuetoBA * e.GBP) AS AmtDuetoBAGBP,
		SUM(AmtDuetoRB * e.GBP) AS AmtDuetoRBGBP,
		SUM(Company * e.GBP) AS CompanyGBP
	FROM #WinLoss w 
		INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
		INNER JOIN  #Exchange e on w.Currency=e.exchangeid AND e.ExchangeDate = w.Winlostdate
	GROUP BY
		w.CustID, w.Currency, c.username, c.username2
	ORDER BY 5,2

	DROP TABLE #bettype
	DROP TABLE #sporttype
	DROP TABLE #tempAg
	DROP TABLE #WinLoss	
	DROP TABLE #Exchange
	DROP TABLE #PlatformList
	
END
GO 
