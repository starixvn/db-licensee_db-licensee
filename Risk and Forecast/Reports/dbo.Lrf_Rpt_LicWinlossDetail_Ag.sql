USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinlossDetail_Ag]   
 @LicenseeID	INT,
 @UserID		INT,
 @CurrencyID	INT = 0, 
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,    
 @showSB		BIT=0,  
 @ShowRB		BIT=0,  
 @ShowNG		BIT=0, 
 @ShowBA		BIT=0,
 @ShowLC		BIT=0,
 @ShowVS		BIT=0,	
 @ShowCS		BIT=0, -- RNG Casino
 @ShowBG		BIT=0, -- Bingo 
 @ShowKN		BIT=0, -- keno
 @ShowMGC 		BIT=0,-- MicroGamming
 @ShowBT 		BIT=0,-- licenseeWLBT
 @ShowAGC		BIT=0,-- AGCasino
 @MoveBetsDay SMALLDATETIME,
 @IsOld BIT = 0,
 @drawfilter SMALLINT = 1,
 @excludeTest BIT = 0
AS  
/*  Created: Henry  
	Date: 2012-01-09  
    Task : Winloss Report for Licensee Agent Level
    DB: DB052.bodb02  
   
    Revisions:  
		 -20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
		 -20120528@Henry: enhance performance
		 -20120725@Jim: add playercomm value
		 -20120814@Jim: add ShowLiveCasino + Virtual Sport
		 -20121004@Jim: replace @currency input param by @currencyID
		 -20121115@Henry: Only Sportsbook needs to exclude BA
		 - 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130204@Jim: support RNG Casino and Bingo product
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: offer Virtual Horse Racing
		- 20131007@Jim: offer Virtual Tennis
		- 20140305@Florent: support Keno
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150123@Jim: support base on Currency GBP
		- 20150612@Jim: support MicroGaming
		- 20150624@Winnie: support licenseeWLBT
		- 20150709@Jim: fix bug #39374 
		- 20150910@Jim: Integrate Microgaming RNG games (feature #43078)
		- 20150921@Jim: Implement the changes on reports for AG Casino (#43172)
	Param's Explanation:  
	  + @CustID: SuperID  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss, 1 - query in table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  +	@ShowLC: Show Live Casino
	  + @MoveBetsDay: The day we move tickets to bettrans14
  
*/  
BEGIN  
SET NOCOUNT ON  

CREATE TABLE #SAgWinLoss (  
	winlostdate		DATETIME,  
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
	TurnoverMGC		MONEY,
	Winlost			MONEY,
	--LicenseeWL		MONEY, --Sportbook and NumberGame
	LicenseeWLSB	MONEY,
	LicenseeWLBA	MONEY,
	LicenseeWLNG    MONEY,
	LicenseeWLRB	MONEY,
	LicenseeWLLC	MONEY,
	LicenseeWLVS	MONEY,
	LicenseeWLCS	MONEY,
	LicenseeWLBG	MONEY,
	LicenseeWLKN	MONEY,
	LicenseeWLMGC	MONEY,
	--WinlossRB		MONEY,  
	AmtDueToBA		MONEY,   
	AmtDueToRB		MONEY,
	CommBA			MONEY,   
	CommRB			MONEY,
	PlayerComm   	MONEY,   
	--Company			MONEY,
	Betcount		BIGINT,
	licenseeWLBT		MONEY,   
	BetTradeComm	MONEY,  
	WLBetTicket		MONEY, 	
	WLBoughtTicket	MONEY
)  


DECLARE @TempAg	TABLE( custID INT,currency INT)  
DECLARE @LicenseeName VARCHAR(50)
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @VNDCurrencyName VARCHAR(20)

SELECT @VNDCurrencyName = currency FROM exchange (NOLOCK) WHERE ExchangeId = 51 

SELECT @LicenseeName = LicenseeName FROM bodb_Licensee.dbo.Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
  
INSERT INTO @TempAg (custID,currency) 
SELECT lc.custID,lc.currency 
FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
WHERE 
	 (@excludeTest=0 OR (@excludeTest=1 AND lc.Currency <> 20))	
/*  
DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency
FROM Dep_CustSuper dc WITH (NOLOCK)  
INNER JOIN #Currency c ON dc.Currency=c.CurrencyID 
WHERE  site = @LicenseeName	  
*/
-----------------------------
DROP TABLE #Currency
-----------------------------  
IF @ShowSB = 1  
BEGIN  
	INSERT  INTO @sporttype( sporttype)
    VALUES  (0)	
	
END  

IF @ShowRB = 1  
BEGIN  
	INSERT  INTO @sporttype( Sporttype)
    VALUES  (151)
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
IF @ShowMGC=1 -- MicroGamming
BEGIN 
	INSERT INTO @sporttype (sporttype)
	VALUES(203)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 2001 AND 2099)
END 
IF  @ShowAGC=1 -- AGCasino
BEGIN
	INSERT INTO @sporttype (sporttype)
	VALUES(250)

	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1800 AND 1899)
END

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @FDate DATETIME 
DECLARE @TDate DATETIME 
--to Deal With Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 
  
IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate

	IF @ShowBA = 1
	BEGIN
	INSERT INTO #SAgWinLoss  
	SELECT   
		b.winlostdate,  
		b.recommend,
		tma.currency, 
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
			0 AS tunroverCS,
			0 AS tunroverBG,
			0 AS tunroverKN,
			0 AS tunroverMGC,
		SUM(b.winlost - b.actual_stake) AS Winlost,  
		--0 AS LicenseeWL,
		0 AS LicenseeWLSB,
		0 AS LicenseeWLBA,
		0 AS LicenseeWLNG,
		0 AS LicenseeWLRB,
		0 AS LicenseeWLLC,
		0 AS LicenseeWLVS,
		0 AS LicenseeWLCS,
		0 AS LicenseeWLBG,
		0 AS LicenseeWLKN,
		0 AS LicenseeWLMGC,
		--0 AS WinlossRB,
		- SUM (b.winlost - b.actual_stake + awinlost + comm ) AS AmountDueToBA,
		0 AS AmountDueToRB,
		SUM (comm ) AS CommBA,
		0 AS CommRB,
		CASE WHEN b.StatusID=111 THEN 0 ELSE SUM (playercomm) END  AS PlayerComm,
		--0 AS Company,
		COUNT(b.transid)  
		* CASE WHEN @drawfilter = 2 THEN
				CASE WHEN b.statusID = 111 THEN 0
				ELSE 1 END
			ELSE 1 END
		   BetCount,
		0 AS licenseeWLBT,
		0 AS BetTradeComm,			
		SUM(CASE WHEN b.betdaqid =0 THEN (b.winlost-b.actual_stake)
			ELSE 0 END) AS WLBetTicket,
		0 AS WLBoughtTicket

	FROM 
		dbo.bettrans b WITH ( NOLOCK) 
		INNER JOIN @TempAg tma ON tma.CustID=b.recommend AND tma.currency = b.currency
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON tma.custid=BA.recommend and b.transid = BA.transid 	 	
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @TDate   
		AND b.bettype NOT IN (901,902,903)
		AND b.statusID  IN (111, 112, 113) 
	GROUP BY   
		b.winlostdate,tma.currency,b.recommend,b.statusID	
	END	
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			b.recommend,
			a.currency, 
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
			0 tunroverBG,
			0 tunroverKN,
			0 tunroverMGC,
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			-- - SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			- SUM (b.winlost - b.actual_stake)  AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			0 AS LicenseeWLMGC,
			--0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			SUM(b.playercomm) AS PlayerComm,
			-- - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company  ,
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,			
			SUM(CASE WHEN b.betdaqid =0 THEN (b.winlost-b.actual_stake)
				ELSE 0 END) AS WLBetTicket,
			0 AS WLBoughtTicket
		FROM 
			dbo.bettrans b WITH ( NOLOCK) 
			INNER JOIN @TempAg a ON b.recommend = a.custid AND a.currency = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) 
			AND b.bettype NOT IN (901,902,903)
			AND
			b.statusID  IN (111, 112, 113) AND
			b.tpositiontaking <>0

		GROUP BY   
			b.winlostdate,a.currency,b.recommend, b.statusID	
	END
	
	IF (@ShowBT=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			b.recommend,
			a.currency, 
			0 turnoverSB, 
			0 AS turnoverBA,
			0 turnoverNG, 
			0 AS turnoverRB,
			0 turnoverLC, 
			0 turnoverVS, 
			0 turnoverCS,
			0 tunroverBG,
			0 tunroverKN,
			0 tunroverMGC,
			SUM(CASE WHEN b.bettype =903 THEN 0
			ELSE (b.winlost-b.actual_stake) END) AS Winlost,  
			-- - SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			0  AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			0 AS LicenseeWLMGC,
			--0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			0 AS PlayerComm,
			-- - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company  ,
			COUNT(CASE WHEN b.bettype = 903 THEN NULL	
			ELSE b.transid END)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount,
			-SUM(CASE WHEN b.bettype IN (901,902) THEN (b.winlost-b.actual_stake)
				ELSE 0 END) AS licenseeWLBT,
			SUM(CASE WHEN b.bettype =903 THEN b.awinlost
				ELSE 0 END) AS BetTradeComm,
			0 WLBetTicket,
			SUM(CASE WHEN b.bettype =902 THEN (b.winlost-b.actual_stake)
				ELSE 0 END) AS WLBoughtTicket
		FROM 
			dbo.bettrans b WITH ( NOLOCK) 
			INNER JOIN @TempAg a ON b.recommend = a.custid AND a.currency = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate   			
			AND b.bettype IN (901,902,903)
		GROUP BY   
			b.winlostdate,a.currency,b.recommend, b.statusID
				
	END

	IF (@ShowNG=1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1 OR @ShowMGC=1 OR @ShowAGC=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			b.recommend,
			a.currency, 
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
			0 AS turnoverRB,
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
			CASE WHEN b.bettype  BETWEEN 1501 AND 1599 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverKN,
			SUM(
			CASE WHEN b.bettype  BETWEEN 2001 AND 2099 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			ELSE 0 END	
			) turnoverMGC,
			
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			-- - SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			0  AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			- SUM(CASE WHEN b.bettype BETWEEN 81 AND 120 THEN (b.winlost-b.actual_stake) ELSE 0 END ) AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			-SUM(CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN (b.winlost-b.actual_stake) ELSE 0 END ) AS LicenseeWLLC,
			-SUM(CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN (b.winlost-b.actual_stake) ELSE 0 END ) AS LicenseeWLVS,
			-SUM(CASE WHEN b.bettype =71 THEN b.winlost - b.actual_stake ELSE 0 END)					AS LicenseeWLCS,
			-SUM(CASE WHEN b.bettype =73 THEN b.winlost - b.actual_stake ELSE 0 END)					AS LicenseeWLBG,
			-SUM(CASE WHEN b.bettype BETWEEN 1501 AND 1599  THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWLKN,
			-SUM(CASE WHEN b.bettype BETWEEN 2001 AND 2099  THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWLMGC,
			--0 AS WinlossRB,
			0 AS AmountDueToBA,
			0 AS AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			SUM(b.playercomm) AS PlayerComm,
			-- - SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company  ,
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,	
			0 AS WLBetTicket,
			0 AS WLBoughtTicket
		FROM 
			dbo.bettrans b WITH ( NOLOCK) 
			INNER JOIN @TempAg a ON b.recommend = a.custid AND b.currency = a.currency
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.winlostdate,a.currency,b.recommend, b.statusID		
	END
	
	
	
    IF @ShowRB = 1
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT   
			b.winlostdate,  
			b.recommend,
			a.currency, 
			0 AS turnoverSB,
			0 AS turnoverBA,
			0 AS turnoverNG,
			SUM(CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			) turnoverRB, 
			0 as turnoverLC,
			0 as turnoverVS,
			0 as turnoverCS,
			0 as turnoverBG,
			0 as turnoverKN,
			0 as turnoverMGC,
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			--0 AS LicenseeWL,
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			SUM (b.awinlost) AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			0 AS LicenseeWLMGC,
			--SUM (b.awinlost) AS WinlossRB,
			0 AS AmountDueToBA,
			- SUM (b.winlost - b.actual_stake + awinlost + comm) AS AmountDueToRB,
			0 AS CommBA,
			SUM (comm ) AS CommRB,
			CASE WHEN b.StatusID=111 THEN 0 ELSE SUM ( playercomm) END  AS PlayerComm,
			--0 AS Company,
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,	
			0 AS WLBetTicket,
			0 AS WLBoughtTicket
		FROM 
			dbo.bettrans b WITH ( NOLOCK) 
			INNER JOIN @TempAg a ON b.recommend = a.custid AND a.currency = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(bettype BETWEEN 31 AND 33) AND
			b.statusID IN (111, 112, 113) 
		GROUP BY   
			b.winlostdate,a.currency,b.recommend, b.statusID
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
			b.winlostdate,  
			b.recommend,
			b.currency,
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
			0 AS turnoverMGC,
			SUM(b.winlost),  
			--0 AS LicenseeWL,
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			0 AS LicenseeWLMGC,
			--0 AS WinlossRB,
			- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
			0 AS AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			CASE WHEN b.StatusID IN (112,113) THEN SUM ( playercomm) ELSE 0 END  AS PlayerComm,
			--0 AS Company,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,	
			SUM(CASE WHEN bt.CustId IS NOT NULL THEN b.winlost
			ELSE 0 END) AS WLBetTicket,
			0 AS WLBoughtTicket
		FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @TempAg a ON b.recommend = a.custID AND b.Currency = a.currency
			LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid=bt.Custid AND b.Currency = bt.currency
		WHERE  
			 b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.bettype NOT IN (901,902,903)
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.winlostdate,b.currency, b.recommend  , b.statusID
	END
	
	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 or @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1 OR @ShowMGC=1 OR @ShowAGC=1)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.recommend,
			b.currency,
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
			SUM(CASE WHEN b.sporttype=180 THEN 
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
			SUM(CASE WHEN b.sporttype=203 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverMGC,
			
			SUM(b.winlost),  
			-- - SUM(CASE WHEN ( b.sporttype IN (0,161,162,180))  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM(CASE WHEN b.sporttype=0 THEN b.winlost ELSE 0 END) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END) AS LicenseeWLNG,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END) AS LicenseeWLLC,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END) AS LicenseeWLVS,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END) AS LicenseeWLCS,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END) AS LicenseeWLBG,
			- SUM(CASE WHEN b.sporttype=202 THEN b.winlost ELSE 0 END) AS LicenseeWLKN,
			- SUM(CASE WHEN b.sporttype=203 THEN b.winlost ELSE 0 END) AS LicenseeWLMGC,
			--SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 AS AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm  ELSE 0 END) AS CommRB,
			SUM ( CASE WHEN b.StatusID IN (112,113) THEN  playercomm ELSE 0 END) AS PlayerComm,
			-- - SUM(CASE WHEN b.sporttype <> 151 THEN b.swinlost + b.mwinlost + b.awinlost + b.winlost + b.scomm ELSE 0 END)  as Company   ,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,	
			SUM(CASE WHEN (bt.CustId IS NOT NULL) AND t.sporttype=0 THEN b.winlost
			ELSE 0 END) AS WLBetTicket,
			0 AS WLBoughtTicket
		FROM 
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @TempAg a ON b.recommend = a.custID AND b.Currency = a.currency
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid=bt.Custid AND b.Currency = bt.currency
		WHERE  
			 b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.bettype NOT IN (901,902,903)
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  b.winlostdate,b.currency, b.recommend, b.statusID
	END
	IF ( @ShowBT=1)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				b.recommend,
				b.currency,
				0 turnoverSB, 
				0 AS turnoverBA,
				0 turnoverNG, 
				0 AS turnoverRB,
				0 turnoverLC, 
				0 turnoverVS, 
				0 turnoverCS,
				0 tunroverBG,
				0 tunroverKN,
				0 turnoverMGC,
				SUM(CASE WHEN b.bettype =903 THEN 0
				ELSE b.winlost END) AS Winlost,  
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGC,			
				0 as AmountDueToBA,
				0 as AmountDueToRB,
				0 as CommBA,
				0 as CommRB,
				0 as PlayerComm,
				COUNT(CASE WHEN b.bettype = 903 THEN NULL	
					ELSE b.BetCount END)
				* CASE WHEN @drawfilter = 2  THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount,	
				-SUM(CASE WHEN b.bettype IN (901,902) THEN (b.winlost)
					ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN b.bettype =903 THEN b.awinlost
					ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN b.bettype =902 THEN (b.winlost)
					ELSE 0 END) AS WLBoughtTicket
			FROM 
				bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.bettype IN (901,902,903)			
				GROUP BY  b.winlostdate,b.currency, b.recommend, b.statusID
		END
	
	
			
 END 
 IF @IsOld = 1 
 BEGIN
	SELECT @MaxOldDate = max(winlostdate) FROM bodb_Licensee.dbo.rptLicWinloss_old (NOLOCK)
	IF @TDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @TDate
 
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.recommend,
			b.currency,
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
			0 AS turnoverMGC,
			SUM(b.winlost),  
			--0 AS LicenseeWL,
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			0 AS LicenseeWLKN,
			0 AS LicenseeWLMGC,
			--0 AS WinlossRB,
			- SUM (b.winlost+b.awinlost+b.comm) AS AmountDueToBA,
			0 AS AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			CASE WHEN b.StatusID IN (112,113) THEN SUM ( playercomm) ELSE 0 END  AS PlayerComm,
			--0 AS Company,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,	
			SUM(CASE WHEN bt.CustId IS NOT NULL THEN b.winlost
			ELSE 0 END) AS WLBetTicket,
			0 AS WLBoughtTicket
		FROM 
			bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @TempAg a ON b.recommend = a.custID AND b.Currency = a.currency
			LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid=bt.Custid AND b.Currency = bt.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.bettype NOT IN (901,902,903)
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.winlostdate,b.currency, b.recommend, b.statusID
	END
 
	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1 OR @ShowKN=1 OR @ShowMGC=1 OR @ShowAGC=1)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.recommend,
			b.currency,
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
			SUM(CASE WHEN b.sporttype=180 THEN 
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
			SUM(CASE WHEN b.sporttype=203 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
			ELSE 0 END) AS turnoverMGC,
			SUM(b.winlost),  
			- SUM(CASE WHEN b.sporttype=0 THEN b.winlost ELSE 0 END) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END) AS LicenseeWLNG,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END) AS LicenseeWLLC,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END) AS LicenseeWLVS,
			-SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END) AS LicenseeWLCS,
			-SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END) AS LicenseeWLBG,
			-SUM(CASE WHEN b.sporttype=202 THEN b.winlost ELSE 0 END) AS LicenseeWLKN,
			-SUM(CASE WHEN b.sporttype=203 THEN b.winlost ELSE 0 END) AS LicenseeWLMGC,
			0 AS AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) AS AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm  ELSE 0 END) AS CommRB,
			SUM ( CASE WHEN b.StatusID IN (112,113) THEN  playercomm ELSE 0 END) AS PlayerComm,
			-- - SUM(CASE WHEN b.sporttype <> 151 THEN b.swinlost + b.mwinlost + b.awinlost + b.winlost + b.scomm ELSE 0 END)  as Company   ,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END,
			0 AS licenseeWLBT,
			0 AS BetTradeComm,	
			SUM(CASE WHEN (bt.CustId IS NOT NULL) AND t.sporttype=0 THEN b.winlost
			ELSE 0 END) AS WLBetTicket,
			0 AS WLBoughtTicket
		FROM bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg a ON b.recommend = a.custID AND b.Currency = a.currency
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN f_GetBetTradeCustList(@LicenseeName) bt ON b.custid=bt.Custid AND b.Currency = bt.currency
		WHERE  
			  b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.bettype NOT IN (901,902,903)
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  b.winlostdate,b.currency, b.recommend, b.statusID
	END
	
		IF ( @ShowBT=1)
		BEGIN
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,  
				b.recommend,
				b.currency,
				0 turnoverSB, 
				0 AS turnoverBA,
				0 turnoverNG, 
				0 AS turnoverRB,
				0 turnoverLC, 
				0 turnoverVS, 
				0 turnoverCS,
				0 tunroverBG,
				0 tunroverKN,
				0 turnoverMGC,
				SUM(CASE WHEN b.bettype =903 THEN 0
				ELSE b.winlost END) AS Winlost,    
				0 AS LicenseeWLSB,
				0 AS LicenseeWLBA,
				0 AS LicenseeWLNG,
				0 AS LicenseeWLRB,
				0 AS LicenseeWLLC,
				0 AS LicenseeWLVS,
				0 AS LicenseeWLCS,
				0 AS LicenseeWLBG,
				0 AS LicenseeWLKN,
				0 AS LicenseeWLMGC,			
				0 as AmountDueToBA,
				0 as AmountDueToRB,
				0 as CommBA,
				0 as CommRB,
				0 as PlayerComm,
				COUNT(CASE WHEN b.bettype = 903 THEN NULL	
					ELSE b.BetCount END)
				* CASE WHEN @drawfilter = 2  THEN
						CASE WHEN b.statusID = 111 THEN 0
						ELSE 1 END
					ELSE 1 END
				   BetCount,	
				-SUM(CASE WHEN b.bettype IN (901,902) THEN (b.winlost)
					ELSE 0 END) AS licenseeWLBT,
				SUM(CASE WHEN b.bettype =903 THEN b.awinlost
					ELSE 0 END) AS BetTradeComm,
				0 WLBetTicket,
				SUM(CASE WHEN b.bettype =902 THEN (b.winlost)
					ELSE 0 END) AS WLBoughtTicket
			FROM 
				bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND ag.currency = b.Currency
			
			WHERE 
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND b.bettype IN (901,902,903)			
				GROUP BY  b.winlostdate,b.currency, b.recommend, b.statusID
		END
 END
 
CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)
 
 SELECT   
	   c.username,  
	   w.custid, 
	   w.currency,
	   CASE WHEN w.Currency = 51 THEN @VNDCurrencyName 
				ELSE e.Code END AS CurrencyName,
	   SUM(TurnoverSB)       AS TurnoverSB,   
	   SUM(TurnoverBA)       AS TurnoverBA,   
	   SUM(TurnoverNG)       AS TurnoverNG,   
	   SUM(TurnoverRB)       AS TurnoverRB,   
	   SUM(TurnoverLC)       AS TurnoverLC,   
	   SUM(TurnoverVS)       AS TurnoverVS, 
	   SUM(TurnoverCS)       AS TurnoverCS,
	   SUM(TurnoverBG)       AS TurnoverBG,	   
	   SUM(TurnoverKN)       AS TurnoverKN,	
	   SUM(TurnoverMGC)       AS TurnoverMGC,	
	   SUM(Winlost)		 AS Winlost,  
	   --SUM(LicenseeWL)   AS LicenseeWL,
	   SUM(LicenseeWLSB) AS LicenseeWLSB,
	   SUM(LicenseeWLBA) AS LicenseeWLBA,
	   SUM(LicenseeWLNG) AS LicenseeWLNG,
	   SUM(LicenseeWLRB) AS LicenseeWLRB,
	   SUM(LicenseeWLLC) AS LicenseeWLLC,
	   SUM(LicenseeWLVS) AS LicenseeWLVS,
	   SUM(LicenseeWLCS) AS LicenseeWLCS,
	   SUM(LicenseeWLBG) AS LicenseeWLBG,
	   SUM(LicenseeWLKN) AS LicenseeWLKN,
	   SUM(LicenseeWLMGC) AS LicenseeWLMGC, 
	   --SUM(WinlossRB)	AS WinlossRB,
	   SUM(CommBA) AS CommBA,
	   SUM(CommRB) AS CommRB,
	   SUM(playerComm)AS PlayerComm,
	   SUM(AmtDuetoBA) AS AmtDuetoBA,
	   SUM(AmtDuetoRB) AS AmtDuetoRB,
	   --SUM(Company) AS Company,
	   SUM(Betcount)	AS Betcount,
	   SUM(licenseeWLBT)	   AS licenseeWLBT,
	   SUM(BetTradeComm)   AS BetTradeComm,
	   SUM(WLBetTicket+WLBoughtTicket-BetTradeComm)	   AS AmtDueToBT,
	   --BaseRM  
	   /*CAST(SUM(TurnoverSB*e.MYR)    AS MONEY)     AS TurnoverSBMYR,   
	   CAST(SUM(TurnoverBA*e.MYR)    AS MONEY)     AS TurnoverBAMYR,   
	   CAST(SUM(TurnoverNG*e.MYR)    AS MONEY)     AS TurnoverNGMYR,   
	   CAST(SUM(TurnoverRB*e.MYR)    AS MONEY)     AS TurnoverRBMYR,
	   CAST(SUM(TurnoverLC*e.MYR)    AS MONEY)     AS TurnoverLCMYR,
	   CAST(SUM(TurnoverVS*e.MYR)    AS MONEY)     AS TurnoverVSMYR,  
	   CAST(SUM(TurnoverCS*e.MYR)    AS MONEY)     AS TurnoverCSMYR,
	   CAST(SUM(TurnoverBG*e.MYR)    AS MONEY)     AS TurnoverBGMYR,
	   CAST(SUM(TurnoverKN*e.MYR)    AS MONEY)     AS TurnoverKNMYR,
	   CAST(SUM(TurnoverMGC*e.MYR)    AS MONEY)     AS TurnoverMGCMYR,
	   CAST(SUM(Winlost*e.MYR)	     AS MONEY)          AS WinlostMYR,  
	   --CAST(SUM(LicenseeWL*e.MYR)    AS MONEY)          AS LicenseeWLMYR,
	   CAST(SUM(LicenseeWLSB*e.MYR)  AS MONEY)          AS LicenseeWLSBMYR,
	   CAST(SUM(LicenseeWLBA*e.MYR)  AS MONEY)      	AS LicenseeWLBAMYR,
	   CAST(SUM(LicenseeWLNG*e.MYR)  AS MONEY)			AS LicenseeWLNGMYR,
	   CAST(SUM(LicenseeWLRB*e.MYR)  AS MONEY)			AS LicenseeWLRBMYR,
	   CAST(SUM(LicenseeWLLC*e.MYR)  AS MONEY)          AS LicenseeWLLCMYR,
	   CAST(SUM(LicenseeWLVS*e.MYR)  AS MONEY)          AS LicenseeWLVSMYR,
	   CAST(SUM(LicenseeWLCS*e.MYR)AS MONEY)    		AS LicenseeWLCSMYR,
	   CAST(SUM(LicenseeWLBG*e.MYR)AS MONEY)     		AS LicenseeWLBGMYR,
	   CAST(SUM(LicenseeWLKN*e.MYR)AS MONEY)     		AS LicenseeWLKNMYR,
	   CAST(SUM(LicenseeWLMGC*e.MYR)AS MONEY)     		AS LicenseeWLMGCMYR,
	   --CAST(SUM(WinlossRB*e.MYR)	 AS MONEY)          AS WinlossRBMYR,
	   CAST(SUM(CommBA * e.MYR)      AS MONEY)          AS CommBAMYR,
	   CAST(SUM(CommRB * e.MYR)      AS MONEY)          AS CommRBMYR,
	   CAST(SUM(PlayerComm*e.MYR)    AS MONEY)          AS PlayerCommMYR,
	   CAST(SUM(AmtDuetoBA*e.MYR)    AS MONEY)          AS AmtDuetoBAMYR,
	   CAST(SUM(AmtDuetoRB*e.MYR)    AS MONEY)          AS AmtDuetoRBMYR,
	   --CAST(SUM(Company * e.MYR)     AS MONEY)          AS CompanyMYR,*/

	   --BaseUSD  
	   CAST(SUM(TurnoverSB*e.USD)    AS MONEY)     AS TurnoverSBUSD,   
	   CAST(SUM(TurnoverBA*e.USD)    AS MONEY)     AS TurnoverBAUSD,   
	   CAST(SUM(TurnoverNG*e.USD)    AS MONEY)     AS TurnoverNGUSD,   
	   CAST(SUM(TurnoverRB*e.USD)    AS MONEY)     AS TurnoverRBUSD,
	   CAST(SUM(TurnoverLC*e.USD)    AS MONEY)     AS TurnoverLCUSD,
	   CAST(SUM(TurnoverVS*e.USD)    AS MONEY)     AS TurnoverVSUSD,
	   CAST(SUM(TurnoverCS*e.USD)    AS MONEY)     AS TurnoverCSUSD,
	   CAST(SUM(TurnoverBG*e.USD)    AS MONEY)     AS TurnoverBGUSD,
	   CAST(SUM(TurnoverKN*e.USD)    AS MONEY)     AS TurnoverKNUSD,
	   CAST(SUM(TurnoverMGC*e.USD)    AS MONEY)     AS TurnoverMGCUSD,
	   CAST(SUM(Winlost*e.USD)	     AS MONEY)          AS WinlostUSD,  
	   --CAST(SUM(LicenseeWL*e.USD)    AS MONEY)          AS LicenseeWLUSD,
	   CAST(SUM(LicenseeWLSB*e.USD)  AS MONEY)          AS LicenseeWLSBUSD,
	   CAST(SUM(LicenseeWLBA*e.USD)  AS MONEY)          AS LicenseeWLBAUSD,
	   CAST(SUM(LicenseeWLNG*e.USD)  AS MONEY)          AS LicenseeWLNGUSD,
	   CAST(SUM(LicenseeWLRB*e.USD)  AS MONEY)          AS LicenseeWLRBUSD,
	   CAST(SUM(LicenseeWLLC*e.USD)  AS MONEY)          AS LicenseeWLLCUSD,
	   CAST(SUM(LicenseeWLVS*e.USD)  AS MONEY)          AS LicenseeWLVSUSD,
	   CAST(SUM(LicenseeWLCS*e.USD)	AS MONEY)	 		AS LicenseeWLCSUSD,
	   CAST(SUM(LicenseeWLBG*e.USD)AS MONEY)	 		AS LicenseeWLBGUSD,
	   CAST(SUM(LicenseeWLKN*e.USD)AS MONEY)			AS LicenseeWLKNUSD,
	   CAST(SUM(LicenseeWLMGC*e.USD)AS MONEY)			AS LicenseeWLMGCUSD,
	   --CAST(SUM(WinlossRB*e.USD)	 AS MONEY)          AS WinlossRBUSD,
	   CAST(SUM(CommBA * e.USD)      AS MONEY)          AS CommBAUSD,
	   CAST(SUM(CommRB * e.USD)      AS MONEY)          AS CommRBUSD,
	   CAST(SUM(PlayerComm*e.USD)    AS MONEY)          AS PlayerCommUSD,
	   CAST(SUM(AmtDuetoBA*e.USD)    AS MONEY)          AS AmtDuetoBAUSD,
	   CAST(SUM(AmtDuetoRB*e.USD)    AS MONEY)          AS AmtDuetoRBUSD, 
	   --CAST(SUM(Company * e.USD)     AS MONEY)          AS CompanyUSD,
	   CAST(SUM(licenseeWLBT* e.USD)	 AS MONEY)	   AS licenseeWLBTUSD,
	   CAST(SUM(BetTradeComm* e.USD)  AS MONEY)  AS BetTradeCommUSD,
	   CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.USD)  AS MONEY)	  AS AmtDueToBTUSD,
	    --BaseEUR  
	   CAST(SUM(TurnoverSB*e.EUR)    AS MONEY)     AS TurnoverSBEUR,   
	   CAST(SUM(TurnoverBA*e.EUR)    AS MONEY)     AS TurnoverBAEUR,   
	   CAST(SUM(TurnoverNG*e.EUR)    AS MONEY)     AS TurnoverNGEUR,   
	   CAST(SUM(TurnoverRB*e.EUR)    AS MONEY)     AS TurnoverRBEUR,
	   CAST(SUM(TurnoverLC*e.EUR)    AS MONEY)     AS TurnoverLCEUR,
	   CAST(SUM(TurnoverVS*e.EUR)    AS MONEY)     AS TurnoverVSEUR, 
	   CAST(SUM(TurnoverCS*e.EUR)    AS MONEY)     AS TurnoverCSEUR,
	   CAST(SUM(TurnoverBG*e.EUR)    AS MONEY)     AS TurnoverBGEUR,
	   CAST(SUM(TurnoverKN*e.EUR)    AS MONEY)     AS TurnoverKNEUR,
	   CAST(SUM(TurnoverMGC*e.EUR)    AS MONEY)     AS TurnoverMGCEUR,
	   CAST(SUM(Winlost*e.EUR)	     AS MONEY)          AS WinlostEUR,  
	   --CAST(SUM(LicenseeWL*e.EUR)    AS MONEY)          AS LicenseeWLEUR,
	   CAST(SUM(LicenseeWLSB*e.EUR)  AS MONEY)			AS LicenseeWLSBEUR,
	   CAST(SUM(LicenseeWLBA*e.EUR)  AS MONEY)			AS LicenseeWLBAEUR,
	   CAST(SUM(LicenseeWLNG*e.EUR)  AS MONEY)			AS LicenseeWLNGEUR,
	   CAST(SUM(LicenseeWLRB*e.EUR)  AS MONEY)			AS LicenseeWLRBEUR,
	   CAST(SUM(LicenseeWLLC*e.EUR)  AS MONEY)          AS LicenseeWLLCEUR,
	   CAST(SUM(LicenseeWLVS*e.EUR)  AS MONEY)          AS LicenseeWLVSEUR,
	   CAST(SUM(LicenseeWLCS*e.EUR)AS MONEY)	 		AS LicenseeWLCSEUR,
	   CAST(SUM(LicenseeWLBG*e.EUR)AS MONEY)	 		AS LicenseeWLBGEUR,
	   CAST(SUM(LicenseeWLKN*e.EUR)AS MONEY)			AS LicenseeWLKNEUR,
	   CAST(SUM(LicenseeWLMGC*e.EUR)AS MONEY)	 		AS LicenseeWLMGCEUR,
	   --CAST(SUM(WinlossRB*e.EUR)	 AS MONEY)			AS WinlossRBEUR,
	   CAST(SUM(CommBA * e.EUR)      AS MONEY)			AS CommBAEUR,
	   CAST(SUM(CommRB * e.EUR)      AS MONEY)			AS CommRBEUR,
	   CAST(SUM(PlayerComm*e.EUR)    AS MONEY)			AS PlayerCommEUR,
	   CAST(SUM(AmtDuetoBA*e.EUR)    AS MONEY)			AS AmtDuetoBAEUR,
	   CAST(SUM(AmtDuetoRB*e.EUR)    AS MONEY)			AS AmtDuetoRBEUR,
	   --CAST(SUM(Company * e.EUR)     AS MONEY)			AS CompanyEUR,
	   CAST(SUM(licenseeWLBT* e.EUR)	 AS MONEY)	   AS licenseeWLBTEUR,
	   CAST(SUM(BetTradeComm* e.EUR)  AS MONEY)  AS BetTradeCommEUR,
	   CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.EUR)  AS MONEY)	  AS AmtDueToBTEUR,
	    --BaseGBP  
	   CAST(SUM(TurnoverSB*e.GBP)    AS MONEY)     AS TurnoverSBGBP,   
	   CAST(SUM(TurnoverBA*e.GBP)    AS MONEY)     AS TurnoverBAGBP,   
	   CAST(SUM(TurnoverNG*e.GBP)    AS MONEY)     AS TurnoverNGGBP,   
	   CAST(SUM(TurnoverRB*e.GBP)    AS MONEY)     AS TurnoverRBGBP,
	   CAST(SUM(TurnoverLC*e.GBP)    AS MONEY)     AS TurnoverLCGBP,
	   CAST(SUM(TurnoverVS*e.GBP)    AS MONEY)     AS TurnoverVSGBP, 
	   CAST(SUM(TurnoverCS*e.GBP)    AS MONEY)     AS TurnoverCSGBP,
	   CAST(SUM(TurnoverBG*e.GBP)    AS MONEY)     AS TurnoverBGGBP,
	   CAST(SUM(TurnoverKN*e.GBP)    AS MONEY)     AS TurnoverKNGBP,
	   CAST(SUM(TurnoverMGC*e.GBP)    AS MONEY)     AS TurnoverMGCGBP,
	   CAST(SUM(Winlost*e.GBP)	     AS MONEY)          AS WinlostGBP,  
	   --CAST(SUM(LicenseeWL*e.GBP)    AS MONEY)          AS LicenseeWLGBP,
	   CAST(SUM(LicenseeWLSB*e.GBP)  AS MONEY)			AS LicenseeWLSBGBP,
	   CAST(SUM(LicenseeWLBA*e.GBP)  AS MONEY)			AS LicenseeWLBAGBP,
	   CAST(SUM(LicenseeWLNG*e.GBP)  AS MONEY)			AS LicenseeWLNGGBP,
	   CAST(SUM(LicenseeWLRB*e.GBP)  AS MONEY)			AS LicenseeWLRBGBP,
	   CAST(SUM(LicenseeWLLC*e.GBP)  AS MONEY)          AS LicenseeWLLCGBP,
	   CAST(SUM(LicenseeWLVS*e.GBP)  AS MONEY)          AS LicenseeWLVSGBP,
	   CAST(SUM(LicenseeWLCS*e.GBP)AS MONEY)	 		AS LicenseeWLCSGBP,
	   CAST(SUM(LicenseeWLBG*e.GBP)AS MONEY)	 		AS LicenseeWLBGGBP,
	   CAST(SUM(LicenseeWLKN*e.GBP)AS MONEY)	 AS LicenseeWLKNGBP,
	   CAST(SUM(LicenseeWLMGC*e.GBP)AS MONEY)	 AS LicenseeWLMGCGBP,
	   --CAST(SUM(WinlossRB*e.GBP)	 AS MONEY)			AS WinlossRBGBP,
	   CAST(SUM(CommBA * e.GBP)      AS MONEY)			AS CommBAGBP,
	   CAST(SUM(CommRB * e.GBP)      AS MONEY)			AS CommRBGBP,
	   CAST(SUM(PlayerComm*e.GBP)    AS MONEY)			AS PlayerCommGBP,
	   CAST(SUM(AmtDuetoBA*e.GBP)    AS MONEY)			AS AmtDuetoBAGBP,
	   CAST(SUM(AmtDuetoRB*e.GBP)    AS MONEY)			AS AmtDuetoRBGBP,
	   --CAST(SUM(Company * e.GBP)     AS MONEY)			AS CompanyGBP
	   CAST(SUM(licenseeWLBT* e.GBP)	 AS MONEY)	   AS licenseeWLBTGBP,
	   CAST(SUM(BetTradeComm* e.GBP)  AS MONEY)  AS BetTradeCommGBP,
	   CAST(SUM((WLBetTicket+WLBoughtTicket-BetTradeComm)* e.GBP)  AS MONEY)	  AS AmtDueToBTGBP
	          
 FROM	#SAgWinLoss w   
		INNER JOIN #TempExchange e 
		ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
		INNER JOIN Customer c WITH(NOLOCK) ON w.custid = c.custid
  GROUP BY w.currency,w.custid, c.username, 
			CASE WHEN w.Currency = 51 THEN @VNDCurrencyName 
				ELSE e.Code END
  ORDER BY w.currency

DROP TABLE #SAgWinLoss
DROP TABLE #TempExchange

END 



GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LicWinlossDetail_Ag] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LicWinlossDetail_Ag] TO [vnteam] 