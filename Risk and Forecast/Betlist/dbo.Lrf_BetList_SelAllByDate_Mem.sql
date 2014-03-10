set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

CREATE  PROCEDURE [dbo].[Lrf_BetList_SelAllByDate_Mem]
	@LicenseeID INT ,
	@UserID		INT,
	@custid INT=NULL,
	@FromDate DATETIME,
	@ToDate DATETIME,
	@Langkey VARCHAR(10) = 'en-US',
	@username VARCHAR(50) = NULL, -- for API
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumPlayerComm    MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT,
	@ShowSB BIT = 0,
	@ShowRB BIT = 0,
	@ShowNG BIT = 0,
	@ShowBA BIT = 0,
	@ShowLC	BIT = 0,
	@ShowVS BIT = 0,
	@ShowCS   BIT=0, -- RNG Casino
	@ShowBG   BIT=0, -- Bingo 
	@ShowKN   BIT=0 -- Keno

AS
SET NOCOUNT ON

/*
Created: Henry@20101209
TASk : Bet List
DB: DB052.bodb02
Original [Age_BetList_SelAllByDate_Mem]
Revisions:
    
    -- 20110214@Jacob: Add column discount IN the result SET
    -- 20110303@Henry: suppport bASed currency
    - 20110408@Amy: Change function to get Odds value AND odds type
					Show odds value AND odds type for Number game
	- 20110712@Henry: Add column LicenseeWL
	- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
	- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to shDow waiting or running status
	- 20111208@Jim: Chang condition  bettype < 31
	- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
	- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
	- 20120319@Henry: show main transid for sub-ticket of system parlay 
	- 20120614@Jim: optimize code 
	- 20120706@Jim: get sporttype for Outright 
	- 20120711@Jim: get value for hdp1, hdp2 
	- 20120724@Jim: add player commision value 
	- 20120817@Jim: add live casino 
	- 20120912@Jim: add virtual sport
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 201300426@Scott: Support RNG Casino and Bingo
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130716@Jim: update matchid for RNG Casino and Bingo
	- 20130903@Jim: offer VHR
	- 20140305@Hannah: offer Keno

*/


if @custid is NULL
	SELECT @custid = custid FROM customer WITH (NOLOCK) WHERE username = @username

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)

DECLARE @Recommend INT
	SELECT @Recommend = Recommend, @UserName = Username 
FROM custinfo  c WITH(NOLOCK) 
	INNER JOIN #Currency cy ON cy.CurrencyID=c.Currency
WHERE CustID=@CustID
------------------------------
DROP TABLE #currency
------------------------------
CREATE TABLE #BetListSelAllByDateMem (
	Username NVARCHAR(50), 
	Sporttype INT,
	Bettype SMALLINT,
	refno NVARCHAR(50),
	TransID BIGINT,
	BetID BIGINT,
	MatchCode NVARCHAR(50),
	MatchID INT,
	Race NVARCHAR(50),
	HomeID INT,
	AwayID INT, 
	hdp1 SMALLMONEY, 
	hdp2 SMALLMONEY, 
	Odds SMALLMONEY, 
	modds SMALLMONEY, 
	Status NVARCHAR(50),
	Stake MONEY, 
	Actual_Stake	MONEY,
	Winlost MONEY,
	LicenseeWL MONEY,
	comm MONEY,
	playercomm MONEY,
	discount DECIMAL(9,8),
	Transdate DATETIME,
	Winlostdate DATETIME,
	Betteam NVARCHAR(50),
	LeagueID INT,
	Liveindicator BIT,
	Livehomescore SMALLINT,
	Liveawayscore SMALLINT,
	IP NVARCHAR(15),
	Betstatus NVARCHAR(50),
	isNeutral BIT,
	oddstype INT NULL,
	currency SMALLINT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)

CREATE TABLE #TempBetList(
	Bettype			INT,
	RefNO			BIGINT,	
	TransID			BIGINT,
	BetID			BIGINT,
	hdp1			SMALLMONEY, 
	hdp2			SMALLMONEY, 
	Odds			SMALLMONEY, 
	modds			SMALLMONEY, 
	Status			NVARCHAR(10),
	Stake			MONEY, 
	Actual_Stake	MONEY,
	Winlost			MONEY,
	LicenseeWL		MONEY,
	comm			MONEY,
	playercomm		MONEY,
	discount DECIMAL(9,8),
	Transdate		DATETIME,
	Winlostdate		DATETIME,
	Betteam			NVARCHAR(20),
	Liveindicator	BIT,
	Livehomescore	SMALLINT,
	Liveawayscore	SMALLINT,
	IP				NVARCHAR(50),
	OddsType		TINYINT,
	currency INT,
	MatchID INT,
	custid	INT 
)

DECLARE @TempBettype AS TABLE (bettype INT PRIMARY KEY)
IF @ShowNG = 1
BEGIN
	INSERT INTO @TempBettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 81 AND 120)
END 

IF @ShowLC = 1
BEGIN
    INSERT INTO @TempBettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1101 AND 1199)
END

IF @ShowVS = 1
BEGIN
	INSERT INTO @TempBettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1201 AND 1299)
END 

IF @ShowCS = 1
BEGIN
	INSERT INTO @TempBettype(bettype)
	VALUES (71)
END 

IF @ShowBG = 1
BEGIN
	INSERT INTO @TempBettype(bettype)
	VALUES (73)
END 
IF @ShowKN = 1
BEGIN
    INSERT INTO @TempBettype(bettype)
	SELECT typeid FROM bettype (NOLOCK)
	WHERE (typeid BETWEEN 1501 AND 1599)
END



IF @ShowBA = 1
BEGIN
	--general
	INSERT INTO #TempBetList
	SELECT 
		b.bettype,
		b.refno,		
		b.transid,
		ISNULL(b.BetID,0),
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		0 AS LicenseeWL ,
		b.comm ,
		b.playercomm  AS PlayerComm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,
		b.Oddstype,
		b.currency,
		b.matchid,
		b.custid 
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
	WHERE
		b.CustID = @CustID 
		AND b.recommend=@Recommend  
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
	
	--Sportsbook
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		m.sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		b.BetID,
		m.matchcode, 
		m.matchid,
		'' AS Race, 
		m.homeID,
		m.awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status AS Status,
		b.stake,
		b.actual_stake,
		b.winlost,
		b.LicenseeWL ,
		b.comm,
		b.playercomm as playercomm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,
		m.betstatus,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.Oddstype,
		b.currency,
		'' AS ShowTime
	FROM 
		#TempBetList b
		INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid	
	WHERE
		(b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))
		AND b.bettype <> 10
		
	--Outright
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName,
		l.sporttype AS sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		b.BetID,
		m.matchcode,
		b.matchid,
		m.GroupMatch AS Race,
		m.teamID AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2,
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		b.winlost,
		b.LicenseeWL ,
		b.comm,
		b.playercomm as Playercomm, 
		b.discount,
		b.transdate,
		b.winlostdate,
		'' AS Betteam,    
		m.leagueID,
		0 AS liveindicator , 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP, 
		'' betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS OddsType ,
		b.currency,
		'' AS ShowTime 
	FROM
		#TempBetList b
		INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid		
		INNER JOIN league l WITH (NOLOCK) ON m.leagueID=l.leagueID
	WHERE
		b.bettype = 10
		
	--MixParlay
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		0 AS sporttype,
		b.bettype,
		CONVERT(NVARCHAR(20),b.refno) AS refno,		
		b.transid,
		ISNULL(b.BetID,0),
		'' AS matchcode, 
		b.matchid,
		'' AS Race, 
		0 AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2,
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		b.winlost,
		b.LicenseeWL ,
		b.comm,
		b.playercomm as playercomm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		0 AS leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,
		'' AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS OddsType ,
		b.currency,
		'' AS ShowTime 
	FROM 
		#TempBetList b
	WHERE
		b.matchid = 9
		AND b.bettype=9
		
	--Combination Mix Parlay
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		0 AS sporttype,
		b.bettype,
		CONVERT(NVARCHAR(20),b.refno) AS refno,		
		CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid,
		ISNULL(b.BetID,0),
		'' AS matchcode, 
		b.matchid,
		'' AS Race, 
		0 AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		b.winlost,
		b.LicenseeWL ,
		b.comm,
		b.playercomm as PlayerComm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		0 AS leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,
		'' AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS OddsType ,
		b.currency,
		'' AS ShowTime 
	FROM 
		#TempBetList b
	WHERE
		b.bettype=29
		AND b.matchid = 29
		
END



IF @ShowSB = 1
BEGIN
	INSERT INTO #BetListSelAllByDateMem
	--Single bets
	SELECT 
		@UserName AS UserName,
		m.sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		ISNULL(b.BetID,0),
		m.matchcode, 
		m.matchid,
		'' AS Race, 
		m.homeID,
		m.awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		- (b.winlost-b.actual_stake) AS LicenseeWL ,
		b.comm ,
		b.playercomm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,
		m.betstatus,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.Oddstype,
		b.currency,
		'' AS ShowTime 
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid	
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend  AND
		b.matchid > 0
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
		AND (b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999))
		AND b.bettype NOT IN (9,29,10)
		AND b.tpositiontaking <>0 --exclude BA tickets
		
	-- OutRight tickets
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName,
		l.sporttype AS sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		ISNULL(b.BetID,0),
		m.matchcode,
		b.matchid,
		m.GroupMatch AS Race,
		m.teamID AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake)  winlost,
		 - (b.winlost-b.actual_stake) AS LicenseeWL ,
		b.comm ,
		b.playercomm AS PlayerComm,
		b.discount,
		b.transdate,
		b.winlostdate,
		'' AS Betteam,    
		m.leagueID,
		0 AS liveindicator , 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP, 
		'' betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS OddsType ,
		b.currency,
		'' AS ShowTime
	FROM
		bettrans b WITH (NOLOCK)
		INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid		
		INNER JOIN league  l WITH (NOLOCK) ON m.leagueID=l.leagueID 
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend 
		AND b.matchid > 0
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
		AND b.bettype = 10
		AND b.tpositiontaking <>0 --exclude BA tickets

	--MixParlay 
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		0 AS sporttype,
		b.bettype,
		CONVERT(NVARCHAR(20),b.refno) AS refno,		
		b.transid,
		ISNULL(b.BetID,0),
		'' AS matchcode, 
		b.matchid,
		'' AS Race, 
		0 AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		- (b.winlost-b.actual_stake) LicenseeWL ,
		b.comm ,
		b.playercomm AS PlayerComm ,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		0 AS leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,
		'' AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS OddsType ,
		b.currency,
		'' AS ShowTime 
	FROM 
		bettrans b WITH (NOLOCK)	
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend  
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
		AND b.matchid = 9
		AND b.bettype=9
		AND b.tpositiontaking <>0 --exclude BA tickets
		
	--Combination Mix Parlay
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		0 AS sporttype,
		b.bettype,
		CONVERT(NVARCHAR(20),b.refno) AS refno,		
		CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid,
		ISNULL(b.BetID,0),
		'' AS matchcode, 
		b.matchid,
		'' AS Race, 
		0 AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		- (b.winlost-b.actual_stake) LicenseeWL ,
		b.comm ,
		b.playercomm AS PlayerComm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		0 AS leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,
		'' AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS OddsType ,
		b.currency,
		'' AS ShowTime 
	FROM 
		bettrans b WITH (NOLOCK)	
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend  
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
		AND b.bettype=29
		AND b.matchid = 29
		AND b.tpositiontaking <>0 --exclude BA tickets
		
		
			
END

--Horse Racing
IF @ShowRB = 1
BEGIN
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName,
		151 AS sporttype,
		b.bettype,
		'' AS refno,		
		b.transid,
		ISNULL(b.BetID,0),
		m.matchcode,
		b.matchid,
		m.GroupMatch AS Race,
		m.teamID AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake)  winlost,
		b.awinlost,
		b.comm ,
		b.playercomm  AS PlayerComm,
		b.discount,
		b.transdate,
		b.winlostdate,
		'' AS Betteam,    
		m.leagueID,
		0 AS liveindicator , 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP, 
		'' betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS oddstype,
		b.currency,
		'' AS ShowTime 
	FROM
		bettrans b WITH (NOLOCK)
		INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid		
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate	
		AND b.bettype IN (31, 32, 33)
END



--NUMBER GAME

IF (@ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1  )
BEGIN
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		m.sporttype,
		b.bettype,
		CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN CONVERT(NVARCHAR(20),b.refno)  ELSE '' END AS refno,		
		b.transid,
		ISNULL(b.BetID,0),
		m.matchcode, 
		m.matchid,
		'' AS Race, 
		m.homeID,
		m.awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2,  
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		- (b.winlost-b.actual_stake) AS LicenseeWL ,
		b.comm ,
		b.playercomm  AS PlayerComm ,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore,
		b.IP AS IP,
		m.betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		b.Oddstype,
		b.currency,
		CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid		
		INNER JOIN @TempBettype bt ON b.bettype = bt.bettype	
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend  
		AND b.bettype NOT IN (71,73)
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
	IF EXISTS (SELECT 1 FROM @TempBettype WHERE bettype IN (1231, 1232, 1233, 1237, 1238) )	
		BEGIN 
			INSERT INTO #BetListSelAllByDateMem
			SELECT 
				@UserName AS UserName,
				r.sporttype,
				b.bettype,
				CONVERT(NVARCHAR(20),b.refno) AS refno,		
				b.transid,
				ISNULL(b.BetID,0),
				CONVERT(varchar(50),o.RacerNum) as matchcode, 
				o.EventID matchid,
				b.oddsid AS Race, 
				o.RacerID as homeID,
				0 as awayID,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,  
				b.odds,
				b.modds,
				CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
				ELSE b.status   
				END as status,
				b.stake,
				b.actual_stake,
				(winlost-actual_stake) winlost,
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm ,
				b.playercomm  AS PlayerComm ,
				b.discount,
				b.transdate,
				b.winlostdate,
				b.betteam,
				r.leagueID,
				b.liveindicator, 
				b.livehomescore, 
				b.liveawayscore,
				b.IP AS IP,
				r.betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.Oddstype,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime)  AS ShowTime 
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @TempBettype bt ON b.bettype = bt.bettype	
			WHERE
				b.CustID = @CustID AND
				b.recommend=@Recommend  
				AND b.bettype NOT IN (71,73)
				AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
		END	
END

IF @ShowCS=1 
BEGIN
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		251 sporttype,
		b.bettype,
		b.refno,		
		b.transid,
		ISNULL(b.BetID,0),
		'' AS matchcode, 
		71  AS matchid,
		'' AS Race, 
		0  AS homeID,
		0  AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2,  
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		- (b.winlost-b.actual_stake) AS LicenseeWL ,
		b.comm ,
		b.playercomm  AS PlayerComm ,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		0 AS leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore,
		b.IP AS IP,
		0 AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		b.Oddstype,
		b.currency,
		''  AS ShowTime 
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN @TempBettype bt ON b.bettype = bt.bettype	
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend  
		AND b.bettype=71
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
END

IF @ShowBG=1 
BEGIN
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		252 sporttype,
		b.bettype,
		b.refno,		
		b.transid,
		ISNULL(b.BetID,0),
		'' AS matchcode, 
		73  AS matchid,
		'' AS Race, 
		0  AS homeID,
		0  AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2,  
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		- (b.winlost-b.actual_stake) AS LicenseeWL ,
		b.comm ,
		b.playercomm  AS PlayerComm ,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		0 AS leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore,
		b.IP AS IP,
		0 AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		b.Oddstype,
		b.currency,
		''  AS ShowTime 
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN @TempBettype bt ON b.bettype = bt.bettype	
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend  
		AND b.bettype=73
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
END

IF @ShowKN=1 
BEGIN
	INSERT INTO #BetListSelAllByDateMem
	SELECT 
		@UserName AS UserName,
		m.sporttype,
		b.bettype,
		b.refno,		
		b.refno,
		ISNULL(b.BetID,0),
		m.matchcode, 
		m.matchid,
		'' AS Race, 
		m.homeID,
		m.awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2,  
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		- (b.winlost-b.actual_stake) AS LicenseeWL ,
		b.comm ,
		b.playercomm  AS PlayerComm ,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		m.leagueID,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore,
		b.IP AS IP,
		m.betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		b.Oddstype,
		b.currency,
		''  AS ShowTime 
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid		
		INNER JOIN @TempBettype bt ON b.bettype = bt.bettype	
	WHERE
		b.CustID = @CustID AND
		b.recommend=@Recommend  
		AND b.bettype BETWEEN 1501 AND 1599
		AND b.transdate>=@FROMDate AND b.transdate<=@ToDate
	UNION ALL
	SELECT 
		@UserName AS UserName,
		t.productID as sporttype,
		t.gameid as bettype,
		t.translogid,		
		t.translogid,
		0 as BetID, 
		m.matchcode, 
		m.matchid,
		'' AS Race, 
		m.homeID,
		m.awayID,
		0 AS hdp1, 
		0 AS hdp2,  
		t.odds ,
		0 as modds,
		t.status,
		t.stake,
		t.actual_stake,
		(0-actual_stake) winlost,
		- (0-t.actual_stake) AS LicenseeWL ,
		0 as comm,
		0 AS PlayerComm,
		t.discount,
		t.transdate,
		t.winlostdate,
		(left((right(t.transdesc, len(t.transdesc) - (charindex(',',t.transdesc)))),(charindex(';', (right(t.transdesc, len(t.transdesc) - (charindex(',', t.transdesc)))))) - 1)) as betteam,
		m.leagueID,
		0 as liveindicator, 
		0 as livehomescore, 
		0 as liveawayscore,
		t.IP AS IP,
		m.betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		0 as Oddstype,
		t.currency,
		''  AS ShowTime 
	FROM dbo.translog AS t WITH (NOLOCK)	
		INNER JOIN match m with (nolock) ON m.matchid=t.eventid
	WHERE
		t.CustID = @CustID AND
		t.recommend=@Recommend  
		AND t.transdate>=@FROMDate AND t.transdate<=@ToDate
END

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

CREATE NONCLUSTERED INDEX IDX_Index_betlist ON #BetListSelAllByDateMem(Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #BetListSelAllByDateMem)



SELECT 
		@TotalRows = COUNT(transid),
		@SumWinlost=SUM(ISNULL(winlost,0)),
		@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
		@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
		@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
		@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
		@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
		@SumComm=SUM(ISNULL(comm,0)) ,
		@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
		@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)),--
		@SumPlayerComm=SUM(ISNULL(playercomm,0)) ,
		@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)) ,
		@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0))		
FROM 
	#BetListSelAllByDateMem b
	INNER JOIN #TempExchange e 
	ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)   AND e.exchangeid = b.currency
	WHERE b.status<>'running'

SELECT c.* FROM 
(
	SELECT 
			ROW_NUMBER() over(ORDER BY b.transid DESC) AS RowNum,
			b.*,
			--bASe USD currency
			Stake*e.USD AS StakeUSD,
			Actual_Stake * e.USD AS Actual_StakeUSD,
			Winlost*e.USD AS WinlostUSD,
			LicenseeWL * e.USD AS LicenseeWLUSD,
			comm*e.USD AS commUSD,
			playercomm*e.USD as PlayerCommUSD,
			--bASe EUR currency
			Stake*e.EUR AS StakeEUR,
			Actual_Stake * e.EUR AS Actual_StakeEUR,
			Winlost*e.EUR AS WinlostEUR,
			LicenseeWL * e.EUR AS LicenseeWLEUR,
			comm*e.EUR AS commEUR,
			playercomm*e.EUR AS PlayerCommEUR
			
			
	FROM	#BetListSelAllByDateMem b
			INNER JOIN #TempExchange e 
			ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)   AND e.exchangeid = b.currency
			
	
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

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
BEGIN
	--get data FROM bettransm for bettype 33,43
	INSERT INTO @BettransDetail
	SELECT 
		BM.refno, 
		BM.odds, 
		BM.stake,
		BM.status, 
		BM.apositiontaking, 
		BM.bettype,
		BM.betteam ,
		BM.stake*e.EUR,	
		BM.stake*e.USD	
	FROM bettransm BM WITH (NOLOCK)
	INNER JOIN #BetListSelAllByDateMem B ON BM.refno = B.transid
	INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
	WHERE B.Bettype IN (33,43)
END
IF @ShowLC=1
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
	INNER JOIN #BetListSelAllByDateMem B ON BG.refno = B.refno and BG.custid = @CustID
	INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
	WHERE B.Bettype BETWEEN 1101 AND 1199	
END 
IF @ShowVS=1
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
			BG.stake*e.USD
		FROM bettransm BG WITH (NOLOCK)
		INNER JOIN #BetListSelAllByDateMem B ON BG.refno = B.refno 
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE B.Bettype=1233
	END
		
SELECT * FROM @BettransDetail 
ORDER BY RefNo,Bettype 

DROP TABLE #TempExchange 
DROP TABLE #BetListSelAllByDateMem
DROP TABLE #TempBetList
GO
GRANT  EXECUTE  ON [dbo].[Lrf_BetList_SelAllByDate_Mem]  TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelAllByDate_Mem] TO [vnteam]
GO