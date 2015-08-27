USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossByBettype]  
	@LicenseeID   INT,  
	@UserID		  INT,
	@LicenseeType VARCHAR(100) = NULL,  
	@CurrencyID   INT=0,  
	@MatchID 	  INT, -- in case of Racing, this param is 'race'  
	@LeagueID     INT = 0, -- in case of Racing, this param is '>0'  
	@Date 		  SMALLDATETIME,  
	@MoveBetsDay  SMALLDATETIME,  
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
	- 20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
	- 20130423@Kyan: offer Virtual Speedway, Virtual Cycling 
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes), column Betcount
	- 20140915@Florent: hotfix duplicated VS bettype
    - 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150123@Jim: support base on Currency GBP
	- 20150203@Jim: fix bug duplicate command when retrieve BA data from bettrans14
	- 20150415@Jim: change to use f_GroupBettype instead of LRF_view_bettype_SS
	- 20150622@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission 
Param's Explanation:   
   
*/  
  
/* demo script  
exec [Lrf_Rpt_MatchWinLossByBettype] @LicenseeID=3,@LicenseeType=default,@MatchID=1700257,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showRB=1,@showNG=0,@showBA=0  
*/  
SET NOCOUNT ON  
  
DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,GBP FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))  
  
DECLARE @bettype AS TABLE (bettype INT)      
      
DECLARE @_Date AS DATETIME  
SET @_Date = @Date  
  
DECLARE @Today SMALLDATETIME   
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)   

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
  
DECLARE @TempAg AS TABLE ( CustId INT, Currency INT )  
INSERT  INTO @TempAg ( CustId,Currency)  
SELECT    CustID   
		  ,Currency 
FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc   
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
	 sporttype SMALLINT,	
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
	 liveindicator BIT,
	 betcount int
	)  
  
CREATE TABLE #TempBetList(  
	 Winlostdate  DATETIME,  
	 currency        INT,  
	 Bettype   INT,  
	 Stake   MONEY,  
	 Winlost   MONEY,  
	 awinlost  MONEY,  
	 comm   MONEY,
	 oddsid INT,
	 playercomm  MONEY,  
	 MatchID         INT,  
	 Liveawayscore SMALLINT,  
	 liveindicator   BIT,  
	 tpositiontaking SMALLMONEY ,
	 betcount int
	)  
  
  
  
IF @ShowLC = 1  
BEGIN  
	INSERT INTO @bettype(bettype)  
	SELECT typeid FROM dbo.bettype WITH (NOLOCK)  
	WHERE (typeid BETWEEN 1101 AND 1199)  
END  
   
  
IF @ShowNG = 1  
BEGIN  
	INSERT INTO @bettype(bettype)  
	SELECT typeid FROM dbo.bettype WITH (NOLOCK)  
	WHERE (typeid BETWEEN 81 AND 120)  
END   
  
IF @ShowVS = 1  
BEGIN  
	INSERT INTO @bettype(bettype)  
	SELECT typeid FROM dbo.bettype WITH (NOLOCK)  
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
	   b.oddsid,
	   SUM(playercomm ) AS PlayerComm,  
	   b.matchid,  
	   0 AS Liveawayscore,  
	   0 AS liveindicator,  
	   0 AS tpositiontaking,
	   count(1) betcount 
	  FROM      
	   bettrans b WITH(NOLOCK)  
	   INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend AND b.transid = BA.transid  
	   INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.Currency = t.Currency	
	  WHERE     
	    b.winlostdate = @_Date  
	   AND b.statusID IN (111,112,113)  
	   AND b.bettype NOT IN (901,902,903)
	   AND b.matchid = @MatchID  
	  GROUP BY  
			   b.Winlostdate,  
			   b.currency,
			   b.oddsid,	
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
		   0 as sporttype,
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
		   0 AS liveindicator ,
		   SUM(b.betcount) betcount
	  FROM  #TempBetList b  
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
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
			 b.oddsid, 	
			 SUM(b.playercomm) AS playercomm,  
			 b.matchid,  
			 b.Liveawayscore,  
			 CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
			 b.tpositiontaking ,
			 COUNT(1) betcount
        FROM  dbo.bettrans b WITH(NOLOCK)  
			INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.Currency = t.Currency
        WHERE     
         b.winlostdate = @_Date  
         AND b.statusID IN (111,112,113)  
		 AND b.bettype NOT IN (901,902,903)
         AND  b.matchid = @MatchID 
		
        GROUP BY  
         b.Winlostdate,  
         b.currency,
         b.oddsid,		 
         b.bettype,  
         b.matchid,  
         b.Liveawayscore,  
         CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
         b.tpositiontaking  
    ELSE  
    BEGIN  
        -- @showRB = 1, Racing  
        INSERT INTO #TempBetList  
        SELECT 	b.Winlostdate,  
				b.currency,  
				b.bettype,  
				SUM(stake) as Stake,  
				SUM(winlost - actual_stake) as Winlost,  
				SUM(b.awinlost) AS awinlost,  
				SUM(b.comm) AS comm,
				b.oddsid,	
				SUM(b.playercomm ) AS playercomm,  
				b.matchid,  
				b.Liveawayscore,  
				CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
				b.tpositiontaking ,
				COUNT(1) betcount
        FROM dbo.bettrans b WITH(NOLOCK)  
		 INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.Currency = t.Currency
            LEFT JOIN outright o (NOLOCK) ON b.matchid = o.orid  
        WHERE     
            b.winlostdate = @_Date   
         AND b.statusID IN (111,112,113)  
		 AND b.bettype NOT IN (901,902,903)
         AND o.leagueid = @LeagueID  
         AND o.groupmatch = @MatchID  
        GROUP BY  
				 b.Winlostdate,  
				 b.currency,
				 b.oddsid,	
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
		   0 sporttype,	
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
		   b.liveindicator AS liveindicator, 
		   SUM(b.betcount) betcount
	  FROM #TempBetList b  
		  INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
	  WHERE  
		   (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						 OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
		   ) AND  
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
		   m.sporttype,	
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
		   b.liveindicator AS liveindicator,
		   SUM(b.betcount) betcount 
	  FROM #TempBetList b  
			INNER JOIN match m WITH ( NOLOCK ) ON m.matchid = b.matchid  
			INNER JOIN @bettype bt ON b.bettype = bt.bettype
      WHERE b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
	  GROUP BY  
		   b.Winlostdate,  
		   b.currency,  
		   m.matchid,  
		   m.homeid,  
		   m.awayid,  
		   b.bettype,
		   m.sporttype,	
		   m.leagueid,  
		   m.matchcode,  
		   m.isNeutral,  
		   b.liveindicator    
    
	IF EXISTS (SELECT 1 FROM @bettype WHERE bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()))
	BEGIN 
		INSERT  INTO @AgMatchWLDetails  
			SELECT  b.Winlostdate,  
					b.currency,  
					o.EventID matchid,  
					o.RacerID as homeID,  
					0 as awayid,  
					b.bettype,
					r.sporttype,	
					r.leagueid,  
					SUM(b.stake),  
					SUM(winlost - actual_stake) as Winlost ,  
					 -SUM(winlost - actual_stake) AS LicenseeWL,  
					0 AS WinlossRB,  
					0 AS AmountDueToBA,  
					0 AS AmountDueToRB,  
					0 AS CommBA,  
					0 as CommRB,  
					SUM(b.playercomm)  as PlayerComm,  
					b.oddsid Race,  
					o.RacerNum as matchcode,  
					ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
					0 AS liveindicator ,
					count(1) betcount 
			FROM  dbo.bettrans b  WITH (NOLOCK)
				INNER JOIN @TempAg t ON b.recommend = t.custid AND b.currency = t.currency
				INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @bettype bt ON b.bettype = bt.bettype  
				WHERE   o.EventID=@MatchID
					AND b.winlostdate=@_Date
					AND b.statusID IN (111,112,113)
					AND b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())			
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
				r.sporttype,  
				r.EventTime
	END		
 END  
   
 IF @showRB=1  
 BEGIN  
	  INSERT  INTO @AgMatchWLDetails  
	  SELECT  b.Winlostdate,  
			   b.currency,  
			   0 AS matchid,  
			   0 AS homeid,  
			   0 AS awayid,  
			   bettype,
				151 sporttype,
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
			   0 as liveindicator ,
			   sum(b.betcount) betcount 
	  FROM  #TempBetList b  
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
		  SELECT b.Winlostdate,  
			   b.currency,  
			   b.bettype,  
			   SUM(stake) as Stake,  
			   SUM(winlost - actual_stake) as Winlost,  
			   0 AS awinlost,  
			   SUM(comm),
			   b.oddsid,	
			   SUM(playercomm  ),  
			   b.matchid,  
			   0 AS Liveawayscore,  
			   0 AS liveindicator,  
			   0 AS tpositiontaking, 
			   count(1) betcount
		  FROM  dbo.bettrans14 b WITH(NOLOCK)  
				INNER JOIN @TempAg ag ON b.recommend = ag.custid  
		  WHERE     
			   b.winlostdate = @_Date  
			   AND b.statusID IN (111,112,113)  
			   AND b.bettype NOT IN (901,902,903)
			   AND b.matchid = @MatchID  
			   AND tpositiontaking = 0  
			   AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999)
								   OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			   )  
		  GROUP BY  
			   b.Winlostdate,  
			   b.currency,
			   b.oddsid	,
			   b.bettype,  
			   b.matchid  
	  
		  --SB  
		  INSERT INTO @AgMatchWLDetails  
		  SELECT b.Winlostdate,  
			   b.currency,  
			   m.matchid,  
			   m.homeid,  
			   m.awayid,  
			   b.bettype,
			   m.sporttype, 	
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
			   0 AS liveindicator,
			   sum(b.betcount) betcount  
		  FROM #TempBetList b  
				INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
		  GROUP BY  
			   b.Winlostdate,  
			   b.currency,   
			   m.matchid,  
			   m.homeid,  
			   m.awayid,  
			   b.bettype,
			   m.sporttype,	
			   m.leagueid,  
			   m.matchcode,  
			   m.isNeutral  
	 END  

 --Get general data  
 TRUNCATE TABLE #TempBetList  
   
 IF (@showRB = 0)  
	INSERT INTO #TempBetList  
	SELECT 	b.Winlostdate,  
			b.currency,  
			b.bettype,  
			SUM(stake) as Stake,  
			SUM(winlost - actual_stake) as Winlost,  
			SUM(b.awinlost) AS awinlost,  
			SUM(b.comm) AS comm, 
			b.oddsid,	
			SUM(b.playercomm  ) AS playercomm,  
			b.matchid,  
			b.Liveawayscore ,  
			CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,  
			b.tpositiontaking,
			COUNT(1) betcount  
	FROM dbo.bettrans14 b WITH(NOLOCK)  
		INNER JOIN @TempAg ag ON b.recommend = ag.custid  AND b.Currency = ag.Currency
	WHERE b.winlostdate = @_Date  
		AND b.statusID NOT IN ( 101, 102, 103 )  
		AND b.bettype NOT IN (901,902,903)
		AND b.matchid = @MatchID  
	GROUP BY  
		b.Winlostdate,  
		b.currency,
		b.oddsid,	
		b.bettype,  
		b.matchid,  
		b.Liveawayscore,  
		CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
		b.tpositiontaking  
ELSE -- @showRB = 1, Racing  
	INSERT INTO #TempBetList  
	SELECT 	b.Winlostdate,  
			b.currency,  
			b.bettype,  
			SUM(stake) as Stake,  
			SUM(winlost - actual_stake) as Winlost,  
			SUM(b.awinlost) AS awinlost,  
			SUM(b.comm) AS comm,
			b.oddsid,	
			SUM(b.playercomm ) AS playercomm,  
			b.matchid,  
			b.Liveawayscore ,  
			CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END AS liveindicator,b.tpositiontaking  ,
			count(1) betcount
	FROM  dbo.bettrans14 b WITH(NOLOCK)  
		INNER JOIN @TempAg ag ON b.recommend = ag.custid  AND b.currency = ag.Currency
		LEFT JOIN outright14 o (NOLOCK) ON b.matchid = o.orid  
	WHERE     
		b.winlostdate = @_Date  
		AND b.statusID NOT IN ( 101, 102, 103 )  
		AND b.bettype NOT IN (901,902,903)
		AND o.leagueid = @LeagueID  
		AND o.groupmatch = @MatchID  
	GROUP BY  
			b.Winlostdate,  
			b.currency,
			b.oddsid,	
			b.bettype,  
			b.matchid,  
			b.Liveawayscore,  
			CASE WHEN b.bettype BETWEEN 81 AND 120 THEN b.liveindicator ELSE 0 END,  
			b.tpositiontaking  
  
 IF (@ShowSB=1)  
	BEGIN  
		INSERT  INTO @AgMatchWLDetails  
		SELECT 	b.Winlostdate,  
				b.currency,  
				m.matchid,  
				m.homeid,  
				m.awayid,  
				b.bettype,
				0 as sporttype,
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
				b.liveindicator AS liveindicator,
				sum(b.betcount) betcount 
		FROM  #TempBetList b  
			 INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
		WHERE     
			(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999)
						  OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
			) AND  
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
	SELECT  b.Winlostdate,  
			b.currency,  
			m.matchid,  
			m.homeid,  
			m.awayid,  
			b.bettype,
			m.sporttype,	
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
			b.liveindicator AS liveindicator,
			sum(b.betcount) betcount  
	FROM #TempBetList b  
		INNER JOIN match14 m WITH ( NOLOCK ) ON m.matchid = b.matchid  
		INNER JOIN @bettype bt ON b.bettype = bt.bettype
		WHERE b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
	GROUP BY  
		b.Winlostdate,  
		b.currency,   
		m.matchid,  
		m.homeid,  
		m.awayid,  
		b.bettype,
		m.sporttype,	
		m.leagueid,  
		m.matchcode,  
		m.isNeutral,  
		b.liveindicator  
   -- VHR
	IF EXISTS (SELECT 1 FROM @bettype WHERE bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()))
	BEGIN 
		INSERT  INTO @AgMatchWLDetails  
		SELECT    
			b.Winlostdate,  
			b.currency,  
			o.EventID matchid,  
			o.RacerID as homeID,  
			0 as awayid,  
			b.bettype,
			r.sporttype,	
			r.leagueid,  
			SUM(b.stake),  
			SUM(winlost - actual_stake) as Winlost ,  
			-SUM(winlost - actual_stake) AS LicenseeWL,  
			0 AS WinlossRB,  
			0 AS AmountDueToBA,  
			0 AS AmountDueToRB,  
			0 AS CommBA,  
			0 as CommRB,  
			SUM(b.playercomm)  as PlayerComm,  
			b.oddsid race,  
			o.RacerNum as matchcode,  
			ISNULL(0, CONVERT(BIT, 0)) AS IsNeutral,  
			0 AS liveindicator,
			count(1) betcount  
		FROM      
			dbo.bettrans14 b  WITH (NOLOCK)
			INNER JOIN @TempAg t ON b.recommend = t.custid AND b.currency = t.currency
			INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @bettype bt ON b.bettype = bt.bettype  
		WHERE  o.EventID=@MatchID
			AND b.winlostdate=@_Date
			AND b.statusID IN (111,112,113)	
			AND b.bettype IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())		
		GROUP BY  
			b.Winlostdate,  
			b.currency,
			o.EventID,	
			b.oddsid,  
			o.RacerID,  
			b.bettype,
			r.sporttype,	
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
		151 sporttype,	
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
		0 AS liveindicator,
		sum(b.betcount) betcount 
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
SELECT ExchangeDate, ExchangeId, USD, EUR,GBP  
FROM Lrf_f_GetExchangeDaily(@_Date,@_Date)  
-- Result  
SELECT      
	matchid,
	sum(b.betcount) betcount,  
	CASE WHEN b.sporttype IN (180,181,182,183,184,185) THEN 0 ELSE homeid END homeid,  
	awayid,  
	CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId
		 ELSE b.bettype 
		END bettype,  
	sporttype,	
	leagueid,  
	CAST(SUM(turnover) AS MONEY) AS turnover,  
	CAST(SUM(turnover * e.USD) AS MONEY) AS turnoverUSD,  
	CAST(SUM(turnover * e.EUR) AS MONEY) AS turnoverEUR,  
	CAST(SUM(turnover * e.GBP) AS MONEY) AS turnoverGBP,
	CAST(SUM(MemberWinLost) AS MONEY) AS MemberWinLost,  
	CAST(SUM(MemberWinLost * e.USD) AS MONEY) AS MemberWinLostUSD,  
	CAST(SUM(MemberWinLost * e.EUR) AS MONEY) AS MemberWinLostEUR,  
	CAST(SUM(MemberWinLost * e.GBP) AS MONEY) AS MemberWinLostGBP,
	--- licenseeWL  
	CAST(SUM(LicenseeWL) AS MONEY) AS LicenseeWL,  
	CAST(SUM(LicenseeWL * e.USD) AS MONEY) AS LicenseeWLUSD,  
	CAST(SUM(LicenseeWL * e.EUR) AS MONEY) AS LicenseeWLEUR,  
	CAST(SUM(LicenseeWL * e.GBP) AS MONEY) AS LicenseeWLGBP,
	CAST(SUM(WinlossRB) AS MONEY) AS WinlossRB,  
	CAST(SUM(WinlossRB * e.USD) AS MONEY) AS WinlossRBUSD,  
	CAST(SUM(WinlossRB * e.EUR) AS MONEY) AS WinlossRBEUR,  
	CAST(SUM(WinlossRB * e.GBP) AS MONEY) AS WinlossRBGBP,  
	CAST(SUM(CommBA) AS MONEY) AS CommBA,  
	CAST(SUM(CommBA * e.USD) AS MONEY) AS CommBAUSD,  
	CAST(SUM(CommBA * e.EUR) AS MONEY) AS CommBAEUR,  
	CAST(SUM(CommBA * e.GBP) AS MONEY) AS CommBAGBP,
	CAST(SUM(commRB) AS MONEY) AS commRB,  
	CAST(SUM(commRB * e.USD) AS MONEY) AS commRBUSD,  
	CAST(SUM(commRB * E.EUR) AS MONEY) AS commRBEUR,  
	CAST(SUM(commRB * E.GBP) AS MONEY) AS commRBGBP,  
	CAST(SUM(PlayerComm) AS MONEY) AS PlayerComm,  
	CAST(SUM(PlayerComm*e.USD) AS MONEY) AS PlayerCommUSD,  
	CAST(SUM(PlayerComm*e.EUR) AS MONEY) AS PlayerCommEUR,  
	CAST(SUM(PlayerComm*e.GBP) AS MONEY) AS PlayerCommGBP, 
	CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA,  
	CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD,  
	CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR,  
	CAST(SUM((AmtDuetoBA) * e.GBP) AS MONEY) AS AmtDuetoBAGBP,  
	CAST(SUM(AmtDuetoRB) AS MONEY) AS AmtDuetoRB,  
	CAST(SUM((AmtDuetoRB) * e.USD) AS MONEY) AS AmtDuetoRBUSD,  
	CAST(SUM((AmtDuetoRB) * e.EUR) AS MONEY) AS AmtDuetoRBEUR,  
	CAST(SUM((AmtDuetoRB) * e.GBP) AS MONEY) AS AmtDuetoRBGBP,  
	 CASE WHEN b.sporttype IN (181,182,183,184,185) THEN '' ELSE race END race,  
	CASE WHEN b.sporttype IN (180,181,182,183,184,185) THEN '' ELSE matchcode END matchcode ,  
	isNeutral,  
	liveindicator  
FROM @AgMatchWLDetails b  
	INNER JOIN @ExchangeDaily e ON b.winlostdate = e.ExchangeDate AND b.currency = e.ExchangeId 
	LEFT JOIN dbo.f_GroupBettype() ss ON b.bettype = ss.bettype 		
GROUP BY    
    matchid,  
    CASE WHEN b.sporttype IN (180,181,182,183,184,185) THEN 0 ELSE homeid END,  
    awayid,  
    CASE WHEN ISNULL(ss.bettype,0) <> 0 THEN ss.grouptypeId
		 ELSE b.bettype 
		END ,
	sporttype,	
    CASE WHEN b.sporttype IN (180,181,182,183,184,185) THEN '' ELSE matchcode END ,  
    leagueid,  
    isNeutral,  
    CASE WHEN b.sporttype IN (181,182,183,184,185) THEN '' ELSE race END ,  
    liveindicator  
      
DROP TABLE #TempBetList
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MatchWinLossByBettype] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MatchWinLossByBettype] TO [vnteam]
   