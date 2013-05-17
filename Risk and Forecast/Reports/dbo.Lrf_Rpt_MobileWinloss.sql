set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_Rpt_MobileWinloss]  
 @LicenseeID	INT,
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
    DB: DBLIC.bodb02  
   
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

	BetCount	BIGINT
	)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @tempAg	TABLE( custID INT PRIMARY KEY, Currency INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @VNDCurrencyName VARCHAR(20)
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME
--to Deal WITH Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 


INSERT INTO @tempAg (custID,currency) 
SELECT custID,currency FROM bodb_Licensee.dbo.LicenseeCust (NOLOCK) 
WHERE 
	LicenseeID = @LicenseeID 
	AND (@CurrencyID = 0 OR (@CurrencyID<> 0 AND Currency=@CurrencyID))
	AND (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	

DECLARE @site VARCHAR(50)
SELECT TOP 1 @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency FROM Dep_CustSuper WITH (NOLOCK)  
WHERE  site = @site

DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))

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
	INSERT  INTO @sporttype( Sporttype) VALUES  (180)
	
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

INSERT INTO @Exchange (exchangedate,exchangeid,eur,usd,code)
SELECT exchangedate,exchangeid,eur,usd,code
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
			---------------------------
			COUNT(b.transid) 
				* CASE WHEN @drawfilter = 2 THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount
		FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
			INNER JOIN @TempAg tma ON tma.CustID=b.recommend 
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON s.custid=BA.srecommend and b.transid = BA.transid 	 	
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
			BetCount)
		SELECT 
			b.custid,
			s.currency,
			
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
			--------BetCount-----------
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend 
			INNER JOIN @Super s ON b.srecommend = s.custid
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) 
			AND b.tpositiontaking <>0
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END
		GROUP BY  s.currency, b.statusID, b.custid	   
	END
	
	
	IF (@ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #WinLoss
			(CustID, Currency, 
			Turnover, Winlost, LicenseeWL, WinlossRB, AmtDueToBA, AmtDueToRB, CommBA, CommRB, playercomm, Company, 
			TurnOverEUR, WinlostEUR, LicenseeWLEUR, WinlossRBEUR, AmtDueToBAEUR, AmtDueToRBEUR, CommBAEUR, CommRBEUR, PlayerCommEUR, CompanyEUR, 
			TurnOverUSD, WinlostUSD, LicenseeWLUSD, WinlossRBUSD, AmtDueToBAUSD, AmtDueToRBUSD, CommBAUSD, CommRBUSD, PlayerCommUSD, CompanyUSD, 
			BetCount)
		SELECT 
			b.custid,
			s.currency,
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
			--------------------------
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend 
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
		GROUP BY   s.currency, b.statusID, b.custid
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
			-----------------------------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
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
			------------------------------------------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
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
	SUM(CompanyUSD) AS CompanyUSD
FROM #WinLoss w 
	INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
	INNER JOIN Exchange e WITH (NOLOCK) on w.Currency=e.exchangeid
GROUP BY
	c.Custid, w.Currency ,c.username,c.username2,
	CASE WHEN w.Currency IN (20,51) THEN e.currency ELSE e.Code END 
ORDER BY 5,2

DROP TABLE #WinLoss
		
	
END	

GRANT EXECUTE ON [dbo].[Lrf_Rpt_MobileWinloss] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MobileWinloss] TO [vnteam]  
	


/*

BEGIN      

	DECLARE @sql varchar(max)
	DECLARE @sql1 varchar(max)
	DECLARE @TempFromDate DATETIME 
	DECLARE @TempToDate DATETIME 
	DECLARE @MaxOldDate DATETIME
	DECLARE @VNDCurrencyName VARCHAR(20)
	DECLARE @FDate DATETIME
	DECLARE @TDate DATETIME
	--to Deal WITH Parameter Sniffing
	SELECT @FDate=@FromDate,@TDate=@ToDate 
	
	SELECT @sql = 'SET NOCOUNT ON ' + char(13)
	SELECT @sql = @sql + '--Declare variable:' + char(13)

	SELECT @sql = @sql +	
					'CREATE TABLE #SAgWinLoss (Winlostdate DATETIME, Currency INT ,Turnover MONEY, Winlost MONEY, LicenseeWL MONEY,'+char(13)+
					'WinlossRB MONEY,AmtDueToBA MONEY,AmtDueToRB MONEY,CommBA MONEY,CommRB MONEY,playercomm MONEY,Company MONEY,BetCount BIGINT)'+char(13)+
					'DECLARE @TmpCondSumWL	TABLE( sporttype INT)'+char(13)+
					'DECLARE @tmpAg	TABLE( custID INT PRIMARY KEY, Currency INT)'+char(13)
	
	SELECT @VNDCurrencyName=currency FROM exchange WITH (NOLOCK) WHERE ExchangeID=51
	SELECT @sql=@sql+  'BEGIN'+char(13)+
								'INSERT INTO @tmpAg(custID,currency) SELECT custID,currency FROM bodb_Licensee.dbo.LicenseeCust (NOLOCK) WHERE LicenseeID = '+CONVERT(VARCHAR(10),@LicenseeID)+
								CASE WHEN @CurrencyID<>0 THEN 'AND Currency='+CONVERT(VARCHAR(10),@CurrencyID) ELSE '' END +char(13)+
								CASE WHEN @excludeTest=1 THEN 'AND Currency<>20'ELSE '' END +char(13)+
						'END'+char(13)
	IF	@ShowSB=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(0)'+char(13)+
						 'END'+char(13)
	IF @ShowRB=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(151)'+char(13)+
						 'END'+char(13)
	IF @ShowNG=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(161)'+char(13)+
						 'END'+char(13)
						 
						 
	IF @ShowLC=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(162)'+char(13)+
						 'END'+char(13)	
							 
	IF @ShowVS=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(180)'+char(13)+
						 'END'+char(13)							
	
	IF @ShowCS=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
									'INSERT INTO @TmpCondSumWL(sporttype) VALUES(251)'+char(13)+
						'END'+char(13)	
	IF @ShowBG=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(252)'+char(13)+
						 'END'+char(13)														
	IF @TDate>@MoveBetsDay
		BEGIN
			IF @FDate <= @MoveBetsDay 
				SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
			ELSE
				SET @TempFromDate = @FDate
			IF @ShowBA=1
					BEGIN	
						SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
														'SELECT b.winlostdate,'+char(13)+  
															'b.currency,'+char(13)+
															'SUM( stake*'+char(13)+
																CASE WHEN @drawfilter IN (2,3) THEN
																	'CASE WHEN b.statusID = 111 THEN 0'+char(13)+
																	'WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5'+char(13)+
																	'ELSE 1 END'
																ELSE '1' END+') turnover,'+char(13)+
															'SUM(b.winlost - b.actual_stake) AS Winlost,'+char(13)+
															'0 as LicenseeWL,'+char(13)+
															'0 as WinlossRB,'+char(13)+
															'- SUM (b.winlost - b.actual_stake + b.awinlost + b.comm ) as AmountDueToBA,'+char(13)+
															'0 as AmountDueToRB,'+char(13)+
															'SUM (b.comm ) as CommBA,'+char(13)+
															'0 as CommRB,'+char(13)+
															'SUM(b.playercomm  ) as PlayerComm,'+char(13)+
															'0 as Company,'+char(13)+
															'(COUNT(b.transid)*'+char(13)+
															CASE WHEN @drawfilter = 2 THEN 'CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END'
															ELSE '1' END +')BetCount'+char(13)+
														'FROM dbo.bettrans b WITH (NOLOCK)'+char(13)+
															'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend and b.transid = BA.transid'+char(13)+
														'WHERE '+char(13)+' b.statusID  IN (111, 112, 113)'+char(13)+
															'AND (b.winlostdate BETWEEN'''+convert(varchar(10),@TempFromDate, 120)+'''AND '''+ convert(varchar(10),@Tdate,120)+''')'+char(13)+
															CASE 
																WHEN (@SiteType=0) THEN ''
																WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
															ELSE ''END+char(13)+
															'AND b.Recommend IN (SELECT custid FROM @tmpAg)'+char(13)+
														'GROUP BY  b.winlostdate, b.currency, b.bettype  , b.statusID'	+char(13)
					END
			IF (@ShowSB=1 or @ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
				BEGIN
					SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
													'SELECT b.winlostdate,'	+char(13)+
														'b.currency,' +char(13)+
														'SUM('+char(13)+
														'(CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END'+char(13)+
														'*'+char(13)+ CASE WHEN @drawfilter IN (2,3) THEN 'CASE WHEN b.statusID=111 THEN 0'+char(13)+
																										   'WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5'+char(13)+
																											'ELSE 1 END '
																									ELSE '1' END +'))turnover,'+char(13)+
														'SUM(b.winlost-b.actual_stake) AS Winlost,'	+char(13)+
														'- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END) AS LicenseeWL ,'+char(13)+
														'SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,'+char(13)+					
														'0 as AmountDueToBA,'+char(13)+															
														'- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) as AmountDueToRB,'+char(13)+
														'0 as CommBA,'+char(13)+
														'SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END)as CommRB,'	+char(13)+
														'SUM (   b.playercomm ) as PlayerComm,'	+char(13)+
														'- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END)  as Company ,'+char(13)+
														'(COUNT(b.transid)*'	+char(13)+ CASE WHEN @drawfilter=2 THEN 'CASE WHEN b.statusID=111 THEN 0 ELSE 1 END'
																							ELSE '1' END +char(13)+') Betcount' +char(13)+
													'FROM '	+char(13)+'dbo.bettrans b WITH (NOLOCK)'+char(13)+
																 'LEFT JOIN bodb_Licensee.dbo.licenseeBAtransaction_active lb WITH (NOLOCK) ON b.recommend = lb.recommend AND b.TransID=lb.TransID'+char(13)+
													'WHERE '+char(13)+'b.statusID IN (111,112,113)'+char(13)+
																CASE 	
																	WHEN (@SiteType=0) THEN ''
																	WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																	WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																	WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
																 ELSE ''END+char(13)+	
																'AND b.matchid>0'+char(13)+
																'AND lb.TransID IS NULL'+char(13)+
																'AND (b.winlostdate BETWEEN'''+convert(varchar(10),@TempFromDate, 120) +'''AND'''+convert(varchar(10),@TDate, 120) +''')'+char(13)+
																'AND b.Recommend IN (SELECT custid FROM @tmpAg)'+char(13)+
																'AND ('+char(13)+'bettype<'+ CASE WHEN @ShowSB=1 THEN '31 OR b.bettype BETWEEN 121 AND 999' ELSE '0' END+char(13)+
																							 CASE WHEN @ShowNG=1 THEN 'OR b.bettype BETWEEN 81 AND 120' ELSE '' END+char(13)+
																							 CASE WHEN @ShowRB=1 THEN 'OR b.bettype BETWEEN 31 AND 33' ELSE ''END+char(13)+
																							 CASE WHEN @ShowLC=1 THEN 'OR b.bettype BETWEEN 1101 AND 1199' ELSE ''END+char(13)+
																							 CASE WHEN @ShowVS=1 THEN 'OR b.bettype BETWEEN 1201 AND 1299' ELSE ''END+char(13)+
																							 CASE WHEN @ShowCS=1 THEN 'OR b.bettype =71' ELSE ''END+char(13)+
																							 CASE WHEN @ShowBG=1 THEN 'OR b.bettype =73' ELSE ''END+char(13)+
																	')'+char(13)+
													'GROUP BY b.winlostdate, b.currency,b.bettype  ,b.statusID'					
				END
		END
	IF @FDate <= @MoveBetsDay 
	BEGIN
			IF @TDate >= @MoveBetsDay
					SET @TempToDate = @MoveBetsDay
				ELSE
					SET  @TempToDate = @TDate
			
			BEGIN
				IF @ShowBA=1 
					BEGIN	
						SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
														'SELECT b.winlostdate,b.currency,'+char(13)+
																'SUM(b.turnover *'+char(13)+ CASE WHEN @drawfilter IN (2,3) THEN 'CASE WHEN b.statusID=111 THEN 0'+char(13)+
																																	   'WHEN b.statusID IN (114,115) THEN 0.5 ELSE 1 END'
																							 ELSE '1' END+char(13)+')AS TurnOver ,'+char(13)+
																'SUM(b.winlost),0 as LicenseeWL,0 AS WinlossRB,- SUM (b.winlost+b.awinlost+b.comm) as AmtDueToBA,0 as AmtDueToRB,SUM (b.comm ) as CommBA,'+char(13)+
																'0 as CommRB,'+char(13)+
																'SUM( b.playerComm ) as PlayerComm,'+char(13)+
																'0 as Company,'+char(13)+
																'(SUM(b.betcount)*'	+char(13)+ CASE WHEN @drawfilter =2 THEN 'CASE WHEN b.statusID=111 THEN 0 ELSE 1 END'
																															ELSE '1' END +') as Betcount '+char(13)+  
														'FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK ) '+char(13)+
														'WHERE '+char(13)+'b.roleid = 2 '+char(13)+
																	  'AND b.Recommend IN (SELECT custid FROM @tmpAg)'	+char(13)+
																	  'AND b.statusID <> 101'+char(13)+
																	  'AND ISNULL(b.isBA,0) = 1'+char(13)+
																	  'AND (b.Winlostdate BETWEEN'''+convert(varchar(10),@FDate, 120)+'''AND'''+convert(varchar(10),@TempToDate, 120)+''')'+char(13)+
																	  CASE	WHEN (@SiteType=0) THEN ''
																			WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																			WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																			WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
																		 ELSE '' END +char(13)+
														'GROUP BY b.winlostdate,   b.currency, b.sporttype, b.statusID'							
										
					END	
				IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR  @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
					BEGIN
						SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
													'SELECT b.winlostdate,b.currency,SUM(b.turnover*'+char(13)+
															CASE WHEN @drawfilter IN (2,3) THEN 'CASE WHEN b.statusID = 111  THEN 0 '+char(13)+
																									  'WHEN b.statusID IN (114,115) THEN 0.5 ELSE 1 END'
																							ELSE '1' END +char(13)+ ') AS TurnOver,'+char(13)+
															'SUM(b.winlost),'+char(13)+
															'- SUM(CASE WHEN (b.sporttype <> 151) THEN b.winlost ELSE 0 END) AS LicenseeWL ,'+char(13)+--SB, NG, Livecasino, Virtual Sport
															'SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,'+char(13)+
															'0 as AmtDueToBA,'+char(13)+
															'- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmtDueToRB,'+char(13)+
															'0 as CommBA,'+char(13)+
															'SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END) as CommRB,'+char(13)+
															'SUM ( b.playercomm ) as PlayerComm,'+char(13)+
															'- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END)  as Company,'+char(13)+
															'(SUM(b.betcount)*'+char(13)+CASE WHEN @drawfilter = 2 THEN 'CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END'
																							 ELSE '1' END+') AS Betcount'+char(13)+
													'FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK ) '+char(13)+
													'WHERE  b.roleid = 2'+char(13)+
															'AND b.Recommend IN (SELECT custid FROM @tmpAg)'+char(13)+
															'AND b.sporttype IN (SELECT Sporttype FROM @TmpCondSumWL)'+char(13)+
															'AND b.statusID <> 101 '+char(13)+
															'AND ISNULL(b.isBA,0) = 0'+char(13)+
															'AND (b.Winlostdate BETWEEN'''+convert(varchar(10),@FDate, 120)+'''AND'''+convert(varchar(10),@TempToDate, 120)+''')'+char(13)+
															CASE	WHEN (@SiteType=0) THEN ''
																	WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																	WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																	WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
															     ELSE '' END +char(13)+
													'GROUP BY  b.winlostdate,   b.currency, b.sporttype, b.statusID'				
				
					END
					
			END
		
	END
	
	SELECT @sql = @sql  +char(13)+'CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)'+char(13)+
								'SELECT * INTO #TempExchange FROM Lrf_f_GetExchangeDaily('''+convert(varchar(10),@FDate, 120)+''','''+convert(varchar(10),@TDate, 120)+''')'+char(13)+
								'WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)'+char(13)
	
	SELECT @sql1= @sql+ char(13)+'SELECT w.winlostdate,Currency ,'+char(13)+
							
							'CASE WHEN Currency = 51 THEN'''+@VNDCurrencyName+''''+char(13)+
							'ELSE e.Code END currencyName,'+char(13)+
							'SUM(TurnOver)	AS Turnover,'+   +char(13)+
							'SUM(Winlost)		AS Winlost,'+char(13)+  
							'SUM(LicenseeWL) AS LicenseeWL,'+char(13)+
							'SUM(WinlossRB)	AS WinlossRB,'+char(13)+
							'SUM(CommBA) AS CommBA,'+char(13)+
							'SUM(CommRB) AS CommRB,'+char(13)+
							'SUM(PlayerComm) AS PlayerComm,'+char(13)+
							'SUM(AmtDuetoBA) AS AmtDuetoBA,'+char(13)+
							'SUM(AmtDuetoRB) AS AmtDuetoRB,'+char(13)+
							'SUM(Company) AS Company,'+char(13)+
							'SUM(Betcount)	AS Betcount,'+char(13)+
								
							--BaseEUR  
							'SUM(TurnOver*e.EUR)	AS TurnoverEUR,'+char(13)+   
							'SUM(Winlost*e.EUR)	AS WinlostEUR,'+char(13)+  
							'SUM(LicenseeWL*e.EUR) AS LicenseeWLEUR,'+char(13)+
							'SUM(WinlossRB*e.EUR)	AS WinlossRBEUR,'+char(13)+
							'SUM(CommBA * e.EUR) AS CommBAEUR,'+char(13)+
							'SUM(CommRB * e.EUR) AS CommRBEUR,'+char(13)+
							'SUM(PlayerComm*e.EUR) as PlayercommEUR,'+char(13)+
							'SUM(AmtDuetoBA*e.EUR) AS AmtDuetoBAEUR,'+char(13)+
							'SUM(AmtDuetoRB*e.EUR) AS AmtDuetoRBEUR,'+char(13)+
							'SUM(Company * e.EUR) AS CompanyEUR,'+char(13)+
							--BaseUSD  
							'SUM(TurnOver*e.USD)	AS TurnoverUSD,'+char(13)+   
							'SUM(Winlost*e.USD)	AS WinlostUSD,'+char(13)+  
							'SUM(LicenseeWL*e.USD) AS LicenseeWLUSD,'+char(13)+
							'SUM(WinlossRB*e.USD)	AS WinlossRBUSD,'+char(13)+
							'SUM(CommBA * e.USD) AS CommBAUSD,'+char(13)+
							'SUM(CommRB * e.USD) AS CommRBUSD,'+char(13)+
							'SUM(PlayerComm*e.USD) as PlayercommUSD,'+char(13)+
							'SUM(AmtDuetoBA*e.USD) AS AmtDuetoBAUSD,'+char(13)+
							'SUM(AmtDuetoRB*e.USD) AS AmtDuetoRBUSD,'+char(13)+
							'SUM(Company * e.USD) AS CompanyUSD'+char(13)+
							
						'FROM #SAgWinLoss w'+char(13)+
							'INNER JOIN #TempExchange e'+char(13)+
							--'INNER JOIN ExchangeDaily e WITH (NOLOCK)'+char(13)+
							'ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId'+char(13)+
						'GROUP BY'+char(13)+
							'w.winlostdate,Currency,CONVERT(VARCHAR(8),w.winlostdate,112),'	+char(13)+
							'CASE WHEN Currency = 51 THEN'''+@VNDCurrencyName+'''ELSE e.Code END'+char(13)+
						'ORDER BY w.winlostdate'+char(13) +
						'DROP TABLE #SAgWinLoss'+char(13) +
						'DROP TABLE #TempExchange'+char(13) 
	--SET @sql=@sql+char(13)+@sql1			
	IF (@debug = 1) 
		PRINT (@sql1 )
	ELSE
		EXEC(@sql1 )
END	
*/
