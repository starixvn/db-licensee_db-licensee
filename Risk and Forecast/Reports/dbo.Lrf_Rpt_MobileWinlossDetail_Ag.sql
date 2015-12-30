USE [bodb02]
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_MobileWinlossDetail_Ag]   
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
 @ShowBG		BIT=9,-- Bingo
 @SiteType	TINYINT=1, 
 @MoveBetsDay SMALLDATETIME,
 @drawfilter SMALLINT = 1  ,
 @excludeTest BIT = 0,
 @Debug		BIT = 0
AS
/*  Created: Henry
	Date: 2013-01-10
    Task : Mobile WinLoss Report 
    DB: DB052.bodb02  
   
    Revisions:  
			- 20130225@Jim: add RNG Casino,Bingo
			- 20140414@Jim: support USD base currency 
			- 20130618@Jim: Restrict permission of Licensee Users by currency
			- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
			- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
			- 20151228@Bobby: Remove RNG Casino
			
	Param's Explanation:  
	  + @SiteType: 1-WAP; 2-Smartphone; 3: Others;0-All  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss2, 1 - query in table rptLicWinloss_old
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  + @ShowLC: Show Live casino
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/
    
BEGIN      

CREATE TABLE #WinLoss (
	Winlostdate DATETIME, 
	CustID			INT,  
	Currency INT ,
	Turnover MONEY, 
	Winlost MONEY, 
	LicenseeWL MONEY,
	WinlossRB MONEY,
	AmtDueToBA MONEY,
	AmtDueToRB MONEY,
	CommBA MONEY,
	CommRB MONEY,
	playercomm MONEY,
	Company MONEY,
	BetCount BIGINT
	)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @tempAg	TABLE( custID INT  , Currency INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @VNDCurrencyName VARCHAR(20)
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME
--to Deal With Parameter Sniffing
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
/*
DECLARE @site VARCHAR(50)
SELECT @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency 
FROM Dep_CustSuper dc  WITH (NOLOCK)  
	 INNER JOIN #Currency c ON  dc.Currency=c.CurrencyID
WHERE  site = @site
*/
DROP TABLE #Currency 

IF @ShowSB = 1  INSERT  INTO @sporttype( sporttype) VALUES  (0)	
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

IF @ShowBG = 1	
BEGIN
	INSERT  INTO @sporttype( Sporttype) VALUES  (252)
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE typeid =73
END

IF @TDate>@MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate
	
	IF @ShowBA=1
	BEGIN
		INSERT INTO #WinLoss
		SELECT 
			b.winlostdate,
			b.recommend,
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
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
			INNER JOIN @TempAg tma ON tma.CustID=b.recommend AND b.currency = tma.currency 
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.bettype NOT IN (901,902,903)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END
		GROUP BY  b.winlostdate, b.currency, b.bettype  , b.statusID, b.recommend	
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #WinLoss
		SELECT 
			b.winlostdate,
			b.recommend,
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
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend  AND b.currency = tma.currency
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) 
			AND b.bettype NOT IN (901,902,903)
			AND b.tpositiontaking <>0
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END
		GROUP BY  b.winlostdate, tma.currency, b.statusID, b.recommend	   
	END
	
	
	IF (@ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #WinLoss
		SELECT 
			b.winlostdate,
			b.recommend,
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
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM dbo.bettrans b WITH (NOLOCK,INDEX=IX_srecommend)
			INNER JOIN @tempAg tma ON tma.CustID=b.recommend AND b.currency  = tma.currency
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		WHERE
			b.statusID  IN (111, 112, 113)
			AND b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END
		GROUP BY  b.winlostdate, tma.currency, b.statusID, b.recommend
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
		SELECT 
			b.winlostdate,
			b.recommend,
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
			- SUM (b.winlost+b.awinlost+b.comm) as AmtDueToBA,
			0 as AmtDueToRB,
			SUM (b.comm ) as CommBA,	
			0 as CommRB,
			SUM( b.playerComm ) as PlayerComm,
			0 as Company,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		WHERE 
			  b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903)
			AND ISNULL(b.isBA,0) = 1
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END		
		GROUP BY	
			b.winlostdate,
			b.recommend,
			b.currency,
			b.statusID	
			
	END
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR  @ShowLC = 1 OR @ShowVS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #WinLoss
		SELECT 
			b.winlostdate,
			b.recommend,
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
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		WHERE 		
			  b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND b.bettype NOT IN (901,902,903)
			AND ISNULL(b.isBA,0) = 0
			AND 1= CASE @SiteType 
				WHEN 1 THEN CASE WHEN b.betfrom = 'm' THEN 1 ELSE 0 END
				WHEN 2 THEN CASE WHEN b.betfrom IN ('s','l') THEN 1 ELSE 0 END
				WHEN 3 THEN CASE WHEN b.betfrom NOT IN ('s','m','l') THEN 1 ELSE 0 END
				ELSE 1 
				END	
		GROUP BY	
			b.winlostdate,
			b.recommend,
			b.currency,
			b.statusID			
	END
END			

CREATE TABLE #Exchange (ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))	
	
CREATE NONCLUSTERED INDEX IDX_Index ON #WinLoss(Currency)

INSERT INTO #Exchange (ExchangeDate,ExchangeId,EUR,USD,Code)
SELECT ExchangeDate,ExchangeId,EUR,USD,Code FROM Lrf_f_GetExchangeDaily(@FromDate,@Todate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #WinLoss)
	
SELECT 
	c.username,
	w.custid,
	w.Currency ,   
	CASE WHEN w.Currency = 51 THEN @VNDCurrencyName 
		ELSE e.Code END currencyName,
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
	SUM(TurnOver * E.EUR)	AS TurnoverEUR,
	SUM(Winlost * E.EUR)		AS WinlostEUR,
	SUM(LicenseeWL * E.EUR) AS LicenseeWLEUR,
	SUM(WinlossRB * E.EUR)	AS WinlossRBEUR,
	SUM(CommBA * E.EUR) AS CommBAEUR,
	SUM(CommRB * E.EUR) AS CommRBEUR,	
	SUM(PlayerComm * E.EUR) AS PlayerCommEUR,
	SUM(AmtDuetoBA * E.EUR) AS AmtDuetoBAEUR,
	SUM(AmtDuetoRB * E.EUR) AS AmtDuetoRBEUR,
	SUM(Company * E.EUR) AS CompanyEUR,
	---------------
		--BASE USD
	SUM(TurnOver * E.USD)	AS TurnoverUSD,
	SUM(Winlost * E.USD)		AS WinlostUSD,
	SUM(LicenseeWL * E.USD) AS LicenseeWLUSD,
	SUM(WinlossRB * E.USD)	AS WinlossRBUSD,
	SUM(CommBA * E.USD) AS CommBAUSD,
	SUM(CommRB * E.USD) AS CommRBUSD,	
	SUM(PlayerComm * E.USD) AS PlayerCommUSD,
	SUM(AmtDuetoBA * E.USD) AS AmtDuetoBAUSD,
	SUM(AmtDuetoRB * E.USD) AS AmtDuetoRBUSD,
	SUM(Company * E.USD) AS CompanyUSD
	---------------
FROM 
	#WinLoss w 
	INNER JOIN #Exchange e	ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
	INNER JOIN Customer c WITH(NOLOCK) ON w.custid = c.custid
GROUP BY
	w.Currency ,c.username,w.custid,
	CASE WHEN w.Currency = 51 THEN @VNDCurrencyName 
		ELSE e.Code END	


DROP TABLE #Exchange
DROP TABLE #WinLoss
		
	
END