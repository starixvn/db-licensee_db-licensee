set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE [dbo].[Lrf_Rpt_WinlossByProduct]  
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
 @ShowCS  		BIT=0, -- RNG Casino
 @ShowBG   		BIT=0, -- Bingo 
 @ReportType	TINYINT=1,  
 @MoveBetsDay SMALLDATETIME,
 @IsOld BIT = 0,
 @drawfilter SMALLINT = 1  ,
 @excludeTest BIT = 0
AS  
/*  Created: Henry  
	Date: 2011-07-06
    Task : Winloss By Product Report for Licensee 
    DB: DB052.bodb02  
   
    Revisions:  
	- 20111013@Henry: change to use rptLicWinloss2
	- 20111208@Jim: change bettype condition
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  	
	- 20120529@henry: enhance performance
	- 20120730@Jim: Add Playercomm Value 
	- 20120814@Henry: add live casino
	- 20120905@Jim:add virtual sport	
	- 20121004@Jim: replace @currency input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130222@Jim: support RNG Casino ,Bingo
	- 20130417@Jim: add more product code value in the result 
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss, 1 - query in table rptLicWinloss_old. 
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  + @ShowLC: Show Live Casino bets
	  +	@ShowVS: Show Virual Sport bets	
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/  
BEGIN  
SET NOCOUNT ON  

CREATE TABLE #SAgWinLoss (  
	winlostdate		DATETIME,  
	Currency		INT,
	ProductCode		VARCHAR(10),
	ProductName		VARCHAR(50),  
	TurnOver		MONEY,   	
	Winlost			MONEY,  
	LicenseeWL		MONEY, 
	Comm			MONEY,  
    PlayerComm 		MONEY, 	
	AmtDueTo3rd		MONEY,
	Betcount		BIGINT
)  

 
DECLARE @tempAg	TABLE( custID INT PRIMARY KEY, currency INT)  
DECLARE @VNDCurrencyName VARCHAR(20)
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)
DECLARE @sporttype TABLE(sporttype INT)

SELECT @VNDCurrencyName = Currency FROM exchange (NOLOCK) WHERE ExchangeId = 51

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @tempAg (custID,currency) 
SELECT custID,currency 
FROM bodb_Licensee.dbo.LicenseeCust lc(NOLOCK) 
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	
	
DECLARE @site VARCHAR(50)
SELECT @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency 
FROM Dep_CustSuper dc WITH (NOLOCK)  
	INNER JOIN #Currency c ON dc.Currency=c.CurrencyID
WHERE  site = @site	
--------------------------------------------
DROP TABLE #Currency	
--------------------------------------------
IF @ShowSB = 1  
BEGIN  
	INSERT  INTO @sporttype( sporttype)
    VALUES  (0)	
	
END  

IF @ShowLC = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
    VALUES  (162)
    
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
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
IF @ShowVS = 1
BEGIN
	INSERT  INTO @sporttype( Sporttype)
    SELECT  180
	UNION ALL 
	SELECT 181 
    
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
			b.winlostdate,  
			s.currency,
			'BA' ProductCode,
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
			SUM(PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
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
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID IN (111, 112, 113) 
		GROUP BY   
			b.winlostdate,s.currency, b.statusID
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
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
			SUM (comm) as Comm,
			SUM( PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
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
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.statusID  IN (111, 112, 113) AND
			b.tpositiontaking<>0
			
		GROUP BY   
			b.winlostdate,s.currency,b.statusID
	END
	
	--SB + RB + LC
	IF (@ShowNG=1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			s.currency,
			CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'LC'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'NG' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS' 
				WHEN b.bettype =71 THEN 'CS'
				WHEN b.bettype =73 THEN 'BG'
				END AS ProductCode,
			CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'Live Casino'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'Number Game' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'Virtual Sports' 
				WHEN b.bettype =71 THEN 'RNG Casino'
				WHEN b.bettype =73 THEN 'Bingo'
				END AS ProductName,
			SUM(stake
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM (comm) as Comm,
			SUM( PlayerComm ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
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
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.winlostdate
			,s.currency
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'LC'
				WHEN b.Bettype BETWEEN 81 AND 120 THEN 'NG' 
				WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS' 
				WHEN b.bettype =71 THEN 'CS'
				WHEN b.bettype =73 THEN 'BG'
				END 
			,CASE 
			WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'Live Casino'
			WHEN b.Bettype BETWEEN 81 AND 120 THEN 'Number Game' 
			WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'Virtual Sports' 
			WHEN b.bettype =71 THEN 'RNG Casino'
			WHEN b.bettype =73 THEN 'Bingo'
			END
			,b.statusID
	END
	
	
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #SAgWinLoss
		SELECT   
			b.winlostdate,  
			s.currency,
			'RB' AS ProductCode,
			'Racing' AS ProductName,
			SUM(CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END 
				*
				CASE WHEN @drawfilter IN (2,3) THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  
			SUM (b.awinlost) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM( playercomm  ) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) as AmountDueTo3rd,
			COUNT(b.transid)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
			   BetCount	
		FROM 
			dbo.bettrans b WITH  ( NOLOCK,INDEX=IX_srecommend )  
			INNER JOIN @Super s ON b.srecommend = s.custid
			INNER JOIN @TempAg a ON b.recommend = a.custid
		WHERE 
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(bettype BETWEEN 31 AND 33) AND 
			b.statusID  IN (111, 112, 113)
		GROUP BY   
			b.winlostdate,s.currency,b.statusID
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
			b.winlostdate,  
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
			SUM (comm) as Comm,
			SUM( PlayerComm ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.winlostdate,  b.currency, b.statusID
	END
	
	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 or @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.currency,
			CASE b.sporttype 
				WHEN 0   THEN 'SB'
				WHEN 151 THEN 'RB'
				WHEN 161 THEN 'NG'
				WHEN 162 THEN 'LC'
				WHEN 180 THEN 'VS'
				WHEN 181 THEN 'VS'
				WHEN 251 THEN 'CS'
				WHEN 252 THEN 'BG'
			END AS ProductCode,
			CASE b.sporttype 
				WHEN 0   THEN 'Sportsbook'
				WHEN 151 THEN 'Racing'
				WHEN 161 THEN 'Number Game'
				WHEN 162 THEN 'Live Casino'
				WHEN 180 THEN 'Virtual Sports'
				WHEN 181 THEN 'Virtual Sports'
				WHEN 251 THEN 'RNG Casino'
				WHEN 252 THEN 'Bingo'
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
			SUM(CASE WHEN (b.sporttype in(0,161,162,180,181,251,252))  THEN -1 * b.winlost 
					WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END
				) AS LicenseeWL,
			SUM(comm ) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  
			b.winlostdate,   
			b.currency,
			CASE b.sporttype 
				WHEN 0   THEN 'SB'
				WHEN 151 THEN 'RB'
				WHEN 161 THEN 'NG'
				WHEN 162 THEN 'LC'
				WHEN 180 THEN 'VS'
				WHEN 181 THEN 'VS'
				WHEN 251 THEN 'CS'
				WHEN 252 THEN 'BG'
			END,		
			CASE b.sporttype 
				WHEN 0 THEN 'Sportsbook'
				WHEN 151 THEN 'Racing'
				WHEN 161 THEN 'Number Game'
				WHEN 162 THEN 'Live Casino'
				WHEN 180 THEN 'Virtual Sports'
				WHEN 181 THEN 'Virtual Sports'
				WHEN 251 THEN 'RNG Casino'
				WHEN 252 THEN 'Bingo'
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
			b.winlostdate,  
			b.currency,
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
			SUM (comm) as Comm,
			SUM( PlayerComm  ) AS PlayerComm, 
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 1
		GROUP BY  b.winlostdate,  b.currency, b.statusID
	END

	--exclude BA tickets
	IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1  or @ShowLC=1 or @ShowVS=1 or @ShowCS=1 or @ShowBG=1)
	BEGIN
		INSERT INTO #SAgWinLoss  
		SELECT 
			b.winlostdate,  
			b.currency,
			CASE b.sporttype 
				WHEN 0 THEN 'SB'
				WHEN 151 THEN 'RB'
				WHEN 161 THEN 'NG'
				WHEN 162 THEN 'LC'
				WHEN 180 THEN 'VS'
				WHEN 181 THEN 'VS'
				WHEN 251 THEN 'CS'
				WHEN 252 THEN 'BG'
			END AS ProductCode,
			CASE b.sporttype 
				WHEN 0 THEN 'Sportsbook'
				WHEN 151 THEN 'Racing'
				WHEN 161 THEN 'Number Game'
				WHEN 162 THEN 'Live Casino'
				WHEN 180 THEN 'Virtual Sports'
				WHEN 181 THEN 'Virtual Sports'
				WHEN 251 THEN 'RNG Casino'
				WHEN 252 THEN 'Bingo'
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
			SUM(CASE WHEN (b.sporttype in(0,161,162,180,181,251,252))  THEN -1 * b.winlost WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS LicenseeWL ,
			SUM(comm) as Comm,
			SUM( playerComm  ) AS PlayerComm,
			- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,
			SUM(b.betcount)
			* CASE WHEN @drawfilter = 2 THEN
					CASE WHEN b.statusID = 111 THEN 0
					ELSE 1 END
				ELSE 1 END
		FROM 
			bodb_Licensee.dbo.rptLicWinloss_old b WITH ( NOLOCK )  
			INNER JOIN @TempAg ag ON ag.custid = b.recommend
			INNER JOIN @sporttype t ON b.sporttype = t.sporttype
		WHERE  
			b.Winlostdate BETWEEN @FDate AND @TempToDate  
			AND b.roleid = 2   
			AND b.statusID <> 101 --exclude REJECT bets
			AND ISNULL(b.isBA,0) = 0
		GROUP BY  
			b.winlostdate,  
			b.currency, 
			CASE b.sporttype 
				WHEN 0 THEN 'SB'
				WHEN 151 THEN 'RB'
				WHEN 161 THEN 'NG'
				WHEN 162 THEN 'LC'
				WHEN 180 THEN 'VS'
				WHEN 181 THEN 'VS'
				WHEN 251 THEN 'CS'
				WHEN 252 THEN 'BG'
			END,
			CASE b.sporttype 
				WHEN 0 THEN 'Sportsbook'
				WHEN 151 THEN 'Racing'
				WHEN 161 THEN 'Number Game'
				WHEN 162 THEN 'Live Casino'
				WHEN 180 THEN 'Virtual Sports'
				WHEN 181 THEN 'Virtual Sports'
				WHEN 251 THEN 'RNG Casino'
				WHEN 252 THEN 'Bingo'
			END
			, b.statusID
	END
END

CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)


SELECT   
   CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
		WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
		ELSE '0' END ReportType,  
   Currency ,   
		CASE WHEN Currency = 51 THEN @VNDCurrencyName 
			ELSE e.Code END currencyName,
   ProductCode,			
   ProductName,
   SUM(TurnOver)	AS Turnover,   
   SUM(Winlost)		AS Winlost,  
   SUM(LicenseeWL) AS LicenseeWL,
   SUM(Comm) AS Comm,
   SUM(PlayerComm) AS PlayerComm,
   SUM(AmtDueto3rd) AS AmtDueto3rd,
   SUM(Betcount)	AS Betcount,
   
   --BaseRM  
   CAST(SUM(TurnOver*e.MYR)				AS MONEY)	AS TurnoverMYR,   
   CAST(SUM(Winlost*e.MYR)				AS MONEY)	AS WinlostMYR,  
   CAST(SUM(LicenseeWL*e.MYR) 			AS MONEY)	AS LicenseeWLMYR,
   CAST(SUM(Comm * e.MYR) 				AS MONEY)	AS CommMYR,
   CAST(SUM(PlayerComm* e.MYR) 			AS MONEY)	AS PlayerCommMYR,
   CAST(SUM(AmtDueto3rd*e.MYR) 			AS MONEY)	AS AmtDueto3rdMYR,
   
   
   --BaseUSD  
   CAST(SUM(TurnOver*e.USD)				AS MONEY)	AS TurnoverUSD,   
   CAST(SUM(Winlost*e.USD)				AS MONEY)	AS WinlostUSD,  
   CAST(SUM(LicenseeWL*e.USD)			AS MONEY)	AS LicenseeWLUSD,
   CAST(SUM(Comm * e.USD) 				AS MONEY)	AS CommUSD,
   CAST(SUM(PlayerComm*e.USD)  			AS MONEY)	AS PlayerCommUSD,
   CAST(SUM(AmtDueto3rd*e.USD) 			AS MONEY)	AS AmtDueto3rdUSD,
   
    --BaseEUR  
   CAST(SUM(TurnOver*e.EUR)				AS MONEY)	AS TurnoverEUR,   
   CAST(SUM(Winlost*e.EUR)				AS MONEY)	AS WinlostEUR,  
   CAST(SUM(LicenseeWL*e.EUR) 			AS MONEY)	AS LicenseeWLEUR,
   CAST(SUM(Comm * e.EUR) 				AS MONEY)	AS CommEUR,
   CAST(SUM(PlayerComm*e.EUR) 			AS MONEY)	AS PlayerCommEUR,
   CAST(SUM(AmtDueto3rd*e.EUR) 			AS MONEY)	AS AmtDueto3rdEUR
FROM	
	#SAgWinLoss w   
	INNER JOIN #TempExchange e 
	ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId
GROUP BY   
	Currency,
	Productcode,
	ProductName,
	CASE WHEN @ReportType = 1 THEN CONVERT(VARCHAR(8),w.winlostdate,112)  
		  WHEN @ReportType = 2 THEN CONVERT(VARCHAR(6),w.winlostdate,112)  
		  ELSE '0' END   ,
	CASE WHEN Currency = 51 THEN @VNDCurrencyName 
			ELSE e.Code END
ORDER BY ReportType,  Currency,ProductName

DROP TABLE #SAgWinLoss
DROP TABLE #TempExchange
 
END   

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlossByProduct] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlossByProduct] TO [vnteam] 