USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_MobileWinloss]  
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
 @ShowCS		BIT=0,--- RNG Casino
 @ShowBG		BIT=0,--- Bingo
 @SiteType	TINYINT=1, 
 @MoveBetsDay SMALLDATETIME,
 @drawfilter SMALLINT = 1  ,
 @excludeTest BIT = 0,
 @Debug		BIT = 0
AS

/*  Created: Jim
	Date: 2012-02-02
    Task : Mobile WinLoss Report 
    DB: DBEXT.bodb02  
   
    Revisions:  
		-20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
		-20120529@Henry: enhance performance
		-20120730@Jim: add playercomm value 
		-20120814@Henry: add ShowLiveCasino 
		- 20120816@Henry: include betfrom "l" for smartphone
		- 20120905@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130109@Henry: Split Mobile to WAP & Smartphone
		- 20130225@Jim: support RNG Casino, Bingo 
		- 20130414@Jim: support USD base currency 
		- 20130516@Tom.Vo: Allow viewing customer list
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: offer Virtual Tennis
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150127@Jim: support base on GBP Currency
		- 20150204@Don: remove index hint
	Param's Explanation:  
	  + @SiteType: 1-WAP; 2-Smartphone; 3: Others;0-All  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss2, 1 - query in table rptLicWinloss_old
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined WITH Sportsbook or Number Game)
	  + @ShowLC: Show Live casino
	  + @ShowCS: Show RNG Casino
	  + @ShowBG: Show Bingo
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/
    
BEGIN      

SET NOCOUNT ON

IF DATEDIFF(MONTH,@FromDate,@ToDate) > 1
	RETURN

CREATE TABLE #WinLoss (
	--Winlostdate DATETIME, 
	CustID		INT,  
	Currency	INT ,
	Turnover	MONEY, 
	Winlost		MONEY, 
	LicenseeWL	MONEY,
	WinlossRB	MONEY,
	AmtDueToBA	MONEY,
	AmtDueToRB	MONEY,
	CommBA		MONEY,
	CommRB		MONEY,
	playercomm	MONEY,
	Company		MONEY,
	
	TurnOverEUR		MONEY,   	
	WinlostEUR		MONEY,  
	LicenseeWLEUR	MONEY,
	WinlossRBEUR	MONEY,
	AmtDueToBAEUR	MONEY,
	AmtDueToRBEUR	MONEY,
	CommBAEUR		MONEY,
	CommRBEUR		MONEY,
	PlayerCommEUR 	MONEY,	
	CompanyEUR		MONEY,
	
	TurnOverUSD		MONEY,   	
	WinlostUSD		MONEY,  
	LicenseeWLUSD	MONEY,
	WinlossRBUSD	MONEY,
	AmtDueToBAUSD	MONEY,
	AmtDueToRBUSD	MONEY,
	CommBAUSD		MONEY,
	CommRBUSD		MONEY,
	PlayerCommUSD 	MONEY,	
	CompanyUSD		MONEY,
	
	TurnOverGBP		MONEY,   	
	WinlostGBP		MONEY,  
	LicenseeWLGBP	MONEY,
	WinlossRBGBP	MONEY,
	AmtDueToBAGBP	MONEY,
	AmtDueToRBGBP	MONEY,
	CommBAGBP		MONEY,
	CommRBGBP		MONEY,
	PlayerCommGBP 	MONEY,	
	CompanyGBP		MONEY,

	BetCount	BIGINT
	)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @tempAg	TABLE( custID INT, Currency INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @VNDCurrencyName VARCHAR(20)
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME
--to Deal WITH Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @tempAg (custID,currency) 
SELECT custID,currency 
FROM  bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE 
	 (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	
/*
DECLARE @site VARCHAR(50)
SELECT TOP 1 @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency 
FROM Dep_CustSuper dc WITH (NOLOCK)  
	INNER JOIN #Currency c ON dc.Currency=c.CurrencyID 
WHERE  site = @site
*/
DROP TABLE #Currency 

DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,GBP FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))

IF @ShowSB = 1  
	INSERT  INTO @sporttype( sporttype) VALUES  (0)	

IF @ShowRB = 1  
BEGIN
	INSERT  INTO @sporttype( Sporttype) VALUES  (151)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 31 AND 33)
END

IF @ShowNG = 1	
BEGIN
	INSERT INTO @sporttype(Sporttype) VALUES(161)  
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END

IF @ShowLC = 1	
BEGIN
	INSERT  INTO @sporttype( Sporttype) VALUES  (162)
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END

IF @ShowVS = 1	
BEGIN
	INSERT  INTO @sporttype( Sporttype) 
	SELECT 180
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END


IF @ShowCS = 1	
BEGIN
	INSERT  INTO @sporttype( Sporttype) VALUES  (251)
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE typeid =71
END

IF @ShowBG = 1	
BEGIN
	INSERT  INTO @sporttype( Sporttype) VALUES  (252)
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE typeid =73
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
			(CustID, Currency, 
			Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP, 
			BetCount)

		SELECT 
			b.custid,
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
			0 as WinlossRB,
			- SUM (b.winlost - b.actual_stake + b.awinlost + b.comm ) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (b.comm ) as CommBA,
			0 as CommRB,
			SUM(b.playercomm  ) as PlayerComm,
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
			0 as WinlossRBEUR,
			- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm ) * e.EUR) as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			SUM (b.comm * e.EUR) as CommBAEUR,
			0 as CommRBEUR,
			SUM(b.playercomm * e.EUR ) as PlayerCommEUR,
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
			0 as WinlossRBUSD,
			- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm ) * e.USD) as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			SUM (b.comm * e.USD) as CommBAUSD,
			0 as CommRBUSD,
			SUM(b.playercomm * e.USD ) as PlayerCommUSD,
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
			0 as WinlossRBGBP,
			- SUM ((b.winlost - b.actual_stake + b.awinlost + b.comm ) * e.GBP) as AmountDueToBAGBP,
			0 as AmountDueToRBGBP,
			SUM (b.comm * e.GBP) as CommBAGBP,
			0 as CommRBGBP,
			SUM(b.playercomm * e.GBP ) as PlayerCommGBP,
			0 as CompanyGBP,
			
			COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
		--FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @TempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND 1= CASE @SiteType 
					WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
					WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
					WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
					ELSE 1 
				END
		GROUP BY   b.currency, b.statusID, b.custid	
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #WinLoss
			(CustID, Currency, 
			Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,
			BetCount)
		SELECT 
			b.custid,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBA,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) as AmountDueToRB,
			0 as CommBA,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END)as CommRB,
			SUM (   b.playercomm ) as PlayerComm,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
			0 as AmountDueToBAEUR,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.EUR) as AmountDueToRBEUR,
			0 as CommBAEUR,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.EUR)as CommRBEUR,
			SUM (   b.playercomm * e.EUR) as PlayerCommEUR,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
			0 as AmountDueToBAUSD,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.USD) as AmountDueToRBUSD,
			0 as CommBAUSD,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.USD)as CommRBUSD,
			SUM (   b.playercomm * e.USD) as PlayerCommUSD,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
			0 as AmountDueToBAGBP,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.GBP) as AmountDueToRBGBP,
			0 as CommBAGBP,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.GBP)as CommRBGBP,
			SUM (   b.playercomm * e.GBP) as PlayerCommGBP,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.GBP)  as CompanyGBP ,
			--------BetCount-----------
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		--FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend  AND b.currency = tma.currency
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
							  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) 
			AND b.tpositiontaking <>0
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END
		GROUP BY  tma.currency, b.statusID, b.custid	   
	END
	
	
	IF (@ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #WinLoss
			(CustID, Currency, 
			Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD,
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,	
			BetCount)
		SELECT 
			b.custid,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBA,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) as AmountDueToRB,
			0 as CommBA,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END)as CommRB,
			SUM (   b.playercomm ) as PlayerComm,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
			0 as AmountDueToBAEUR,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.EUR) as AmountDueToRBEUR,
			0 as CommBAEUR,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.EUR) as CommRBEUR,
			SUM (   b.playercomm * e.EUR) as PlayerCommEUR,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
			0 as AmountDueToBAUSD,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.USD) as AmountDueToRBUSD,
			0 as CommBAUSD,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.USD) as CommRBUSD,
			SUM (   b.playercomm * e.USD) as PlayerCommUSD,
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
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
			0 as AmountDueToBAGBP,
			- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END * e.GBP) as AmountDueToRBGBP,
			0 as CommBAGBP,
			SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END * e.GBP) as CommRBGBP,
			SUM (   b.playercomm * e.GBP) as PlayerCommGBP,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END * e.GBP)  as CompanyGBP ,
			--------------------------
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		--FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END
		GROUP BY   tma.currency, b.statusID, b.custid
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
			(CustID, Currency, 
			Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,
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
			0 as WinlossRB,
			- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (comm ) AS CommBA,
			0 AS CommRB,
			SUM(b.playercomm ) AS PlayerComm, 
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
			0 as WinlossRBEUR,
			- SUM ((b.winlost+b.awinlost+b.comm) * e.EUR) as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			SUM (comm * e.EUR) AS CommBAEUR,
			0 AS CommRBEUR,
			SUM(b.playercomm * e.EUR ) AS PlayerCommEUR, 
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
			0 as WinlossRBUSD,
			- SUM ((b.winlost+b.awinlost+b.comm) * e.USD) as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			SUM (comm * e.USD) AS CommBAUSD,
			0 AS CommRBUSD,
			SUM(b.playercomm * e.USD ) AS PlayerCommUSD, 
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
			0 as WinlossRBGBP,
			- SUM ((b.winlost+b.awinlost+b.comm) * e.GBP) as AmountDueToBAGBP,
			0 as AmountDueToRBGBP,
			SUM (comm * e.GBP) AS CommBAGBP,
			0 AS CommRBGBP,
			SUM(b.playercomm * e.GBP ) AS PlayerCommGBP, 
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
		WHERE 
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END		
		GROUP BY	
			b.custid,
			b.currency,
			b.statusID	
			
	END
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR  @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #WinLoss
			(CustID, Currency, 
			Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
			TurnOverGBP, WinlostGBP, LicenseeWLGBP, WinlossRBGBP, AmtDueToBAGBP, AmtDueToRBGBP, CommBAGBP, CommRBGBP, PlayerCommGBP, CompanyGBP,
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
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmtDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmtDueToRB,
			0 as CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END) as CommRB,
			SUM ( b.playercomm ) as PlayerComm,
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
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS WinlossRBEUR,
			0 as AmtDueToBAEUR,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.EUR) as AmtDueToRBEUR,
			0 as CommBAEUR,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END * e.EUR) as CommRBEUR,
			SUM ( b.playercomm * e.EUR) as PlayerCommEUR,
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
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS WinlossRBUSD,
			0 as AmtDueToBAUSD,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.USD) as AmtDueToRBUSD,
			0 as CommBAUSD,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END * e.USD) as CommRBUSD,
			SUM ( b.playercomm * e.USD) as PlayerCommUSD,
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
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.GBP) AS WinlossRBGBP,
			0 as AmtDueToBAGBP,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.GBP) as AmtDueToRBGBP,
			0 as CommBAGBP,
			SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END * e.GBP) as CommRBGBP,
			SUM ( b.playercomm * e.GBP) as PlayerCommGBP,
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
		WHERE 		
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END	
		GROUP BY	
			b.custid,
			b.currency,
			b.statusID			
	END
END			


SELECT 
	c.Custid, 
	c.username, 
	SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
	w.Currency ,   
	case WHEN w.Currency IN (20,51) THEN e.currency ELSE e.Code END as CurrencyName,
	
	SUM(TurnOver)	AS Turnover,
	SUM(Winlost)		AS Winlost,
	SUM(LicenseeWL) AS LicenseeWL,
	SUM(WinlossRB)	AS WinlossRB,

	SUM(CommBA) AS CommBA,
	SUM(CommRB) AS CommRB,	
	SUM(PlayerComm) AS PlayerComm,
	SUM(AmtDuetoBA) AS AmtDuetoBA,
	SUM(AmtDuetoRB) AS AmtDuetoRB,
	SUM(Company) AS Company,
	
	SUM(Betcount)	AS Betcount,
			
	--BASE EUR
	SUM(TurnOverEUR)	AS TurnoverEUR,
	SUM(WinlostEUR)		AS WinlostEUR,
	SUM(LicenseeWLEUR) AS LicenseeWLEUR,
	SUM(WinlossRBEUR)	AS WinlossRBEUR,
	SUM(CommBAEUR) AS CommBAEUR,
	SUM(CommRBEUR) AS CommRBEUR,	
	SUM(PlayerCommEUR) AS PlayerCommEUR,
	SUM(AmtDuetoBAEUR) AS AmtDuetoBAEUR,
	SUM(AmtDuetoRBEUR) AS AmtDuetoRBEUR,
	SUM(CompanyEUR) AS CompanyEUR,
	
	--BASE USD
	SUM(TurnOverUSD)	AS TurnoverUSD,
	SUM(WinlostUSD)		AS WinlostUSD,
	SUM(LicenseeWLUSD) AS LicenseeWLUSD,
	SUM(WinlossRBUSD)	AS WinlossRBUSD,
	SUM(CommBAUSD) AS CommBAUSD,
	SUM(CommRBUSD) AS CommRBUSD,	
	SUM(PlayerCommUSD) AS PlayerCommUSD,
	SUM(AmtDuetoBAUSD) AS AmtDuetoBAUSD,
	SUM(AmtDuetoRBUSD) AS AmtDuetoRBUSD,
	SUM(CompanyUSD) AS CompanyUSD,
	--BASE GBP
	SUM(TurnOverGBP)	AS TurnoverGBP,
	SUM(WinlostGBP)		AS WinlostGBP,
	SUM(LicenseeWLGBP) AS LicenseeWLGBP,
	SUM(WinlossRBGBP)	AS WinlossRBGBP,
	SUM(CommBAGBP) AS CommBAGBP,
	SUM(CommRBGBP) AS CommRBGBP,	
	SUM(PlayerCommGBP) AS PlayerCommGBP,
	SUM(AmtDuetoBAGBP) AS AmtDuetoBAGBP,
	SUM(AmtDuetoRBGBP) AS AmtDuetoRBGBP,
	SUM(CompanyGBP) AS CompanyGBP
FROM #WinLoss w 
	INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
	INNER JOIN Exchange e WITH (NOLOCK) on w.Currency=e.exchangeid
GROUP BY
	c.Custid, w.Currency ,c.username,c.username2,
	CASE WHEN w.Currency IN (20,51) THEN e.currency ELSE e.Code END 
ORDER BY 5,2

DROP TABLE #WinLoss
		
	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MobileWinloss] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MobileWinloss] TO [vnteam] AS [dbo]