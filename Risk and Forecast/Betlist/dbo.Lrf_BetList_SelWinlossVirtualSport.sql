 ALTER  PROCEDURE [dbo].[Lrf_BetList_SelWinlossVirtualSport]	 
	 @LicenseeID INT ,
	 @UserID	 INT,
     @LicenseeType VARCHAR(100) = NULL ,
     @CurrencyID INT=0,     
	 @FromDate SMALLDATETIME,  
	 @ToDate SMALLDATETIME,  
	 @MoveBetsDay SMALLDATETIME ,
	 @PageSize INT=1000,
	 @PageIndex INT=1	 
AS  

/*
Created: Jim@20120924
Task : Virtual Sports winloss report - Betlist
DB: DB052.bodb02
Original:Lrf_BetList_SelWinlossLiveCasino
Revisions:        
     - 20121004@Jim: replace @currencyname input param by @currencyID
	 - 20130514@Jim: Restrict permission of Licensee Users by currency
	 - 20130904@Jim: support Virtual Horse Racing
*/


SET NOCOUNT ON  

DECLARE @TempAg AS TABLE (custid INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME
DECLARE @TempCount INT
DECLARE @RowStart INT, @RowEnd INT  

SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE TABLE #Data (  
	 sporttype TINYINT,  
	 Custid INT,
	 username nvarchar(50),  	 
	 bettype SMALLINT,    	 
	 transid BIGINT,  
	 BetID BIGINT,
	 race VARCHAR(50),  
	 matchcode VARCHAR(50),  
	 homeID INT,  
	 awayID INT,  
	 hdp1 SMALLMONEY,  
	 hdp2 SMALLMONEY,  
	 Modds SMALLMONEY,
	 odds SMALLMONEY,  
	 status nvarchar(50),  
	 stake MONEY,  
	 winlost MONEY,  
	 licenseeWL MONEY,
	 comm MONEY,
	 playercomm MONEY,
	 discount MONEY,
	 transdate DATETIME,  
	 betteam nvarchar(25),  
	 apositiontaking SMALLMONEY,  
	 liveindicator BIT,  
	 livehomescore SMALLINT,  
	 liveawayscore SMALLINT,  
	 leagueID INT,  
	 matchid INT,   
	 IP VARCHAR(30),  
	 betstatus VARCHAR(50),  
	 isNeutral BIT ,
	 winlostdate DATETIME,
	 currency SMALLINT,
	 refno BIGINT
)  
CREATE INDEX IX_Data on #Data (Winlostdate, Currency)

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
						INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE    [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
DROP TABLE #Currency

IF @Fromdate <= @MoveBetsDay 
BEGIN  

	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @ToDate
		
	 INSERT INTO #Data 
	 SELECT TOP (@RowEnd)
	  180,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	    
	  b.transid,  
	  ISNULL(b.BetID,0),
	  '' AS race,  
	  m.matchcode,  
	  0,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake),  
	  (-1 * (b.winlost - b.actual_stake))  AS LicenseeWL,    
      comm , 
	  playercomm,
	  b.adiscount,
	  b.transdate,  
	  '',  
	  b.apositiontaking,
	  0,
	  b.livehomescore,
	  b.liveawayscore,    
	  m.leagueID,  
	  b.matchid,   
	  b.IP AS IP,
	  NULL,  
	  CONVERT(BIT,0) AS IsNeutral,
	  b.winlostdate,
	  b.currency,
	  b.refno
	 FROM  
		bettrans14 b WITH (NOLOCK,INDEX(bettrans143))  
		INNER JOIN @TempAg t  ON b.recommend =t.custid 
		INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid   	  
	 WHERE  		  
	  b.bettype BETWEEN 1201 AND 1299 AND
	  b.Winlostdate BETWEEN @FromDate AND @TempToDate AND
	  b.statusID IN (111,112,113)	
	-- VHR
	UNION ALL 
	 SELECT TOP (@RowEnd)
	  181,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	    
	  b.transid,  
	  ISNULL(b.BetID,0),
	  b.oddsid AS race,  
	  CONVERT(VARCHAR(50),o.RacerNum) matchcode,  
	  0,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake),  
	  (-1 * (b.winlost - b.actual_stake))  AS LicenseeWL,    
      comm , 
	  playercomm,
	  b.adiscount,
	  b.transdate,  
	  '',  
	  b.apositiontaking,
	  0,
	  b.livehomescore,
	  b.liveawayscore,    
	  r.leagueID,  
	  o.EventID matchid,   
	  b.IP AS IP,
	  NULL,  
	  CONVERT(BIT,0) AS IsNeutral,
	  b.winlostdate,
	  b.currency,
	  b.refno
	 FROM
		bettrans14 b WITH (NOLOCK)  
		INNER JOIN @TempAg t  ON b.recommend =t.custid 
		INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	 	  
	 WHERE  		  
	  b.bettype BETWEEN 1201 AND 1299 AND
	  b.Winlostdate BETWEEN @FromDate AND @TempToDate AND
	  b.statusID IN (111,112,113)		
	 ORDER BY transid
END  

SELECT @TempCount = COUNT(1) FROM #Data

IF @Todate > @MoveBetsDay  AND @TempCount < @RowEnd
BEGIN  

	IF @FromDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate
		
	 INSERT INTO #Data 
	 SELECT TOP (@RowEnd) 
	  180,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	   
	  b.transid, 
	  ISNULL(b.BetID,0), 
	  '' AS race,  
	  m.matchcode,  
	  0,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake),  
	  (-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,    
      comm , 
	  playercomm,
	  b.adiscount,
	  b.transdate,  
	  '', 
	  b.apositiontaking,
	  0,
	  b.livehomescore,
	  b.liveawayscore,  
	  m.leagueID,  
	  b.matchid,   
	  b.IP AS IP,
  	  NULL,  
	  CONVERT(BIT,0) AS IsNeutral,
	  b.winlostdate,
	  b.currency,
	  b.refno
	 FROM  
	  bettrans b WITH (NOLOCK) 
	  INNER JOIN @TempAg t  ON b.recommend =t.custid  
	  INNER JOIN [match] m WITH (NOLOCK) ON b.matchid=m.matchid   	  
	 WHERE  	  	  
	  b.bettype BETWEEN 1201 AND 1299 AND
	  b.Winlostdate BETWEEN @TempFromDate AND @ToDate AND  	  
	  b.statusID IN (111,112,113)
	 -- VHR
	UNION ALL 
	 SELECT TOP (@RowEnd)
	  181,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	    
	  b.transid,  
	  ISNULL(b.BetID,0),
	  b.oddsid AS race,  
	  CONVERT(VARCHAR(50),o.RacerNum) matchcode,  
	  0,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake),  
	  (-1 * (b.winlost - b.actual_stake))  AS LicenseeWL,    
      comm , 
	  playercomm,
	  b.adiscount,
	  b.transdate,  
	  '',  
	  b.apositiontaking,
	  0,
	  b.livehomescore,
	  b.liveawayscore,    
	  r.leagueID,  
	  o.EventID matchid,   
	  b.IP AS IP,
	  NULL,  
	  CONVERT(BIT,0) AS IsNeutral,
	  b.winlostdate,
	  b.currency,
	  b.refno
	 FROM
		bettrans b WITH (NOLOCK)  
		INNER JOIN @TempAg t  ON b.recommend =t.custid 
		INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	 	  
	 WHERE  		  
	  b.bettype BETWEEN 1201 AND 1299 AND
	  b.Winlostdate BETWEEN @FromDate AND @TempToDate AND
	  b.statusID IN (111,112,113)		
	 ORDER BY transid 
	
END  

CREATE NONCLUSTERED INDEX IDX_Index_data ON #Data(Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY transid desc) AS RowNum,
			b.* ,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			--USD
			stake*e.USD stakeUSD,
			winlost*e.USD winlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			--EUR
			stake*e.EUR stakeEUR,
			winlost*e.EUR winlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR
			
	FROM #Data b
	INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
	INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

CREATE TABLE #DetailTicket
(
refno bigint,
odds smallmoney,
stake money,
status NVARCHAR(10),
apositiontaking smallmoney,
bettype INT,
Betteam nvarchar,
stakeEUR  money,
stakeUSD money,
)
IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO #DetailTicket
		SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype  ,
				BG.Betteam,
				BG.stake*e.EUR,
				BG.stake*e.USD
			FROM bettransm BG WITH (NOLOCK)
			INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype=1233
	END
IF @Fromdate <= @MoveBetsDay 
	BEGIN 
		INSERT INTO #DetailTicket
		SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype  ,
				BG.Betteam,
				BG.stake*e.EUR,
				BG.stake*e.USD
			FROM bettransm14 BG WITH (NOLOCK)
			INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype=1233
	END
SELECT * FROM #DetailTicket

DROP TABLE 	#DetailTicket
DROP TABLE #Data	
DROP TABLE #TempExchange 

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossVirtualSport] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossVirtualSport] TO [vnteam] 

 