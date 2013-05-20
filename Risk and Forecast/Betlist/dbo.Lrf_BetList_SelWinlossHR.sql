ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossHR]
	 --@CustID INT=null, --AgentID  
	 @LicenseeID INT ,
	 @UserID	INT,
     @LicenseeType VARCHAR(100) = NULL ,
     @CurrencyID  INT=0,
	 @Bettype INT,  
	 @LeagueId INT,  
	 @RaceNo VARCHAR(50),  
	 @FromDate smalldatetime,  
	 @ToDate smalldatetime,  
	 @MoveBetsDay smalldatetime ,
	 @PageSize INT=1000,
	 @PageIndex INT=1,
	 @TotalRows INT=0 OUTPUT ,
	 @SumWinlost MONEY=0 OUTPUT,
	 @SumLicenseeWL MONEY=0 OUTPUT,
	 @SumComm MONEY=0 OUTPUT,
	 @SumPlayerComm MONEY=0 OUTPUT,
	 @SumWinlostUSD MONEY=0 OUTPUT,
	 @SumLicenseeWLUSD MONEY=0 OUTPUT,
	 @SumCommUSD MONEY=0 OUTPUT,
	 @SumPlayerCommUSD MONEY=0 OUTPUT,
	 @SumWinlostEUR MONEY=0 OUTPUT,
	 @SumLicenseeWLEUR MONEY=0 OUTPUT,
	 @SumCommEUR MONEY=0 OUTPUT,
	 @SumPlayerCommEUR MONEY=0 OUTPUT 
AS  

/*
Created: Henry@20101210
Task : Betlist HR
DB: DB052.bodb02
Original: Age_BetList_SelWinlossHR_Ag
Revisions:    
    -- 20110214@Jacob: Add column discount in the result SET
    -- 20110216@Jacob: Add column nickname in the result SET
    -- 20110303@Henry: suppport based currency
    -- 20110506@Henry: fix bug do not have data if only parameter @CustID --> change to param: @LicenseeID, @LicenseeType, @CurrencyName to get the list of agents
    -- 20110721@Henry: Add Licensee WL
    -- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
	-- 20120726@Jim: add playercomm value 
	-- 20121004@Jim: replace @currencyname input param by @currencyID
	-- 20130305@Jim: change  input param @Race by @RaceNo
	-- 20130514@Jim: Restrict permission of Licensee Users by currency
*/

SET NOCOUNT ON  

DECLARE @TempAg as TABLE (custid INT)

CREATE  TABLE #AgWinlossHR (  
	 sporttype tinyint,  
	 username nvarchar(50),  
	 NickName NVARCHAR(50),
	 bettype SMALLINT,    	 
	 transid bigint,  
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
                WHERE  [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
DROP TABLE #Currency 

IF @Todate > @MoveBetsDay  
BEGIN  
	 INSERT INTO #AgWinlossHR SELECT  
	  l.sporttype,  
	  b.username,  
	  substring(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) as nickname,   		
	  b.bettype,    	   
	  b.transid,  
	  m.groupmatch as race,  
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
	  b.playercomm AS PlayerComm,
	  b.adiscount,
	  b.transdate,  
	  '',  
	  b.apositiontaking,
	  0,
	  b.livehomescore,
	  b.liveawayscore,  
	  l.leagueID,  
	  b.matchid,   
	  b.IP as IP,
  	  NULL,  
	  CONVERT(BIT,0) as IsNeutral,
	  b.winlostdate,
	  b.currency
	 FROM  
	  bettrans b with (nolock)   
	  inner join outright m with (nolock) on b.matchid=m.orid   
	  inner join League l with (nolock) on m.leagueID=l.leagueID   
	  INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	   	 		 
	 WHERE  
	  --b.Recommend=@CustID AND  
	  b.recommend in (SELECT custid from @TempAg) AND
	  b.Winlostdate>=@FromDate AND  
	  b.Winlostdate<=@ToDate AND  
	  l.leagueid = @LeagueId AND  
	  m.groupmatch = @RaceNo AND  
	  b.Bettype= @Bettype AND  
	  b.Ruben=1  
END  
  
IF @Fromdate <= @MoveBetsDay  
BEGIN  
	 INSERT INTO #AgWinlossHR SELECT  
	  l.sporttype,  
	  b.username,  
	  substring(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) as nickname,   		
	  b.bettype,    	    
	  b.transid,  
	  m.groupmatch as race,  
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
	  b.playercomm AS PlayerComm, 
	  b.adiscount,
	  b.transdate,  
	  '',  
	  b.apositiontaking,
	  0,
	  b.livehomescore,
	  b.liveawayscore,    
	  l.leagueID,  
	  b.matchid,   
	  b.IP as IP,
	  NULL,  
	  CONVERT(BIT,0) as IsNeutral,
	  b.winlostdate,
	  b.currency
	 FROM  
	  bettrans14 b with (nolock)   
	  inner join outright14 m with (nolock) on b.matchid=m.orid   
	  inner join League l with (nolock) on m.leagueID=l.leagueID  
	  INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	   	 		
	 WHERE  
	  --b.Recommend=@CustID AND  
	  b.recommend in (SELECT custid from @TempAg) AND
	  b.Winlostdate>=@FromDate AND  
	  b.Winlostdate<=@ToDate AND  
	  l.leagueid = @LeagueId AND  
	  m.groupmatch = @RaceNo AND  
	  b.Bettype=@Bettype AND  
	  b.Ruben=1   
END  
  

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #AgWinlossHR (Currency)

SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #AgWinlossHR)

SELECT 
	@TotalRows = count(transid),
	@SumWinlost=SUM(isnull(winlost,0)),
	@SumLicenseeWL=SUM(isnull(LicenseeWL,0)),
	@SumComm=SUM(isnull(comm,0)) ,
	@SumPlayerComm=SUM(ISNULL(playercomm,0)), 
	--USD
	@SumWinlostUSD=SUM(isnull(winlost*e.USD,0)),
	@SumLicenseeWLUSD=SUM(isnull(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(isnull(comm*e.USD,0)) ,
	@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)),
	--EUR
	@SumWinlostEUR=SUM(isnull(winlost*e.EUR,0)),
	@SumLicenseeWLEUR=SUM(isnull(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(isnull(comm*e.EUR,0)),
	@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0))	
	
	
FROM #AgWinlossHR b
INNER JOIN  #TempExchange e
ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY Status, Transid) as RowNum,
			b.* ,
			--USD
			stake*e.USD stakeUSD,
			winlost*e.USD winlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			--EUR
			stake*e.EUR stakeEUR,
			winlost*e.EUR winlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR PlayercommEUR
			
			
	FROM #AgWinlossHR b
	INNER JOIN  #TempExchange e
	ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency

) A WHERE A.RowNum between @RowStart AND @RowEnd

--get data from bettransm for bettype 33,43
IF @Bettype = 33 OR @Bettype =43
BEGIN
	DECLARE @Bettransm TABLE(  
	 refno bigint,  
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
		FROM bettransm BM with (NOLOCK)
		INNER JOIN #AgWinlossHR B ON BM.refno = B.transid
		WHERE B.Bettype = @Bettype
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
		FROM bettransm14 BM with (NOLOCK)
		INNER JOIN #AgWinlossHR B ON BM.refno = B.transid
		WHERE B.Bettype = @Bettype
	END	
	
	SELECT * FROM @Bettransm ORDER BY RefNo,Bettype
	
END
	
DROP TABLE #TempExchange 
DROP TABLE #AgWinlossHR

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossHR] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossHR] TO [vnteam]