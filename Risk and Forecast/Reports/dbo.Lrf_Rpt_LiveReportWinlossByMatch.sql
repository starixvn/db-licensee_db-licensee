ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportWinlossByMatch]    
	@LicenseeID		INT ,
	@UserID			INT,
    @CurrencyID		INT = NULL , 
    @ShowSB			BIT	= 0,
    @ShowBA			BIT	= 0,
	@ShowLC 		BIT = 0,
	@ShowVS			BIT = 0,
    @SportId		INT = 0,
    @FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS /*
Created: 20111031@
Task : Live Report Summary by Sport
DB: DB052.bodb02

Revisions:
	- 20120110@Henry: remove @LicenseeType + enhance performance + remove currency UUS
	- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120614@Jim: optimize code 
	- 20120726@Jim: add player commission value 
	- 20120820@Jim : add live casino 
	- 20120830@Henry: split column for clearer + Add Virtual Sports
	- 20121004@Jim: replace @currency input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20130618@Jim:  Restrict permission of Licensee Users by currency
	- 20130625@Jim: support to view currency UUS 
Return 3 tables:
WinlostBySport
WinlostByCurrency
WinlostByBetType
Param's Explanation:
	@SportId: Not includes mixparlay, outright, numbergame, horseracing
Example:

DECLARE @FromDate DATETIME
DECLARE @ToDate DATETIME
DECLARE @MoveBetsDay DATETIME
SELECT @FromDate = DATEADD(DAY, -15, GETDATE())
SELECT @ToDate = GETDATE()
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)

EXEC [Lrf_Rpt_LiveReportWinlossByMatch_xtest]	 @LicenseeId = 1, @CurrencyID = 0, @FromDate=@FromDate, @SportId =1, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay

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

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE ( CustId INT )
INSERT  INTO @TempAg ( CustId)
SELECT  CustID  
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
--WHERE   Currency <> 20
		
DROP TABLE #Currency 
    
DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY)


IF @ShowLC = 1
BEGIN
    INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END


IF @ShowVS = 1
BEGIN
	INSERT INTO @bettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END  

CREATE TABLE #tmpWinloss (
	winlostdate		DATETIME,  
	Currency		INT,
	MatchId			INT,	
	HomeId			INT,
	AwayId			INT,
	TurnOver		MONEY,   	
	Winlost			MONEY,  
	LicenseeWL		MONEY, 
	Comm			MONEY,  
	PlayerComm		MONEY,	
	AmtDueTo3rd		MONEY,
	Betcount		INT,
	Bettype			INT,
	showtime 		NVARCHAR(50) -- table - shoe - hand of Live Casino
)	

IF @TDate > @MoveBetsDay
BEGIN
	IF @FDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FDate

	

	IF @ShowBA = 1 
	BEGIN
		
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			0 AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid				
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  			
			b.matchid > 0 AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.statusID IN (111,112,113) AND
			b.tpositiontaking=0 AND
			m.sporttype = @SportId 
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
				
	END
	
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  	
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype, 
			'' AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid				
			INNER JOIN @TempAg t ON b.recommend = t.custid
			
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.matchid > 0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId AND
			b.tpositiontaking<>0
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
	END

	IF ( @ShowLC=1 OR @ShowVS=1)
	BEGIN
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  	
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  b.playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype, 
			CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		FROM bettrans b  WITH (NOLOCK) 
			INNER JOIN [match] m WITH(NOLOCK) ON b.matchid=m.matchid				
			INNER JOIN @TempAg t ON b.recommend = t.custid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate AND  
			b.matchid > 0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype,
					CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END 
				
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
		
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			0 AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (  playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			b.Recommend IN ( SELECT custid FROM @TempAg)  AND    
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.tpositiontaking=0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId 	
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
	END			
			
	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			'' AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			INNER JOIN @TempAg t ON b.recommend = t.custid
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			
			
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId 
			
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype
				
	END		
			
	IF (@ShowLC = 1 OR @ShowVS = 1)
	BEGIN
		
		INSERT INTO #tmpWinloss			
		SELECT
			b.winlostdate,  
			b.currency,
			m.matchid, 		
			m.homeid, 
			m.awayid,	
			SUM(stake) turnover, 
			SUM(b.winlost - b.actual_stake) AS Winlost,  		
			SUM(-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,
			SUM (comm ) as Comm,
			SUM (playercomm  ) as PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			COUNT(b.transid) BetCount,
			b.bettype,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		FROM bettrans14 b  WITH (NOLOCK) 
			INNER JOIN @TempAg t ON b.recommend = t.custid
			INNER JOIN [match14] m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
			
		WHERE
			b.winlostdate BETWEEN @FDate AND @TempToDate  AND
			b.statusID IN (111,112,113) AND
			m.sporttype = @SportId
		GROUP BY  b.winlostdate, b.currency, b.matchid, m.matchid, m.homeid, m.awayid,b.bettype, 
				CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END
	END		
	
	
	
END	
-- Get winlost by match 
CREATE NONCLUSTERED INDEX IX_tmpWinloss on #tmpWinloss (Currency)

SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss)

SELECT
	b.matchid,	
	b.homeid,	
	b.awayid,
	--b.bettype,
	CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN b.bettype ELSE 0 END as bettype,
	CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(b.showtime,'') ELSE '' END AS ShowTime ,
	SUM(TurnOver)	AS Turnover,   
	SUM(Winlost)		AS Winlost,  
	SUM(LicenseeWL) AS LicenseeWL,
	SUM(Comm) AS Comm,
	SUM(PlayerComm) AS PlayerComm,
	SUM(AmtDueto3rd) AS AmtDueto3rd,
	SUM(Betcount)	AS Betcount,
	
	--BaseEUR  
	CAST(SUM(TurnOver*e.EUR) AS MONEY)	AS TurnoverEUR,   
	CAST(SUM(Winlost*e.EUR) AS MONEY)	AS WinlostEUR,  
	CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,
	CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,
	CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR,
	CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,

	CAST(SUM(TurnOver*e.USD) AS MONEY)	AS TurnoverUSD,   
	CAST(SUM(Winlost*e.USD) AS MONEY)	AS WinlostUSD,  
	CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,
	CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD,
	CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD,
	CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD
FROM #tmpWinloss b  WITH (NOLOCK) 	
	INNER JOIN  #TempExchange e
	ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
group by b.matchid, b.homeid, b.awayid,CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN b.bettype ELSE 0 END ,CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(b.showtime,'') ELSE '' END

DROP TABLE #TempExchange
DROP TABLE #tmpWinloss
	
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportWinlossByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportWinlossByMatch] TO [vnteam]  