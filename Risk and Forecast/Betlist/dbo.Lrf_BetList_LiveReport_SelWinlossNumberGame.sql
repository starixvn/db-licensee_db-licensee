use bodb02
go
set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame]	 
	 @LicenseeID INT ,
	 @UserID	 INT,
     @CurrencyID INT = 0 ,     
	 @FromDate SMALLDATETIME,  
	 @ToDate SMALLDATETIME,  
	 @MoveBetsDay SMALLDATETIME ,
	 @PageSize INT=1000,
	 @PageIndex INT=1,
	 @Sort VARCHAR(20) = 'Transid DESC'	 
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
	-20130514@Jim: Restrict permission of Licensee Users by currency
	-20130625@Jim: Support to view currency UUS
	-20140507@Hannah: Sort betlist
*/

SET NOCOUNT ON  

CREATE TABLE #TempAg (custid INT)
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
	 --USD
	 stakeUSD MONEY,
	 winlostUSD MONEY,
	 LicenseeWLUSD MONEY,
	 commUSD MONEY,
     --EUR
	 stakeEUR MONEY,
	 winlostEUR MONEY,
	 LicenseeWLEUR MONEY,
	 commEUR MONEY
)  
CREATE INDEX IX_Data on #Data (Winlostdate, Currency)

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT  INTO #TempAg ( CustId)
SELECT  CustID  
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
-- WHERE    Currency <> 20
		
DROP TABLE #Currency
DECLARE @sql NVARCHAR(2500)
DECLARE @SortTemp VARCHAR(250) 
DECLARE @LicenseeWL VARCHAR(150) 
SET @LicenseeWL = '(-1 * (b.winlost - b.actual_stake))'		
DECLARE @Winlost VARCHAR(150) 
SET @Winlost = '(b.winlost-b.actual_stake)'

IF (@Sort LIKE '%USD%') OR (@Sort LIKE '%EUR%')
BEGIN
	DECLARE @charindex INT
	SELECT @charindex = CHARINDEX( ' ', @Sort, 1)
	IF @Sort LIKE '%Winlost%'
	BEGIN
		SELECT @SortTemp = @Winlost
	 + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
	END
	ELSE
	IF @Sort LIKE '%LicenseeWL%'
	BEGIN
		SELECT @SortTemp = @LicenseeWL
	 + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
	END
	ELSE
	BEGIN
		SELECT @SortTemp = substring (@Sort, 1, @charindex - 4) + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
	END	
END
ELSE
BEGIN
	SET @SortTemp = @Sort
END

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)

IF @Fromdate <= @MoveBetsDay 
BEGIN  

	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @ToDate
		
	 --INSERT INTO #Data 
	 SELECT @sql =
	 'SELECT TOP ('+CAST(@RowEnd AS VARCHAR(50))+')
	  161,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	    
	  b.transid,  
	  ISNULL(b.BetID,0),
	  '''' AS race,  
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
	  b.currency,
	 --USD
	 stake*e.USD stakeUSD,
	 '+@Winlost+'*e.USD winlostUSD,
	 '+@LicenseeWL+'*e.USD LicenseeWLUSD,
 	 comm*e.USD commUSD,
	 --EUR
	 stake*e.EUR stakeEUR,
	 '+@Winlost+'*e.EUR winlostEUR,
	 '+@LicenseeWL+'*e.EUR LicenseeWLEUR,
	 comm*e.EUR commEUR
	 FROM  
		bettrans14 b WITH (NOLOCK,INDEX(bettrans143))  
		INNER JOIN #TempAg t  ON b.recommend =t.custid 
		INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid   	
		INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate 
	 WHERE  		  
	  b.bettype BETWEEN 81 AND 120 AND
	  b.Winlostdate BETWEEN '''+CAST(@FromDate AS VARCHAR(50))+''' AND '''+CAST(@TempToDate AS VARCHAR(50))+''' AND
	  b.statusID IN (111,112,113)	
	 ORDER  BY '+ @SortTemp 
	 
	 INSERT INTO #Data
     (sporttype,Custid,username,bettype,transid,BetID,race,matchcode,homeID,awayID,hdp1 ,  
	 hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,playercomm,discount ,
	 transdate,betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,  
	 leagueID,matchid,IP,betstatus,isNeutral,winlostdate,currency,
	 stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,stakeEUR,winlostEUR,LicenseeWLEUR,commEUR)
	 EXEC (@sql)
	 
END  

SELECT @TempCount = COUNT(1) FROM #Data

IF @Todate > @MoveBetsDay  AND @TempCount < @RowEnd
BEGIN  

	IF @FromDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate
		
	 --INSERT INTO #Data 
	 SET @sql = 
	 'SELECT TOP ('+CAST(@RowEnd AS VARCHAR(50))+') 
	  161,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	   
	  b.transid, 
	  ISNULL(b.BetID,0), 
	  '''' AS race,  
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
	  b.currency,
	  --USD
	  stake*e.USD stakeUSD,
	  '+@Winlost+'*e.USD winlostUSD,
	  '+@LicenseeWL+'*e.USD LicenseeWLUSD,
 	  comm*e.USD commUSD,
	  --EUR
	  stake*e.EUR stakeEUR,
	  '+@Winlost+'*e.EUR winlostEUR,
	  '+@LicenseeWL+'*e.EUR LicenseeWLEUR,
	  comm*e.EUR commEUR
	 FROM  
	  bettrans b WITH (NOLOCK) 
	  INNER JOIN #TempAg t  ON b.recommend =t.custid  
	  INNER JOIN [match] m WITH (NOLOCK) ON b.matchid=m.matchid   	  
      INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
	 WHERE  	  	  
	  b.bettype BETWEEN 81 AND 120 AND
	  b.Winlostdate BETWEEN '''+CAST(@TempFromDate AS VARCHAR(50))+''' AND '''+CAST(@ToDate AS VARCHAR(50))+''' AND  	  
	  b.statusID IN (111,112,113)
	 ORDER  BY '+ @SortTemp 
	 
	 INSERT INTO #Data
     (sporttype,Custid,username,bettype,transid,BetID,race,matchcode,homeID,awayID,hdp1 ,  
	 hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,playercomm,discount ,
	 transdate,betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,  
	 leagueID,matchid,IP,betstatus,isNeutral,winlostdate,currency,
	 stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,stakeEUR,winlostEUR,LicenseeWLEUR,commEUR)
	 EXEC (@sql)	 
END 

CREATE NONCLUSTERED INDEX IDX_Index_data ON #Data(Currency)

SELECT @sql = 
'SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY '+ @Sort+' ) AS RowNum,
			b.sporttype,b.Custid,b.username,b.bettype,b.transid,b.BetID,b.race,b.matchcode,b.homeID,b.awayID,b.hdp1 ,  
			b.hdp2,b.Modds,b.odds,b.status,b.stake,b.winlost,b.licenseeWL,b.comm,b.playercomm,b.discount ,
			b.transdate,b.betteam,b.apositiontaking,b.liveindicator,b.livehomescore,b.liveawayscore,  
			b.leagueID,b.matchid,b.IP,b.betstatus,b.isNeutral,b.winlostdate,b.currency,
			SUBSTRING(c.username2,  CHARINDEX(''$'',c.username2)+1, len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,   		
			--USD
			b.stakeUSD,
			b.winlostUSD,
			b.LicenseeWLUSD,
			b.commUSD,
			--EUR
			b.stakeEUR,
			b.winlostEUR,
			b.LicenseeWLEUR,
			b.commEUR			
	FROM #Data b
	INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
) A WHERE A.RowNum BETWEEN '+CAST(@RowStart AS VARCHAR(50))+' AND '+CAST(@RowEnd AS VARCHAR(50))

EXEC (@sql)

DROP TABLE #Data	
DROP TABLE #TempExchange 
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame] TO [vnteam] 