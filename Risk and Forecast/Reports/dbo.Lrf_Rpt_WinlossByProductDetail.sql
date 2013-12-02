set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER  PROCEDURE [dbo].[Lrf_Rpt_WinlossByProductDetail]  
 @LicenseeID	INT,
 @UserID		INT,
 @CurrencyID	INT = 0,
 @CustID		INT = 0, --AgentID
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @showSB		BIT=0,  
 @ShowRB		BIT=0,  
 @ShowNG		BIT=0, 
 @ShowBA		BIT=0,  
 @ShowLC 		BIT=0,	
 @ShowVS		BIT=0,
 @ShowCS 		BIT=0,-- RNG Casino
 @ShowBG		BIT=0,-- Bingo
 @MoveBetsDay SMALLDATETIME,
 @IsOld BIT = 0,
 @drawfilter SMALLINT = 1  ,
 @excludeTest BIT = 0
AS  
/*  Created: Henry  
	Date: 2011-07-06
    Task : Winloss By Product Detail Report for Licensee Member Level 
    DB: DB052.bodb02  
   
    Revisions:  
	-20111013@Henry: change to use rptLicWinloss2
	-20111208@Jim: change bettype condition
	-20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	-20120529@Henry: enhance performance
	-20120731@Jim: add playercomm value 
	-20120815@Jim: add live casino
	-20120905@Jim: add virtual sport
	-20121004@Jim: replace @currency input param by @currencyID
	-20121022@Jim:  re-calculate AmountDueTo3rd's value 
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130222@Jim: support RNG Casino,Bingo
	- 20130402@Jim: support base currency USD 
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
	- 20131007@Jim: offer Virtual Tennis
	Param's Explanation:  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss, 1 - query in table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  + @ShowLC: Show Live Casino	
	  +	@ShowVS: Show Virtual Sport
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/  
BEGIN  
SET NOCOUNT ON  

CREATE TABLE #SAgWinLoss  (  
	--winlostdate		DATETIME,  
	CustID			INT,   
	Currency		INT,
	ProductCode 	VARCHAR(10),
	ProductName		VARCHAR(50),  
	TurnOver		MONEY,   	
	Winlost			MONEY,  
	LicenseeWL		MONEY, 
	Comm			MONEY, 
	PlayerComm 		MONEY,	
	AmtDueTo3rd		MONEY,
	
	TurnOverEUR		MONEY,   	
	WinlostEUR			MONEY,  
	LicenseeWLEUR		MONEY, 
	CommEUR			MONEY, 
	PlayerCommEUR 		MONEY,	
	AmtDueTo3rdEUR		MONEY,
	
	TurnOverUSD		MONEY,   	
	WinlostUSD			MONEY,  
	LicenseeWLUSD		MONEY, 
	CommUSD			MONEY, 
	PlayerCommUSD 		MONEY,	
	AmtDueTo3rdUSD		MONEY,
	
	Betcount		BIGINT
)  
--CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Custid)


DECLARE @tempAg	TABLE( custID INT PRIMARY KEY,currency INT)  
DECLARE @Code VARCHAR(20), @TempCurrencyID INT
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)
DECLARE @Exchange TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT,  EUR FLOAT,USD FLOAT,Code VARCHAR(10), PRIMARY KEY(ExchangeDate,ExchangeId))

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @tempAg (custID,currency) 
SELECT custID,currency 
FROM bodb_Licensee.dbo.LicenseeCust lc (NOLOCK) 
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID	
WHERE (@CustID=0 OR (@CustID<>0 AND CustiD=@CustID))
		AND (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	

DECLARE @site VARCHAR(50)
SELECT @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency 
FROM Dep_CustSuper dc WITH (NOLOCK)  
INNER JOIN #Currency c ON dc.Currency=c.CurrencyID
WHERE  site = @site	

--------------------
DROP TABLE #Currency
--------------------

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

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @MaxOldDate DATETIME
DECLARE @FDate DATETIME 
DECLARE @TDate DATETIME 
--to Deal With Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 

INSERT INTO @Exchange (exchangedate,exchangeid,eur,usd,code)
SELECT exchangedate,exchangeid,eur,usd,code
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT Currency FROM @TempAg)	

IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate
	

	
	IF @ShowBA=1 
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT   
			b.custid,
			s.currency,
			'BA' AS ProductCode,
			'BA' AS ProductName,  
			 
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
			SUM (comm ) as Comm,
			SUM ( PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			
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
			SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
			0 as LicenseeWLEUR,
			SUM (comm * e.EUR) as CommEUR,
			SUM ( PlayerComm * e.EUR ) AS PlayerCommEUR,
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) AmountDueTo3rdEUR  ,
			------------USD
			SUM( stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverUSD, 
			SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
			0 as LicenseeWLUSD,
			SUM (comm * e.USD) as CommUSD,
			SUM ( PlayerComm * e.USD ) AS PlayerCommUSD,
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) AmountDueTo3rdUSD  ,
			
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
			b.custid,s.currency, b.statusID
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			--b.username,
			s.currency,
			'SB' AS ProductCode,
			'Sportsbook' AS ProductName,
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			
			--EUR
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverEUR, 
			SUM((b.winlost - b.actual_stake)*e.EUR) AS WinlostEUR,  
			- SUM((b.winlost - b.actual_stake)*e.EUR) AS LicenseeWLEUR,
			SUM (comm * e.EUR) as CommEUR,
			SUM( PlayerComm  * e.EUR) AS PlayerCommEUR, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm)*e.EUR) AmountDueTo3rdEUR  ,
			------USD
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverUSD, 
			SUM((b.winlost - b.actual_stake)*e.USD) AS WinlostUSD,  
			- SUM((b.winlost - b.actual_stake)*e.USD) AS LicenseeWLUSD,
			SUM (comm * e.USD) as CommUSD,
			SUM( PlayerComm  * e.USD) AS PlayerCommUSD, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm)*e.USD) AmountDueTo3rdUSD  ,
			
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	
		FROM 
			dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend )
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN @TempAg a ON b.recommend = a.custid
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.statusID  IN (111, 112, 113) AND
			b.tpositiontaking <> 0
			
		GROUP BY   
			b.custid,
			s.currency , statusID
	END
	
	--NG+LC+VS+RB
	IF (@ShowNG=1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowRB=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.custid,
			--b.username,
			s.currency,
			CASE 
				WHEN b.Bettype BETWEEN 31 AND 33 THEN 'RB'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'NG' 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'LC' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'  
				WHEN b.bettype=71 THEN 'CS'
				WHEN b.bettype=73 THEN 'BG'
			END AS ProductCode,
			CASE 
				WHEN b.Bettype BETWEEN 31 AND 33 THEN 'Racing'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'Number Game' 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'Live Casino' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'Virtual Sports'  
				WHEN b.bettype=71 THEN 'RNG Casino'
				WHEN b.bettype=73 THEN 'Bingo'
			END AS ProductName,
				
			SUM(
				CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN -1 * (b.winlost - b.actual_stake) ELSE b.awinlost END ) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			
			--EUR
			
			SUM(
				CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				* e.EUR
			) turnoverEUR, 
			SUM((b.winlost - b.actual_stake)*e.EUR) AS WinlostEUR,  
			SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN -1 * (b.winlost - b.actual_stake) ELSE b.awinlost END * e.EUR) AS LicenseeWLEUR,
			SUM (comm * e.EUR) as CommEUR,
			SUM( PlayerComm * e.EUR ) AS PlayerCommEUR, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) AmountDueTo3rdEUR  ,
			--- USD
			SUM(
				CASE WHEN b.bettype = 33 AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
				* e.USD
			) turnoverUSD, 
			SUM((b.winlost - b.actual_stake)*e.USD) AS WinlostUSD,  
			SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN -1 * (b.winlost - b.actual_stake) ELSE b.awinlost END * e.USD) AS LicenseeWLUSD,
			SUM (comm * e.USD) as CommUSD,
			SUM( PlayerComm * e.USD ) AS PlayerCommUSD, 
			- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) AmountDueTo3rdUSD  ,
			
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	
		FROM 
			dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend )
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN @TempAg a ON b.recommend = a.custid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.custid,
			s.currency ,
			CASE 
				WHEN b.Bettype BETWEEN 31 AND 33 THEN 'RB'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'NG' 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'LC' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'  
				WHEN b.bettype=71 THEN 'CS'
				WHEN b.bettype=73 THEN 'BG'
			END
			,
			CASE 
				WHEN b.Bettype BETWEEN 31 AND 33 THEN 'Racing'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'Number Game' 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'Live Casino' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'Virtual Sports' 
				WHEN b.bettype=71 THEN 'RNG Casino'
				WHEN b.bettype=73 THEN 'Bingo'
				END
			, statusID
			
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
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			'BA' AS ProductCode,
			'BA' AS ProductName,
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
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
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
			SUM (comm * e.EUR ) as CommEUR,
			SUM( PlayerComm * e.EUR  ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.EUR) as AmountDueTo3rdEUR,
			---- EUR
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
			SUM (comm * e.USD ) as CommUSD,
			SUM( PlayerComm * e.USD  ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.USD) as AmountDueTo3rdUSD,
			
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
		GROUP BY   b.custid,
			b.currency, b.statusID
	END
	
	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			
			CASE 
				WHEN b.sporttype=0   THEN 'SB'
				WHEN b.sporttype=151 THEN 'RB'
				WHEN b.sporttype=161 THEN 'NG'
				WHEN b.sporttype=162 THEN 'LC' 
				WHEN b.sporttype=180 THEN 'VS'
				WHEN b.sporttype=251 THEN 'CS'
				WHEN b.sporttype=252 THEN 'BG'
			END AS ProductCode,
			CASE 
				WHEN b.sporttype=0   THEN 'Sportsbook'
				WHEN b.sporttype=151 THEN 'Racing'
				WHEN b.sporttype=161 THEN 'Number Game'
				WHEN b.sporttype=162 THEN 'Live Casino' 
				WHEN b.sporttype=180 THEN 'Virtual Sports'
				WHEN b.sporttype=251 THEN 'RNG Casino'
				WHEN b.sporttype=252 THEN 'Bingo'
			END AS ProductName,	
			
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),     
			SUM(b.winlost),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWL ,
			SUM(comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
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
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS LicenseeWLEUR ,
			SUM(comm * e.EUR) as CommEUR,
			SUM( PlayerComm * e.EUR ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.EUR) as AmountDueTo3rdEUR,
			---USD
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
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS LicenseeWLUSD ,
			SUM(comm * e.USD) as CommUSD,
			SUM( PlayerComm * e.USD ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.USD) as AmountDueTo3rdUSD,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  
			b.custid,
			b.currency, 
			CASE 
				WHEN b.sporttype=0   THEN 'SB'
				WHEN b.sporttype=151 THEN 'RB'
				WHEN b.sporttype=161 THEN 'NG'
				WHEN b.sporttype=162 THEN 'LC' 
				WHEN b.sporttype=180 THEN 'VS'
				WHEN b.sporttype=251 THEN 'CS'
				WHEN b.sporttype=252 THEN 'BG'
			END,
			CASE 
				WHEN b.sporttype=0 THEN 'Sportsbook'
				WHEN b.sporttype=151 THEN 'Racing'
				WHEN b.sporttype=161 THEN 'Number Game'
				WHEN b.sporttype=162 THEN 'Live Casino' 
				WHEN b.sporttype=180 THEN 'Virtual Sports'
				WHEN b.sporttype=251 THEN 'RNG Casino'
				WHEN b.sporttype=252 THEN 'Bingo'
			END
			, b.statusID
	END
END 
IF @IsOld = 1 
BEGIN
	SELECT @MaxOldDate = MAX(winlostdate) FROM bodb_Licensee.dbo.rptLicWinloss_old (NOLOCK)
	IF @TDate >= @MaxOldDate
			SET @TempToDate = @MaxOldDate
		ELSE
			SET  @TempToDate = @TDate

	IF @ShowBA=1 
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			'BA' ProductCode,
			'BA' AS ProductName,
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
			SUM (comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
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
			SUM (comm * e.EUR ) as CommEUR,
			SUM( PlayerComm * e.EUR  ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.EUR) as AmountDueTo3rdEUR,
			----USD 
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
			SUM (comm * e.USD ) as CommUSD,
			SUM( PlayerComm * e.USD  ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm)* e.USD) as AmountDueTo3rdUSD,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1  
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.custid,
		b.currency, b.statusID
	END

	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.custid,
			b.currency,
			CASE 
				WHEN b.sporttype=0   THEN 'SB'
				WHEN b.sporttype=151 THEN 'RB'
				WHEN b.sporttype=161 THEN 'NG'
				WHEN b.sporttype=162 THEN 'LC' 
				WHEN b.sporttype=180 THEN 'VS'
				WHEN b.sporttype=251 THEN 'CS'
				WHEN b.sporttype=252 THEN 'BG'
			END AS ProductCode, 
			CASE 
				WHEN b.sporttype=0   THEN 'Sportsbook'
				WHEN b.sporttype=151 THEN 'Racing'
				WHEN b.sporttype=161 THEN 'Number Game'
				WHEN b.sporttype=162 THEN 'Live Casino' 
				WHEN b.sporttype=180 THEN 'Virtual Sports'
				WHEN b.sporttype=251 THEN 'RNG Casino'
				WHEN b.sporttype=252 THEN 'Bingo'
			END AS ProductName,	
			
			SUM(b.turnover
			*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111  THEN 0
					WHEN b.statusID IN (114,115) THEN 0.5
					ELSE 1 END
				ELSE 1 END
			),     
			SUM(b.winlost),  
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWL ,
			SUM(comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			
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
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.EUR) AS LicenseeWLEUR ,
			SUM(comm * e.EUR) as CommEUR,
			SUM( PlayerComm * e.EUR ) AS PlayerCommEUR,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.EUR) as AmountDueTo3rdEUR,
			-------------USD
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
			SUM(CASE WHEN ( b.sporttype <> 151)  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END * e.USD) AS LicenseeWLUSD ,
			SUM(comm * e.USD) as CommUSD,
			SUM( PlayerComm * e.USD ) AS PlayerCommUSD,
			- SUM ((b.awinlost + b.winlost + b.comm) * e.USD) as AmountDueTo3rdUSD,
			
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			LEFT JOIN @Exchange e  ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 1  
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  
			b.custid,
			b.currency, 
			CASE 
				WHEN b.sporttype=0   THEN 'SB'
				WHEN b.sporttype=151 THEN 'RB'
				WHEN b.sporttype=161 THEN 'NG'
				WHEN b.sporttype=162 THEN 'LC' 
				WHEN b.sporttype=180 THEN 'VS'
				WHEN b.sporttype=251 THEN 'CS'
				WHEN b.sporttype=252 THEN 'BG'
			END,
			CASE 
				WHEN b.sporttype=0 THEN 'Sportsbook'
				WHEN b.sporttype=151 THEN 'Racing'
				WHEN b.sporttype=161 THEN 'Number Game'
				WHEN b.sporttype=162 THEN 'Live Casino' 
				WHEN b.sporttype=180 THEN 'Virtual Sports'
				WHEN b.sporttype=251 THEN 'RNG Casino'
				WHEN b.sporttype=252 THEN 'Bingo'
			END
			, b.statusID
	END
END


SELECT   
	c.username,  
	SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,	   w.custid, 
	w.Currency ,   
	@Code AS CurrencyName,
	ProductCode, 
	ProductName,
	SUM(TurnOver)	  AS Turnover,   
	SUM(Winlost)	  AS Winlost,  
	SUM(LicenseeWL)   AS LicenseeWL,
	SUM(Comm) 		  AS Comm,
	SUM(PlayerComm)   AS PlayerComm, 
	SUM(AmtDueto3rd)  AS AmtDueto3rd,
	SUM(Betcount)	  AS Betcount,
	
	--BaseEUR  
	CAST(SUM(TurnOverEUR)			AS MONEY)	AS TurnoverEUR,   
	CAST(SUM(WinlostEUR)				AS MONEY)	AS WinlostEUR,  
	CAST(SUM(LicenseeWLEUR) 			AS MONEY)	AS LicenseeWLEUR,
	CAST(SUM(CommEUR) 				AS MONEY)	AS CommEUR,
	CAST(SUM(PlayerCommEUR) 			AS MONEY)	AS PlayerCommEUR,
	CAST(SUM(AmtDueto3rdEUR) 		AS MONEY)	AS AmtDueto3rdEUR,
	--BaseUSD  
	CAST(SUM(TurnOverUSD)			AS MONEY)	AS TurnoverUSD,   
	CAST(SUM(WinlostUSD)				AS MONEY)	AS WinlostUSD,  
	CAST(SUM(LicenseeWLUSD) 			AS MONEY)	AS LicenseeWLUSD,
	CAST(SUM(CommUSD) 				AS MONEY)	AS CommUSD,
	CAST(SUM(PlayerCommUSD) 			AS MONEY)	AS PlayerCommUSD,
	CAST(SUM(AmtDueto3rdUSD) 		AS MONEY)	AS AmtDueto3rdUSD
FROM	
	#SAgWinLoss w   
	INNER JOIN bodb_licensee.dbo.licenseecustinfo c WITH (NOLOCK) ON w.custid = c.custid
GROUP BY   
	w.custid, c.username,c.username2  , 
	w.Currency,
	Productcode,
	ProductName
	
ORDER BY c.username

DROP TABLE #SAgWinLoss

 
END   


GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlossByProductDetail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlossByProductDetail] TO [vnteam]   
