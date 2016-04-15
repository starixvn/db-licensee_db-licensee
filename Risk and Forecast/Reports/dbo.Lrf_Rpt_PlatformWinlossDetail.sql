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
 @PlatformType	TINYINT=1, 
 @MoveBetsDay SMALLDATETIME,
 @drawfilter SMALLINT = 1,
 @excludeTest BIT = 0
AS

/*  Created: 20160406@Victor
    Task : Platform WinLoss Report - Detail view
    DB: DBEXT/bodb02  
   
    Revisions:  
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
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/
    
BEGIN      

SET NOCOUNT ON

IF DATEDIFF(MONTH,@FromDate,@ToDate) > 1
	RETURN

CREATE TABLE #WinLoss (
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
	
	TurnoverEUR		MONEY,   	
	WinlostEUR		MONEY,  
	LicenseeWLEUR	MONEY,
	PlayerCommEUR 	MONEY,	
	WinlossRBEUR	MONEY,
	AmtDueToBAEUR	MONEY,
	AmtDueToRBEUR	MONEY,
	CommBAEUR		MONEY,
	CommRBEUR		MONEY,	
	CompanyEUR		MONEY,
	
	TurnOverUSD		MONEY,   	
	WinlostUSD		MONEY,  
	LicenseeWLUSD	MONEY,
	PlayerCommUSD 	MONEY,	
	WinlossRBUSD	MONEY,
	AmtDueToBAUSD	MONEY,
	AmtDueToRBUSD	MONEY,
	CommBAUSD		MONEY,
	CommRBUSD		MONEY,	
	CompanyUSD		MONEY,
	
	TurnOverGBP		MONEY,   	
	WinlostGBP		MONEY,  
	LicenseeWLGBP	MONEY,
	PlayerCommGBP 	MONEY,	
	WinlossRBGBP	MONEY,
	AmtDueToBAGBP	MONEY,
	AmtDueToRBGBP	MONEY,
	CommBAGBP		MONEY,
	CommRBGBP		MONEY,	
	CompanyGBP		MONEY,

	BetCount	BIGINT
	)
DECLARE @sporttype TABLE(sporttype INT, ProductPrefix VARCHAR(10))
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY, ProductPrefix VARCHAR(10))
DECLARE @tempAg	TABLE( custID INT, Currency INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @VNDCurrencyName VARCHAR(20)
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME

--to Deal WITH Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 
SELECT @VNDCurrencyName = currency FROM exchange (NOLOCK) WHERE ExchangeId = 51
SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @tempAg (custID,currency) 
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

DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))

IF @ShowSB = 1  
	INSERT  INTO @sporttype(sporttype, ProductPrefix) VALUES  (0, 'SB')	

IF @ShowRB = 1  
BEGIN
	INSERT  INTO @sporttype( Sporttype, ProductPrefix) VALUES  (151, 'RB')

	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'RB' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 31 AND 33)
END

IF @ShowNG = 1	
BEGIN
	INSERT INTO @sporttype(Sporttype, ProductPrefix) VALUES(161, 'NG')  
	
	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'NG' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END

IF @ShowLC = 1	
BEGIN
	INSERT  INTO @sporttype( Sporttype, ProductPrefix) VALUES  (162, 'LC')
	
	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'LC' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END

IF @ShowVS = 1	
BEGIN
	INSERT  INTO @sporttype( Sporttype, ProductPrefix) 
	SELECT 180, 'VS'
	
	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'VS' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END

IF @ShowCS=1 -- RNG Casino
BEGIN
	INSERT INTO @sporttype(sporttype, ProductPrefix)
	VALUES (251, 'CS')
	INSERT INTO @bettype(bettype, ProductPrefix)
	VALUES(71, 'CS')
	
	-- MBC - RNG Casino
	INSERT INTO @sporttype(sporttype, ProductPrefix)
	VALUES (208, 'CS'),(209, 'CS'),(210, 'CS')
	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT DISTINCT bettype, 'CS'
	FROM dbo.SportBettypeMatrix WITH(NOLOCK)
	WHERE sporttype IN (208, 209, 210)
END

IF @ShowKN=1 -- Keno
BEGIN 
	INSERT INTO @sporttype (sporttype, ProductPrefix)
	VALUES(202, 'KN')

	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'KN' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1501 AND 1599)
END 
IF @showMGCLC =1 -- MicroGamming LC
BEGIN 
	INSERT INTO @sporttype (sporttype, ProductPrefix)
	VALUES(203, 'MGCLC')

	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'MGCLC' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2001 AND 2007)
END 

IF @showMGCRnG =1 -- MicroGamming RNG
BEGIN 
	INSERT INTO @sporttype (sporttype, ProductPrefix)
	VALUES(205, 'MGCRNG')

	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'MGCRNG' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2008 AND 2009)
END

IF @showVB = 1 -- Voidbridge
BEGIN 
	INSERT INTO @sporttype (sporttype, ProductPrefix)
	VALUES(212, 'VB')

	INSERT INTO @bettype(bettype, ProductPrefix)
	SELECT typeid, 'VB' FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 4001 AND 7999)
END

INSERT INTO @Exchange (exchangedate,exchangeid,eur,usd,gbp,code)
SELECT exchangedate,exchangeid,eur,usd,gbp,code
	FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
	WHERE exchangeid IN (SELECT Currency FROM @TempAg)	

IF @TDate>@MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate
	
	IF @ShowBA=1
	BEGIN
		INSERT INTO #WinLoss 
			(CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company,
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, PlayerCommEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, CompanyEUR,
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, PlayerCommUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, CompanyUSD,
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, PlayerCommGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, CompanyGBP,
			BetCount)

		SELECT 
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
			
			--EUR
			SUM( stake
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.EUR
				) turnoverEUR,
			SUM((b.winlost - b.actual_stake)*e.EUR) AS WinlostEUR,		
			0 as LicenseeWLEUR,
			SUM(b.playercomm * e.EUR ) as PlayerCommEUR,
			0 as WinlossRBEUR,
			- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm ) * e.EUR) as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			SUM (b.comm * e.EUR) as CommBAEUR,
			0 as CommRBEUR,
			0 as CompanyEUR,
			---------------------------
			--USD
			SUM( stake
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.USD
				) turnoverUSD,
			SUM((b.winlost - b.actual_stake)*e.USD) AS WinlostUSD,		
			0 as LicenseeWLUSD,
			SUM(b.playercomm * e.USD ) as PlayerCommUSD,
			0 as WinlossRBUSD,
			- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm ) * e.USD) as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			SUM (b.comm * e.USD) as CommBAUSD,
			0 as CommRBUSD,
			0 as CompanyUSD,
			--GBP
			SUM( stake
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.GBP
				) turnoverGBP,
			SUM((b.winlost - b.actual_stake)*e.GBP) AS WinlostGBP,		
			0 as LicenseeWLGBP,
			SUM(b.playercomm * e.GBP ) as PlayerCommGBP,
			0 as WinlossRBGBP,
			- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm ) * e.GBP) as AmountDueToBAGBP,
			0 as AmountDueToRBGBP,
			SUM (b.comm * e.GBP) as CommBAGBP,
			0 as CommRBGBP,			
			0 as CompanyGBP,
			
			COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @TempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.bettype NOT IN (901,902,903)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
		GROUP BY   b.custid, b.currency, b.statusID
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #WinLoss
			(CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company,
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, PlayerCommEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, CompanyEUR,
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, PlayerCommUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, CompanyUSD,
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, PlayerCommGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, CompanyGBP,
			BetCount)
		SELECT 
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

			--------------EUR
			SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.EUR
				) turnoverEUR,
			SUM((b.winlost-b.actual_stake)*e.EUR) AS WinlostEUR,	
			- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLEUR ,
			SUM (   b.playercomm * e.EUR) as PlayerCommEUR,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
			0 as AmountDueToBAEUR,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.EUR) as AmountDueToRBEUR,
			0 as CommBAEUR,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.EUR)as CommRBEUR,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.EUR)  as CompanyEUR ,
			
			--------------USD
			SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.USD
				) turnoverUSD,
			SUM((b.winlost-b.actual_stake)*e.USD) AS WinlostUSD,	
			- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLUSD ,
			SUM (   b.playercomm * e.USD) as PlayerCommUSD,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
			0 as AmountDueToBAUSD,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.USD) as AmountDueToRBUSD,
			0 as CommBAUSD,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.USD)as CommRBUSD,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.USD)  as CompanyUSD ,
			--------------GBP
			SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.GBP
				) turnoverGBP,
			SUM((b.winlost-b.actual_stake)*e.GBP) AS WinlostGBP,	
			- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
			SUM (   b.playercomm * e.GBP) as PlayerCommGBP,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
			0 as AmountDueToBAGBP,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.GBP) as AmountDueToRBGBP,
			0 as CommBAGBP,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.GBP)as CommRBGBP,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.GBP)  as CompanyGBP ,
			--------BetCount-----------
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend  AND b.currency = tma.currency
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
							  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) 
			AND b.bettype NOT IN (901,902,903)
			AND b.tpositiontaking <>0
		GROUP BY  b.CustID, tma.currency, b.statusID
	END
	
	
	IF (@ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1)
	BEGIN
		INSERT INTO #WinLoss
			(CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company,
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, PlayerCommEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, CompanyEUR,
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, PlayerCommUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, CompanyUSD,
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, PlayerCommGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, CompanyGBP,
			BetCount)
		SELECT 
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
			
			--EUR
			SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.EUR
				) turnoverEUR,
			SUM((b.winlost-b.actual_stake) * e.EUR) AS WinlostEUR,	
			- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLEUR ,
			SUM (   b.playercomm * e.EUR) as PlayerCommEUR,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
			0 as AmountDueToBAEUR,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.EUR) as AmountDueToRBEUR,
			0 as CommBAEUR,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.EUR) as CommRBEUR,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.EUR)  as CompanyEUR ,
			--------------------------
			--USD
			SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.USD
				) turnoverUSD,
			SUM((b.winlost-b.actual_stake) * e.USD) AS WinlostUSD,	
			- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLUSD ,
			SUM (   b.playercomm * e.USD) as PlayerCommUSD,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
			0 as AmountDueToBAUSD,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.USD) as AmountDueToRBUSD,
			0 as CommBAUSD,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.USD) as CommRBUSD,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.USD)  as CompanyUSD ,
			--GBP
			SUM( CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END
					*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111 THEN 0
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
						ELSE 1 END
					ELSE 1 END
					* e.GBP
				) turnoverGBP,
			SUM((b.winlost-b.actual_stake) * e.GBP) AS WinlostGBP,	
			- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
			SUM (   b.playercomm * e.GBP) as PlayerCommGBP,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
			0 as AmountDueToBAGBP,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.GBP) as AmountDueToRBGBP,
			0 as CommBAGBP,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.GBP) as CommRBGBP,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.GBP)  as CompanyGBP ,
			--------------------------
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
		GROUP BY  b.CustID, tma.currency, b.statusID

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
		INSERT INTO #WinLoss
			(CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company,
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, PlayerCommEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, CompanyEUR,
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, PlayerCommUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, CompanyUSD,
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, PlayerCommGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, CompanyGBP,
			BetCount)
		SELECT 
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

			--EUR
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			),     
			SUM(b.winlost * e.EUR),  
			0 as LicenseeWLEUR,
			SUM(b.playercomm * e.EUR ) AS PlayerCommEUR, 
			0 as WinlossRBEUR,
			- SUM ((b.winlost+b.awinlost+b.comm) * e.EUR) as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			SUM (comm * e.EUR) AS CommBAEUR,
			0 AS CommRBEUR,
			0 AS CompanyEUR,
			------------------------
			--USD
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			),     
			SUM(b.winlost * e.USD),  
			0 as LicenseeWLUSD,
			SUM(b.playercomm * e.USD ) AS PlayerCommUSD, 
			0 as WinlossRBUSD,
			- SUM ((b.winlost+b.awinlost+b.comm) * e.USD) as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			SUM (comm * e.USD) AS CommBAUSD,
			0 AS CommRBUSD,
			0 AS CompanyUSD,
			--GBP
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			),     
			SUM(b.winlost * e.GBP),  
			0 as LicenseeWLGBP,
			SUM(b.playercomm * e.GBP ) AS PlayerCommGBP, 
			0 as WinlossRBGBP,
			- SUM ((b.winlost+b.awinlost+b.comm) * e.GBP) as AmountDueToBAGBP,
			0 as AmountDueToRBGBP,
			SUM (comm * e.GBP) AS CommBAGBP,
			0 AS CommRBGBP,
			0 AS CompanyGBP,
			-----------------------------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE 
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903)
			AND ISNULL(b.isBA,0) = 1	
		GROUP BY b.CustID, b.currency, b.statusID
			
	END
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR  @ShowLC = 1 OR @ShowVS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1)
	BEGIN
		INSERT INTO #WinLoss
			(CustID, Currency, Turnover, Winlost, LicenseeWL, playercomm, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, Company,
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, PlayerCommEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, CompanyEUR,
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, PlayerCommUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, CompanyUSD,
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, PlayerCommGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, CompanyGBP,
			BetCount)
		SELECT 
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
			
			--EUR
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			),     
			SUM(b.winlost * e.EUR),
			- SUM(CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLEUR ,
			SUM ( b.playercomm * e.EUR) as PlayerCommEUR,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
			0 as AmtDueToBAEUR,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.EUR) as AmtDueToRBEUR,
			0 as CommBAEUR,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END * e.EUR) as CommRBEUR,
			- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END * e.EUR)  as CompanyEUR,
			------------------------------------------
				--USD
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			),     
			SUM(b.winlost * e.USD),
			- SUM(CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLUSD ,
			SUM ( b.playercomm * e.USD) as PlayerCommUSD,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
			0 as AmtDueToBAUSD,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.USD) as AmtDueToRBUSD,
			0 as CommBAUSD,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END * e.USD) as CommRBUSD,
			- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END * e.USD)  as CompanyUSD,
			--GBP
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.GBP
			),     
			SUM(b.winlost * e.GBP),
			- SUM(CASE WHEN (b.sporttype <> 151)  THEN b.winlost ELSE 0 END * e.GBP) AS LicenseeWLGBP ,
			SUM ( b.playercomm * e.GBP) as PlayerCommGBP,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
			0 as AmtDueToBAGBP,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.GBP) as AmtDueToRBGBP,
			0 as CommBAGBP,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END * e.GBP) as CommRBGBP,
			- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END * e.GBP)  as CompanyGBP,
			------------------------------------------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE 		
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903)
			AND ISNULL(b.isBA,0) = 0	
		GROUP BY b.CustID, b.currency, b.statusID
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
	SUM(TurnOverEUR)	AS TurnoverEUR,
	SUM(WinlostEUR)		AS WinlostEUR,
	SUM(LicenseeWLEUR) AS LicenseeWLEUR,
	SUM(PlayerCommEUR) AS PlayerCommEUR,
	SUM(WinlossRBEUR)	AS WinlossRBEUR,
	SUM(CommBAEUR) AS CommBAEUR,
	SUM(CommRBEUR) AS CommRBEUR,	
	SUM(AmtDuetoBAEUR) AS AmtDuetoBAEUR,
	SUM(AmtDuetoRBEUR) AS AmtDuetoRBEUR,
	SUM(CompanyEUR) AS CompanyEUR,
	
	--BASE USD
	SUM(TurnOverUSD)	AS TurnoverUSD,
	SUM(WinlostUSD)		AS WinlostUSD,
	SUM(LicenseeWLUSD) AS LicenseeWLUSD,
	SUM(PlayerCommUSD) AS PlayerCommUSD,
	SUM(WinlossRBUSD)	AS WinlossRBUSD,
	SUM(CommBAUSD) AS CommBAUSD,
	SUM(CommRBUSD) AS CommRBUSD,	
	SUM(AmtDuetoBAUSD) AS AmtDuetoBAUSD,
	SUM(AmtDuetoRBUSD) AS AmtDuetoRBUSD,
	SUM(CompanyUSD) AS CompanyUSD,
	--BASE GBP
	SUM(TurnOverGBP)	AS TurnoverGBP,
	SUM(WinlostGBP)		AS WinlostGBP,
	SUM(LicenseeWLGBP) AS LicenseeWLGBP,
	SUM(PlayerCommGBP) AS PlayerCommGBP,
	SUM(WinlossRBGBP)	AS WinlossRBGBP,
	SUM(CommBAGBP) AS CommBAGBP,
	SUM(CommRBGBP) AS CommRBGBP,	
	SUM(AmtDuetoBAGBP) AS AmtDuetoBAGBP,
	SUM(AmtDuetoRBGBP) AS AmtDuetoRBGBP,
	SUM(CompanyGBP) AS CompanyGBP
FROM #WinLoss w 
	INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
	INNER JOIN  (SELECT DISTINCT ExchangeId,Code FROM @Exchange) e on w.Currency=e.exchangeid
GROUP BY
	w.CustID, w.Currency, c.username, c.username2,
	CASE 
		WHEN w.Currency =51 THEN @VNDCurrencyName
		WHEN w.Currency =70 THEN 'MKK'
		ELSE e.Code 
	END 
ORDER BY 5,2

DROP TABLE #WinLoss	
	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_PlatformWinlossDetail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_PlatformWinlossDetail] TO [vnteam] AS [dbo]