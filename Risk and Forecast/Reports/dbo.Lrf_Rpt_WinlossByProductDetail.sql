USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossDetail]  
		@LicenseeID INT , 
		@UserID 	INT ,	
		@LicenseeType VARCHAR(100) = NULL ,  
		@CurrencyID INT=0 ,  
		@FromDate SMALLDATETIME ,  
		@ToDate SMALLDATETIME ,  
		@MoveBetsDay SMALLDATETIME ,  
		@showSB BIT = 0,  
		@showRB BIT = 0,  
		@showNG BIT = 0,  
		@showBA BIT = 0,  
		@ShowLC BIT = 0,  
		@ShowVS BIT = 0,  
		@ShowBG BIT = 0,  
		@ShowCS BIT = 0,  
		@PageSize INT = 1000 ,  
		@PageIndex INT = 1  
      
AS /*  
Created: 20101201@Jacob  
Task :   
DB: DB052.bodb02  
Original:Age_Rpt_MatchWinLossDetail_Ag  
Revisions:  
	- 20101201@Jacob: Copy source code from Age_Rpt_MatchWinLossDetail_Ag  
	-- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency  
	- 20110325@Henry: Enhance performance (by using Custid instead of AgentId)  
	- 20110505@Henry: Support filter by Sportbook, RaceBook  
	- 20110519@Henry: Support filter by NumberGame  
	- 20110616@Henry: Suport filter BA tickets + add column commission  
	- 20110707@Henry: show Comm, Amt Due to for each 3rd party product: BA, Racing  
	- 20110729@Henry: offer 3 new bettypes for Number Game + Mix Parlay Combination  
	- 20111208@Jim: change bettype condition  
	- 20120214@Jim: Replace table ExchangeDaily by function Lrf_f_GetExchangeDaily  
	- 20120730@Jim: add playercomm value   
	- 20120815@Henry: add live casino  
	- 20120904@Jim: add virtual sport  
	- 20121004@Jim: replace @currencyname input param by @currencyID  
	- 20121115@Henry: Only Sportsbook needs to exclude BA  
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets  
	- 20130426@Scott: Add more parameter @ShowBG,@ShowCS
	- 20130618@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing 	
	- 20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
	- 20140212@Florent: fix group by, rownumber
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
Param's Explanation:   
   
*/  
  
SET NOCOUNT ON  
DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))  
  
DECLARE @RowStart INT ,  
    @RowEnd INT ,  
    @TotalRows INT ,  
    @Today SMALLDATETIME   
      
DECLARE @_ToDate AS DATETIME  
SET @_ToDate = @todate  
  
DECLARE @_FromDate AS DATETIME  
SET @_FromDate = @fromdate      
       
SELECT  @PageIndex = @PageIndex - 1 ,  
        @RowStart = @PageSize * @PageIndex + 1 ,  
        @RowEnd = @RowStart + @PageSize - 1 ,  
        @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)   
  
SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

  
DECLARE @TempAg AS TABLE ( CustId INT )  
INSERT  INTO @TempAg ( CustId)  
SELECT  CustID    
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )
						INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE    [Description] = COALESCE(@LicenseeType,    
                                                     [Description])  
DROP TABLE #Currency 
													 
DECLARE @bettype AS TABLE (bettype INT)   
  
DECLARE @AgMatchWLDetails TABLE  
(  
 Winlostdate SMALLDATETIME,  
 KickoffTime DATETIME,
 Currency INT,  
 BetGroup INT ,  
 matchid INT ,  
 homeid INT ,  
 awayid INT ,  
 bettype SMALLINT ,  
 sporttype SMALLINT,
 leagueid INT ,  
 turnover MONEY ,  
 MemberWinLost  MONEY ,  
 LicenseeWL  MONEY, --Sportbook and NumberGame  
 WinlossRB  MONEY,  
 AmtDueToBA  MONEY,     
 AmtDueToRB  MONEY,  
 CommBA   MONEY,     
 CommRB   MONEY,     
 PlayerComm  MONEY,     
 race    NVARCHAR(20) ,  
 matchcode   NVARCHAR(50) ,  
 isNeutral   BIT,  
 liveindicator  BIT,  
 showtime  NVARCHAR(50),
 betcount INT
)  
  
DECLARE @TempBetList AS TABLE(  
 Winlostdate  DATETIME,  
 currency   INT,  
 Bettype   INT,  
 Stake   MONEY,  
 Winlost   MONEY,  
 awinlost  MONEY,  
 comm   MONEY,
 oddsid INT,
 playercomm  MONEY,  
 MatchID   INT,  
 Liveawayscore SMALLINT,  
 liveindicator  BIT,  
 tpositiontaking SMALLMONEY ,
 Betcount INT
)  
  
IF @ShowLC = 1  
BEGIN  
   
    INSERT INTO @bettype(bettype)  
 SELECT typeid FROM bettype (NOLOCK)  
 WHERE (typeid BETWEEN 1101 AND 1199)  
END  
   
  
IF @ShowNG = 1  
BEGIN  
 INSERT INTO @bettype(bettype)  
 SELECT typeid FROM bettype (NOLOCK)  
 WHERE (typeid BETWEEN 81 AND 120)  
END   
  
IF @ShowVS = 1  
BEGIN  
   
 INSERT INTO @bettype(bettype)  
 SELECT typeid FROM bettype (NOLOCK)  
 WHERE (typeid BETWEEN 1201 AND 1299)  
END  
  
IF @_Todate > @MoveBetsDay   
BEGIN  
   
  
 IF @ShowBA = 1  
 BEGIN  
  INSERT INTO @TempBetList   
  SELECT    
   b.Winlostdate,  
   b.currency,  
   b.bettype ,  
   SUM(case when b.bettype <> 29 then stake else actual_stake end) as Stake,  
   SUM(winlost - actual_stake) as Winlost,  
   0 AS awinlost,  
   SUM(comm),
   b.oddsid,
   SUM(playercomm) AS PlayerComm,  
   b.matchid,  
   0 AS Liveawayscore,  
   0 AS liveindicator,  
   0 AS tpositiontaking,
   count(1) betcount
  FROM      
   bettrans b WITH(NOLOCK)  
   INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend = BA.recommend AND b.transid = BA.transid     
  WHERE     
    b.recommend IN (SELECT custid FROM @TempAg)  
   AND b.winlostdate BETWEEN @_Fromdate AND @_Todate  
   AND b.statusID IN (111,112,113)  
  GROUP BY  
    b.Winlostdate,  
    b.currency ,
	b.oddsid	,
    b.bettype ,  
    b.matchid  
      
      
  --SB  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   NULL,
   b.currency,  
   0 AS BetGroup ,  
   m.matchid ,  
   m.homeid ,  
   m.awayid ,  
   b.bettype , 
   CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END sporttype,	
   m.leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm ) as CommBA,  
   0 as CommRB,  
   SUM ( playercomm) as PlayerComm,  
   '' ,  
   m.matchcode ,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   0 AS liveindicator,  
   '' AS ShowTime,
   SUM(b.Betcount) betcount
  FROM      
   @TempBetList b  
   INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
     
  WHERE     
   b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999) 
   OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
  GROUP BY  
    b.Winlostdate,  
    b.currency ,  
    m.matchid ,  
    m.homeid ,  
    m.awayid ,  
    b.bettype ,
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END,		
    m.leagueid ,  
    m.matchcode ,  
    m.isNeutral   
      
      
  --Mix Parlay  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,
   b.currency,  
   3 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   9 AS bettype , 
   101 as sporttype,	
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm ) as CommBA,  
   0 as CommRB,  
   SUM (playercomm) as PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime,
   sum(b.Betcount) betcount
  FROM      
   @TempBetList b  
  WHERE     
   b.bettype = 9   
        GROUP BY   
   b.Winlostdate,  
   b.currency  
    
  --Combination Mix Parlay  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   4 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   29 AS bettype ,  
   102 AS sporttype,
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm ) as CommBA,  
   0 as CommRB,  
   SUM(playercomm)AS PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime,
   sum(b.Betcount) betcount
  FROM      
   @TempBetList b  
  WHERE     
   b.bettype = 29  
        GROUP BY   
   b.Winlostdate,  
   b.currency   
    
  --Outright  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   2 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   bettype ,  
   103 As sporttype,
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm ) as CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) as PlayerComm,  
   m.groupmatch AS race ,  
   'ZZZZ' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime,
   sum(b.Betcount) betcount
  FROM      
   @TempBetList b  
   INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE     
   b.bettype = 10  
  GROUP BY   
   b.Winlostdate,b.currency,bettype ,m.groupmatch   
    
 END  
   
 --Get general data  
 DELETE FROM @TempBetList  
 INSERT INTO @TempBetList  
 SELECT    
   b.Winlostdate,  
   b.currency,  
   b.bettype ,  
   SUM(case when b.bettype <> 29 then stake else actual_stake end) as Stake,  
   SUM(winlost - actual_stake) as Winlost,  
   SUM(b.awinlost) AS awinlost,  
   SUM(b.comm) AS comm,
   b.oddsid, 	
   SUM(b.playercomm) AS playercomm,  
   b.matchid,  
   b.Liveawayscore ,  
   CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
   b.tpositiontaking,
   count(1) betcount
  FROM      
   bettrans b WITH(NOLOCK)
  WHERE     
   b.recommend IN (SELECT custid FROM @TempAg)  
   AND b.winlostdate between @_Fromdate and @_Todate  
   AND b.statusID IN (111,112,113)  
   AND b.matchid>0  
  GROUP BY  
    b.Winlostdate,  
    b.currency ,
	b.oddsid,	
    b.bettype ,  
    b.matchid,  
    b.Liveawayscore,  
    CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
    b.tpositiontaking  
      
   
 IF (@ShowSB=1)  
 BEGIN  
  --exclude BA tickets  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   0 AS BetGroup ,  
   m.matchid ,  
   m.homeid ,  
   m.awayid ,  
   b.bettype ,  
   CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END sporttype,
   m.leagueid ,  
   SUM(stake) ,  
   SUM(winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) AS PlayerComm,  
   '' ,  
   m.matchcode ,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator,  
   '' AS ShowTime,
   sum(b.Betcount) betcount
  FROM      
   @TempBetList b  
   INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
  WHERE   
   (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
				 OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
   ) AND  
   b.tpositiontaking <> 0  
  GROUP BY  
    b.Winlostdate,  
    b.currency ,  
    m.matchid ,  
    m.homeid ,  
    m.awayid ,  
    b.bettype , 
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END ,	
    m.leagueid ,  
    m.matchcode ,  
    m.isNeutral,  
    b.liveindicator   
    
  -- Outright   
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   2 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   10 as bettype , 
   103 AS sporttype,	
   0 AS leagueid ,  
   SUM(b.stake) ,  
   SUM(b.winlost) ,  
   - SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM (  b.playercomm ) as PlayerComm,  
   m.groupmatch AS race ,  
   'ZZZZ' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime,
   sum(b.Betcount) betcount  
  FROM      
   @TempBetList b  
   INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE     
   b.bettype = 10 AND b.tpositiontaking <> 0  
  GROUP BY   
   b.Winlostdate,b.currency,m.groupmatch    
      
  -- MixParlay  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   3 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   9 AS bettype , 
   101 AS sporttype,		
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm)  AS PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime ,
   sum(b.Betcount) betcount
  FROM      
   @TempBetList b  
  WHERE     
   b.bettype = 9  
   AND b.tpositiontaking <> 0  
   
   GROUP BY   
   b.Winlostdate,  
   b.currency  
     
  --Combination MixParlay  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   4 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   29 AS bettype , 
   102 AS sporttype,	
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm)  AS PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 AS liveindicator,  
   '' as showtime ,
   sum(b.Betcount) betcount
  FROM      
   @TempBetList b  
  WHERE     
   b.bettype = 29  
   AND b.tpositiontaking <> 0  
        GROUP BY   
   b.Winlostdate,  
   b.currency  
 END  
   
 IF (@showNG=1 OR @showLC=1 OR @ShowVS=1)   
 BEGIN  
  --exclude BA tickets  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   0 AS BetGroup ,  
   m.matchid ,  
   m.homeid ,  
   m.awayid ,  
   b.bettype ,
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END sporttype,
   m.leagueid ,  
   SUM(stake) ,  
   SUM(winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) AS PlayerComm,  
   '' ,  
   m.matchcode ,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator,  
   CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN m.showtime ELSE '' END AS ShowTime,
   sum(b.Betcount) betcount  
  FROM      
   @TempBetList b  
   INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
   INNER JOIN @bettype bt ON b.bettype = bt.bettype 
  GROUP BY  
    b.Winlostdate,  
    b.currency ,  
    m.matchid ,  
    m.homeid ,  
    m.awayid ,  
    b.bettype ,  
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END ,
    m.leagueid ,  
    m.matchcode ,  
    m.isNeutral,  
    b.liveindicator ,  
    CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN m.showtime ELSE '' END  
    IF EXISTS (SELECT 1 FROM @TempBetList WHERE bettype IN (1231, 1232, 1233, 1237, 1238) )
	BEGIN 
		INSERT  INTO @AgMatchWLDetails  
		SELECT    
		b.Winlostdate,
		r.EventTime KickoffTime, 		
		b.currency,
		0 AS BetGroup, 	

		o.EventID matchid,  
		o.RacerID as homeID,  
		0 as awayid,  
		b.bettype,
		r.sporttype,	
		r.leagueid,  
		SUM(b.stake),  
		SUM(b.winlost),  
		-SUM(b.winlost) AS LicenseeWL,  
		0 AS WinlossRB,  
		0 AS AmountDueToBA,  
		0 AS AmountDueToRB,  
		0 AS CommBA,  
		0 as CommRB,  
		SUM(b.playercomm)  as PlayerComm,  
		b.oddsid,  
		CONVERT (VARCHAR(50),o.RacerNum) as matchcode,  
		ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
		b.liveindicator AS liveindicator,
		CONVERT(VARCHAR(20),r.EventTime) as ShowTime ,
		sum(b.Betcount) betcount
		FROM      
		@TempBetList b  
		INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN @bettype bt ON b.bettype = bt.bettype  
		GROUP BY  
		b.Winlostdate,  
		b.currency, 
		b.oddsid,
		o.EventID,  
		o.RacerID,  
		b.bettype,
		r.sporttype,	
		r.leagueid,  
		o.RacerNum,  
		b.liveindicator,
		r.EventTime
	END
    
 END  
   
   
   
 IF @showRB=1  
 BEGIN  
  -- HR  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,	
   b.currency,  
   1 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   bettype ,
   151 as sporttype, 		
   m.leagueid AS leagueid ,  
   SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END) ,  
   SUM(b.winlost) ,  
   0 AS LicenseeWL,  
   SUM (CASE WHEN b.bettype IN (31,32,33) THEN b.awinlost ELSE 0 END) AS WinlossRB,  
   0 AS AmountDueToBA,  
   - SUM ( CASE WHEN b.bettype IN (31,32,33) THEN (b.winlost + awinlost + comm) ELSE 0 END) AS AmountDueToRB,  
   0 AS CommBA,  
   SUM ( CASE WHEN b.bettype IN (31,32,33) THEN comm ELSE 0 END) as CommRB,  
   SUM (  b.playercomm ) as PlayerComm,  
   m.groupmatch AS race ,  
   'ZZZZ' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime ,
   sum(b.Betcount) betcount
  FROM      
   @TempBetList b  
   INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE     
   b.bettype IN (31,32,33)  
  GROUP BY   
   b.Winlostdate,b.currency,bettype ,m.groupmatch ,m.leagueid  
 END  
   
END  
IF @_Fromdate <= @MoveBetsDay   
BEGIN  
   
 IF @ShowBA = 1  
 BEGIN  
  DELETE FROM @TempBetList  
    
  INSERT INTO @TempBetList   
  SELECT    
   b.Winlostdate,
   b.currency,  
   b.bettype ,  
   SUM(stake) as Stake,  
   SUM(winlost - actual_stake) as Winlost,  
   0 AS awinlost,  
   SUM(comm),
   b.oddsid,
   SUM(b.playercomm ) AS PlayerComm,  
   b.matchid,  
   0 AS Liveawayscore,  
   0 AS liveindicator,  
   0 AS tpositiontaking,
   count(1) betcount 
  FROM      
   bettrans14 b WITH(NOLOCK)  
   INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk BA WITH (NOLOCK) ON b.recommend = BA.recommend AND b.transid = BA.transid    
  WHERE     
    b.recommend IN (SELECT custid FROM @TempAg)  
   AND b.winlostdate between @_Fromdate and @_Todate  
   AND b.statusID IN (111,112,113)  
  
  GROUP BY  
    b.Winlostdate,  
    b.currency ,  
	b.oddsid,
    b.bettype ,  
    b.matchid  
  
  --SB  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,
   b.currency,  
   0 AS BetGroup ,  
   m.matchid ,  
   m.homeid ,  
   m.awayid ,  
   b.bettype , 
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END sporttype,
   m.leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm) as CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) as PlayerComm,  
   '' AS race ,  
   m.matchcode ,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   0 AS liveindicator,  
   '' as showtime,
   sum(b.Betcount) betcount 
  FROM     
   @TempBetList b  
   INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
  WHERE     
   b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999)  
   OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
  GROUP BY  
    b.Winlostdate,  
    b.currency,   
    m.matchid ,  
    m.homeid ,  
    m.awayid ,  
    b.bettype ,
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END ,	
    m.leagueid ,  
    m.matchcode ,  
    m.isNeutral  
      
      
  --Mix Parlay  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
   NULL,
   b.currency,  
   3 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   9 AS bettype ,
   101 AS sporttype,		
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm) as CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) AS PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime,
   sum(b.betcount) betcount  
  FROM      
   @TempBetList b   
  WHERE     
   b.bettype = 9  
  GROUP BY  
   b.Winlostdate,  
   b.currency  
     
  --Mix Parlay Combination  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,	
   b.currency,  
   4 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   29 AS bettype ,
   102 AS sporttype,  
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm) as CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) as PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime ,
   sum(b.betcount) betcount
  FROM      
   @TempBetList b   
  WHERE     
   b.bettype = 29  
  GROUP BY  
   b.Winlostdate,  
   b.currency   
    
  --outright  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,
   b.currency,  
   2  AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   bettype , 
	103 as bettype, 
   0 AS leagueid ,  
   SUM(stake) ,  
   SUM(Winlost) ,  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm ) as CommBA,  
   0 as CommRB,  
   SUM(b.PlayerComm) AS PlayerComm,  
   m.groupmatch AS race ,  
   'ZZZZ' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime,
   sum(b.betcount) betcount  
  FROM      
   @TempBetList b  
   INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE     
   b.bettype = 10  
  GROUP BY   
   b.Winlostdate,  
   b.currency,  
   bettype ,  
   m.groupmatch  
 END  
  
 --Get general data  
 DELETE FROM @TempBetList  
 INSERT INTO @TempBetList  
 SELECT    
   b.Winlostdate,  
   b.currency,  
   b.bettype ,  
   SUM(stake) as Stake,  
   SUM(winlost - actual_stake) as Winlost,  
   SUM(b.awinlost) AS awinlost,  
   SUM(b.comm) AS comm,
   b.oddsid,
   SUM( b.playercomm ) AS playercomm,  
   b.matchid,  
   b.Liveawayscore ,  
   CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
   b.tpositiontaking,
   count(1) betcount  
  FROM      
   bettrans14 b WITH(NOLOCK)
  WHERE     
   b.recommend in (SELECT * from @TempAg)  
   AND b.winlostdate between @_Fromdate and @_Todate  
   AND b.ruben = 1  
   AND b.statusID NOT IN ( 101, 102, 103 )  
  GROUP BY  
    b.Winlostdate,  
    b.currency ,
	b.oddsid,	
    b.bettype ,  
    b.matchid,  
    b.Liveawayscore,  
    CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
    b.tpositiontaking  
  
 IF (@ShowSB=1)  
 BEGIN  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,
   b.currency,  
   0 AS BetGroup ,  
   m.matchid ,  
   m.homeid ,  
   m.awayid ,  
   b.bettype , 
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END sporttype,   
   m.leagueid ,  
   SUM(stake) ,  
   SUM(winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) AS PlayerComm,  
   '' AS race ,  
   m.matchcode ,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator,  
   '' AS ShowTime,
   sum(b.betcount) betcount  
  FROM     
   @TempBetList b  
   INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
  WHERE  
   (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
				 OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
   ) AND  
   b.tpositiontaking<>0   
  GROUP BY  
    b.Winlostdate,  
    b.currency,   
    m.matchid ,  
    m.homeid ,  
    m.awayid ,  
    b.bettype ,
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END ,	
    m.leagueid ,  
    m.matchcode ,  
    m.isNeutral,  
    b.liveindicator   
      
  -- Mix parlay (14)  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,
   b.currency,  
   3 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   9 AS bettype ,
	101 AS sporttype,
   0 AS leagueid ,  
   SUM(stake) AS stake ,  
   SUM(b.winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 AS CommRB,  
   SUM(b.playercomm)  AS PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime,
   sum(b.betcount) betcount  
  FROM      
   @TempBetList b  
  WHERE     
   b.bettype = 9  
   AND b.tpositiontaking<>0  
  GROUP BY  
   b.Winlostdate,  
   b.currency  
  -- Combination Mix parlay (14)   
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,
   b.currency,  
   4 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   29 AS bettype ,
   102 AS sporttype,
   0 AS leagueid ,  
   SUM(stake) AS stake ,  
   SUM(b.winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 AS CommRB,  
   SUM(b.playercomm) AS PlayerComm,  
   '' AS race ,  
   '' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator,  
   '' as showtime ,
   sum(b.betcount) betcount   
  FROM      
   @TempBetList b  
  WHERE     
   b.bettype = 29  
   AND b.tpositiontaking<>0  
  GROUP BY  
   b.Winlostdate,  
   b.currency   
     
  -- Outright (14) + HR  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,	
   b.currency,  
   2 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   10 as bettype , 
   103 as sporttype, 
   0 AS leagueid ,  
   SUM(b.stake) ,  
   SUM(winlost) ,  
   - SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 AS CommRB,  
   SUM (  b.playercomm ) AS PlayerComm,  
   m.groupmatch AS race ,  
   'ZZZZ' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 AS liveindicator,  
   '' as showtime,
   sum(b.betcount) betcount    
  FROM      
   @TempBetList b  
   INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE     
   b.bettype = 10 AND b.tpositiontaking<>0  
  GROUP BY   
   b.Winlostdate,  
   b.currency,  
   m.groupmatch   
     
 END  
   
  
 IF (@showNG=1 OR @showLC=1 OR @ShowVS=1)   
 BEGIN  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,	
   b.currency,  
   0 AS BetGroup ,  
   m.matchid ,  
   m.homeid ,  
   m.awayid ,  
   b.bettype ,  
   CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END sporttype,	
   m.leagueid ,  
   SUM(stake) ,  
   SUM(winlost) ,  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) AS PlayerComm,  
   '' AS race ,  
   m.matchcode ,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator,  
   CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN m.showtime ELSE '' END AS ShowTime,
   sum(b.betcount) betcount    
  FROM     
   @TempBetList b  
   INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
   INNER JOIN @bettype bt ON b.bettype = bt.bettype  
  GROUP BY  
    b.Winlostdate,  
    b.currency,   
    m.matchid ,  
    m.homeid ,  
    m.awayid ,  
    b.bettype ,
	CASE WHEN b.bettype=9 THEN 101
		WHEN b.bettype=29 THEN 102
		WHEN b.bettype=10 THEN 103
		ELSE ISNULL(m.sporttype,1)
		END ,		
    m.leagueid ,  
    m.matchcode ,  
    m.isNeutral,  
    b.liveindicator ,  
    CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN m.showtime ELSE '' END  
  IF EXISTS (SELECT 1 FROM  @TempBetList  WHERE bettype IN (1231, 1232, 1233, 1237, 1238))
	BEGIN 
		INSERT  INTO @AgMatchWLDetails  
		SELECT    
		b.Winlostdate,
		r.EventTime KickoffTime,	
		b.currency,
		0 AS BetGroup, 	
		o.EventID matchid,  
		o.RacerID as homeID,  
		0 as awayid,  
		b.bettype,
		r.sporttype,	
		r.leagueid,  
		SUM(b.stake),  
		SUM(b.winlost),  
		-SUM(b.winlost) AS LicenseeWL,  
		0 AS WinlossRB,  
		0 AS AmountDueToBA,  
		0 AS AmountDueToRB,  
		0 AS CommBA,  
		0 as CommRB,  
		SUM(b.playercomm)  as PlayerComm,  
		b.oddsid ,  
		CONVERT(VARCHAR(50),o.RacerNum) as matchcode,  
		ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
		b.liveindicator AS liveindicator,
		CONVERT(VARCHAR(20),r.EventTime) as ShowTime,
		sum(b.betcount) betcount    
		FROM      
		@TempBetList b  
		INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		INNER JOIN @bettype bt ON b.bettype = bt.bettype  
		GROUP BY  
		b.Winlostdate,  
		b.currency,
		b.oddsid,		
		o.EventID ,  
		o.RacerID,  
		b.bettype,
		r.sporttype,	
		r.leagueid,  
		o.RacerNum,  
		b.liveindicator,
		r.EventTime
	END    

 END      
  
 IF  @showRB=1  
 BEGIN  
  -- Outright (14) + HR  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,
	NULL,
   b.currency,  
   1 AS BetGroup ,  
   0 AS matchid ,  
   0 AS homeid ,  
   0 AS awayid ,  
   bettype ,
	151 AS sportype, 
   m.leagueid AS leagueid ,  
   SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END) ,  
   SUM(winlost) ,  
   0 AS LicenseeWL,  
   SUM (CASE WHEN b.bettype IN (31,32,33) THEN b.awinlost ELSE 0 END) AS WinlossRB,  
   0 AS AmountDueToBA,  
   - SUM ( CASE WHEN b.bettype IN (31,32,33) THEN (b.winlost + awinlost + comm) ELSE 0 END) AS AmountDueToRB,  
   0 AS CommBA,  
   SUM ( CASE WHEN b.bettype IN (31,32,33) THEN b.comm  ELSE 0 END) AS CommRB,  
   SUM (  b.playercomm ) AS PlayerComm,  
   m.groupmatch AS race ,  
   'ZZZZ' AS matchcode ,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 AS liveindicator,  
   '' as showtime,
   sum(b.betcount) betcount    
  FROM      
   @TempBetList b  
   INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE     
   b.bettype IN (31,32,33)  
  GROUP BY   
   b.Winlostdate,  
   b.currency,  
   bettype ,
   m.groupmatch ,   
   m.leagueid  
 END  
   
END  
  
INSERT INTO @ExchangeDaily  
    SELECT ExchangeDate, ExchangeId, USD, EUR  
    FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate)  
  
SELECT  @TotalRows = COUNT(1)  
FROM    ( SELECT DISTINCT  
                BetGroup ,  
                matchid ,  
                homeid ,  
                awayid ,  
                bettype ,
				sporttype,	
                matchcode ,  
                leagueid ,  
                isNeutral ,  
                race,  
                liveindicator  
          FROM      @AgMatchWLDetails  
        ) AS Temp  
       
SELECT  wl.*  
FROM    ( SELECT      
				BetGroup ,  
                matchid ,  
                CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE homeid END homeid ,  
                CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE awayid END awayid ,  
                bettype ,
				sporttype,	
                leagueid ,  
                CAST(SUM(turnover) AS MONEY) AS turnover ,  
                CAST(SUM(turnover * e.USD) AS MONEY) AS turnoverUSD ,  
                CAST(SUM(turnover * e.EUR) AS MONEY) AS turnoverEUR ,  
                CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost ,  
                CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD ,  
                CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR ,  
                CAST(SUM(LicenseeWL) AS MONEY) AS LicenseeWL,  
                CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD,  
                CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR,  
				CAST(SUM(WinlossRB) AS MONEY) AS WinlossRB,  
                CAST(SUM(WinlossRB * e.USD) AS MONEY) AS WinlossRBUSD,  
                CAST(SUM(WinlossRB * e.EUR) AS MONEY) AS WinlossRBEUR,  
                CAST(SUM(CommBA) AS MONEY) AS CommBA,  
                CAST(SUM(CommBA * e.USD) AS MONEY) AS CommBAUSD,  
                CAST(SUM(CommBA * e.EUR) AS MONEY) AS CommBAEUR,  
                CAST(SUM(commRB) AS MONEY) AS commRB,  
                CAST(SUM(commRB * e.USD) AS MONEY) AS commRBUSD,  
                CAST(SUM(commRB * E.EUR) AS MONEY) AS commRBEUR,  
				CAST(SUM (PlayerComm) AS MONEY) AS PlayerComm,  
				CAST ((SUM(PlayerComm*e.USD))AS MONEY) AS PlayerCommUSD,  
				CAST ((SUM(PlayerComm*e.EUR))AS MONEY) AS PlayerCommEUR,  
                CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA,  
                CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD,  
                CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR,  
                CAST(SUM(AmtDuetoRB) AS MONEY) AS AmtDuetoRB,  
                CAST(SUM((AmtDuetoRB) * e.USD) AS MONEY) AS AmtDuetoRBUSD,  
                CAST(SUM((AmtDuetoRB) * e.EUR) AS MONEY) AS AmtDuetoRBEUR,  
                CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE race END race ,  
                CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN '' ELSE matchcode END matchcode ,  
                isNeutral ,  
                liveindicator,
				b.KickoffTime,
				sum(b.betcount) betcount , 		
                CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN b.showtime ELSE '' END as showtime,  
                --ROW_NUMBER() OVER ( ORDER BY betgroup, matchid, leagueid, race, bettype, matchcode ) AS RowNum  
				ROW_NUMBER() OVER (	ORDER BY betgroup,matchid,leagueid) AS RowNum
          FROM    
			@AgMatchWLDetails b  
			INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId  
          GROUP BY    
				BetGroup ,  
                matchid ,  
                CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE homeid END,  
                CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE awayid END,  
                bettype ,
				sporttype,	
                leagueid , 
				CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN 0 ELSE race END,  
                CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN '' ELSE matchcode END,  
                isNeutral ,  
                liveindicator,
				b.KickoffTime,		
                CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN b.showtime ELSE '' END
        ) wl  
WHERE   wl.RowNum BETWEEN @RowStart AND @RowEnd  
  
SELECT    
 CAST(SUM(Turnover) AS MONEY) AS SumTurnover ,  
    CAST(SUM(Turnover * e.USD) AS MONEY)  AS SumTurnoverUSD ,  
    CAST(SUM(Turnover * e.EUR) AS MONEY) AS SumTurnoverEUR ,  
    CAST(SUM(MemberWinLost) AS MONEY) AS SumMemberWinLost ,  
    CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS SumMemberWinLostUSD ,  
    CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS SumMemberWinLostEUR ,  
    CAST(SUM(LicenseeWL) AS MONEY) AS SumLicenseeWL,  
    CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS SumLicenseeWLUSD,  
    CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS SumLicenseeWLEUR,  
 CAST(SUM(WinlossRB) AS MONEY) AS SumWinlossRB,  
    CAST(SUM(WinlossRB * e.USD) AS MONEY) AS SumWinlossRBUSD,  
    CAST(SUM(WinlossRB * e.EUR) AS MONEY) AS SumWinlossRBEUR,  
    CAST(SUM(CommBA) AS MONEY) AS SumCommBA,  
    CAST(SUM(CommBA * e.USD) AS MONEY) AS SumCommBAUSD,  
    CAST(SUM(CommBA * e.EUR) AS MONEY) AS SumCommBAEUR,  
    CAST(SUM(commRB) AS MONEY) AS SumcommRB,  
    CAST(SUM(commRB * e.USD) AS MONEY) AS SumcommRBUSD,  
    CAST(SUM(commRB * e.EUR) AS MONEY) AS SumcommRBEUR,  
 CAST(SUM(PlayerComm) AS MONEY) AS SumPlayerComm,  
 CAST(SUM(PlayerComm *e.USD) AS MONEY) AS SumPlayerCommUSD,   
 CAST(SUM(PlayerComm *e.EUR) AS MONEY) AS SumPlayerCommEUR,  
    CAST(SUM(AmtDuetoBA) AS MONEY) AS SumAmtDuetoBA,  
    CAST(SUM(AmtDuetoBA * e.USD) AS MONEY) AS SumAmtDuetoBAUSD,  
    CAST(SUM(AmtDuetoBA * e.EUR) AS MONEY) AS SumAmtDuetoBAEUR,  
    CAST(SUM(AmtDuetoRB) AS MONEY) AS SumAmtDuetoRB,  
    CAST(SUM(AmtDuetoRB * e.USD) AS MONEY) AS SumAmtDuetoRBUSD,  
    CAST(SUM(AmtDuetoRB * e.EUR) AS MONEY) AS SumAmtDuetoRBEUR,  
    ISNULL(@TotalRows, 0) AS TotalRows,
	SUM(b.betcount) AS SumBetCount
FROM      
 @AgMatchWLDetails b  
 INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_WinlossByProductDetail] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_WinlossByProductDetail] TO [vnteam]   