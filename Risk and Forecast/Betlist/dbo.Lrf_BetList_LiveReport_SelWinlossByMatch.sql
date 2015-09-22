USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossByMatch]
	@MatchID		INT,
	@LicenseeID		INT,
	@UserID			INT,
	@CurrencyID		INT = 0,
	@PageSize		INT = 1000,
	@PageIndex		INT = 1,
	@ShowSB			BIT = 0,
	@ShowBA			BIT = 0,
	@ShowLC			BIT = 0,
	@ShowVS			BIT = 0,
	@Liveindicator	INT = 1
AS
/*
	Created: 20120111@Henry
	Task : Betlist
	DB: DB052.bodb02
	Original:[Lrf_BetList_SelWinlostByMatch]
	Revisions:
		Get all tickets for a match
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		- 20120614@Jim: optimize code
		- 20120724@Jim: add playercomm value 
		- 20120820@Jim: add livecasino  
		- 20120913@Jim: add virtual sport 
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20130411@Jim: support base currency USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS 
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20140630@Hannah: offer BetRadar and Sporting Solution 
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust   
		- 20150124@Winnie: add base currency GBP
		- 20150413@Winnie: Apply spottype bettype matrix & add 60 bettype betradar 
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20150609@Edward: Support Microgaming
		- 20150922@Edward: Don't support Microgaming anymore

	Param's Explanation: 
		@Liveindicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All 	
*/

SET NOCOUNT ON
DECLARE @SportBettype TABLE(ProductID INT,Bettype INT,EventType INT)
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4

DELETE @SportBettype WHERE ProductID = 1 AND Bettype IN (901,902,903)
--DECLARE @bettype AS TABLE (bettype INT)   

--IF @ShowLC = 1
--BEGIN	
 --   INSERT INTO @bettype(bettype)
	--SELECT typeid FROM bettype (NOLOCK)
	--WHERE (typeid BETWEEN 1101 AND 1199)

--END
 
--IF @ShowVS = 1
--BEGIN
	--INSERT INTO @bettype(bettype)
	--SELECT typeid FROM bettype (NOLOCK)
	--WHERE (typeid BETWEEN 1201 AND 1299)
--END 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
INSERT  INTO @TempAg ( CustId)
SELECT DISTINCT CustID  
FROM    bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )  
		INNER JOIN #currency c ON lc.Currency=c.CurrencyID AND lc.LicenseeID=c.LicenseeID
--WHERE   lc.Currency <> 20
---------------------

---------------------
DECLARE @Fromdate DATETIME
DECLARE @Todate DATETIME
DECLARE @RowStart INT, @RowEnd INT  

SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE TABLE #Data
(
	Sporttype INT,
	Username NVARCHAR(50),
	CustID INT,
	Bettype INT,
	LeagueID INT,
	Transid BIGINT,
	Matchcode VARCHAR(50),
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	status NVARCHAR(50),
	stake MONEY,
	Winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	transdate DATETIME,
	Winlostdate DATETIME,
	betteam VARCHAR (50),
	liveindicator INT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	MatchID INT,
	ip NVARCHAR(30),
	Betstatus NVARCHAR(50),
	IsNeutral BIT,
	oddstype INT,
	betid BIGINT,
	currency SMALLINT,
	RefNO			BIGINT,	
	showtime NVARCHAR(50), -- table - shoe - hand of Live Casino
	betcheck NVARCHAR(50)
)

IF EXISTS(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID=@MatchID)
BEGIN	
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime,
			b.betcheck AS betcheck
		FROM
			bettrans b WITH (NOLOCK,INDEX=IXU_transid) 
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.matchid=@matchid AND			
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			--b.bettype NOT IN (9,29) AND
			sbt.ProductID=1  AND sbt.EventType!=0 AND-- sportbook
			b.statusID IN (111,112,113) AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid		
		
		--BA for parlay
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime
			,NULL AS betcheck
		FROM
			bettrans b WITH (NOLOCK,INDEX=IXU_transid) 
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.matchid=@matchid AND			
			b.recommend IN (SELECT custid FROM @TempAg)	AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			--b.bettype IN (9,29) AND
			sbt.ProductID=1 AND sbt.EventType=0 AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime 
			,b.betcheck AS betcheck
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.matchid=@matchid AND			
			--(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) AND
			--b.bettype NOT IN (9,29) AND
			sbt.ProductID=1 AND sbt.EventType!=0 AND
			b.recommend IN (SELECT custid FROM @TempAg)	AND	
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid

		--SB for parlay
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime 
			,NULL AS betcheck
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE
			b.matchid=@matchid AND			
			--b.bettype IN (9,29) AND
			sbt.ProductID=1 AND sbt.EventType=0 AND
			b.recommend IN (SELECT custid FROM @TempAg)	AND	
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid
	END

	IF (@ShowLC=1 OR @ShowVS=1 ) 
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			CASE WHEN sbt.ProductID=4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime--b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
			,NULL AS betcheck
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid
			--INNER JOIN @bettype bt ON b.bettype = bt.bettype 
			INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype	  
		WHERE
			b.matchid=@matchid AND			
			b.recommend IN (SELECT custid FROM @TempAg)	AND	
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.statusID IN (111,112,113)	AND
			(
			(@ShowVS=1 AND sbt.ProductID=5 AND sbt.EventType=1)
			OR (@ShowLC=1 AND sbt.ProductID=4)
			) AND
			--b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))

		ORDER BY
			b.status, b.transid
	END	
END
ELSE
BEGIN	
	IF @ShowBA = 1
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime
			,b.betcheck AS betcheck
		FROM
			bettrans14 b WITH (NOLOCK) 			
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype	
		WHERE
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.matchid=@matchid AND						
			b.statusID IN (111,112,113)	
			AND tpositiontaking = 0
			--AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) AND
			--b.bettype NOT IN (9,29) AND
			AND sbt.ProductID=1 AND sbt.EventType!=0 AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid

		--BA for parlay
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			0 AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime
			,NULL AS betcheck
		FROM
			bettrans14 b WITH (NOLOCK) 			
			--INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid 	 		
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype
		WHERE
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.matchid=@matchid AND						
			b.statusID IN (111,112,113)	
			AND tpositiontaking = 0	AND 
			--b.bettype IN (9,29) AND
			sbt.ProductID=1 AND sbt.EventType=0 AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid
	END

	IF (@ShowSB=1)
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime 
			,b.betcheck AS betcheck
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype	
		WHERE
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.matchid=@matchid AND						
			--(b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) AND
			--b.bettype NOT IN (9,29) AND
			sbt.ProductID=1 AND sbt.EventType!=0 AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid

		--SB for parlay
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime 
			,NULL AS betcheck
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
			INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype
		WHERE
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.matchid=@matchid AND						
			--b.bettype IN (9,29) AND
			sbt.ProductID=1 AND sbt.EventType=0 AND
			b.tpositiontaking<>0 AND
			b.statusID IN (111,112,113) AND
			((@Liveindicator = 0 and b.livehomescore = 0)
			OR (@Liveindicator = 1 and b.livehomescore = 1)
			OR (@Liveindicator = 2))
		ORDER BY
			b.status, b.transid
	END

	IF (@ShowLC=1 OR @ShowVS=1)
	BEGIN
		INSERT INTO #Data	
		SELECT TOP(@RowEnd)
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueID,			
			b.transid,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			b.IP AS IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			CASE WHEN sbt.ProductID=4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime
			--CASE WHEN b.bettype BETWEEN 1101 AND 1199  THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
			,NULL AS betcheck
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN @TempAg t  ON b.recommend =t.custid  
			INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid
			--INNER JOIN @bettype bt ON b.bettype = bt.bettype
			INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype	
		WHERE
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) and
			b.matchid=@matchid AND						
			b.statusID IN (111,112,113)	AND
			--b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
			(
			(@ShowVS=1 AND sbt.ProductID=5 AND sbt.EventType=1)
			OR (@ShowLC=1 AND sbt.ProductID=4)
			) AND
			((@Liveindicator = 0 and b.liveindicator = 0)
			OR (@Liveindicator = 1 and b.liveindicator = 1)
			OR (@Liveindicator = 2))

		ORDER BY
			b.status, b.transid
	END	
END

SELECT @Fromdate=MIN(winlostdate),@Todate=MAX(winlostdate) 
FROM #Data 

CREATE NONCLUSTERED INDEX IDX_Index_data ON #Data(Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
			b.* ,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   		
			--USD
			stake*e.USD stakeUSD,
			Winlost*e.USD WinlostUSD,
			LicenseeWL*e.USD LicenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD playerCommUSD,
			
			stake*e.EUR stakeEUR,
			Winlost*e.EUR WinlostEUR,
			LicenseeWL*e.EUR LicenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR playerCommEUR,
			
			stake*e.GBP			stakeGBP,
			Winlost*e.GBP		WinlostGBP,
			LicenseeWL*e.GBP	LicenseeWLGBP,
			comm*e.GBP			commGBP,
			playercomm*e.GBP	playerCommGBP
			
	FROM #Data b
	INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
	INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DECLARE @BettransDetail TABLE(  
	refno BIGINT,  
	odds SMALLMONEY,  
	stake MONEY,
	status NVARCHAR(10),  
	apositiontaking SMALLMONEY,  
	bettype SMALLINT,
	Betteam nvarchar (10),
	stakeEUR MONEY,
	stakeUSD MONEY,
	stakeGBP MONEY
	 )   

IF @ShowLC=1
BEGIN
	IF EXISTS(SELECT TOP 1 1 FROM Match WITH(NOLOCK) WHERE MatchID=@MatchID)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam,
			BG.stake*e.EUR,
			BG.stake*e.USD,
			BG.stake*e.GBP
		FROM bettransg BG WITH (NOLOCK)
		INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
		INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
		INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE sbt.ProductID=4--B.Bettype BETWEEN 1101 AND 1199
	END
		
	IF EXISTS(SELECT TOP 1 1 FROM Match14 WITH(NOLOCK) WHERE MatchID=@MatchID)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype,
			BG.Betteam ,
			BG.stake*e.EUR,	
			BG.stake*e.USD,
			BG.stake*e.GBP
		FROM bettransg14 BG WITH (NOLOCK)
		INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
		INNER JOIN #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
		INNER JOIN @SportBettype sbt ON b.Bettype=sbt.Bettype
		WHERE sbt.ProductID=4--B.Bettype BETWEEN 1101 AND 1199
	END	
END

SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype

DROP TABLE #Data
DROP TABLE #TempExchange
DROP TABLE 	#currency
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossByMatch] TO [vnteam]