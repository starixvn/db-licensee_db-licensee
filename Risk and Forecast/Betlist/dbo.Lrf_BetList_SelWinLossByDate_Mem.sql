set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinLossByDate_Mem]
	@LicenseeID 	INT,
	@UserID			INT,
	@CustID INT,
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@Langkey VARCHAR(20) = 'en-US',
	@MoveBetsDay SMALLDATETIME,
	@BalanceUpDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumLicenseeWL	 MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumLicenseeWLUSD 	MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWLEUR   MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT,
	@ShowSB BIT = 0,
	@ShowRB BIT = 0,
	@ShowNG BIT = 0,
	@ShowBA BIT = 0,
	@ShowLC BIT = 0,
	@ShowVS BIT = 0,
	@ShowCS BIT = 0,-- RNG Casino
	@ShowBG BIT = 0
	
AS

/*
Created: 20101209@Henry
Task : Bet List Win-loss By Date
DB: DBRPT/bodb02
Original: [Age_BetList_SelWinLossByDate_Mem]

Revisions:
   -- 20110214@Jacob: Add column discount in the result SET
   -- 20110303@Henry: suppport based currency
   -- 20110318@Henry: Change server DB052 to DB06 (support bet list old)	
   -- 20110408@Amy: Change function to get Odds value AND odds type
					Get data for Number Game
   - 20110513@Henry: change bettype to new range
   - 20110523@Henry: remove @ShowCasino, @ShowP2P, @ShowFI, @ShowBI
   - 20110712@Henry: Add column LicenseeWL	
   - 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mixed Parlay
   - 20111208@Jim: change condition bettype<31		
   - 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
   - 20120319@Henry: show main transid for sub-ticket of system parlay
   - 20120614@Jim: optimize code 
   - 20120711@Jim: get value for hdp1, hdp2 
   - 20120726@Jim: add playercomm value 
   - 20120817@Jim: add live casino 
   - 20120913@Jim: add virtual sport 	
   - 20130123@Daniel: Change link server alias
   - 20130225@Jim: support RNG Casino, Bingo 
   - 20130514@Jim:Restrict permission of Licensee Users by currency
   - 20130716@Jim: update matchid for RNG Casino and Bingo
   */

SET NOCOUNT ON

DECLARE @UserName NVARCHAR(20), @Recommend INT

	SELECT CurrencyID
		  ,LicenseeID
		  INTO #Currency
	FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE  usrID=@userID 
		AND LicenseeID=@LicenseeID 
		AND SystemID=1
		AND isActive=1

SELECT @UserName =UserName, @Recommend = Recommend 
FROM custinfo c WITH(NOLOCK) 
	INNER JOIN #Currency cy ON c.Currency=cy.CurrencyID	
WHERE CustID=@CustID
----------------------------------------
DROP TABLE #currency
-----------------------------------------
CREATE TABLE #BetListByDateMem (
	Sporttype SMALLINT,
	Username NVARCHAR(20), 
	TransID BIGINT,
	BetID BIGINT,
	Bettype SMALLINT,
	hdp1 SMALLMONEY, 
	hdp2 SMALLMONEY, 
	OddsType TINYINT,
	Odds SMALLMONEY, 
	modds SMALLMONEY, 
	Stake MONEY, 
	Actual_Stake	MONEY,
	Betteam NVARCHAR(20),
	Status NVARCHAR(10),
	RefNO BIGINT,	
	Transdate DATETIME,
	Winlostdate DATETIME,
	Winlost MONEY,
	licenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	Liveindicator BIT,
	Livehomescore SMALLINT,
	Liveawayscore SMALLINT,
	IP NVARCHAR(15),
	LeagueID INT,
	MatchID INT,
	MatchCode NVARCHAR(50),
	Race NVARCHAR(20),
	HomeID INT,
	AwayID INT, 	
	Betstatus NVARCHAR(50),
	isNeutral BIT,
	currency SMALLINT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)

CREATE TABLE  #TempBetList (
	TransID			BIGINT,
	BetID			BIGINT,
	Bettype			INT,
	hdp1			SMALLMONEY, 
	hdp2			SMALLMONEY, 
	OddsType		TINYINT,
	Odds			SMALLMONEY, 
	modds SMALLMONEY, 
	Stake MONEY, 
	Actual_Stake	MONEY,
	Betteam			NVARCHAR(20),
	Status			NVARCHAR(10),
	RefNO			BIGINT,	
	Transdate		DATETIME,
	Winlostdate		DATETIME,
	Winlost			MONEY,
	LicenseeWL		MONEY,
	comm			MONEY,
	playercomm 		MONEY,
	Liveindicator	BIT,
	Livehomescore	SMALLINT,
	Liveawayscore	SMALLINT,
	IP				NVARCHAR(50),
	currency INT,
	MatchID INT
)

DECLARE @TempFromDate DATETIME
DECLARE @TempToDate DATETIME

IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay 
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate

	--general BA tickets
	INSERT INTO #TempBetList
	SELECT
		b.TransID,
		ISNULL(b.BetID,0),
		b.Bettype,
		b.hdp1, 
		b.hdp2,
		b.OddsType,
		b.Odds,
		b.modds,
		b.stake,
		b.actual_stake, 
		b.betteam,
		b.status AS Status,				
		b.refno,
		b.Transdate,	
		b.winlostdate,			
		(b.winlost-actual_stake),
		0 AS LicenseeWL ,
		b.comm,
		b.playercomm ,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		b.IP AS IP,		
		b.currency,
		b.MatchID
	FROM
		dbo.bettrans AS b WITH (NOLOCK)		
		INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @TempFromDate AND @todate AND
		b.recommend = @Recommend AND --to improve performance
		b.custid=@custid AND
		b.ruben = 1 

	IF @ShowBA = 1
	BEGIN
		--sport book		
		INSERT INTO #BetListByDateMem
		SELECT
			m.Sporttype, 
			@Username, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake,  
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
			INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999)) AND 
			b.bettype <>10
		
		--Outright
		INSERT INTO #BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			@Username, 
			b.TransID,
			b.BetID,
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
			INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10
		-- Mix Parlay
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9 
		
		--Combination Mixed Parlay
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake,  
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
		WHERE
			b.bettype = 29
			AND b.matchid = 29
			
	END

	--Sport Book
	IF @ShowSB = 1
	BEGIN
		INSERT INTO #BetListByDateMem
		SELECT
			m.Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid=m.matchid 					
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND --to improve performance
			b.matchid > 0 AND
			b.custid=@custid AND
			(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999 )) AND
			b.bettype NOT IN (9,29,10) AND
			b.ruben = 1 AND
			b.transid NOT IN (SELECT Transid FROM #TempBetList) 

		-- Outright
		INSERT INTO #BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake,  
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  ,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND
			b.custid=@custid AND
			b.bettype = 10 AND
			b.ruben = 1 AND
			b.transid NOT IN (SELECT Transid FROM #TempBetList) 
				

		-- Mix Parlay		
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			dbo.bettrans AS b WITH (NOLOCK)	
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND
			b.custid=@custid AND
			b.bettype = 9 AND
			b.matchid = 9 AND
			b.ruben = 1 AND
			b.transid NOT IN (SELECT Transid FROM #TempBetList) 
				
		--Combination Mix Parlay	
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			ISNULL(b.BetID,0),
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake,  
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			dbo.bettrans AS b WITH (NOLOCK)	
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND
			b.custid=@custid AND
			b.bettype = 29 AND
			b.matchid = 29 AND
			b.ruben = 1 AND
			b.transid NOT IN (SELECT Transid FROM #TempBetList) 
				
	END

	-- Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			b.awinlost,
			b.comm,
			b.playercomm ,	
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND
			b.custid=@custid AND
			b.bettype IN (31, 32, 33) AND
			b.ruben = 1
				
	END
	

	IF (@ShowNG=1 )
	BEGIN
		INSERT INTO #BetListByDateMem
			SELECT
			m.Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.Oddstype,			
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,				
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			 ''  AS ShowTime 	
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid=@CustID AND
			(b.bettype BETWEEN 81 AND 120) AND
			b.ruben = 1 
			
	END
	IF (@ShowLC=1 OR @ShowVS=1 )
	BEGIN
		INSERT INTO #BetListByDateMem
			SELECT
			m.Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.Oddstype,			
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,				
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			CASE WHEN (b.bettype BETWEEN 1101 AND 1199) THEN ISNULL (m.showtime,'') ELSE '' END AS  ShowTime 	
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
			INNER JOIN dbo.MATCH AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid=@CustID AND
			((@ShowLC=1 AND b.bettype BETWEEN 1101 AND 1199) 
				OR (@ShowVS=1 AND b.bettype BETWEEN 1201 AND 1299)
				)  AND
			--((b.bettype BETWEEN 81 AND 120) OR (b.bettype BETWEEN 1101 AND 1199) ) AND
			b.ruben = 1 
			
	END
	IF @ShowCS=1
	BEGIN
		INSERT INTO #BetListByDateMem
			SELECT
			251 Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.Oddstype,			
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,				
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0  AS  LeagueID,
			71  AS MatchID,	
			'' AS  MatchCode,
			'' AS  Race,	
			0  AS HomeID,
			0  AS AwayID, 		
			0  AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			'' AS  ShowTime 	
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid=@CustID AND
			b.bettype=71 AND 
			b.ruben = 1 
			
	END
	
	IF @ShowBG=1
	BEGIN
		INSERT INTO #BetListByDateMem
			SELECT
			252 Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.Oddstype,			
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,				
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0  AS  LeagueID,
			73  AS MatchID,	
			'' AS  MatchCode,
			'' AS  Race,	
			0  AS HomeID,
			0  AS AwayID, 		
			0  AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			'' AS  ShowTime 	
		FROM
			dbo.bettrans AS b WITH (NOLOCK)		
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid=@CustID AND
			b.bettype=73 AND 
			b.ruben = 1 
			
	END
END

IF @Fromdate <= @MoveBetsDay
BEGIN
	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET  @TempToDate = @ToDate
	
	IF @BalanceUpDay < @FromDate 
		SELECT @BalanceUpDay=@FromDate

	DELETE FROM #TempBetList
		
	--general BA tickets
	INSERT INTO #TempBetList
	SELECT
		b.TransID,
		ISNULL(b.BetID,0),
		b.Bettype,
		b.hdp1, 
		b.hdp2, 
		b.Oddstype,
		b.odds,
		b.modds,
		b.stake,
		b.actual_stake,  
		b.betteam,
		b.status AS Status,				
		b.refno,
		b.Transdate,	
		b.winlostdate,						
		(b.winlost-actual_stake),
		0 AS LicenseeWL ,			
		b.comm,
		b.playercomm  ,
		b.Liveindicator,
		b.Livehomescore,
		b.Liveawayscore,
		b.IP AS IP,
		b.currency,
		b.matchid
	FROM
		dbo.bettrans14 AS b WITH (NOLOCK)		
		INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
		b.recommend = @Recommend AND
		b.custid=@custid AND
		b.ruben = 1

	IF @ShowBA = 1
	BEGIN
		
			
		--sport book		
		INSERT INTO #BetListByDateMem
		SELECT
			m.Sporttype, 
			@Username, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
			INNER JOIN dbo.MATCH14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND  999 )) AND
			b.bettype <>10
		
		--Outright
		INSERT INTO #BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			@Username, 
			b.TransID,
			b.BetID,
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
			INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10
		-- Mix Parlay
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake,  
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9 
		
		-- Combination Mixed Parlay
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake,  
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
		WHERE
			b.bettype = 29 
			AND b.matchid = 29
		
	END

	--Sport Book
	IF @ShowSB = 1
	BEGIN	
		INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status AS Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				m.LeagueID,
				m.MatchID,	
				m.MatchCode,
				'' AS Race,	--Race
				m.HomeID,
				m.AwayID, 		
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)		
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 					
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.recommend = @Recommend AND
				b.custid=@custid AND
				b.matchid > 0 AND
				(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999)) AND
				b.bettype NOT IN (9,29,10) AND
				b.ruben = 1 AND 
				b.transid NOT IN (SELECT Transid FROM #TempBetList) 
				
		--Mix Parlay
		INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,  
				b.betteam,
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race	
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)	
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.recommend = @Recommend AND
				b.custid=@custid AND
				b.bettype = 9 AND				
				b.matchid = 9 AND
				b.ruben = 1 AND 
				b.transid NOT IN (SELECT Transid FROM #TempBetList)
				
		--Combination Mixed Parlay
		INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,  
				b.betteam,
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm  ,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race	
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)	
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.recommend = @Recommend AND
				b.custid=@custid AND
				b.bettype = 29 AND				
				b.matchid = 29 AND
				b.ruben = 1 AND 
				b.transid NOT IN (SELECT Transid FROM #TempBetList)
			
				
		INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake)  AS LicenseeWL ,
				b.comm,
				b.playercomm  ,		
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.OrId,--0, --MatchID	
				m.MatchCode,
				m.GroupMatch AS Race,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)		
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
				b.recommend = @Recommend AND
				b.custid=@custid AND
				b.bettype = 10 AND
				b.ruben = 1 AND 
				b.transid NOT IN (SELECT Transid FROM #TempBetList)
				
				
	END	
	--Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			(b.winlost-actual_stake),
			b.awinlost,
			b.comm,
			b.playercomm  ,
			0 AS LiveIndicator, 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch AS Race,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS isNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)		
			INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.recommend = @Recommend AND
			b.custid=@custid AND
			b.bettype IN (31, 32, 33) AND				
			b.ruben = 1			
	END
	
	--Number Game , Live Casino ,Virtual Sport, Bingo
	IF (@ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1  ) 
	BEGIN	
		INSERT INTO #BetListByDateMem
		SELECT
			m.Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.Oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 	
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)		
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid=m.matchid 
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid=@CustID AND
			((@ShowNG=1 AND b.bettype BETWEEN 81 AND 120) 
				OR (@ShowLC=1 AND b.bettype BETWEEN 1101 AND 1199 )
				OR (@ShowVS=1 AND b.bettype BETWEEN 1201 AND 1299 )
				) AND
			b.ruben = 1
	END
	-- RNG Casino
	IF @ShowCS=1 
	BEGIN	
		INSERT INTO #BetListByDateMem
		SELECT
			251 Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.Oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0  AS  LeagueID,
			71  AS  MatchID,	
			'' AS  MatchCode,
			'' AS Race,	
			0  AS HomeID,
			0  AS AwayID, 		
			0  AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			''  AS ShowTime 	
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)		
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid=@CustID AND
			b.bettype=71 AND 
			b.ruben = 1
	END
	---- Bingo
	IF @ShowBG=1 
	BEGIN	
		INSERT INTO #BetListByDateMem
		SELECT
			252 Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.Oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0  AS  LeagueID,
			73  AS  MatchID,	
			'' AS  MatchCode,
			'' AS Race,	
			0  AS HomeID,
			0  AS AwayID, 		
			0  AS Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			''  AS ShowTime 	
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)		
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.recommend = @Recommend AND --to improve performance
			b.custid=@CustID AND
			b.bettype=73 AND 
			b.ruben = 1
	END	
END	

IF @FromDate < @BalanceUpDay
BEGIN
	IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
		SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
	ELSE
		SET @TempToDate = @todate

	DELETE FROM #TempBetList
		
		--general BA tickets
		INSERT INTO #TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1, 
			b.hdp2, 			
			b.Oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			0 AS LicenseeWL ,			
			b.comm,
			b.playercomm ,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			b.currency,
			b.matchid
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (nolock, index=IX_custid)		
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid				
		WHERE
			b.winlostdate BETWEEN @fromdate AND @TempToDate AND
			b.recommend = @Recommend  AND
			b.custid=@custid AND
			b.ruben = 1 

	IF @ShowBA = 1
	BEGIN
		

		--sport book		
		INSERT INTO #BetListByDateMem
		SELECT
			m.Sporttype, 
			@Username, 
			b.TransID,
			b.BetID,
			b.Bettype,
			b.hdp1, 
			b.hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			b.winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
			INNER JOIN bodb_archive.dbo.MATCH_BK AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999)) AND
			b.bettype <>10
		
		--Outright
		INSERT INTO #BetListByDateMem
		SELECT
			l.sporttype, --Sporttype
			@Username, 
			b.TransID,
			b.BetID,
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			'' AS Betteam, --Betteam
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			0 AS LiveIndicator , 
			b.LiveHomescore, 
			b.LiveAwayscore,
			b.IP AS IP,
			m.LeagueID,
			m.OrId,--0, --MatchID	
			m.MatchCode,
			m.GroupMatch,--Race
			m.TeamID, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
			INNER JOIN bodb_archive.dbo.Outright_BK AS m WITH (NOLOCK) ON b.matchid=m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.bettype = 10
		-- Mix Parlay
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
		WHERE
			b.bettype = 9 AND
			b.matchid = 9 
		
		--Combination Mixed Parlay
		INSERT INTO #BetListByDateMem
		SELECT
			0, --Sporttype
			@Username, 
			b.TransID,
			b.BetID,
			b.bettype,
			b.hdp1, 
			b.hdp2, 
			0 AS OddsType, 
			b.Odds, 
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,						
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0, --LeagueID
			0, --MatchID	
			'',--MatchCode
			'',--Race
			0, --HomeID
			0, --AwayID		
			0, --Betstatus
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
		FROM
			#TempBetList b
		WHERE
			b.bettype = 29
			AND b.matchid = 29
			

	END
	

	--Sport Book
	IF @ShowSB = 1
	BEGIN	
		INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 			
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status AS Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,			
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm AS PlayerComm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				m.LeagueID,
				m.MatchID,		
				m.MatchCode,
				'' AS Race,	
				m.HomeID,
				m.AwayID, 		
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (nolock, index=IX_custid)		
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (nolock) ON b.matchid=m.matchid 					
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate AND
				b.custid=@custid AND
				b.recommend = @Recommend AND 
				b.ruben = 1 AND
				(b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999 ) ) AND
				b.bettype <> 10 AND
				b.transid NOT IN (SELECT Transid FROM #TempBetList) 

		-- Mix Parlay		

		INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake)  AS LicenseeWL ,
				b.comm,
				b.playercomm  AS PlayerComm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (nolock, index=IX_custid)
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate AND
				b.custid=@custid AND	
				b.recommend = @Recommend AND				
				b.bettype = 9 AND
				b.matchid IN (0,9) AND --should not remove 0 in Archive
				b.ruben = 1 AND
				b.transid NOT IN (SELECT Transid FROM #TempBetList) 
		
		--Combination Mixed Parlay
		INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,  
				b.betteam,
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake)  AS LicenseeWL ,
				b.comm,
				b.playercomm AS PlayerComm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP AS IP,
				0, --LeagueID
				0, --MatchID	
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (nolock, index=IX_custid)
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate AND
				b.custid=@custid AND
				b.recommend = @Recommend  AND 		
				b.bettype = 29 AND
				b.matchid = 29 AND
				b.ruben = 1 AND
				b.transid NOT IN (SELECT Transid FROM #TempBetList) 
				
		-- Outright		
		INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm,
				b.playercomm  AS PlayerComm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.orid, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.teamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (nolock, index=IX_custid)		
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (nolock) ON b.matchid=m.orid 
				INNER JOIN dbo.League AS l WITH (nolock) ON m.leagueID = l.leagueID
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate AND
				b.custid=@custid AND
				b.recommend = @Recommend  AND		
				b.ruben = 1 AND
				b.bettype = 10 AND
				b.ruben = 1 AND
				b.transid NOT IN (SELECT Transid FROM #TempBetList) 
	END
	
	--Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam, --Betteam
				b.Status,				
				b.refno,
				b.Transdate,	
				b.winlostdate,						
				(b.winlost-actual_stake),
				b.awinlost,
				b.comm,
				b.playercomm AS PlayerComm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP AS IP,
				m.LeagueID,
				m.orid, --MatchID	
				m.MatchCode,
				m.GroupMatch,--Race
				m.teamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime 
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (nolock, index=IX_custid)		
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (nolock) ON b.matchid=m.orid 
				INNER JOIN dbo.League AS l WITH (nolock) ON m.leagueID = l.leagueID
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate AND
				b.custid=@custid AND
				b.recommend = @Recommend AND 		
				b.ruben = 1 AND 
				b.bettype IN (31, 32, 33)
	
	END
	
	--Number Game,Live Casino 
	IF (@ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1  )
	BEGIN	
		INSERT INTO #BetListByDateMem
		SELECT			
			m.Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.Betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,				
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			m.LeagueID,
			m.MatchID,	
			m.MatchCode,
			'' AS Race,	
			m.HomeID,
			m.AwayID, 		
			m.Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 	
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)		
			INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid=m.matchid 		
		WHERE
			b.winlostdate BETWEEN @fromdate AND @TempToDate AND			
			b.custid=@CustID AND
			b.recommend = @Recommend  AND
			((@ShowNG=1 AND b.bettype BETWEEN 81 AND 120) 
				OR (@ShowLC=1 AND b.bettype BETWEEN 1101 AND 1199 )
				OR (@ShowVS=1 AND b.bettype BETWEEN 1201 AND 1299 )
				) AND
			b.ruben = 1
			
			
	END
	IF @ShowCS=1
	BEGIN	
		INSERT INTO #BetListByDateMem
		SELECT			
			251 Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.Betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,				
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS  LeagueID,
			71 AS  MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0  AS  HomeID,
			0  AS  AwayID, 		
			0  AS  Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			'' AS ShowTime 	
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)		
		WHERE
			b.winlostdate BETWEEN @fromdate AND @TempToDate AND			
			b.custid=@CustID AND
			b.recommend = @Recommend AND	
			b.bettype=71 AND 
			b.ruben = 1
			
			
	END
	IF @ShowBG=1
	BEGIN	
		INSERT INTO #BetListByDateMem
		SELECT			
			252 Sporttype, 
			@Username, 
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.OddsType,
			b.Odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.Betteam,
			b.status AS Status,				
			b.refno,
			b.Transdate,	
			b.winlostdate,			
			(b.winlost-actual_stake),
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm  AS PlayerComm,				
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP AS IP,
			0 AS  LeagueID,
			73 AS  MatchID,	
			'' AS MatchCode,
			'' AS Race,	
			0  AS  HomeID,
			0  AS  AwayID, 		
			0  AS  Betstatus,
			CONVERT(BIT,0) AS IsNeutral	,
			b.currency,
			'' AS ShowTime 	
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, index=IX_custid)		
		WHERE
			b.winlostdate BETWEEN @fromdate AND @TempToDate AND			
			b.custid=@CustID AND
			b.recommend = @Recommend AND	
			b.bettype=73 AND 
			b.ruben = 1
			
			
	END
END

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @Today SMALLDATETIME 
SET @Today = convert(VARCHAR(10), CURRENT_TIMESTAMP, 120)

CREATE NONCLUSTERED INDEX IDX_Index_betlist ON #BetListByDateMem (Currency)


SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #BetListByDateMem)


SELECT 
	@TotalRows = COUNT(transid),
	@SumWinlost=SUM(ISNULL(winlost,0)),
	@SumLicenseeWL=SUM(ISNULL(licenseeWL,0)),
	@SumComm=SUM(ISNULL(comm,0)) ,
	@SumPlayerComm=SUM(ISNULL(playercomm,0)),
	--USD
	@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
	@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
	@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)),
	--EUR
	@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
	@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)) ,
	@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0))
FROM #BetListByDateMem b
	INNER JOIN #TempExchange e 
	ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN  b.winlostdate ELSE @Today END)   AND e.exchangeid = b.currency


SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.TransID) AS RowNum,
			b.* ,
			--USD
			Stake*e.USD StakeUSD,
			Actual_Stake*e.USD Actual_StakeUSD,
			Winlost*e.USD WinlostUSD,
			licenseeWL*e.USD licenseeWLUSD,
			comm*e.USD commUSD,
			playercomm*e.USD PlayerCommUSD,
			--EUR
			Stake*e.EUR StakeEUR,
			Actual_Stake*e.EUR Actual_StakeEUR,
			Winlost*e.EUR WinlostEUR,
			licenseeWL*e.EUR licenseeWLEUR,
			comm*e.EUR commEUR,
			playercomm*e.EUR PlayerCommEUR
			
	FROM #BetListByDateMem b
	INNER JOIN #TempExchange e  
	ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN  b.winlostdate ELSE @Today END)   AND e.exchangeid = b.currency
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
	stakeUSD MONEY

	 )   

IF @ShowRB = 1
	IF @Todate > @MoveBetsDay 
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype,
			BM.betteam,
			BM.stake*e.EUR,
			BM.stake*e.USD	
		FROM bettransm BM WITH (NOLOCK)
		INNER JOIN #BetListByDateMem B ON BM.refno = B.transid
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE B.Bettype IN (33,43)
	END
		
	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype,
			BM.betteam,
			BM.stake*e.EUR,
			BM.stake*e.USD	
		FROM bettransm14 BM WITH (NOLOCK)
		INNER JOIN #BetListByDateMem B ON BM.refno = B.transid
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE B.Bettype IN (33,43)
	END	
	IF @FromDate < @BalanceUpDay
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BM.refno, 
			BM.odds, 
			BM.stake,
			BM.status, 
			BM.apositiontaking, 
			BM.bettype,
			BM.betteam,
			BM.stake*e.EUR,	
			BM.stake*e.USD
		FROM bodb_archive.dbo.bettransm BM WITH (NOLOCK)
		INNER JOIN #BetListByDateMem B ON BM.refno = B.transid
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE B.Bettype IN (33,43)
	
	END
	
IF @ShowLC=1
	BEGIN
		IF @Todate > @MoveBetsDay 
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.betteam,
				BG.stake*e.EUR,	
				BG.stake*e.USD
			FROM bettransg BG WITH (NOLOCK)
			INNER JOIN #BetListByDateMem B ON BG.refno = B.refno AND BG.CustID=@CustID
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype BETWEEN 1101 AND 1199 
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.betteam,
				BG.stake*e.EUR,	
				BG.stake*e.USD
			FROM bettransg14 BG WITH (NOLOCK)
			INNER JOIN #BetListByDateMem B ON BG.refno = B.refno AND BG.CustID=@CustID 
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype BETWEEN 1101 AND 1199
		END	
		IF @FromDate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				BG.refno, 
				BG.odds, 
				BG.stake,
				BG.status, 
				BG.apositiontaking, 
				BG.bettype,
				BG.betteam,
				BG.stake*e.EUR,
				BG.stake*e.USD	
			FROM bodb_archive.dbo.bettransg BG WITH (NOLOCK)
			INNER JOIN #BetListByDateMem B ON BG.refno = B.refno AND BG.CustID=@CustID
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency	
			WHERE B.Bettype BETWEEN 1101 AND 1199
		
		END
	END 
	SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype
	

DROP TABLE #TempExchange
DROP TABLE #BetListByDateMem
DROP TABLE #TempBetList
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinLossByDate_Mem] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinLossByDate_Mem] TO [vnteam] AS [dbo]
