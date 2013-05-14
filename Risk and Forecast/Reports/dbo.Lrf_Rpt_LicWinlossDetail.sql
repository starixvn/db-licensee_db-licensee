set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


/*
exec Lrf_Rpt_LicWinlossDetail_xtest 
@licenseeid=1
,@currencyid=6
,@fromdate='2013-01-27 00:00:00:000'
,@todate='2013-01-27 00:00:00:000'
,@isold=0
,@drawfilter=1
,@excludetest=0
,@movebetsday='2013-01-28 00:00:00:000'
,@custid=791088,@showSB=1,@showNG=0,@showBA=0,@showLC=0,@showVS=0,@ShowCS=1,@ShowBG=1
*/
ALTER  PROCEDURE [dbo].[Lrf_Rpt_LicWinlossDetail]  
	@LicenseeID	INT,
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
	Winlost			MONEY,  
	LicenseeWLSB	MONEY,
	LicenseeWLBA	MONEY,
	LicenseeWLNG	MONEY,
	LicenseeWLRB	MONEY,
	LicenseeWLLC	MONEY,
	LicenseeWLVS	MONEY,
	LicenseeWLCS	MONEY,
	LicenseeWLBG	MONEY,
	AmtDueToBA		MONEY,   
	AmtDueToRB		MONEY,
	CommBA			MONEY,   
	CommRB			MONEY,
	PlayerComm  	MONEY,
	Company			MONEY,
	
	TurnoverSBEUR		MONEY,
	TurnoverBAEUR		MONEY,
	TurnoverNGEUR		MONEY,
	TurnoverRBEUR		MONEY,
	TurnoverLCEUR		MONEY,
	TurnoverVSEUR		MONEY,
	TurnoverCSEUR		MONEY,
	TurnoverBGEUR		MONEY,
	WinlostEUR			MONEY,  
	LicenseeWLSBEUR	MONEY,
	LicenseeWLBAEUR	MONEY,
	LicenseeWLNGEUR	MONEY,
	LicenseeWLRBEUR	MONEY,
	LicenseeWLLCEUR	MONEY,
	LicenseeWLVSEUR	MONEY,
	LicenseeWLCSEUR	MONEY,
	LicenseeWLBGEUR	MONEY,
	AmtDueToBAEUR		MONEY,   
	AmtDueToRBEUR		MONEY,
	CommBAEUR			MONEY,   
	CommRBEUR			MONEY,
	PlayerCommEUR  	MONEY,
	CompanyEUR			MONEY,
	--------------
	TurnoverSBUSD		MONEY,
	TurnoverBAUSD		MONEY,
	TurnoverNGUSD		MONEY,
	TurnoverRBUSD		MONEY,
	TurnoverLCUSD		MONEY,
	TurnoverVSUSD		MONEY,
	TurnoverCSUSD		MONEY,
	TurnoverBGUSD		MONEY,
	WinlostUSD			MONEY,  
	LicenseeWLSBUSD	MONEY,
	LicenseeWLBAUSD	MONEY,
	LicenseeWLNGUSD	MONEY,
	LicenseeWLRBUSD	MONEY,
	LicenseeWLLCUSD	MONEY,
	LicenseeWLVSUSD	MONEY,
	LicenseeWLCSUSD	MONEY,
	LicenseeWLBGUSD	MONEY,
	AmtDueToBAUSD		MONEY,   
	AmtDueToRBUSD		MONEY,
	CommBAUSD			MONEY,   
	CommRBUSD			MONEY,
	PlayerCommUSD  	MONEY,
	CompanyUSD			MONEY,
	---------------
	Betcount		BIGINT
)  


DECLARE @tempAg	TABLE( custID INT PRIMARY KEY, Currency INT)  
DECLARE @Code VARCHAR(20), @TempCurrencyID INT
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,MYR FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))



INSERT INTO @tempAg (custID,currency) 
SELECT custID,currency FROM bodb_Licensee.dbo.LicenseeCust (NOLOCK) 
WHERE 
	LicenseeID = @LicenseeID
	AND (@CustID=0 OR (@CustID<>0 AND CustiD=@CustID))
	AND (@CurrencyID = 0 OR (@CurrencyID<> 0 AND Currency=@CurrencyID))
	AND (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	
	

DECLARE @site VARCHAR(50)
SELECT @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency FROM Dep_CustSuper WITH (NOLOCK)  
WHERE  site = @site

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
    VALUES  (180)
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
			--b.winlostdate,  
			b.custid,
			s.currency, 
			
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
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			--0 as LicenseeWL,
			0 as LicenseeWLSB,
			0 as LicenseeWLBA,
			0 as LicenseeWLNG,
			0 as LicenseeWLRB,
			0 as LicenseeWLLC,
			0 as LicenseeWLVS,
			0 as LicenseeWLCS,
			0 as LicenseeWLBG,
			--0 as WinlossRB,
			- SUM (b.winlost - b.actual_stake + awinlost + comm ) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			SUM(playercomm)   AS PlayerComm,
			0 AS Company,
			
			0 AS turnoverSBEUR,
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverBAEUR, 
			0 AS turnoverNGEUR,
			0 AS turnoverRBEUR,
			0 AS turnoverLCEUR,
			0 AS turnoverVSEUR,
			0 AS turnoverCSEUR,
			0 AS turnoverBGEUR,
			SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
			--0 as LicenseeWL,
			0 as LicenseeWLSBEUR,
			0 as LicenseeWLBAEUR,
			0 as LicenseeWLNGEUR,
			0 as LicenseeWLRBEUR,
			0 as LicenseeWLLCEUR,
			0 as LicenseeWLVSEUR,
			0 as LicenseeWLCSEUR,
			0 as LicenseeWLBGEUR,
			--0 as WinlossRB,
			- SUM ((b.winlost - b.actual_stake + awinlost + comm )* e.EUR) as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			SUM (comm * e.EUR) AS CommBAEUR,
			0 AS CommRBEUR,
			SUM(playercomm*e.EUR)   AS PlayerCommEUR,
			0 AS CompanyEUR,
			--------------------------------
			0 AS turnoverSBUSD,
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverBAUSD, 
			0 AS turnoverNGUSD,
			0 AS turnoverRBUSD,
			0 AS turnoverLCUSD,
			0 AS turnoverVSUSD,
			0 AS turnoverCSUSD,
			0 AS turnoverBGUSD,
			SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
			--0 as LicenseeWL,
			0 as LicenseeWLSBUSD,
			0 as LicenseeWLBAUSD,
			0 as LicenseeWLNGUSD,
			0 as LicenseeWLRBUSD,
			0 as LicenseeWLLCUSD,
			0 as LicenseeWLVSUSD,
			0 as LicenseeWLCSUSD,
			0 as LicenseeWLBGUSD,
			--0 as WinlossRB,
			- SUM ((b.winlost - b.actual_stake + awinlost + comm )* e.USD) as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			SUM (comm * e.USD) AS CommBAUSD,
			0 AS CommRBUSD,
			SUM(playercomm*e.USD)   AS PlayerCommUSD,
			0 AS CompanyUSD,
			--------------------------------
			
			COUNT(b.transid) 
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM 
			dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend) 
			INNER JOIN @TempAg tma ON tma.CustID=b.recommend 
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON s.custid=BA.srecommend and b.transid = BA.transid 	 	
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID IN (111, 112, 113)
		GROUP BY   
			b.custid, s.currency,b.statusID
	END		

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			s.currency, 
			
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
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			-- -SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			-SUM(b.winlost-b.actual_stake ) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			--0 AS WinlossRB,
			0 as AmountDueToBA,
			0 as AmountDueToRB,
			0 AS CommBA,
			0 AS CommRB,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) Company  ,
			
			SUM(
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				*
				e.EUR
			) turnoverSBEUR, 
			0 AS turnoverBAEUR,
			0 turnoverNGEUR, 
			0 AS turnoverRBEUR,
			0 turnoverLCEUR, 
			0 turnoverVSEUR, 
			0 turnoverCSEUR, 
			0 turnoverBGEUR, 
			SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
			-- -SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			-SUM((b.winlost-b.actual_stake )* e.EUR) AS LicenseeWLSBEUR,
			0 AS LicenseeWLBAEUR,
			0 AS LicenseeWLNGEUR,
			0 AS LicenseeWLRBEUR,
			0 AS LicenseeWLLCEUR,
			0 AS LicenseeWLVSEUR,
			0 AS LicenseeWLCSEUR,
			0 AS LicenseeWLBGEUR,
			--0 AS WinlossRB,
			0 as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			0 AS CommBAEUR,
			0 AS CommRBEUR,
			SUM(b.playercomm * e.EUR) AS PlayerCommEUR,
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) CompanyEUR,
			----------------------------------------
			SUM(
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				*
				e.USD
			) turnoverSBUSD, 
			0 AS turnoverBAUSD,
			0 turnoverNGUSD, 
			0 AS turnoverRBUSD,
			0 turnoverLCUSD, 
			0 turnoverVSUSD, 
			0 turnoverCSUSD, 
			0 turnoverBGUSD, 
			SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
			-- -SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			-SUM((b.winlost-b.actual_stake )* e.USD) AS LicenseeWLSBUSD,
			0 AS LicenseeWLBAUSD,
			0 AS LicenseeWLNGUSD,
			0 AS LicenseeWLRBUSD,
			0 AS LicenseeWLLCUSD,
			0 AS LicenseeWLVSUSD,
			0 AS LicenseeWLCSUSD,
			0 AS LicenseeWLBGUSD,
			--0 AS WinlossRB,
			0 as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			0 AS CommBAUSD,
			0 AS CommRBUSD,
			SUM(b.playercomm * e.USD) AS PlayerCommUSD,
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) CompanyUSD,
			----------------------------------------
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM 	
			Bettrans b WITH ( NOLOCK)
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN @TempAg a ON b.recommend = a.custid
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = s.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.statusID  IN (111, 112, 113) AND
			b.tpositiontaking <>0
		GROUP BY   
			b.custid,s.currency,b.statusID
	END

	IF (@ShowNG=1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowRB=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			b.currency, 
			
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
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			-- -SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			-SUM(CASE WHEN (b.bettype BETWEEN 81 AND 120 ) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLNG,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN  b.awinlost ELSE 0 END) AS LicenseeWLRB,
			-SUM(CASE WHEN (b.bettype BETWEEN 1101 AND 1199) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLLC,
			-SUM(CASE WHEN (b.bettype BETWEEN 1201 AND 1299) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLVS,
			-SUM(CASE WHEN (b.bettype =71) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLCS,
			-SUM(CASE WHEN (b.bettype =73) THEN (b.winlost-b.actual_stake) ELSE 0 END) AS LicenseeWLBG,
			--0 AS WinlossRB,
			0 as AmountDueToBA,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END) as AmountDueToRB,
			0 AS CommBA,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END) AS CommRB,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.awinlost + b.winlost - b.actual_stake + b.comm ELSE 0 END) Company  ,
			
			--EUR
			0 turnoverSBEUR, 
			0 AS turnoverBAEUR,
			SUM(
			CASE WHEN b.bettype BETWEEN 81 AND 120 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.EUR
			ELSE 0 END	
			) turnoverNGEUR, 
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN 
					CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				ELSE 0 END	
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.EUR
			) turnoverRBEUR, 
			SUM(
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.EUR
			ELSE 0 END	
			) turnoverLCEUR, 
			SUM(
			CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.EUR
			ELSE 0 END	
			) turnoverVSEUR, 
			SUM(
			CASE WHEN b.bettype =71 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.EUR
			ELSE 0 END	
			) turnoverCSEUR,
			SUM(
			CASE WHEN b.bettype =73 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.EUR
			ELSE 0 END	
			) turnoverBGEUR,
			SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
			-- -SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			0 AS LicenseeWLSBEUR,
			0 AS LicenseeWLBAEUR,
			-SUM(CASE WHEN (b.bettype BETWEEN 81 AND 120 ) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.EUR ) AS LicenseeWLNGEUR,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN  b.awinlost ELSE 0 END * e.EUR) AS LicenseeWLRBEUR,
			-SUM(CASE WHEN (b.bettype BETWEEN 1101 AND 1199) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLLCEUR,
			-SUM(CASE WHEN (b.bettype BETWEEN 1201 AND 1299) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLVSEUR,
			-SUM(CASE WHEN (b.bettype =71) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLCSEUR,
			-SUM(CASE WHEN (b.bettype =73) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.EUR) AS LicenseeWLBGEUR,
			--0 AS WinlossRB,
			0 as AmountDueToBAEUR,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END * e.EUR) as AmountDueToRBEUR,
			0 AS CommBAEUR,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END * e.EUR) AS CommRBEUR,
			SUM(b.playercomm*e.EUR) AS PlayerCommEUR,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.awinlost + b.winlost - b.actual_stake + b.comm ELSE 0 END * e.EUR) CompanyEUR  ,
			----------------------------
			--USD
			0 turnoverSBUSD, 
			0 AS turnoverBAUSD,
			SUM(
			CASE WHEN b.bettype BETWEEN 81 AND 120 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.USD
			ELSE 0 END	
			) turnoverNGUSD, 
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN 
					CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				ELSE 0 END	
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.USD
			) turnoverRBUSD, 
			SUM(
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.USD
			ELSE 0 END	
			) turnoverLCUSD, 
			SUM(
			CASE WHEN b.bettype BETWEEN 1201 AND 1299 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.USD
			ELSE 0 END	
			) turnoverVSUSD, 
			SUM(
			CASE WHEN b.bettype =71 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.USD
			ELSE 0 END	
			) turnoverCSUSD,
			SUM(
			CASE WHEN b.bettype =73 THEN
				stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				*
				e.USD
			ELSE 0 END	
			) turnoverBGUSD,
			SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
			-- -SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			0 AS LicenseeWLSBUSD,
			0 AS LicenseeWLBAUSD,
			-SUM(CASE WHEN (b.bettype BETWEEN 81 AND 120 ) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.USD ) AS LicenseeWLNGUSD,
			SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN  b.awinlost ELSE 0 END * e.USD) AS LicenseeWLRBUSD,
			-SUM(CASE WHEN (b.bettype BETWEEN 1101 AND 1199) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLLCUSD,
			-SUM(CASE WHEN (b.bettype BETWEEN 1201 AND 1299) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLVSUSD,
			-SUM(CASE WHEN (b.bettype =71) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLCSUSD,
			-SUM(CASE WHEN (b.bettype =73) THEN (b.winlost-b.actual_stake) ELSE 0 END * e.USD) AS LicenseeWLBGUSD,
			--0 AS WinlossRB,
			0 as AmountDueToBAUSD,
			- SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.winlost - b.actual_stake + awinlost + comm ELSE 0 END * e.USD) as AmountDueToRBUSD,
			0 AS CommBAUSD,
			SUM (CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm ELSE 0 END * e.USD) AS CommRBUSD,
			SUM(b.playercomm*e.USD) AS PlayerCommUSD,
			- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN b.awinlost + b.winlost - b.actual_stake + b.comm ELSE 0 END * e.USD) CompanyUSD  ,
			--------------------------------
			
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount
		FROM 	
			Bettrans b WITH ( NOLOCK)
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN @TempAg a ON b.recommend = a.custid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = s.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.custid,b.currency,b.statusID
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
			SUM(b.winlost),  
			--0 as LicenseeWL,
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			--0 AS WinlossRB,
			- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			SUM(playercomm) AS PlayerComm,
			0 AS Company,
			
			--EUR
			0 AS turnoverSBEUR,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverBAEUR,     
			0 AS turnoverNGEUR,
			0 AS turnoverRBEUR,
			0 AS turnoverLCEUR,
			0 AS turnoverVSEUR,
			0 AS turnoverCSEUR,
			0 AS turnoverBGEUR,
			SUM(b.winlost*e.EUR) WinlostEUR,  
			--0 as LicenseeWL,
			0 AS LicenseeWLSBEUR,
			0 AS LicenseeWLBAEUR,
			0 AS LicenseeWLNGEUR,
			0 AS LicenseeWLRBEUR,
			0 AS LicenseeWLLCEUR,
			0 AS LicenseeWLVSEUR,
			0 AS LicenseeWLCSEUR,
			0 AS LicenseeWLBGEUR,
			--0 AS WinlossRB,
			- SUM ((b.winlost+b.awinlost+b.comm)* e.EUR) as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			SUM (comm * e.EUR) AS CommBAEUR,
			0 AS CommRBEUR,
			SUM(playercomm * e.EUR) AS PlayerCommEUR,
			0 AS CompanyEUR,
			-------------------------
			--USD
			0 AS turnoverSBUSD,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverBAUSD,     
			0 AS turnoverNGUSD,
			0 AS turnoverRBUSD,
			0 AS turnoverLCUSD,
			0 AS turnoverVSUSD,
			0 AS turnoverCSUSD,
			0 AS turnoverBGUSD,
			SUM(b.winlost*e.USD) WinlostUSD,  
			--0 as LicenseeWL,
			0 AS LicenseeWLSBUSD,
			0 AS LicenseeWLBAUSD,
			0 AS LicenseeWLNGUSD,
			0 AS LicenseeWLRBUSD,
			0 AS LicenseeWLLCUSD,
			0 AS LicenseeWLVSUSD,
			0 AS LicenseeWLCSUSD,
			0 AS LicenseeWLBGUSD,
			--0 AS WinlossRB,
			- SUM ((b.winlost+b.awinlost+b.comm)* e.USD) as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			SUM (comm * e.USD) AS CommBAUSD,
			0 AS CommRBUSD,
			SUM(playercomm * e.USD) AS PlayerCommUSD,
			0 AS CompanyUSD,
			-------------------------------
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.custid,b.currency, b.statusID
	END
	
	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
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
			SUM(b.winlost),  
			-- - SUM(CASE WHEN (b.sporttype IN (0,161,162,180))  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END ) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END ) AS LicenseeWLNG,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END ) AS LicenseeWLLC,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END ) AS LicenseeWLVS,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END ) AS LicenseeWLCS,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END ) AS LicenseeWLBG,
			--SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END) AS CommRB,
			SUM ( playercomm) AS PlayerComm,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END)  as Company   ,
			
			--EUR
			SUM(CASE WHEN b.sporttype=0 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR	
			ELSE 0 END) AS turnoverSBEUR,
			0 AS turnoverBAEUR,
			SUM(CASE WHEN b.sporttype=161 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR	
			ELSE 0 END) AS turnoverNGEUR,
			SUM(CASE WHEN b.sporttype=151 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END	
				* e.EUR	
			ELSE 0 END) AS turnoverRBEUR,
			SUM(CASE WHEN b.sporttype=162 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverLCEUR,
			SUM(CASE WHEN b.sporttype=180 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverVSEUR,
			SUM(CASE WHEN b.sporttype=251 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverCSEUR,
			SUM(CASE WHEN b.sporttype=252 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverBGEUR,
			SUM(b.winlost * e.EUR) winlostEUR,  
			-- - SUM(CASE WHEN (b.sporttype IN (0,161,162,180))  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLSBEUR,
			0 AS LicenseeWLBAEUR,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLNGEUR,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS LicenseeWLRBEUR,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLLCEUR,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLVSEUR,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLCSEUR,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLBGEUR,
			--SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBAEUR,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.EUR) as AmountDueToRBEUR,
			0 AS CommBAEUR,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END * e.EUR) AS CommRBEUR,
			SUM ( playercomm * e.EUR) AS PlayerCommEUR,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END * e.EUR)  as CompanyEUR   ,
			-------------------------------
			--USD
			SUM(CASE WHEN b.sporttype=0 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD	
			ELSE 0 END) AS turnoverSBUSD,
			0 AS turnoverBAUSD,
			SUM(CASE WHEN b.sporttype=161 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD	
			ELSE 0 END) AS turnoverNGUSD,
			SUM(CASE WHEN b.sporttype=151 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END	
				* e.USD	
			ELSE 0 END) AS turnoverRBUSD,
			SUM(CASE WHEN b.sporttype=162 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverLCUSD,
			SUM(CASE WHEN b.sporttype=180 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverVSUSD,
			SUM(CASE WHEN b.sporttype=251 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverCSUSD,
			SUM(CASE WHEN b.sporttype=252 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverBGUSD,
			SUM(b.winlost * e.USD) winlostUSD,  
			-- - SUM(CASE WHEN (b.sporttype IN (0,161,162,180))  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLSBUSD,
			0 AS LicenseeWLBAUSD,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLNGUSD,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS LicenseeWLRBUSD,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLLCUSD,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLVSUSD,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLCSUSD,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLBGUSD,
			--SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBAUSD,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.USD) as AmountDueToRBUSD,
			0 AS CommBAUSD,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END * e.USD) AS CommRBUSD,
			SUM ( playercomm * e.USD) AS PlayerCommUSD,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END * e.USD)  as CompanyUSD   ,
			--------------------------
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
		GROUP BY  b.custid,b.currency,b.statusID
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
			SUM(b.winlost),  
			--0 as LicenseeWL,
			0 AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			0 AS LicenseeWLNG,
			0 AS LicenseeWLRB,
			0 AS LicenseeWLLC,
			0 AS LicenseeWLVS,
			0 AS LicenseeWLCS,
			0 AS LicenseeWLBG,
			--0 AS WinlossRB,
			- SUM (b.winlost+b.awinlost+b.comm) as AmountDueToBA,
			0 as AmountDueToRB,
			SUM (comm) AS CommBA,
			0 AS CommRB,
			SUM(playercomm) AS PlayerComm,
			0 AS Company,
			
			--EUR
			0 AS turnoverSBEUR,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverBAEUR,     
			0 AS turnoverNGEUR,
			0 AS turnoverRBEUR,
			0 AS turnoverLCEUR,
			0 AS turnoverVSEUR,
			0 AS turnoverCSEUR,
			0 AS turnoverBGEUR,
			SUM(b.winlost*e.EUR) WinlostEUR,  
			--0 as LicenseeWL,
			0 AS LicenseeWLSBEUR,
			0 AS LicenseeWLBAEUR,
			0 AS LicenseeWLNGEUR,
			0 AS LicenseeWLRBEUR,
			0 AS LicenseeWLLCEUR,
			0 AS LicenseeWLVSEUR,
			0 AS LicenseeWLCSEUR,
			0 AS LicenseeWLBGEUR,
			--0 AS WinlossRB,
			- SUM ((b.winlost+b.awinlost+b.comm)* e.EUR) as AmountDueToBAEUR,
			0 as AmountDueToRBEUR,
			SUM (comm * e.EUR) AS CommBAEUR,
			0 AS CommRBEUR,
			SUM(playercomm * e.EUR) AS PlayerCommEUR,
			0 AS CompanyEUR,
			--USD
			0 AS turnoverSBUSD,
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverBAUSD,     
			0 AS turnoverNGUSD,
			0 AS turnoverRBUSD,
			0 AS turnoverLCUSD,
			0 AS turnoverVSUSD,
			0 AS turnoverCSUSD,
			0 AS turnoverBGUSD,
			SUM(b.winlost*e.USD) WinlostUSD,  
			--0 as LicenseeWL,
			0 AS LicenseeWLSBUSD,
			0 AS LicenseeWLBAUSD,
			0 AS LicenseeWLNGUSD,
			0 AS LicenseeWLRBUSD,
			0 AS LicenseeWLLCUSD,
			0 AS LicenseeWLVSUSD,
			0 AS LicenseeWLCSUSD,
			0 AS LicenseeWLBGUSD,
			--0 AS WinlossRB,
			- SUM ((b.winlost+b.awinlost+b.comm)* e.USD) as AmountDueToBAUSD,
			0 as AmountDueToRBUSD,
			SUM (comm * e.USD) AS CommBAUSD,
			0 AS CommRBUSD,
			SUM(playercomm * e.USD) AS PlayerCommUSD,
			0 AS CompanyUSD,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.custid,b.currency,b.statusID
	END
	
	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		SELECT 
			b.custid,
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
			SUM(b.winlost),  
			-- - SUM(CASE WHEN (b.sporttype IN (0,161,162,180))  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END ) AS LicenseeWLSB,
			0 AS LicenseeWLBA,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END ) AS LicenseeWLNG,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWLRB,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END ) AS LicenseeWLLC,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END ) AS LicenseeWLVS,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END ) AS LicenseeWLCS,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END ) AS LicenseeWLBG,
			--SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBA,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmountDueToRB,
			0 AS CommBA,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END) AS CommRB,
			SUM ( playercomm) AS PlayerComm,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END)  as Company   ,
			
			--EUR
			SUM(CASE WHEN b.sporttype=0 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR	
			ELSE 0 END) AS turnoverSBEUR,
			0 AS turnoverBAEUR,
			SUM(CASE WHEN b.sporttype=161 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR	
			ELSE 0 END) AS turnoverNGEUR,
			SUM(CASE WHEN b.sporttype=151 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END	
				* e.EUR	
			ELSE 0 END) AS turnoverRBEUR,
			SUM(CASE WHEN b.sporttype=162 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverLCEUR,
			SUM(CASE WHEN b.sporttype=180 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverVSEUR,
				SUM(CASE WHEN b.sporttype=251 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverCSEUR,
			SUM(CASE WHEN b.sporttype=252 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.EUR		
			ELSE 0 END) AS turnoverBGEUR,
			SUM(b.winlost * e.EUR) winlostEUR,  
			-- - SUM(CASE WHEN (b.sporttype IN (0,161,162,180))  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLSBEUR,
			0 AS LicenseeWLBAEUR,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLNGEUR,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS LicenseeWLRBEUR,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLLCEUR,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLVSEUR,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLCSEUR,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END * e.EUR) AS LicenseeWLBGEUR,
			--SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBAEUR,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.EUR) as AmountDueToRBEUR,
			0 AS CommBAEUR,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END * e.EUR) AS CommRBEUR,
			SUM ( playercomm * e.EUR) AS PlayerCommEUR,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END * e.EUR)  as CompanyEUR   ,
			--USD
			SUM(CASE WHEN b.sporttype=0 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD	
			ELSE 0 END) AS turnoverSBUSD,
			0 AS turnoverBAUSD,
			SUM(CASE WHEN b.sporttype=161 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD	
			ELSE 0 END) AS turnoverNGUSD,
			SUM(CASE WHEN b.sporttype=151 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END	
				* e.USD	
			ELSE 0 END) AS turnoverRBUSD,
			SUM(CASE WHEN b.sporttype=162 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverLCUSD,
			SUM(CASE WHEN b.sporttype=180 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverVSUSD,
				SUM(CASE WHEN b.sporttype=251 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverCSUSD,
			SUM(CASE WHEN b.sporttype=252 THEN 
				b.turnover
				*
					CASE WHEN @drawfilter IN (2,3) THEN
						CASE WHEN b.statusID = 111  THEN 0
						WHEN b.statusID IN (114,115) THEN 0.5
						ELSE 1 END
					ELSE 1 END
				* e.USD		
			ELSE 0 END) AS turnoverBGUSD,
			SUM(b.winlost * e.USD) winlostUSD,  
			-- - SUM(CASE WHEN (b.sporttype IN (0,161,162,180))  THEN b.winlost ELSE 0 END) AS LicenseeWL ,
			- SUM(CASE WHEN (b.sporttype=0) THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLSBUSD,
			0 AS LicenseeWLBAUSD,
			- SUM(CASE WHEN b.sporttype=161 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLNGUSD,
			SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS LicenseeWLRBUSD,
			- SUM(CASE WHEN b.sporttype=162 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLLCUSD,
			- SUM(CASE WHEN b.sporttype=180 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLVSUSD,
			- SUM(CASE WHEN b.sporttype=251 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLCSUSD,
			- SUM(CASE WHEN b.sporttype=252 THEN b.winlost ELSE 0 END * e.USD) AS LicenseeWLBGUSD,
			--SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,
			0 as AmountDueToBAUSD,
			- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END * e.USD) as AmountDueToRBUSD,
			0 AS CommBAUSD,
			SUM ( CASE WHEN b.sporttype = 151 THEN comm   ELSE 0 END * e.USD) AS CommRBUSD,
			SUM ( playercomm * e.USD) AS PlayerCommUSD,
			- SUM(CASE WHEN b.sporttype <> 151 THEN  b.awinlost + b.winlost + b.comm ELSE 0 END * e.USD)  as CompanyUSD ,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		
		FROM bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  b.custid,b.currency,b.statusID
	END
	
 END
 
-- CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Custid)


 
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
	   SUM(Winlost)		  AS Winlost,  
	  -- SUM(LicenseeWL)    AS LicenseeWL,
	   SUM(LicenseeWLSB)  AS LicenseeWLSB,
	   SUM(LicenseeWLBA)  AS LicenseeWLBA,
	   SUM(LicenseeWLNG)  AS LicenseeWLNG,
	   SUM(LicenseeWLRB)  AS LicenseeWLRB,	
	   SUM(LicenseeWLLC)  AS LicenseeWLLC,
	   SUM(LicenseeWLVS)  AS LicenseeWLVS,
	   SUM(LicenseeWLCS)  AS LicenseeWLCS,
	   SUM(LicenseeWLBG)  AS LicenseeWLBG,
	   --SUM(WinlossRB)	  AS WinlossRB,
	   SUM(CommBA) AS CommBA,
	   SUM(CommRB) AS CommRB,
	   SUM(PlayerComm) AS PlayerComm,
	   SUM(AmtDuetoBA) AS AmtDuetoBA,
	   SUM(AmtDuetoRB) AS AmtDuetoRB,
	   SUM(Company) AS Company,
	   SUM(Betcount)	AS Betcount,
	  
	  
	    --BaseEUR  
	   CAST(SUM(TurnoverSBEUR)    AS MONEY)     AS TurnoverSBEUR,   
	   CAST(SUM(TurnoverBAEUR)    AS MONEY)     AS TurnoverBAEUR,   
	   CAST(SUM(TurnoverNGEUR)    AS MONEY)     AS TurnoverNGEUR,   
	   CAST(SUM(TurnoverRBEUR)    AS MONEY)     AS TurnoverRBEUR,
	   CAST(SUM(TurnoverLCEUR)    AS MONEY)     AS TurnoverLCEUR,
	   CAST(SUM(TurnoverVSEUR)    AS MONEY)     AS TurnoverVSEUR,  
	   CAST(SUM(TurnoverCSEUR)    AS MONEY)     AS TurnoverCSEUR,
	   CAST(SUM(TurnoverBGEUR)    AS MONEY)     AS TurnoverBGEUR,
	   CAST(SUM(WinlostEUR)	     AS MONEY)   AS WinlostEUR,  
	   --CAST(SUM(LicenseeWL*e.EUR)    AS MONEY)   AS LicenseeWLEUR,
	   CAST(SUM(LicenseeWLSBEUR)  AS MONEY)   AS LicenseeWLSBEUR,
	   CAST(SUM(LicenseeWLBAEUR)  AS MONEY)   AS LicenseeWLBAEUR,
	   CAST(SUM(LicenseeWLNGEUR)  AS MONEY)   AS LicenseeWLNGEUR,
	   CAST(SUM(LicenseeWLRBEUR)  AS MONEY)   AS LicenseeWLRBEUR,
	   CAST(SUM(LicenseeWLLCEUR)  AS MONEY)   AS LicenseeWLLCEUR,
	   CAST(SUM(LicenseeWLVSEUR)  AS MONEY)   AS LicenseeWLVSEUR,
	   CAST(SUM(LicenseeWLCSEUR)  AS MONEY)   AS LicenseeWLCSEUR,
	   CAST(SUM(LicenseeWLBGEUR)  AS MONEY)   AS LicenseeWLBGEUR,
	   --CAST(SUM(WinlossRB*e.EUR)	 AS MONEY)   AS WinlossRBEUR,
	   CAST(SUM(CommBAEUR)      AS MONEY)   AS CommBAEUR,
	   CAST(SUM(CommRBEUR)      AS MONEY)   AS CommRBEUR,
	   CAST(SUM(PlayerCommEUR)  AS MONEY)   AS PlayerCommEUR,
	   CAST(SUM(AmtDuetoBAEUR)    AS MONEY)   AS AmtDuetoBAEUR,
	   CAST(SUM(AmtDuetoRBEUR)    AS MONEY)   AS AmtDuetoRBEUR,
	   CAST(SUM(CompanyEUR)     AS MONEY)   AS CompanyEUR,
	    --BaseUSD  
	   CAST(SUM(TurnoverSBUSD)    AS MONEY)     AS TurnoverSBUSD,   
	   CAST(SUM(TurnoverBAUSD)    AS MONEY)     AS TurnoverBAUSD,   
	   CAST(SUM(TurnoverNGUSD)    AS MONEY)     AS TurnoverNGUSD,   
	   CAST(SUM(TurnoverRBUSD)    AS MONEY)     AS TurnoverRBUSD,
	   CAST(SUM(TurnoverLCUSD)    AS MONEY)     AS TurnoverLCUSD,
	   CAST(SUM(TurnoverVSUSD)    AS MONEY)     AS TurnoverVSUSD,  
	   CAST(SUM(TurnoverCSUSD)    AS MONEY)     AS TurnoverCSUSD,
	   CAST(SUM(TurnoverBGUSD)    AS MONEY)     AS TurnoverBGUSD,
	   CAST(SUM(WinlostUSD)	     AS MONEY)   AS WinlostUSD,  
	   --CAST(SUM(LicenseeWL*e.USD)    AS MONEY)   AS LicenseeWLUSD,
	   CAST(SUM(LicenseeWLSBUSD)  AS MONEY)   AS LicenseeWLSBUSD,
	   CAST(SUM(LicenseeWLBAUSD)  AS MONEY)   AS LicenseeWLBAUSD,
	   CAST(SUM(LicenseeWLNGUSD)  AS MONEY)   AS LicenseeWLNGUSD,
	   CAST(SUM(LicenseeWLRBUSD)  AS MONEY)   AS LicenseeWLRBUSD,
	   CAST(SUM(LicenseeWLLCUSD)  AS MONEY)   AS LicenseeWLLCUSD,
	   CAST(SUM(LicenseeWLVSUSD)  AS MONEY)   AS LicenseeWLVSUSD,
	   CAST(SUM(LicenseeWLCSUSD)  AS MONEY)   AS LicenseeWLCSUSD,
	   CAST(SUM(LicenseeWLBGUSD)  AS MONEY)   AS LicenseeWLBGUSD,
	   --CAST(SUM(WinlossRB*e.USD)	 AS MONEY)   AS WinlossRBUSD,
	   CAST(SUM(CommBAUSD)      AS MONEY)   AS CommBAUSD,
	   CAST(SUM(CommRBUSD)      AS MONEY)   AS CommRBUSD,
	   CAST(SUM(PlayerCommUSD)  AS MONEY)   AS PlayerCommUSD,
	   CAST(SUM(AmtDuetoBAUSD)    AS MONEY)   AS AmtDuetoBAUSD,
	   CAST(SUM(AmtDuetoRBUSD)    AS MONEY)   AS AmtDuetoRBUSD,
	   CAST(SUM(CompanyUSD)     AS MONEY)   AS CompanyUSD      
 FROM	#SAgWinLoss w   
		INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
  GROUP BY w.custid, c.username,c.username2,w.currency
 


DROP TABLE #SAgWinLoss
 
END   

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LicWinlossDetail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LicWinlossDetail] TO [vnteam]  



