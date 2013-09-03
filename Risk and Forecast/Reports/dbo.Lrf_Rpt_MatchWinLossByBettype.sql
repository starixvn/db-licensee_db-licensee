CREATE PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossByBettype]  
	@LicenseeID INT,  
	@UserID		INT,
	@LicenseeType VARCHAR(100) = NULL,  
	@CurrencyID   INT=0,  
	@MatchID INT, -- in case of Racing, this param is 'race'  
	@LeagueID INT = 0, -- in case of Racing, this param is '>0'  
	@Date SMALLDATETIME,  
	@MoveBetsDay SMALLDATETIME,  
	@showSB BIT = 0,  
	@showRB BIT = 0,  
	@showNG BIT = 0,  
	@showBA BIT = 0,  
	@showLC BIT = 0,  
	@showVS BIT = 0,
	@ShowCS BIT = 0, --- RNG Casino  
	@ShowBG BIT = 0 --- Bingo  
      
AS   
/*  
Created: 20120529@Don  
Task :   
DB: DB052.bodb02  
Original: Lrf_Rpt_MatchWinLossDetail  
Revisions:  
	- 20120815@Henry: add live casino  
	- 20120904@Jim : add virtual Sport  
	- 20121004@Jim: replace @currencyname input param by @currencyID  
	- 20121115@Henry: Only Sportsbook needs to exclude BA  
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets  
	- 20130401@Scott: add more parameter @ShowCS,@ShowBG  
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
Param's Explanation:   
   
*/  
  
/* demo script  
exec [Lrf_Rpt_MatchWinLossByBettype_xtest] @LicenseeID=3,@LicenseeType=default,@MatchID=1700257,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showRB=1,@showNG=0,@showBA=0  
*/  
SET NOCOUNT ON  
  
DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))  
  
DECLARE @bettype AS TABLE (bettype INT)      
      
DECLARE @_Date AS DATETIME  
SET @_Date = @Date  
  
DECLARE @Today SMALLDATETIME   
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)   

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
  
DECLARE @TempAg AS TABLE ( CustId INT )  
INSERT  INTO @TempAg ( CustId)  
SELECT  CustID    
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )    
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE   [Description] = COALESCE(@LicenseeType,    
									 [Description])   
                                                       
-----------------------------------    
DROP TABLE #currency
-----------------------------------
  
DECLARE @AgMatchWLDetails TABLE  
(  
 Winlostdate SMALLDATETIME,  
 Currency INT,  
 matchid INT,  
 homeid INT,  
 awayid INT,  
 bettype SMALLINT,  
 leagueid INT,  
 turnover MONEY,  
 MemberWinLost MONEY,  
 LicenseeWL  MONEY, --Sportbook and NumberGame  
 WinlossRB  MONEY,  
 AmtDueToBA MONEY,     
 AmtDueToRB MONEY,  
 CommBA   MONEY,     
 CommRB  MONEY,   
 PlayerComm MONEY,   
 race NVARCHAR(20),  
 matchcode NVARCHAR(50),  
 isNeutral BIT,  
 liveindicator BIT  
)  
  
CREATE TABLE #TempBetList(  
 Winlostdate  DATETIME,  
 currency        INT,  
 Bettype   INT,  
 Stake   MONEY,  
 Winlost   MONEY,  
 awinlost  MONEY,  
 comm   MONEY,  
 playercomm  MONEY,  
 MatchID         INT,  
 Liveawayscore SMALLINT,  
 liveindicator   BIT,  
 tpositiontaking SMALLMONEY  
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
    
  
IF @_Date > @MoveBetsDay   
BEGIN  
   
  
 IF @ShowBA = 1  
 BEGIN  
  INSERT INTO #TempBetList   
  SELECT    
   b.Winlostdate,  
   b.currency,  
   b.bettype,  
   SUM(stake) as Stake,  
   SUM(winlost - actual_stake) as Winlost,  
   0 AS awinlost,  
   SUM(comm),  
   SUM(playercomm ) AS PlayerComm,  
   b.matchid,  
   0 AS Liveawayscore,  
   0 AS liveindicator,  
   0 AS tpositiontaking  
  FROM      
   bettrans b WITH(NOLOCK)  
   INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend AND b.transid = BA.transid     
  WHERE     
      b.recommend IN (SELECT custid FROM @TempAg)  
   AND b.winlostdate = @_Date  
   AND b.statusID IN (111,112,113)  
   AND b.matchid = @MatchID  
  GROUP BY  
   b.Winlostdate,  
   b.currency,  
   b.bettype,  
   b.matchid  
      
  --SB  
  INSERT INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   SUM(stake),  
   SUM(Winlost),  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm ) as CommBA,  
   0 as CommRB,  
   SUM(PlayerComm) as PlayerComm,  
   '',  
   m.matchcode,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   0 AS liveindicator  
     
  FROM      
   #TempBetList b  
   INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
  /*WHERE     
   b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999)*/  
  GROUP BY  
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   m.matchcode,  
   m.isNeutral   
    
 END  
   
 --Get general data  
 TRUNCATE TABLE #TempBetList  
   
 IF (@showRB = 0)  
        INSERT INTO #TempBetList  
        SELECT    
         b.Winlostdate,  
         b.currency,  
         b.bettype,  
         SUM(stake) as Stake,  
         SUM(winlost - actual_stake) as Winlost,  
         SUM(b.awinlost) AS awinlost,  
         SUM(b.comm) AS comm,  
         SUM(b.playercomm) AS playercomm,  
         b.matchid,  
         b.Liveawayscore,  
         CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
         b.tpositiontaking  
        FROM      
         bettrans b WITH(NOLOCK)  
        WHERE     
            b.recommend IN (SELECT custid FROM @TempAg)  
         AND b.winlostdate = @_Date  
         AND b.statusID IN (111,112,113)  
         AND b.matchid = @MatchID  
        GROUP BY  
         b.Winlostdate,  
         b.currency,  
         b.bettype,  
         b.matchid,  
         b.Liveawayscore,  
         CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
         b.tpositiontaking  
    ELSE  
    BEGIN  
        -- @showRB = 1, Racing  
        INSERT INTO #TempBetList  
        SELECT    
         b.Winlostdate,  
         b.currency,  
         b.bettype,  
         SUM(stake) as Stake,  
         SUM(winlost - actual_stake) as Winlost,  
         SUM(b.awinlost) AS awinlost,  
         SUM(b.comm) AS comm,  
         SUM(b.playercomm ) AS playercomm,  
         b.matchid,  
         b.Liveawayscore,  
         CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
         b.tpositiontaking  
        FROM      
         bettrans b WITH(NOLOCK)  
            LEFT JOIN outright o (NOLOCK) ON b.matchid = o.orid  
        WHERE     
            b.recommend IN (SELECT custid FROM @TempAg)  
         AND b.winlostdate = @_Date  
         AND b.statusID IN (111,112,113)  
         AND o.leagueid = @LeagueID  
         AND o.groupmatch = @MatchID  
        GROUP BY  
         b.Winlostdate,  
         b.currency,  
         b.bettype,  
         b.matchid,  
         b.Liveawayscore,  
         CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
         b.tpositiontaking  
    END  
   
 IF (@showSB=1)  
 BEGIN  
  --exclude BA tickets  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   SUM(stake),  
   SUM(winlost),  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
  0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm)  AS PlayerComm,  
   '',  
   m.matchcode,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator  
  FROM      
   #TempBetList b  
   INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
  WHERE  
   (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND  
   b.tpositiontaking <> 0  
  GROUP BY  
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   m.matchcode,  
   m.isNeutral,  
   b.liveindicator    
 END  
   
 IF (@showNG=1 OR @showLC=1 OR @ShowVS=1)  
 BEGIN  
  --exclude BA tickets  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   SUM(stake),  
   SUM(winlost),  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm)  AS PlayerComm,  
   '',  
   m.matchcode,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator  
  FROM      
   #TempBetList b  
   INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
   INNER JOIN @bettype bt ON b.bettype = bt.bettype
  GROUP BY  
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   m.matchcode,  
   m.isNeutral,  
   b.liveindicator    
    
	IF EXISTS (SELECT 1 FROM @bettype WHERE bettype IN (1231, 1232, 1233, 1237, 1238))
	BEGIN 
		INSERT  INTO @AgMatchWLDetails  
			SELECT    
			b.Winlostdate,  
			b.currency,  
			b.matchid,  
			o.RacerID as homeID,  
			0 as awayid,  
			b.bettype,  
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
			'',  
			o.RacerNum as matchcode,  
			ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
			b.liveindicator AS liveindicator  
			FROM      
			#TempBetList b  
			INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @bettype bt ON b.bettype = bt.bettype  
			GROUP BY  
			b.Winlostdate,  
			b.currency,  
			b.matchid,  
			o.RacerID,  
			b.bettype,  
			r.leagueid,  
			o.RacerNum,  
			r.sporttype,  
			r.EventTime
	END		
 END  
   
 IF @showRB=1  
 BEGIN  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   0 AS matchid,  
   0 AS homeid,  
   0 AS awayid,  
   bettype,  
   m.leagueid,  
   SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END),  
   SUM(b.winlost),  
   0 AS LicenseeWL,  
   SUM(b.awinlost) AS WinlossRB,  
   0 AS AmountDueToBA,  
   - SUM(b.winlost + awinlost + comm) AS AmountDueToRB,  
   0 AS CommBA,  
   SUM(comm ) as CommRB,  
   SUM(PlayerComm) AS PlayerComm,  
   m.groupmatch AS race,  
   'ZZZZ' AS matchcode,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 as liveindicator  
  FROM      
   #TempBetList b  
   INNER JOIN outright m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE b.bettype IN (31,32,33)  
  GROUP BY   
   b.Winlostdate,b.currency,bettype,m.groupmatch,m.leagueid  
 END  
   
   
END  
IF @_Date <= @MoveBetsDay   
BEGIN  
   
  
 IF @ShowBA = 1  
 BEGIN  
  TRUNCATE TABLE #TempBetList  
    
  INSERT INTO #TempBetList   
  SELECT    
   b.Winlostdate,  
   b.currency,  
   b.bettype,  
   SUM(stake) as Stake,  
   SUM(winlost - actual_stake) as Winlost,  
   0 AS awinlost,  
   SUM(comm),  
   SUM(playercomm  ),  
   b.matchid,  
   0 AS Liveawayscore,  
   0 AS liveindicator,  
   0 AS tpositiontaking  
  FROM      
   bettrans14 b WITH(NOLOCK)  
   INNER JOIN @TempAg ag ON b.recommend = ag.custid  
   --INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid   
  WHERE     
   b.winlostdate = @_Date  
   AND b.statusID IN (111,112,113)  
   AND b.matchid = @MatchID  
   AND tpositiontaking = 0  
   AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))  
  GROUP BY  
   b.Winlostdate,  
   b.currency,  
   b.bettype,  
   b.matchid  
  
  --SB  
  INSERT INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   SUM(stake),  
   SUM(Winlost),  
   0 AS LicenseeWL,  
   0 AS WinlossRB,  
   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
   0 AS AmountDueToRB,  
   SUM (comm ) as CommBA,  
   0 as CommRB,  
   SUM(PlayerComm)  as PlayerComm,   
   '' AS race,  
   m.matchcode,  
   ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,  
   0 AS liveindicator  
  FROM     
   #TempBetList b  
   INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
  /*WHERE     
   b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999)*/  
  GROUP BY  
   b.Winlostdate,  
   b.currency,   
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   m.matchcode,  
   m.isNeutral  
      
 END  
  
 --Get general data  
 TRUNCATE TABLE #TempBetList  
   
 IF (@showRB = 0)  
     INSERT INTO #TempBetList  
     SELECT    
      b.Winlostdate,  
      b.currency,  
      b.bettype,  
      SUM(stake) as Stake,  
      SUM(winlost - actual_stake) as Winlost,  
      SUM(b.awinlost) AS awinlost,  
      SUM(b.comm) AS comm,  
      SUM(b.playercomm  ) AS playercomm,  
      b.matchid,  
      b.Liveawayscore ,  
      CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
      b.tpositiontaking  
     FROM      
      bettrans14 b WITH(NOLOCK)  
      INNER JOIN @TempAg ag ON b.recommend = ag.custid  
     WHERE           b.winlostdate = @_Date  
      AND b.statusID NOT IN ( 101, 102, 103 )  
      AND b.matchid = @MatchID  
     GROUP BY  
      b.Winlostdate,  
      b.currency,  
      b.bettype,  
      b.matchid,  
      b.Liveawayscore,  
      CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
      b.tpositiontaking  
    ELSE -- @showRB = 1, Racing  
        INSERT INTO #TempBetList  
        SELECT    
      b.Winlostdate,  
      b.currency,  
      b.bettype,  
      SUM(stake) as Stake,  
      SUM(winlost - actual_stake) as Winlost,  
      SUM(b.awinlost) AS awinlost,  
      SUM(b.comm) AS comm,  
      SUM(b.playercomm ) AS playercomm,  
      b.matchid,  
      b.Liveawayscore ,  
      CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
   b.tpositiontaking  
     FROM      
      bettrans14 b WITH(NOLOCK)  
      INNER JOIN @TempAg ag ON b.recommend = ag.custid  
      LEFT JOIN outright14 o (NOLOCK) ON b.matchid = o.orid  
     WHERE     
      b.winlostdate = @_Date  
      AND b.statusID NOT IN ( 101, 102, 103 )  
      AND o.leagueid = @LeagueID  
         AND o.groupmatch = @MatchID  
     GROUP BY  
      b.Winlostdate,  
      b.currency,  
      b.bettype,  
      b.matchid,  
      b.Liveawayscore,  
      CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
      b.tpositiontaking  
  
 IF (@ShowSB=1)  
 BEGIN  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   SUM(stake),  
   SUM(winlost),  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) as PlayerComm,  
   '' AS race,  
   m.matchcode,  
   ISNULL(m.isNeutral,   
   CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator  
  FROM     
   #TempBetList b  
   INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
  WHERE     
   (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)) AND  
   b.tpositiontaking <> 0   
    
  GROUP BY  
   b.Winlostdate,  
   b.currency,   
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   m.matchcode,  
   m.isNeutral,  
   b.liveindicator  
 END  
  
 IF (@showNG=1 OR @showLC=1 OR @ShowVS=1)  
 BEGIN  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   SUM(stake),  
   SUM(winlost),  
   -SUM(b.winlost) AS LicenseeWL,  
   0 AS WinlossRB,  
   0 AS AmountDueToBA,  
   0 AS AmountDueToRB,  
   0 AS CommBA,  
   0 as CommRB,  
   SUM(b.playercomm) as PlayerComm,  
   '' AS race,  
   m.matchcode,  
   ISNULL(m.isNeutral,   
   CONVERT(BIT, 0)) AS IsNeutral,  
   b.liveindicator AS liveindicator  
  FROM     
   #TempBetList b  
   INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
   INNER JOIN @bettype bt ON b.bettype = bt.bettype 
   LEFT JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON b.matchid = r.eventid  AND b.bettype IN  (111, 112, 113)
    
  GROUP BY  
   b.Winlostdate,  
   b.currency,   
   m.matchid,  
   m.homeid,  
   m.awayid,  
   b.bettype,  
   m.leagueid,  
   m.matchcode,  
   m.isNeutral,  
   b.liveindicator  
   -- VHR
	IF EXISTS (SELECT 1 FROM @bettype WHERE bettype IN (1231, 1232, 1233, 1237, 1238))
	BEGIN 
		INSERT  INTO @AgMatchWLDetails  
			SELECT    
			b.Winlostdate,  
			b.currency,  
			b.matchid,  
			o.RacerID as homeID,  
			0 as awayid,  
			b.bettype,  
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
			'',  
			o.RacerNum as matchcode,  
			ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
			b.liveindicator AS liveindicator  
			FROM      
			#TempBetList b  
			INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @bettype bt ON b.bettype = bt.bettype  
			GROUP BY  
			b.Winlostdate,  
			b.currency,  
			b.matchid,  
			o.RacerID,  
			b.bettype,  
			r.leagueid,  
			o.RacerNum,  
			r.sporttype,  
			r.EventTime
	END			
 END      
  
 IF @showRB=1  
 BEGIN  
  INSERT  INTO @AgMatchWLDetails  
  SELECT    
   b.Winlostdate,  
   b.currency,  
   0 AS matchid,  
   0 AS homeid,  
   0 AS awayid,  
   bettype,  
   m.leagueid,  
   SUM(CASE WHEN b.liveawayscore = 0 AND b.bettype IN ( 33, 43 ) THEN b.stake / 2 ELSE b.stake END),  
   SUM(winlost),  
   0 AS LicenseeWL,  
   SUM(b.awinlost) AS WinlossRB,  
   0 AS AmountDueToBA,  
   - SUM(b.winlost + awinlost + comm) AS AmountDueToRB,  
   0 AS CommBA,  
   SUM(b.comm) AS CommRB,  
   SUM(b.playercomm) AS PlayerComm,  
   m.groupmatch AS race,  
   'ZZZZ' AS matchcode,  
   CONVERT(BIT, 0) AS IsNeutral,  
   0 AS liveindicator  
  FROM      
   #TempBetList b  
   INNER JOIN outright14 m WITH ( NOLOCK ) ON m.orid = b.matchid  
  WHERE b.bettype IN (31,32,33)  
  GROUP BY   
   b.Winlostdate,  
   b.currency,  
   bettype,  
   m.groupmatch,   
   m.leagueid  
 END  
   
END  
  
INSERT INTO @ExchangeDaily  
    SELECT ExchangeDate, ExchangeId, USD, EUR  
    FROM Lrf_f_GetExchangeDaily(@_Date,@_Date)  
      
      
-- Result  
SELECT      
    matchid,  
    homeid,  
    awayid,  
    bettype,  
    leagueid,  
    CAST(SUM(turnover) AS MONEY) AS turnover,  
    CAST(SUM(turnover * e.USD) AS MONEY) AS turnoverUSD,  
    CAST(SUM(turnover * e.EUR) AS MONEY) AS turnoverEUR,  
    CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost,  
    CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD,  
    CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR,  
    --- licenseeWL  
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
 CAST(SUM(PlayerComm) AS MONEY) AS PlayerComm,  
 CAST(SUM(PlayerComm*e.USD) AS MONEY) AS PlayerCommUSD,  
 CAST(SUM(PlayerComm*e.EUR) AS MONEY) AS PlayerCommEUR,  
    CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA,  
    CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD,  
    CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR,  
    CAST(SUM(AmtDuetoRB) AS MONEY) AS AmtDuetoRB,  
    CAST(SUM((AmtDuetoRB) * e.USD) AS MONEY) AS AmtDuetoRBUSD,  
    CAST(SUM((AmtDuetoRB) * e.EUR) AS MONEY) AS AmtDuetoRBEUR,  
    race,  
    matchcode,  
    isNeutral,  
    liveindicator  
FROM    
 @AgMatchWLDetails b  
 --INNER JOIN (SELECT *  FROM Lrf_f_GetExchangeDaily(@_FromDate,@_ToDate))e   
 INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId  
GROUP BY    
    matchid,  
    homeid,  
    awayid,  
    bettype,  
    matchcode,  
    leagueid,  
    isNeutral,  
    race,  
    liveindicator  
      
DROP TABLE #TempBetList      

   

GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MatchWinLossByBettype] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MatchWinLossByBettype] TO vnteam
