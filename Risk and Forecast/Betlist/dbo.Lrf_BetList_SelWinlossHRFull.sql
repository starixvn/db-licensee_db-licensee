ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossHRFull]	 
	 @LicenseeID INT ,
	 @UserID	INT,
     @LicenseeType VARCHAR(100) = NULL ,
     @CurrencyID INT=0 ,
     @SportType	INT = 151,	 
	 @FromDate SMALLDATETIME,  
	 @ToDate SMALLDATETIME,  
	 @MoveBetsDay SMALLDATETIME ,
	 @PageSize INT=1000,
	 @PageIndex INT=1
AS  

/*
Created: Jacob@20111110
Task : Betlist HR
DB: DB052.bodb02
Original: [Lrf_BetList_SelWinlossHR]
Revisions:        
    Get all HR/Greyhound/Harness tickets in a duration FromDate => ToDate 
    -20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
    - 20120614@Jim: optimize code 
	- 20120724@Jim: add player commision value 
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim: Restrict permission of Licensee Users by currency
*/

SET NOCOUNT ON  

DECLARE @TempAg AS TABLE (custid INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME
DECLARE @TempCount INT
DECLARE @RowStart INT, @RowEnd INT  

SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE TABLE #Data
(
	sporttype TINYINT,  
	Custid INT,
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
SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
						INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
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
	  @SportType,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	    
	  b.transid,  
	  m.groupmatch AS race,  
	  m.matchcode,  
	  m.teamID,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake),  
	  b.awinlost,
	  comm, 
	  b.playercomm,
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
	  b.currency
	 FROM  
	  bettrans14 b WITH (NOLOCK,INDEX=bettrans143)
	  INNER JOIN @TempAg t  ON b.recommend =t.custid     
	  INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid=m.orid   
	  INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID  	  
	 WHERE  	 	  
	  b.Winlostdate BETWEEN @FromDate AND @TempToDate AND 	  
	  l.SportType= @SportType AND
	  b.Ruben=1 AND
	  b.bettype BETWEEN 31 AND 33 AND
	  b.statusID NOT IN (101, 102, 103)
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
	  @SportType,  
	  b.custid,
	  b.username,  	  
	  b.bettype,    	   
	  b.transid,  
	  m.groupmatch AS race,  
	  m.matchcode,  
	  m.teamID,  
	  0,  
	  b.hdp1,  
	  b.hdp2,  
	  modds,
	  b.odds,  
	  b.status,  
	  b.stake,  
	  (b.winlost-actual_stake),  
	  b.awinlost,
	  b.comm,
	  b.playercomm,
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
	  b.currency
	 FROM  
	  bettrans b WITH (NOLOCK)   
	  INNER JOIN @TempAg t  ON b.recommend =t.custid  
	  INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid   
	  INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID   	  
	 WHERE  	    	  
	  b.Winlostdate BETWEEN @TempFromDate AND @ToDate AND  
	  l.SportType= @SportType AND
	  b.Ruben=1 AND
	  b.bettype BETWEEN 31 AND 33 AND
	  b.statusID NOT IN (101, 102, 103)
END  

CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #Data (Currency)
SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY Transid) AS RowNum,
			b.* ,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			--USD
			stake*e.USD stakeUSD,
			winlost*e.USD winlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD playercommUSD,
			--EUR
			stake*e.EUR stakeEUR,
			winlost*e.EUR winlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR playercommEUR
			
			
	FROM #Data b
	INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
	INNER JOIN  #TempExchange e
	ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
) A WHERE A.RowNum between @RowStart AND @RowEnd

--get data from bettransm for bettype 33,43

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
	INNER JOIN #Data B ON BM.refno = B.transid	
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
	INNER JOIN #Data B ON BM.refno = B.transid	
END	

SELECT * FROM @Bettransm ORDER BY RefNo,Bettype

DROP TABLE #Data
DROP TABLE #TempExchange	

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossHRFull] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossHRFull] TO [vnteam]