ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummary]
    @LicenseeID INT ,
	@UserID		INT,	
    @CurrencyID INT = NULL ,  
    @FromDate		SMALLDATETIME,  
	@ToDate		SMALLDATETIME,
	@MoveBetsDay SMALLDATETIME
	
AS /*
Created: 20111031@Henry
Task : Live Report Summary
DB: DB052.bodb02


Revisions:
	-20111208@Jim: change bettype condition
	-20120109@Henry: enhance performance + remove @LicenseeType + remove currency UUS
	-20120214@Jim: change to use  table ExchangeDaily by function Lrf_f_GetExchangeDaily  
	-20120614@Jim: optimize code 
	-20120726@Jim: add playercomm value 
	-20120815@Henry: add Live casino
	-20120831@Henry: add Virtual Sports
	-20121004@Jim: replace @currency input param by @currencyID
	-20121115@Henry: Only Sportsbook needs to exclude BA
	-20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	-20130328@Scott: Support RNG Casino and Bingo
	-20130514@Jim:  Restrict permission of Licensee Users by currency
	-20130625@Jim: support to view currency UUS
	-20130809@Jim: offer Virtual Horse Racing
	-20131007@Jim: support Virtual Tennis
	
	
Param's Explanation:
	
Example: 
	
DECLARE @DateFrom DATETIME
DECLARE @DateTo DATETIME
DECLARE @MoveBetsDay DATETIME
SELECT @DateFrom = DATEADD(DAY, -15, GETDATE())
SELECT @DateTo = GETDATE()
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)

EXEC [Lrf_Rpt_LiveReportSummary] @LicenseeId = 1, @CurrencyID = 0, @FromDate=@DateFrom, @ToDate=@DateTo, @MoveBetsDay = @MoveBetsDay

*/
SET NOCOUNT ON
   

DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME 
DECLARE @FDate SMALLDATETIME  
DECLARE @TDate SMALLDATETIME 
	
--to Deal With Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 

IF @CurrencyID IS NULL
	SET @CurrencyID = 0

CREATE TABLE #tmpWinloss (
	winlostdate		DATETIME,  
	Currency		INT,
	ProductCode		VARCHAR(2),  	
	TurnOver		MONEY,   	
	Winlost			MONEY,  
	LicenseeWL		MONEY, 
	Comm			MONEY, 
	PlayerComm	 	MONEY,	
	AmtDueTo3rd		MONEY,
	Betcount		INT
)	
SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE ( CustId INT )
INSERT  INTO @TempAg ( CustId)
SELECT  CustID  
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID	
WHERE    (@CurrencyID=0 OR (Currency = @CurrencyID))

DECLARE @site VARCHAR(50)
SELECT @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID

DECLARE @Super AS TABLE (custid int primary key, currency int)
INSERT INTO @Super(custid,currency)  
SELECT CustID,currency 
FROM Dep_CustSuper dc WITH (NOLOCK)  
	INNER JOIN #Currency c ON dc.Currency=c.CurrencyID
WHERE  site = @site	    

DROP TABLE #Currency 

IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate
	
	
	--BA
	INSERT INTO #tmpWinloss  
	SELECT   
		b.winlostdate,  
		s.currency,
		'BA' AS ProductCode,   		
		SUM( stake) turnover, 
		SUM(b.winlost - b.actual_stake) AS Winlost,  
		0 as LicenseeWL,
		SUM (comm) as Comm,
		SUM( b.playercomm  ) as PlayerComm,
		- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
		COUNT(b.transid) BetCount	
	FROM 
		dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend)
		INNER JOIN @TempAg t  ON b.recommend =t.custid 
		INNER JOIN @Super s ON b.srecommend = s.custid
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON s.custid=BA.srecommend and b.transid = BA.transid 	 	
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @TDate AND  		   
		b.statusID IN (111,112,113)
	GROUP BY   
		b.winlostdate, s.currency
	
	--RB
	INSERT INTO #tmpWinloss
	SELECT   
		b.winlostdate,  
		s.currency,
		'RB' AS ProductCode,
		SUM(CASE WHEN b.bettype in (33, 43) AND liveawayscore = 0 THEN stake/2 ELSE stake END) turnover, 
		SUM(b.winlost - b.actual_stake) AS Winlost,  
		
		SUM(b.awinlost) AS LicenseeWL,
		SUM (comm) as Comm,
		SUM ( playercomm  ) AS PlayerComm,
		- SUM((b.winlost - b.actual_stake + awinlost + comm)) AmountDueTo3rd  ,
		COUNT(b.transid) BetCount	
	FROM 
		dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend)
		INNER JOIN @TempAg t  ON b.recommend =t.custid  
		INNER JOIN @Super s ON b.srecommend = s.custid
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @TDate AND  		
		b.bettype BETWEEN 31 AND 33 AND
		b.statusID IN (111,112,113)
	GROUP BY b.winlostdate, s.currency, b.bettype
		
	--SB
	INSERT INTO #tmpWinloss
	SELECT   
		b.winlostdate,  
		s.currency,
		'SB' AS ProductCode,
		SUM(stake) turnover, 
		SUM(b.winlost - b.actual_stake) AS Winlost,  
		SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
		SUM (comm ) as Comm,
		SUM ( b.playercomm  )as PlayerComm,
		- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
		COUNT(b.transid) BetCount	
	FROM 
		dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend)
		INNER JOIN @TempAg t  ON b.recommend =t.custid  
		INNER JOIN @Super s ON b.srecommend = s.custid
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @TDate AND  		
		(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
		b.tpositiontaking<>0 AND
		b.statusID IN (111,112,113)
	GROUP BY b.winlostdate, s.currency, b.bettype	
		
	--Others
	INSERT INTO #tmpWinloss
	SELECT   
		b.winlostdate,  
		s.currency,
		CASE 
			WHEN bettype BETWEEN 81 AND 120 THEN 'NG'
			WHEN b.bettype BETWEEN 1101 AND 1199 THEN 'LC'
			WHEN b.bettype BETWEEN 1201 AND 1299 THEN 'VS'
			WHEN b.bettype = 71 THEN 'CS'
			WHEN b.bettype = 73 THEN 'BG'
			
			END AS ProductCode,
		SUM(stake) turnover, 
		SUM(b.winlost - b.actual_stake) AS Winlost,  
		SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
		SUM (comm ) as Comm,
		SUM ( b.playercomm  )as PlayerComm,
		- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
		COUNT(b.transid) BetCount	
	FROM 
		dbo.bettrans b WITH ( NOLOCK,INDEX=IX_srecommend)
		INNER JOIN @TempAg t  ON b.recommend =t.custid  
		INNER JOIN @Super s ON b.srecommend = s.custid
	WHERE 
		b.winlostdate BETWEEN @TempFromDate AND @TDate AND  		
		b.bettype NOT IN (31,32,33) AND
		b.statusID IN (111,112,113) AND
		(
			b.bettype BETWEEN 81 AND 120 OR 
			b.bettype BETWEEN 1101 AND 1199 OR 
			b.bettype BETWEEN 1201 AND 1299 OR
			b.bettype in (71,73) --RNG CASINO & BINGO
		)
		
	GROUP BY b.winlostdate, s.currency, b.bettype
END
IF @FDate <= @MoveBetsDay 
BEGIN
	IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @TDate
	
			
	INSERT INTO #tmpWinloss  
	SELECT 
		b.winlostdate,  
		b.currency,
		CASE WHEN ISNULL(b.isBA,0) = 1 THEN 'BA'
		ELSE
			CASE b.sporttype 
				WHEN 0 THEN 'SB'
				WHEN 151 THEN 'RB'
				WHEN 161 THEN 'NG'
				WHEN 162 THEN 'LC'
				WHEN 180 THEN 'VS'
				WHEN 181 THEN 'VS'
				WHEN 186 THEN 'VS'
				WHEN 251 THEN 'CS'
				WHEN 252 THEN 'BG'
			END 
		END AS ProductCode,		
		SUM(b.turnover),     
		SUM(b.winlost),  
		SUM(CASE WHEN ISNULL(b.isBA,0) = 1 THEN 0 
			ELSE 
				CASE WHEN b.sporttype IN (0,161,162,180,181,186,251,252)  THEN -1 * b.winlost 
					WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END
			END) AS LicenseeWL ,
		SUM (comm ) as Comm,
		SUM ( playercomm ) as PlayerComm,
		- SUM (b.winlost+b.awinlost+b.comm) as AmountDueTo3rd,
		SUM(b.betcount)
	FROM 
		bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
		INNER JOIN @TempAg t  ON b.recommend =t.custid  
	WHERE  
		b.Winlostdate BETWEEN @FDate AND @TempToDate  
		AND b.roleid = 2   		
		AND b.statusID <> 101 --exclude REJECT bets
	GROUP BY  b.winlostdate, b.currency,b.isBA, b.sporttype		
END

CREATE NONCLUSTERED INDEX IX_tmpWinloss on #tmpWinloss (Currency)

SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss)

SELECT   
   ProductCode,
   CASE ProductCode 
		WHEN 'BA' THEN 'BA'
		WHEN 'RB' THEN 'Racing'
		WHEN 'NG' THEN 'Number Game'
		WHEN 'LC' THEN 'Live Casino'
		WHEN 'VS' THEN 'Virtual Sports'
		WHEN 'CS' THEN 'RNG Casino'
		WHEN 'BG' THEN 'Bingo'
		ELSE 'Sportsbook'
   END AS ProductName,
   SUM(TurnOver)	AS Turnover,   
   SUM(Winlost)		AS Winlost,  
   SUM(LicenseeWL)  AS LicenseeWL,
   SUM(Comm)        AS Comm,
   SUM(playercomm)   AS PlayerComm,
   SUM(AmtDueto3rd) AS AmtDueto3rd,
   SUM(Betcount)	AS Betcount,
   
    --BaseEUR  
   CAST(SUM(TurnOver*e.EUR) AS MONEY)	  AS TurnoverEUR,   
   CAST(SUM(Winlost*e.EUR) AS MONEY)	  AS WinlostEUR,  
   CAST(SUM(LicenseeWL*e.EUR) AS MONEY)  AS LicenseeWLEUR,
   CAST(SUM(Comm * e.EUR) AS MONEY)      AS CommEUR,
   CAST(SUM(playercomm*e.EUR) AS MONEY)   AS PlayerCommEUR,
   CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,
   
   CAST(SUM(TurnOver*e.USD) AS MONEY)	  AS TurnoverUSD,   
   CAST(SUM(Winlost*e.USD) AS MONEY)	  AS WinlostUSD,  
   CAST(SUM(LicenseeWL*e.USD) AS MONEY)  AS LicenseeWLUSD,
   CAST(SUM(Comm * e.USD) AS MONEY)      AS CommUSD,
   CAST(SUM(playercomm*e.USD) AS MONEY)  AS PlayerCommUSD ,
   CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD
FROM	
	#tmpWinloss b   
	INNER JOIN  #TempExchange e
	ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
GROUP BY ProductCode
ORDER BY ProductName  


DROP TABLE 	#tmpWinloss
DROP TABLE 	#TempExchange

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportSummary] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportSummary] TO [vnteam] 
