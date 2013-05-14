---
set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame]	 
	 @LicenseeID INT ,
     @CurrencyID INT = 0 ,     
	 @FromDate SMALLDATETIME,  
	 @ToDate SMALLDATETIME,  
	 @MoveBetsDay SMALLDATETIME ,
	 @PageSize INT=1000,
	 @PageIndex INT=1	 
AS  

/*

Created: Henry@20120119
Task : Betlist Number Game
DB: DB052.bodb02
Original: [Lrf_BetList_SelWinlossNumberGame]
Revisions:        
    Get all Number Game ticket in a duration FromDate => ToDate
    -20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
    -20120614@Jim: optimize code
	-20120724@Jim: add player commision value 
	-20121004@Jim: replace @currency input param by @currencyID
	-20130403@Jim: fix bug page index and liveindicator value 
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
	 currency SMALLINT
)  
CREATE INDEX IX_Data on #Data (Winlostdate, Currency)


INSERT  INTO @TempAg ( CustId)
SELECT  CustID  
FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
WHERE   LicenseeID = @LicenseeID  
		AND Currency <> 20
		AND (@CurrencyID=0 OR (@CurrencyID <> 0 AND Currency = @CurrencyID))

  


IF @Fromdate <= @MoveBetsDay 
BEGIN  

	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @ToDate
		
	 INSERT INTO #Data 
	 SELECT TOP (@RowEnd)
	  161,  
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
	  b.betteam,  
	  b.apositiontaking,
	  b.liveindicator,
	  b.livehomescore,
	  b.liveawayscore,    
	  m.leagueID,  
	  b.matchid,   
	  b.IP AS IP,
	  NULL,  
	  CONVERT(BIT,0) AS IsNeutral,
	  b.winlostdate,
	  b.currency
	 FROM  
		bettrans14 b WITH (NOLOCK,INDEX(bettrans143))  
		INNER JOIN @TempAg t  ON b.recommend =t.custid 
		INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid   	  
	 WHERE  		  
	  b.bettype BETWEEN 81 AND 120 AND
	  b.Winlostdate BETWEEN @FromDate AND @TempToDate AND
	  b.statusID IN (111,112,113)	
	 ORDER  BY b.transid DESC
	 
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
	  161,  
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
	  b.betteam, 
	  b.apositiontaking,
	  b.liveindicator,
	  b.livehomescore,
	  b.liveawayscore,  
	  m.leagueID,  
	  b.matchid,   
	  b.IP AS IP,
  	  NULL,  
	  CONVERT(BIT,0) AS IsNeutral,
	  b.winlostdate,
	  b.currency
	 FROM  
	  bettrans b WITH (NOLOCK) 
	  INNER JOIN @TempAg t  ON b.recommend =t.custid  
	  INNER JOIN [match] m WITH (NOLOCK) ON b.matchid=m.matchid   	  
	 WHERE  	  	  
	  b.bettype BETWEEN 81 AND 120 AND
	  b.Winlostdate BETWEEN @TempFromDate AND @ToDate AND  	  
	  b.statusID IN (111,112,113)
	 ORDER  BY b.transid DESC
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

DROP TABLE #Data	
DROP TABLE #TempExchange 
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame] TO [vnteam] 

