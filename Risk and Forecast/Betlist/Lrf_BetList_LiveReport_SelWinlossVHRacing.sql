ALTER   PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossVHRacing]	 
	@LicenseeID INT ,
	@UserID		INT,
	@CurrencyID INT = 0 , 
	@SportType	INT = 181,	 
	@FromDate SMALLDATETIME,  
	@ToDate SMALLDATETIME,  
	@MoveBetsDay SMALLDATETIME ,
	@SUMWL MONEY=0 OUTPUT,
	@SUMLicenseeWL MONEY=0 OUTPUT,
	@SUMWLUSD MONEY=0 OUTPUT,
	@SUMLicenseeWLUSD MONEY=0 OUTPUT,
	@SUMWLEUR MONEY=0 OUTPUT,
	@SUMLicenseeWLEUR MONEY=0 OUTPUT,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@Sort VARCHAR(20) = 'Transid DESC'	 
AS  

/*
Created: Jim@20130912
Task : Betlist VHR for Live Report
DB: DB052.bodb02
Original: 
Revisions:   
	- 20140520@Hannah: Sort betlist    
	- 20140522@Hannah: fix bug Sort betlist
	- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
*/

SET NOCOUNT ON  

CREATE TABLE #TempAg (custid INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME
DECLARE @TempCount INT
DECLARE @RowStart INT, @RowEnd INT  
DECLARE @DataSum AS TABLE (SUMWL MONEY,SUMLicenseeWL MONEY,Winlostdate DATETIME,Currency INT)

SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE TABLE #Data
(
	sporttype TINYINT,  
	Custid INT,
	refno BIGINT,
	username nvarchar(50),  	 
	bettype SMALLINT,    	 
	transid BIGINT PRIMARY KEY,  
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
	discount MONEY,
	playerdiscount MONEY,
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
	playercomm MONEY,
	showtime  	DATETIME,
	--USD
	stakeUSD MONEY,
	winlostUSD MONEY,
	LicenseeWLUSD MONEY,
	commUSD MONEY,
	playercommUSD MONEY,
	--EUR
	stakeEUR MONEY,
	winlostEUR MONEY,
	LicenseeWLEUR MONEY,
	commEUR MONEY,
	playercommEUR MONEY
)
SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT  INTO #TempAg ( CustId)
SELECT  DISTINCT lc.CustID  
FROM    bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )  
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
--------------------------------------------------------		
DROP TABLE #Currency 
--------------------------------------------------------  
DECLARE @sql NVARCHAR(2500)
DECLARE @SortTemp VARCHAR(250) 
DECLARE @LicenseeWL VARCHAR(150) 
SET @LicenseeWL = '(-(b.winlost-b.actual_stake))'		
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
	  '+CAST(@SportType AS VARCHAR(15))+',  
	  b.custid,
	  b.refno,
	  b.username,  	  
	  b.bettype,    	    
	  b.transid,  
	  b.oddsid AS race,  
	  CONVERT(VARCHAR(50),o.RacerNum) matchcode,  
	  o.RacerID teamID,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake) AS winlost,  
	  (-(b.winlost-actual_stake)) AS licenseeWL,
	  b.comm AS Comm, 
	  b.adiscount AS discount,
	  b.playerdiscount AS playerdiscount,
	  b.transdate,  
	  '''',  
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
	  b.playercomm,
	  r.EventTime,
	  --USD
	  stake*e.USD stakeUSD,
	  '+@winlost+'*e.USD winlostUSD,
	  '+@LicenseeWL+'*e.USD LicenseeWLUSD,
	  comm*e.USD commUSD,
	  (b.playercomm * e.USD) AS playercommUSD,
	  --EUR
	  stake*e.EUR stakeEUR,
	  '+@winlost+'*e.EUR winlostEUR,
	  '+@LicenseeWL+'*e.EUR LicenseeWLEUR,
	  comm*e.EUR commEUR,
	  (b.playercomm * e.EUR) AS playercommEUR
	 FROM  
	  bettrans14 b WITH (NOLOCK)
	  INNER JOIN #TempAg t  ON b.recommend =t.custid     
	  INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid=o.Orid
	  INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
   	  INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
	 WHERE  	 	  
	  b.Winlostdate BETWEEN '''+CAST(@FromDate AS VARCHAR(50))+''' AND '''+CAST(@TempToDate AS VARCHAR(50))+''' AND 	  
	  r.SportType= '+CAST(@SportType AS VARCHAR(15))+' AND
	  b.bettype IN (1231,1232,1233,1237,1238) AND 
	  b.statusID IN (111,112,113)
	 ORDER  BY '+ @SortTemp 
	  
	INSERT INTO #Data
	(sporttype,Custid,refno,username,bettype,transid,race,matchcode,homeID,awayID,hdp1,  
	hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,discount,playerdiscount,transdate,  
	betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,leagueID,matchid,   
	IP,betstatus,isNeutral,winlostdate,currency,playercomm,showtime,
	stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,playercommUSD,
	stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,playercommEUR)
	EXEC (@sql)
	
	INSERT INTO @DataSum
	SELECT SUM(b.winlost-actual_stake+playercomm),
			SUM(b.awinlost+comm),
			b.Winlostdate,
			b.Currency
	FROM
		bettrans14 b WITH (NOLOCK)
		INNER JOIN #TempAg t  ON b.recommend =t.custid     
		INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID  
	WHERE  	 	  
		b.Winlostdate BETWEEN @FromDate AND @TempToDate AND 	  
		r.SportType= @SportType AND
		b.bettype IN (1231,1232,1233,1237,1238) AND 
		b.statusID IN (111,112,113)	
	GROUP BY b.Winlostdate,b.Currency 	
END  

SELECT @TempCount = COUNT(1) FROM #Data

IF @Todate > @MoveBetsDay  AND @TempCount < @RowEnd
BEGIN  
	IF @FromDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate
		
	 --INSERT INTO #Data 
	 SELECT @sql =
	 'SELECT TOP ('+CAST(@RowEnd AS VARCHAR(50))+')
	  '+CAST(@SportType AS VARCHAR(15))+',  
	  b.custid,
	  b.refno,
	  b.username,  	  
	  b.bettype,    	    
	  b.transid,  
	  b.oddsid AS race,  
	  CONVERT(VARCHAR(50),o.RacerNum) matchcode,  
	  o.RacerID teamID,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake) AS winlost,  
	  (-(b.winlost-actual_stake)) AS licenseeWL,
	  b.comm AS Comm, 
	  b.adiscount AS discount,
	  b.playerdiscount AS playerdiscount,
	  b.transdate,  
	  '''',  
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
	  b.playercomm ,
	  r.EventTime,
	  --USD
	  stake*e.USD stakeUSD,
	  '+@winlost+'*e.USD winlostUSD,
	  '+@LicenseeWL+'*e.USD LicenseeWLUSD,
	  comm*e.USD commUSD,
	  (b.playercomm * e.USD) AS playercommUSD,
	  --EUR
	  stake*e.EUR stakeEUR,
	  '+@winlost+'*e.EUR winlostEUR,
	  '+@LicenseeWL+'*e.EUR LicenseeWLEUR,
	  comm*e.EUR commEUR,
	  (b.playercomm * e.EUR) AS playercommEUR
	 FROM  
	  bettrans b WITH (NOLOCK)
	  INNER JOIN #TempAg t  ON b.recommend =t.custid     
	  INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid=o.Orid
	  INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
	  INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate	  
	 WHERE  	 	  
	  b.Winlostdate BETWEEN '''+CAST(@TempFromDate AS VARCHAR(50))+''' AND '''+CAST(@ToDate AS VARCHAR(50))+''' AND 	  
	  r.SportType= '+CAST(@SportType AS VARCHAR(15))+' AND
	  b.bettype IN (1231,1232,1233,1237,1238) AND 
	  b.statusID IN (111,112,113)
	 ORDER  BY '+ @SortTemp 

	INSERT INTO #Data
	(sporttype,Custid,refno,username,bettype,transid,race,matchcode,homeID,awayID,hdp1,  
	hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,discount,playerdiscount,transdate,  
	betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,leagueID,matchid,   
	IP,betstatus,isNeutral,winlostdate,currency,playercomm,showtime,
	stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,playercommUSD,
	stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,playercommEUR)
	EXEC (@sql)
	
	INSERT INTO @DataSum 
	SELECT SUM(b.winlost-actual_stake),
		SUM(	b.awinlost),
		b.Winlostdate,
		b.Currency
		   
	FROM  
	bettrans b WITH (NOLOCK)   
	INNER JOIN #TempAg t  ON b.recommend =t.custid  
	INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid=o.Orid
	INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID 	  
	WHERE  	    	  
	b.Winlostdate BETWEEN @TempFromDate AND @ToDate AND  
	r.SportType= @SportType AND
	b.bettype IN (1231,1232,1233,1237,1238) AND 
	b.statusID IN (111,112,113)		
	GROUP BY b.winlostdate,b.Currency 	
END  

CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

SELECT @sql = 
'SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY '+ @Sort+') AS RowNum,
			b.sporttype,b.Custid,b.refno,b.username,b.bettype,b.transid,b.race,b.matchcode,b.homeID,b.awayID,b.hdp1,  
			b.hdp2,b.Modds,b.odds,b.status,b.stake,b.winlost,b.licenseeWL,b.comm,b.discount,b.playerdiscount,b.transdate,  
			b.betteam,b.apositiontaking,b.liveindicator,b.livehomescore,b.liveawayscore,b.leagueID,b.matchid,   
			b.IP,b.betstatus,b.isNeutral,b.winlostdate,b.currency,b.playercomm,b.showtime,
			SUBSTRING(c.username2,  CHARINDEX(''$'',c.username2)+1, len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,   		
			--USD
			b.stakeUSD,
			b.winlostUSD,
			b.LicenseeWLUSD,
			b.commUSD,
			b.playercommUSD,
			--EUR
			b.stakeEUR,
			b.winlostEUR,
			b.LicenseeWLEUR,
			b.commEUR,
			b.playercommEUR			
	FROM #Data b
	INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
) A WHERE A.RowNum between '+CAST(@RowStart AS VARCHAR(50))+' AND '+CAST(@RowEnd AS VARCHAR(50))
+' ORDER BY A.RowNum'
EXEC (@sql)

--get data from bettransm for bettype 1233
DECLARE @Bettransm TABLE(  
 refno BIGINT,  
 finalodds SMALLMONEY,
 odds SMALLMONEY,  
 status nvarchar(10),  
 apositiontaking SMALLMONEY,  
 bettype SMALLINT
 )   

IF @Todate > @MoveBetsDay 
BEGIN
	INSERT INTO @Bettransm
	SELECT 
		BM.refno, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.apositiontaking, 
		BM.bettype  
	FROM bettransm BM WITH (NOLOCK)
	INNER JOIN #Data B ON BM.refno = B.refno	
	WHERE b.bettype=1233
END
	
IF @Fromdate <= @MoveBetsDay
BEGIN
	INSERT INTO @Bettransm
	SELECT 
		BM.refno, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.apositiontaking, 
		BM.bettype  
	FROM bettransm14 BM WITH (NOLOCK)
	INNER JOIN #Data B ON BM.refno = B.refno
	WHERE b.bettype=1233	
END	

SELECT * FROM @Bettransm ORDER BY RefNo,Bettype

DROP TABLE #Data
DROP TABLE #TempExchange 
DROP TABLE #TempAg

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossVHRacing] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossVHRacing] TO [vnteam] 