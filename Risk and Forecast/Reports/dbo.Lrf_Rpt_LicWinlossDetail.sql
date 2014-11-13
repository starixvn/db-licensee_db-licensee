USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinlossDetail]  
	@LicenseeID	INT,
	@UserID		INT,
	@CurrencyID	INT = 0,
	@CustID		INT = 0, --AgentID			
	@FromDate	SMALLDATETIME,  
	@ToDate		SMALLDATETIME,   
	@showSB		BIT=0,  
	@ShowRB		BIT=0,  
	@ShowNG		BIT=0,
	@ShowBA		BIT=0,
	@ShowLC		BIT=0,
	@ShowVS		BIT=0,
	@ShowCS		BIT=0, -- RNG Casino
	@ShowBG		BIT=0, -- Bingo 
	@ShowKN		BIT=0, -- Keno 
	@MoveBetsDay SMALLDATETIME,
	@IsOld BIT = 0,
	@drawfilter SMALLINT = 1,
	@excludeTest BIT = 0

AS  
/*  Created: Henry  
	Date: 2012-01-09  
    Task : Winloss Report for Licensee Member Level
    DB: DB052.bodb02  
   
    Revisions:  
		-20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		-20120529@Henry: enhance performance
		-20120726@Jim: add playercomm value 
		-20120814@Jim: add ShowLiveCasino 
		-20120830@Jim : add virtual Sport
		-20121004@Jim : replace @Currency input param by @CurrencyID  
		-20121115@Henry:  Only Sportsbook needs to exclude BA
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130204@Jim: support RNG Casino and Bingo product
		- 20130414@Jim: support USD base currency 
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20130916@Jim: offer Virtual Tennis
		- 20131120@Victor: Enhance performance
		- 20140305@Florent: support Keno
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	Param's Explanation:  
	  + @CustID: SuperID  
	  + @BaseCurrency (input currencyID): 2-MYR ; 3-USD; 6-EUR
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query IN table rptLicWinloss, 1 - query IN table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowLC: Show live Casino 
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  
  
*/  
BEGIN  
SET NOCOUNT ON  

CREATE TABLE #SAgWinLoss (  
	--winlostdate		DATETIME,  
	CustID			INT,   
	Currency		INT,  
	TurnoverSB		MONEY,
	TurnoverBA		MONEY,
	TurnoverNG		MONEY,
	TurnoverRB		MONEY,
	TurnoverLC		MONEY,
	TurnoverVS		MONEY,
	TurnoverCS 		MONEY,
	TurnoverBG		MONEY,
	TurnoverKN		MONEY,
	Winlost			MONEY,  
	LicenseeWLSB	MONEY,
	LicenseeWLBA	MONEY,
	LicenseeWLNG	MONEY,
	LicenseeWLRB	MONEY,
	LicenseeWLLC	MONEY,
	LicenseeWLVS	MONEY,
	LicenseeWLCS	MONEY,
	LicenseeWLBG	MONEY,
	LicenseeWLKN	MONEY,
	AmtDueToBA		MONEY,   
	AmtDueToRB		MONEY,
	CommBA			MONEY,   
	CommRB			MONEY,
	PlayerComm  	MONEY,
	Company			MONEY,
	
	---------------
	Betcount		BIGINT
)  


DECLARE @tempAg	TABLE( custID INT , Currency INT)  
DECLARE @Code VARCHAR(20), @TempCurrencyID INT
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,MYR FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))


SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @tempAg (custID,currency) 
SELECT lc.custID,lc.currency 
FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
WHERE 
	(@CustID=0 OR (@CustID<>0 AND lc.CustiD=@CustID))
	AND (@excludeTest=0 OR (@excludeTest=1 AND lc.Currency <> 20))	
/*
DECLARE @site VARCHAR(50)
SELECT @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency 
FROM Dep_CustSuper dc WITH (NOLOCK)  
INNER JOIN #Currency c ON dc.Currency=c.CurrencyID
WHERE  site = @site
*/
------------------
DROP TABLE #Currency
------------------
SELECT TOP 1 @TempCurrencyID=currency FROM @tempAg 

IF @TempCurrencyID in (51,20)
	SELECT @Code = currency FROM exchange (nolock) WHERE ExchangeId = @TempCurrencyID
ELSE
	SELECT @Code = code FROM exchange (nolock) WHERE exchangeid=@TempCurrencyID

IF @ShowSB = 1  
BEGIN  
	INSERT  INTO @sporttype( sporttype)
    VALUES  (0)	
	
END  

IF @ShowRB = 1  
BEGIN  
	INSERT  INTO @sporttype( Sporttype)
    VALUES  (151)
    
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 31 AND 33)
END  

IF @ShowNG = 1
BEGIN
	INSERT INTO @sporttype(Sporttype)  
	VALUES(161)  
	
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END  
IF @ShowLC = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
    VALUES  (162)
    
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
IF @ShowCS=1 -- RNG Casino
BEGIN
	INSERT INTO @sporttype(sporttype)
	VALUES (251)
	INSERT INTO @bettype(bettype)
	VALUES(71)
END 
IF @ShowBG=1 -- Bingo
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(252)
	INSERT INTO @bettype(bettype)
	VALUES(73)
END 

IF @ShowKN=1 -- Keno
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(202)
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1501 AND 1599)
END 

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @FDate DATETIME   
DECLARE @TDate DATETIME   
--to Deal With Parameter Sniffing
	SELECT @FDate=@FromDate,@TDate=@ToDate 
	
INSERT INTO @Exchange (exchangedate,exchangeid,usd,eur,myr,code)
SELECT exchangedate,exchangeid,usd,eur,myr,code
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT Currency FROM @TempAg)

DECLARE @eEUR FLOAT
DECLARE @eUSD FLOAT
SELECT TOP 1 @eEUR = eur, @eUSD = usd FROM @Exchange	
	
IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  dateadd(day,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate

	IF @ShowBA = 1
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT   
			b.custid,
			@CurrencyID, 
			
			0 AS turnoverSB,
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnoverBA, 
			0 AS turnoverNG,
			0 AS turnoverRB,
			0 AS turnoverLC,
			0 AS turnoverVS,
			0 AS turnoverCS,
			0 AS turnoverBG,
			0 AS turnoverKN,
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			0 as LicenseeWLSB,
			0 as LicenseeWLBA,
			0 as LicenseeWLNG,
			0 as LicenseeWLRB,
			0 as LicenseeWLLC,
			0 as LicenseeWLVS,
			0 as LicenseeWLCS,
			0 as LicenseeWLBG,
			0 as LicenseeWLKN,
			- SUM (b.winlost - b.actual_stake + awinlost + comm ) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			SUM(playercomm)   AS PlayerComm,
			0 AS Company,
			
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM 
			dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend) 
			INNER JOIN @TempAg tma ON tma.CustID=b.recommend AND b.currency = tma.Currency
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID IN (111, 112, 113)
		GROUP BY   
			b.custid, b.statusID
	END		

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			@CurrencyID, 
			
			SUM(
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnoverSB, 
			0 AS turnoverBA,
			0 turnoverNG, 
			0 AS turnoverRB,
			0 turnoverLC, 
			0 turnoverVS, 
			0 turnoverCS, 
			0 turnoverNG, 
			0 turnoverKN, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			-SUM(b.winlost-b.actual_stake ) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			0 as AmountDueToBA,
			0 as AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company  ,
			
			----------------------------------------
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM 	
			Bettrans b WITH ( NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency 
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND
			b.statusID  IN (111, 112, 113) AND
			b.tpositiontaking <>0
		GROUP BY   
			b.custid,b.statusID
	END

	IF (@ShowNG=1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowRB=1 OR @ShowCS=1 OR @ShowBG=1 OR @showKN=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			@CurrencyID,
			0 turnoverSB, 
			0 AS turnoverBA,
			SUM(
			CASE WHEN b.bettype BETWEEN 81 AND 120 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverNG, 
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN 
					CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				ELSE 0 END	
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			) turnoverRB, 
			SUM(
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverLC, 
			SUM(
			CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverVS, 
			SUM(
			CASE WHEN b.bettype =71 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverCS,
			SUM(
			CASE WHEN b.bettype =73 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverBG,
			SUM(
			CASE WHEN b.bettype between 1501 and 1599 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverKN,
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			-SUM(CASE WHEN (b.bettype BETWEEN 81 AND 120 ) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLNG,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN  b.awinlost ELSE 0 END) AS LicenseeWLRB,
			-SUM(CASE WHEN (b.bettype BETWEEN 1101 AND 1199) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLLC,
			-SUM(CASE WHEN (b.bettype BETWEEN 1201 AND 1299) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLVS,
			-SUM(CASE WHEN (b.bettype =71) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLCS,
			-SUM(CASE WHEN (b.bettype =73) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLBG,
			-SUM(CASE WHEN (b.bettype BETWEEN 1501 AND 1599) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLKN,
			--0 AS WinlossRB,
			0 as AmountDueToBA,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END) as AmountDueToRB,
			0 AS CommBA,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END) AS CommRB,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.awinlost + b.winlost - b.actual_stake + b.comm ELSE 0 END) Company  ,
			
			
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM 	
			Bettrans b WITH ( NOLOCK)
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.custid,b.statusID
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
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			@CurrencyID,
			  
			0 AS turnoverSB,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnoverBA,     
			0 AS turnoverNG,
			0 AS turnoverRB,
			0 AS turnoverLC,
			0 AS turnoverVS,
			0 AS turnoverCS,
			0 AS turnoverBG,
			0 AS turnoverKN,
			SUM(b.winlost),  
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			SUM(playercomm) AS PlayerComm,
			0 AS Company,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
		WHERE  
			b.recommend IN (SELECT DISTINCT CustID FROM @TempAg)
			AND b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.custid, b.statusID
	END
	
	--exclude BA tickets
	
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1)
	BEGIN
		
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			@CurrencyID,
			  
			SUM(CASE WHEN b.sporttype=0 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverSB,
			0 AS turnoverBA,
			SUM(CASE WHEN b.sporttype=161 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverNG,
			SUM(CASE WHEN b.sporttype=151 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverRB,
			SUM(CASE WHEN b.sporttype=162 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverLC,
			SUM(CASE WHEN b.sporttype IN (180,181,186) THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverVS,
			SUM(CASE WHEN b.sporttype=251 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverCS,
			SUM(CASE WHEN b.sporttype=252 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverBG,
			SUM(CASE WHEN b.sporttype=202 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverKN,
			SUM(b.winlost),  

			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END ) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END ) AS LicenseeWLNG,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END ) AS LicenseeWLLC,
			- SUM(CASE WHEN b.sporttype IN (180,181,186) THEN b.winlost ELSE 0 END ) AS LicenseeWLVS,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END ) AS LicenseeWLCS,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END ) AS LicenseeWLBG,
			- SUM(CASE WHEN b.sporttype=202 THEN b.winlost ELSE 0 END ) AS LicenseeWLKN,
			0 as AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END) AS CommRB,
			SUM ( playercomm) AS PlayerComm,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END)  as Company   ,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
		WHERE  
			b.recommend IN (SELECT DISTINCT custid FROM @TempAg)
			AND b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  b.custid,b.statusID
	END
	
			
 END 
 
 IF @IsOld = 1 
 BEGIN
	SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_Licensee.dbo.rptLicWinloss_old (nolock)
	IF @TDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @TDate
 
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT
			b.custid,
			@CurrencyID,
			  
			0 AS turnoverSB,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnoverBA,     
			0 AS turnoverNG,
			0 AS turnoverRB,
			0 AS turnoverLC,
			0 AS turnoverVS,
			0 AS turnoverCS,
			0 AS turnoverBG,
			0 AS turnoverKN,
			SUM(b.winlost),  
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			SUM(playercomm) AS PlayerComm,
			0 AS Company,
			
					
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
		WHERE  
			b.recommend IN (SELECT DISTINCT CustId FROM @TempAg)
			AND b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.custid,b.statusID
	END
	
	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @showKN=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT 
			b.custid,
			@CurrencyID,
			  
			SUM(CASE WHEN b.sporttype=0 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverSB,
			0 AS turnoverBA,
			SUM(CASE WHEN b.sporttype=161 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverNG,
			SUM(CASE WHEN b.sporttype=151 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverRB,
			SUM(CASE WHEN b.sporttype=162 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverLC,
			SUM(CASE WHEN b.sporttype IN (180,181,186) THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverVS,
			SUM(CASE WHEN b.sporttype=251 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverCS,
			SUM(CASE WHEN b.sporttype=252 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverBG,
			SUM(CASE WHEN b.sporttype=202 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverKN,

			SUM(b.winlost),  
			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END ) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END ) AS LicenseeWLNG,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END ) AS LicenseeWLLC,
			- SUM(CASE WHEN b.sporttype IN (180,181,186) THEN b.winlost ELSE 0 END ) AS LicenseeWLVS,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END ) AS LicenseeWLCS,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END ) AS LicenseeWLBG,
			- SUM(CASE WHEN b.sporttype=202 THEN b.winlost ELSE 0 END ) AS LicenseeWLKN,
			0 as AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END) AS CommRB,
			SUM ( playercomm) AS PlayerComm,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END)  as Company   ,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		
		FROM bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
		WHERE  
			b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  b.custid,b.statusID
		
	END
 END


 
 SELECT 
	   c.username,  
	   SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
	   w.custid, 
	   w.currency,
	   @Code AS CurrencyName,
	   SUM(TurnoverSB)       AS TurnoverSB,   
	   SUM(TurnoverBA)       AS TurnoverBA,   
	   SUM(TurnoverNG)       AS TurnoverNG,   
	   SUM(TurnoverRB)       AS TurnoverRB,   
	   SUM(TurnoverLC)       AS TurnoverLC,   
	   SUM(TurnoverVS)       AS TurnoverVS,   
	   SUM(TurnoverCS)       AS TurnoverCS,
	   SUM(TurnoverBG)       AS TurnoverBG,
	   SUM(TurnoverKN)       AS TurnoverKN,
	   SUM(Winlost)		  AS Winlost,  
	   SUM(LicenseeWLSB)  AS LicenseeWLSB,
	   SUM(LicenseeWLBA)  AS LicenseeWLBA,
	   SUM(LicenseeWLNG)  AS LicenseeWLNG,
	   SUM(LicenseeWLRB)  AS LicenseeWLRB,	
	   SUM(LicenseeWLLC)  AS LicenseeWLLC,
	   SUM(LicenseeWLVS)  AS LicenseeWLVS,
	   SUM(LicenseeWLCS)  AS LicenseeWLCS,
	   SUM(LicenseeWLBG)  AS LicenseeWLBG,
	   SUM(LicenseeWLKN)  AS LicenseeWLKN,
	   SUM(CommBA) AS CommBA,
	   SUM(CommRB) AS CommRB,
	   SUM(PlayerComm) AS PlayerComm,
	   SUM(AmtDuetoBA) AS AmtDuetoBA,
	   SUM(AmtDuetoRB) AS AmtDuetoRB,
	   SUM(Company) AS Company,
	   SUM(Betcount)	AS Betcount,
	  
	  
	    --BaseEUR  
	   CAST(SUM(TurnoverSB)*@eEUR    AS MONEY)     AS TurnoverSBEUR,   
	   CAST(SUM(TurnoverBA)*@eEUR    AS MONEY)     AS TurnoverBAEUR,   
	   CAST(SUM(TurnoverNG)*@eEUR    AS MONEY)     AS TurnoverNGEUR,   
	   CAST(SUM(TurnoverRB)*@eEUR    AS MONEY)     AS TurnoverRBEUR,
	   CAST(SUM(TurnoverLC)*@eEUR    AS MONEY)     AS TurnoverLCEUR,
	   CAST(SUM(TurnoverVS)*@eEUR    AS MONEY)     AS TurnoverVSEUR,  
	   CAST(SUM(TurnoverCS)*@eEUR    AS MONEY)     AS TurnoverCSEUR,
	   CAST(SUM(TurnoverBG)*@eEUR    AS MONEY)     AS TurnoverBGEUR,
	   CAST(SUM(TurnoverKN)*@eEUR    AS MONEY)     AS TurnoverKNEUR,
	   CAST(SUM(Winlost)*@eEUR	     AS MONEY)   AS WinlostEUR,  
	   CAST(SUM(LicenseeWLSB)*@eEUR  AS MONEY)   AS LicenseeWLSBEUR,
	   CAST(SUM(LicenseeWLBA)*@eEUR  AS MONEY)   AS LicenseeWLBAEUR,
	   CAST(SUM(LicenseeWLNG)*@eEUR  AS MONEY)   AS LicenseeWLNGEUR,
	   CAST(SUM(LicenseeWLRB)*@eEUR  AS MONEY)   AS LicenseeWLRBEUR,
	   CAST(SUM(LicenseeWLLC)*@eEUR  AS MONEY)   AS LicenseeWLLCEUR,
	   CAST(SUM(LicenseeWLVS)*@eEUR  AS MONEY)   AS LicenseeWLVSEUR,
	   CAST(SUM(LicenseeWLCS)*@eEUR  AS MONEY)   AS LicenseeWLCSEUR,
	   CAST(SUM(LicenseeWLBG)*@eEUR  AS MONEY)   AS LicenseeWLBGEUR,
	   CAST(SUM(LicenseeWLKN)*@eEUR  AS MONEY)   AS LicenseeWLKNEUR,
	   CAST(SUM(CommBA)*@eEUR      AS MONEY)   AS CommBAEUR,
	   CAST(SUM(CommRB)*@eEUR      AS MONEY)   AS CommRBEUR,
	   CAST(SUM(PlayerComm)*@eEUR  AS MONEY)   AS PlayerCommEUR,
	   CAST(SUM(AmtDuetoBA)*@eEUR    AS MONEY)   AS AmtDuetoBAEUR,
	   CAST(SUM(AmtDuetoRB)*@eEUR    AS MONEY)   AS AmtDuetoRBEUR,
	   CAST(SUM(Company)*@eEUR     AS MONEY)   AS CompanyEUR,
	    --BaseUSD  
	   CAST(SUM(TurnoverSB)*@eUSD    AS MONEY)     AS TurnoverSBUSD,   
	   CAST(SUM(TurnoverBA)*@eUSD    AS MONEY)     AS TurnoverBAUSD,   
	   CAST(SUM(TurnoverNG)*@eUSD    AS MONEY)     AS TurnoverNGUSD,   
	   CAST(SUM(TurnoverRB)*@eUSD    AS MONEY)     AS TurnoverRBUSD,
	   CAST(SUM(TurnoverLC)*@eUSD    AS MONEY)     AS TurnoverLCUSD,
	   CAST(SUM(TurnoverVS)*@eUSD    AS MONEY)     AS TurnoverVSUSD,  
	   CAST(SUM(TurnoverCS)*@eUSD    AS MONEY)     AS TurnoverCSUSD,
	   CAST(SUM(TurnoverBG)*@eUSD    AS MONEY)     AS TurnoverBGUSD,
	   CAST(SUM(TurnoverKN)*@eUSD    AS MONEY)     AS TurnoverKNUSD,
	   CAST(SUM(Winlost)*@eUSD	     AS MONEY)   AS WinlostUSD,  
	   CAST(SUM(LicenseeWLSB)*@eUSD  AS MONEY)   AS LicenseeWLSBUSD,
	   CAST(SUM(LicenseeWLBA)*@eUSD  AS MONEY)   AS LicenseeWLBAUSD,
	   CAST(SUM(LicenseeWLNG)*@eUSD  AS MONEY)   AS LicenseeWLNGUSD,
	   CAST(SUM(LicenseeWLRB)*@eUSD  AS MONEY)   AS LicenseeWLRBUSD,
	   CAST(SUM(LicenseeWLLC)*@eUSD  AS MONEY)   AS LicenseeWLLCUSD,
	   CAST(SUM(LicenseeWLVS)*@eUSD  AS MONEY)   AS LicenseeWLVSUSD,
	   CAST(SUM(LicenseeWLCS)*@eUSD  AS MONEY)   AS LicenseeWLCSUSD,
	   CAST(SUM(LicenseeWLBG)*@eUSD  AS MONEY)   AS LicenseeWLBGUSD,
	   CAST(SUM(LicenseeWLKN)*@eUSD  AS MONEY)   AS LicenseeWLKNUSD,
	   CAST(SUM(CommBA)*@eUSD      AS MONEY)   AS CommBAUSD,
	   CAST(SUM(CommRB)*@eUSD      AS MONEY)   AS CommRBUSD,
	   CAST(SUM(PlayerComm)*@eUSD  AS MONEY)   AS PlayerCommUSD,
	   CAST(SUM(AmtDuetoBA)*@eUSD    AS MONEY)   AS AmtDuetoBAUSD,
	   CAST(SUM(AmtDuetoRB)*@eUSD    AS MONEY)   AS AmtDuetoRBUSD,
	   CAST(SUM(Company)*@eUSD     AS MONEY)   AS CompanyUSD      
 FROM	#SAgWinLoss w   
		INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid		
 GROUP BY w.custid, c.username,c.username2,w.currency
  


DROP TABLE #SAgWinLoss
 
END   

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LicWinlossDetail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LicWinlossDetail] TO [vnteam]  