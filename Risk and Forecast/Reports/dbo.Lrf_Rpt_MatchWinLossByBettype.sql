/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

 
ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchWinLossByBettype]  	
	@MatchID 	  INT, -- in case of Racing, this param is 'race'  
	@LeagueID     INT = 0, -- in case of Racing, this param is '>0'  
	@Date 		  SMALLDATETIME,  
	@MoveBetsDay  SMALLDATETIME,  
	@showSB BIT = 0,  
	@showNG BIT = 0,  
	@showBA BIT = 0,  
	@showVS BIT = 0,
	@ShowCS BIT = 0, --- RNG Casino  
	@ShowVS2 BIT = 0, -- Bet Radar Virtual Sports
	@AgentList	VARCHAR(MAX)
      
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
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
	- 20170731@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180808@Amanda: Remove Racing, Bingo [RedmineID: #99378]
	- 20181019@Amanda: Add new bet types for E-Sports 2.0 [RedmineID: #100721]
	- 20181210@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]

Param's Explanation:   
	+ @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT> 
*/  
  
/* demo script  
exec [Lrf_Rpt_MatchWinLossByBettype] @LicenseeID=3,@LicenseeType=default,@MatchID=1700257,@Date='May 19 2012 12:00:00:000AM',@MoveBetsDay='May 21 2012 12:00:00:000AM',@showSB=1,@showNG=0,@showBA=0  
*/  
SET NOCOUNT ON  
  
DECLARE @ExchangeDaily TABLE(ExchangeDate SMALLDATETIME, ExchangeId INT, USD FLOAT, EUR FLOAT,GBP FLOAT, PRIMARY KEY(ExchangeDate,ExchangeId))  
  
DECLARE @bettype		TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))     
DECLARE @ProductList	VARCHAR (500)

DECLARE @_Date AS DATETIME  
SET @_Date = @Date  
  
DECLARE @Today SMALLDATETIME   
SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)   

DECLARE @IsTest BIT = 0
SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;
  
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
	 AmtDueToBA MONEY,     
	 CommBA   MONEY,     
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
     
IF @ShowNG = 1  
BEGIN  
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'NG', 'NG')
END   
  
IF @ShowVS = 1  
BEGIN  
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS', 'VS')  
END   

IF @ShowVS2 = 1 -- Betradar Virtual Sports
BEGIN
	SELECT @ProductList = COALESCE(@ProductList + ',' + 'VS2', 'VS2')
END

IF LEN(ISNULL(@ProductList, '')) > 0 
BEGIN
	-- Insert Bettype
	INSERT INTO @bettype ( bettype, ProductCode )
	SELECT DISTINCT BetType, ProductPrefix
	FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)
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
		   AND (b.bettype < 901 OR b.bettype > 904)
		   AND (b.bettype < 911 OR b.bettype > 914)
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
			   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
			   SUM (comm ) as CommBA,  
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
		 CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END AS liveindicator,  
		 b.tpositiontaking ,
		 COUNT(1) betcount
	FROM  dbo.bettrans b WITH(NOLOCK)  
		INNER JOIN @TempAg t ON b.recommend = t.CustId AND b.Currency = t.Currency
	WHERE     
	 b.winlostdate = @_Date  
	 AND b.statusID IN (111,112,113)  
	 AND (b.bettype < 901 OR b.bettype > 904)
	 AND (b.bettype < 911 OR b.bettype > 914)
	 AND  b.matchid = @MatchID 

	GROUP BY  
	 b.Winlostdate,  
	 b.currency,
	 b.oddsid,		 
	 b.bettype,  
	 b.matchid,  
	 b.Liveawayscore,  
	 CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END,  
	 b.tpositiontaking  
	 
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
			   0 AS AmountDueToBA,  
			   0 AS CommBA,  
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
							 OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0
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
   
	 IF (@showNG=1 OR @ShowVS=1 OR @ShowVS2 = 1)  
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
			   0 AS AmountDueToBA,  
			   0 AS CommBA,  
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
						0 AS AmountDueToBA,  
						0 AS CommBA,  
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
			   AND (b.bettype < 901 OR b.bettype > 904)
			   AND (b.bettype < 911 OR b.bettype > 914)
			   AND b.matchid = @MatchID  
			   AND tpositiontaking = 0  
			   AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999)
								   OR (b.Bettype BETWEEN 1301 and 1399) --new tennis's bettypes
								   OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0
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
			   -SUM (Winlost +  awinlost + comm) AS AmtDueToBA,  
			   SUM (comm ) as CommBA,  
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
			CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END AS liveindicator,  
			b.tpositiontaking,
			COUNT(1) betcount  
	FROM dbo.bettrans14 b WITH(NOLOCK)  
		INNER JOIN @TempAg ag ON b.recommend = ag.custid  AND b.Currency = ag.Currency
	WHERE b.winlostdate = @_Date  
		AND b.statusID NOT IN ( 101, 102, 103 )  
		AND (b.bettype < 901 OR b.bettype > 904)
		AND (b.bettype < 911 OR b.bettype > 914)
		AND b.matchid = @MatchID  
	GROUP BY  
		b.Winlostdate,  
		b.currency,
		b.oddsid,	
		b.bettype,  
		b.matchid,  
		b.Liveawayscore,  
		CASE WHEN (b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 8101 AND 8120) THEN b.liveindicator ELSE 0 END,  
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
				0 AS AmountDueToBA,  
				0 AS CommBA,  
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
						  OR (b.Bettype BETWEEN 9001 and 9086) -- E-Sports 2.0
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
  
 IF (@showNG=1 OR @ShowVS=1 OR @ShowVS2 = 1)  
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
			0 AS AmountDueToBA,  
			0 AS CommBA,  
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
			0 AS AmountDueToBA,  
			0 AS CommBA,  
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
	CAST(SUM(CommBA) AS MONEY) AS CommBA,  
	CAST(SUM(CommBA * e.USD) AS MONEY) AS CommBAUSD,  
	CAST(SUM(CommBA * e.EUR) AS MONEY) AS CommBAEUR,  
	CAST(SUM(CommBA * e.GBP) AS MONEY) AS CommBAGBP,
	CAST(SUM(PlayerComm) AS MONEY) AS PlayerComm,  
	CAST(SUM(PlayerComm*e.USD) AS MONEY) AS PlayerCommUSD,  
	CAST(SUM(PlayerComm*e.EUR) AS MONEY) AS PlayerCommEUR,  
	CAST(SUM(PlayerComm*e.GBP) AS MONEY) AS PlayerCommGBP, 
	CAST(SUM(AmtDuetoBA) AS MONEY) AS AmtDuetoBA,  
	CAST(SUM((AmtDuetoBA) * e.USD) AS MONEY) AS AmtDuetoBAUSD,  
	CAST(SUM((AmtDuetoBA) * e.EUR) AS MONEY) AS AmtDuetoBAEUR,  
	CAST(SUM((AmtDuetoBA) * e.GBP) AS MONEY) AS AmtDuetoBAGBP,  
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
   