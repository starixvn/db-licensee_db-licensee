USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_PlatformWinlossDetail]   
 @LicenseeID	INT,
 @UserID		INT,
 @CurrencyID	INT = 0,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @showSB		BIT=0,  
 @ShowRB		BIT=0,  
 @ShowNG		BIT=0, 
 @ShowBA		BIT=0,
 @ShowLC 		BIT=0,
 @ShowVS		BIT=0,
 @ShowKN		BIT=0,
 @ShowCS		BIT=0,
 @ShowMGCLC		BIT=0,
 @ShowMGCRNG	BIT=0,
 @ShowVB		BIT=0,		
 @ShowAB		BIT=0,	
 @ShowFW		BIT=0,
 @PlatformType	TINYINT=0, 
 @MoveBetsDay SMALLDATETIME,
 @drawfilter SMALLINT = 1,
 @excludeTest BIT = 0
AS

/*  Created: 20160406@Victor
    Task : Platform WinLoss Report - Detail view
    DB: DBEXT/bodb02  
   
    Revisions:  
		- 20160719@Jim: Allbet - Live Casino Integration for Licensees (#59624)
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
		- 20161115@Jim: LRF - Integrate new product Fishing World [RedmineID : #66737]
	Param's Explanation:  
	  + @PlatformType: 0: All  
					   1: Asia (d)  
					   2: New Asia (a)
					   3: Euro (e) (and Euro 12bet (u))
					   4: WAP (m)    
					   5: SMARTPHONE (s,l)  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover onlly)
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined WITH Sportsbook or Number Game)
	  + @ShowLC: Show Live casino
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

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @VNDCurrencyName VARCHAR(20)
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME

CREATE TABLE #sporttype (sporttype INT, ProductPrefix VARCHAR(10))
CREATE TABLE #bettype (bettype INT PRIMARY KEY, ProductPrefix VARCHAR(10))
CREATE TABLE #tempAg (custID INT, Currency INT)

--to Deal WITH Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 
SELECT @VNDCurrencyName = currency FROM exchange (NOLOCK) WHERE ExchangeId = 51
SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO #tempAg (custID,currency) 
SELECT custID,currency 
FROM  bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE 
	 (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	

DROP TABLE #Currency 

DECLARE @PlatformList TABLE (betfrom NVARCHAR(1))
INSERT INTO @PlatformList (betfrom)
SELECT	CASE 
			WHEN @PlatformType = 1 THEN 'd'
			WHEN @PlatformType = 2 THEN 'a'
			WHEN @PlatformType = 3 THEN 'e'
			WHEN @PlatformType = 4 THEN 'm'
			WHEN @PlatformType = 5 THEN 's'
		END
UNION
SELECT	CASE 
			WHEN @PlatformType = 3 THEN 'u'
			WHEN @PlatformType = 5 THEN 'l'
		END
IF @PlatformType = 0
BEGIN
	INSERT INTO @PlatformList (betfrom) VALUES ('a')
	INSERT INTO @PlatformList (betfrom) VALUES ('d')
	INSERT INTO @PlatformList (betfrom) VALUES ('e')
	INSERT INTO @PlatformList (betfrom) VALUES ('u')
	INSERT INTO @PlatformList (betfrom) VALUES ('s')
	INSERT INTO @PlatformList (betfrom) VALUES ('m')
	INSERT INTO @PlatformList (betfrom) VALUES ('l')
END
DELETE FROM @PlatformList WHERE betfrom IS NULL

CREATE TABLE #Exchange (ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))

IF @ShowSB = 1  
	INSERT  INTO #sporttype(sporttype, ProductPrefix) VALUES  (0, 'SB')	

IF @ShowRB = 1  
BEGIN
	INSERT  INTO #sporttype( Sporttype, ProductPrefix) VALUES  (151, 'RB')

	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'RB' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 31 AND 33)
END

IF @ShowNG = 1	
BEGIN
	INSERT INTO #sporttype(Sporttype, ProductPrefix) VALUES(161, 'NG')  
	
	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'NG' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END

IF @ShowLC = 1	
BEGIN
	INSERT  INTO #sporttype( Sporttype, ProductPrefix) VALUES  (162, 'LC')
	
	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'LC' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END

IF @ShowVS = 1	
BEGIN
	INSERT  INTO #sporttype( Sporttype, ProductPrefix) 
	SELECT 180, 'VS'
	
	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'VS' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END

IF @ShowCS=1 -- RNG Casino
BEGIN
	INSERT INTO #sporttype(sporttype, ProductPrefix)
	VALUES (251, 'CS')
	INSERT INTO #bettype(bettype, ProductPrefix)
	VALUES(71, 'CS')
	
	-- MBC - RNG Casino
	INSERT INTO #sporttype(sporttype, ProductPrefix)
	VALUES (208, 'CS'),(209, 'CS'),(210, 'CS')
	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT DISTINCT bettype, 'CS'
	FROM dbo.SportBettypeMatrix WITH(NOLOCK)
	WHERE sporttype IN (208, 209, 210)
END

IF @ShowKN=1 -- Keno
BEGIN 
	INSERT INTO #sporttype (sporttype, ProductPrefix)
	VALUES(202, 'KN')

	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'KN' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1501 AND 1599)
END 
IF @showMGCLC =1 -- MicroGamming LC
BEGIN 
	INSERT INTO #sporttype (sporttype, ProductPrefix)
	VALUES(203, 'MGCLC')

	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'MGCLC' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2001 AND 2007)
END 

IF @showMGCRnG =1 -- MicroGamming RNG
BEGIN 
	INSERT INTO #sporttype (sporttype, ProductPrefix)
	VALUES(205, 'MGCRNG')

	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'MGCRNG' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2008 AND 2009)
END

IF @showVB = 1 -- Voidbridge
BEGIN 
	INSERT INTO #sporttype (sporttype, ProductPrefix)
	VALUES(212, 'VB')

	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'VB' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 4001 AND 7999)
END

IF @showAB = 1 -- Allbet
BEGIN 
	INSERT INTO #sporttype (sporttype, ProductPrefix)
	VALUES(211, 'AB')

	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'AB' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2401 AND 2499)
END

IF @showFW = 1 -- Fishing World. 
BEGIN 
	INSERT INTO #sporttype (sporttype, ProductPrefix)
	VALUES(219, 'FW')

	INSERT INTO #bettype(bettype, ProductPrefix)
	SELECT typeid, 'FW' FROM bettype (NOLOCK)
	WHERE (typeid  BETWEEN 1011 AND 1020)
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
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.bettype NOT IN (901,902,903,904)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
		GROUP BY   b.winlostdate, b.custid, b.currency, b.statusID
	END
	
	IF (@ShowSB=1)
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
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
							  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) 
			AND b.bettype NOT IN (901,902,903,904)
			AND b.tpositiontaking <>0
		GROUP BY  b.winlostdate, b.CustID, tma.currency, b.statusID
	END
	
	
	IF (@ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW =1 )
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
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
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
	IF @ShowBA=1 
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
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE 
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903,904)
			AND ISNULL(b.isBA,0) = 1	
		GROUP BY b.winlostdate, b.CustID, b.currency, b.statusID
			
	END
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR  @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1 OR @ShowAB = 1 OR @ShowFW =1)
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
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE 		
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903,904)
			AND ISNULL(b.isBA,0) = 0	
		GROUP BY b.winlostdate, b.CustID, b.currency, b.statusID
	END
END			


SELECT 
	w.CustID,
	c.username, 
	SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
	w.Currency,
	CASE 
		WHEN w.Currency =51 THEN @VNDCurrencyName 
		WHEN w.Currency =70 THEN 'MKK'
		ELSE e.Code 
	END AS CurrencyName,
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
	w.CustID, w.Currency, c.username, c.username2,
	CASE 
		WHEN w.Currency =51 THEN @VNDCurrencyName
		WHEN w.Currency =70 THEN 'MKK'
		ELSE e.Code 
	END 
ORDER BY 5,2

DROP TABLE #bettype
DROP TABLE #sporttype
DROP TABLE #tempAg
DROP TABLE #WinLoss	
DROP TABLE #Exchange
	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_PlatformWinlossDetail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_PlatformWinlossDetail] TO [vnteam] AS [dbo]