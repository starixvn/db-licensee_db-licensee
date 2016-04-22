USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_PlatformWinloss]   
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
	 @PlatformType	TINYINT=0, 
	 @MoveBetsDay SMALLDATETIME,
	 @drawfilter SMALLINT = 1,
	 @excludeTest BIT = 0
AS

/*  Created: 20160406@Victor
    Task : Platform WinLoss Report 
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
	Winlostdate DATE,
	Currency	INT ,
	ProductPrefix	VARCHAR(10),
	PlatformType	TINYINT,
	Turnover	MONEY, 
	Winlost		MONEY, 
	LicenseeWL	MONEY,
	playercomm	MONEY,
	BetCount	BIGINT
	)


DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME

CREATE TABLE #sporttype (sporttype INT, ProductPrefix VARCHAR(10))
CREATE TABLE #bettype	(bettype INT PRIMARY KEY, ProductPrefix VARCHAR(10))
CREATE TABLE #tempAg	(custID INT, Currency INT)

--to Deal WITH Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 
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
		INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)

		SELECT
			b.Winlostdate, 
			b.currency,
			'BA' AS ProductPrefix,
			CASE 
				WHEN b.betfrom = 'd' THEN 1
				WHEN b.betfrom = 'a' THEN 2
				WHEN b.betfrom IN ('e', 'u') THEN 3
				WHEN b.betfrom = 'm' THEN 4
				WHEN b.betfrom IN ('s','l') THEN 5
				ELSE 6
			END AS PlatformType,

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
			AND b.bettype NOT IN (901,902,903)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
		GROUP BY   b.winlostdate, b.currency, b.statusID, 	CASE 
												WHEN b.betfrom = 'd' THEN 1
												WHEN b.betfrom = 'a' THEN 2
												WHEN b.betfrom IN ('e', 'u') THEN 3
												WHEN b.betfrom = 'm' THEN 4
												WHEN b.betfrom IN ('s','l') THEN 5
												ELSE 6
											END
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
		SELECT
			b.winlostdate, 
			tma.currency,
			'SB' AS ProductPrefix,
			CASE
				WHEN b.betfrom = 'd' THEN 1
				WHEN b.betfrom = 'a' THEN 2
				WHEN b.betfrom IN ('e', 'u') THEN 3
				WHEN b.betfrom = 'm' THEN 4
				WHEN b.betfrom IN ('s','l') THEN 5
				ELSE 6
			END AS PlatformType,
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
			AND b.bettype NOT IN (901,902,903)
			AND b.tpositiontaking <>0
		GROUP BY  b.winlostdate, tma.currency, b.statusID, CASE 
												WHEN b.betfrom = 'd' THEN 1
												WHEN b.betfrom = 'a' THEN 2
												WHEN b.betfrom IN ('e', 'u') THEN 3
												WHEN b.betfrom = 'm' THEN 4
												WHEN b.betfrom IN ('s','l') THEN 5
												ELSE 6
											END	   
	END
	
	
	IF (@ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1)
	BEGIN
		INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
		SELECT 
			b.Winlostdate,
			tma.currency,
			bt.ProductPrefix AS ProductPrefix,
			CASE 
				WHEN b.betfrom = 'd' THEN 1
				WHEN b.betfrom = 'a' THEN 2
				WHEN b.betfrom IN ('e', 'u') THEN 3
				WHEN b.betfrom = 'm' THEN 4
				WHEN b.betfrom IN ('s','l') THEN 5
				ELSE 6
			END AS PlatformType,

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
		GROUP BY   b.winlostdate, tma.currency, b.statusID, bt.ProductPrefix, 
			CASE 
				WHEN b.betfrom = 'd' THEN 1
				WHEN b.betfrom = 'a' THEN 2
				WHEN b.betfrom IN ('e', 'u') THEN 3
				WHEN b.betfrom = 'm' THEN 4
				WHEN b.betfrom IN ('s','l') THEN 5
				ELSE 6
			END

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
		INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
		SELECT 
			b.winlostdate,
			b.currency,
			'BA' AS ProductPrefix,
			CASE
				WHEN b.betfrom = 'd' THEN 1
				WHEN b.betfrom = 'a' THEN 2
				WHEN b.betfrom IN ('e', 'u') THEN 3
				WHEN b.betfrom = 'm' THEN 4
				WHEN b.betfrom IN ('s','l') THEN 5
				ELSE 6
			END AS PlatformType,

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
			--------BetCount-----------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN 	#tempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE 
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903)
			AND ISNULL(b.isBA,0) = 1	
		GROUP BY b.winlostdate, b.currency, b.statusID, CASE 
											WHEN b.betfrom = 'd' THEN 1
											WHEN b.betfrom = 'a' THEN 2
											WHEN b.betfrom IN ('e', 'u') THEN 3
											WHEN b.betfrom = 'm' THEN 4
											WHEN b.betfrom IN ('s','l') THEN 5
											ELSE 6
										 END
			
	END
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR  @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowKN=1 OR @showMGCLC =1 OR @showMGCRnG =1 OR @ShowVB = 1)
	BEGIN
		INSERT INTO #WinLoss (Winlostdate, Currency, ProductPrefix, PlatformType, Turnover, Winlost, LicenseeWL, playercomm, BetCount)
		SELECT 
			b.winlostdate,
			b.currency,
			t.ProductPrefix,
			CASE
				WHEN b.betfrom = 'd' THEN 1
				WHEN b.betfrom = 'a' THEN 2
				WHEN b.betfrom IN ('e', 'u') THEN 3
				WHEN b.betfrom = 'm' THEN 4
				WHEN b.betfrom IN ('s','l') THEN 5
				ELSE 6
			END AS PlatformType,
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
			--------BetCount-----------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN #tempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
			INNER JOIN #sporttype t ON b.sporttype = t.sporttype
			INNER JOIN @PlatformList pl ON pl.betfrom = b.betfrom
		WHERE 		
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903)
			AND ISNULL(b.isBA,0) = 0	
		GROUP BY	
			b.winlostdate,
			b.currency,
			b.statusID,
			t.ProductPrefix,
			CASE 
				WHEN b.betfrom = 'd' THEN 1
				WHEN b.betfrom = 'a' THEN 2
				WHEN b.betfrom IN ('e', 'u') THEN 3
				WHEN b.betfrom = 'm' THEN 4
				WHEN b.betfrom IN ('s','l') THEN 5
				ELSE 6
			END
	END
END			


SELECT 
	w.ProductPrefix, 
	w.PlatformType, 
	
	SUM(Betcount)		AS Betcount,

	SUM(Turnover)		AS Turnover,
	SUM(Winlost)		AS Winlost,
	SUM(LicenseeWL)		AS LicenseeWL,
	SUM(PlayerComm)		AS PlayerComm,
			
	--BASE EUR
	SUM(Turnover * e.EUR)	AS TurnoverEUR,
	SUM(Winlost * e.EUR)		AS WinlostEUR,
	SUM(LicenseeWL * e.EUR)	AS LicenseeWLEUR,
	SUM(PlayerComm * e.EUR)	AS PlayerCommEUR,
	
	--BASE USD
	SUM(Turnover * e.USD)	AS TurnoverUSD,
	SUM(Winlost * e.USD)		AS WinlostUSD,
	SUM(LicenseeWL * e.USD)	AS LicenseeWLUSD,
	SUM(PlayerComm * e.USD)	AS PlayerCommUSD,
	--BASE GBP
	SUM(Turnover * e.GBP)	AS TurnoverGBP,
	SUM(Winlost * e.GBP)		AS WinlostGBP,
	SUM(LicenseeWL * e.GBP)	AS LicenseeWLGBP,
	SUM(PlayerComm * e.GBP)	AS PlayerCommGBP
FROM #WinLoss w 
	INNER JOIN  #Exchange e on w.Currency=e.exchangeid AND e.ExchangeDate = w.Winlostdate
GROUP BY
	w.ProductPrefix, w.PlatformType
ORDER BY w.PlatformType, w.ProductPrefix

DROP TABLE #sporttype
DROP TABLE #bettype
DROP TABLE #Exchange
DROP TABLE #WinLoss
DROP TABLE #tempAg

END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_PlatformWinloss] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_PlatformWinloss] TO [vnteam] AS [dbo]