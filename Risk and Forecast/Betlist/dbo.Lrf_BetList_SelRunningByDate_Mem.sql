set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByDate_Mem]
	@LicenseeID INT ,
	@UserID		INT,
	@CustID INT=NULL,
	@FromDate DATETIME = '',
	@ToDate DATETIME  = '',
	@Langkey VARCHAR(10) = 'en-US',
	@username VARCHAR(30) = NULL, -- for API
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT,
	@ShowSB BIT = 0,
	@ShowRB BIT = 0,
	@ShowNG BIT = 0,
	@ShowBA BIT = 0,
	@ShowLC	BIT = 0,
	@ShowVS BIT = 0,
	@ShowCS BIT = 0, -- RNG Casino
	@ShowBG BIT = 0  -- Bingo
	
AS

/*
Created: Henry@20101210
Task : Bet List
DB: DB052.bodb02
Original [Age_BetList_SelRunningByDate_Mem]
Revisions:
   -- 20110303@Henry: suppport based currency
   -- 20110408@Amy: Change function to get Odds value AND odds type
   					Show odds value AND odds type for Number game
   -- 20110627@Henry: show column discount
   - 20110712@Henry: remove @ShowBI, @ShowP2P, @ShowCasino. Add @ShowBA
   - 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mixed Parlay
   - 20111118@Henry: using [creator] column as sporttype for racing ticket
   - 20111122@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
   - 20111208@Jim : Change condition bettype <31 
   - 20111229@Jim : change the way to get odds/oddstype/betteam to web dev
   - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
   - 20120319@Henry: show main transid for sub-ticket of system parlay
   - 20120706@Jim: get sporttype for Outright 
   - 20120726@Jim: add playercomm value 
   - 20120817@Henry: add live casino
   - 20120924@Jim: add virtual sport 
   - 20130226@Jim: support RNG Casino,Bingo	
   - 20130326@Jim: remove input parameter @GetAll
   - 20130514@Jim: Restrict permission of Licensee Users by currency
   - 20130716@Jim: update matchid for RNG Casino and Bingo
*/

SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)

IF @custid IS NULL
	SELECT @custid = custid 
	FROM customer c WITH (nolock) 
		INNER JOIN #currency cy ON c.Currency=cy.CurrencyID
	WHERE username = @username
ELSE
	SELECT @username = username 
	FROM customer  c WITH(nolock) 
	INNER JOIN #currency cy ON c.Currency=cy.CurrencyID
	WHERE CustID=@CustID


CREATE TABLE #BetListSelRunningByDateMem
(
	Sporttype 		INT,
	Username 		NVARCHAR(50), 
	Bettype 		SMALLINT,
	LeagueID 		INT,
	refno 			BIGINT,
	TransID 		BIGINT,
	BetID 			BIGINT,
	MatchCode 		NVARCHAR(50),
	Race 			NVARCHAR(50),
	HomeID 			INT,
	AwayID 			INT, 
	hdp1 			SMALLMONEY, 
	hdp2 			SMALLMONEY, 
	Odds 			SMALLMONEY, 
	modds 			SMALLMONEY,  
	Status 			NVARCHAR(50),
	Stake 			MONEY, 
	Actual_Stake	MONEY,
	Transdate 		DATETIME,
	Betteam 		NVARCHAR(50),
	discount 		DECIMAL(9,8),
	Liveindicator 	BIT,
	Livehomescore 	SMALLINT,
	Liveawayscore 	SMALLINT,
	IP 				NVARCHAR(30),
	isNeutral 		BIT,
	oddstype 		INT,
	winlostdate 	DATETIME,
	currency 		SMALLINT,
	playercomm 		MONEY,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)

CREATE TABLE #TempBetList
(
	Bettype			INT,
	RefNO			BIGINT,	
	TransID			BIGINT PRIMARY KEY,
	BetID			BIGINT,
	hdp1			SMALLMONEY, 
	hdp2			SMALLMONEY, 
	Odds			SMALLMONEY, 
	modds 			SMALLMONEY,  
	Status			NVARCHAR(10),
	Stake MONEY, 
	Actual_Stake	MONEY,
	Transdate		DATETIME,
	Betteam			NVARCHAR(20),
	discount		DECIMAL(9,8),
	Liveindicator	BIT,
	Livehomescore	SMALLINT,
	Liveawayscore	SMALLINT,
	IP				NVARCHAR(50),
	OddsType		TINYINT,
	Winlostdate		DATETIME,
	currency 		INT,
	MatchID 		INT,
	playercomm 		MONEY
)

	--general BA Ticket 
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
		--b.status,
		CASE WHEN b.bettype NOT IN (9,29,10) AND b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,  
		b.stake,
		b.actual_stake, 
		b.transdate,		
		b.betteam,
		b.discount,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP AS IP,			
		b.oddstype,
		b.winlostdate,
		b.currency,
		b.matchid,
		b.playercomm 
	FROM 
		bettrans b WITH (NOLOCK)			
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.transdate>=@FromDate AND b.transdate<=@ToDate
		AND b.custid=@CustID 
		AND b.statusID IN (0,1) 
		
	IF @ShowBA = 1
	BEGIN
		
			
		--Sportbook
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,	
			b.refno,					
			b.transid,
			b.BetID,
			m.matchcode,
			'' AS Race,
			m.homeID,
			m.awayID,
			b.hdp1, 
			b.hdp2, 
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP AS IP,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM 
			#TempBetList b 
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid		
		WHERE
			(b.bettype < 31 or (b.bettype BETWEEN 121 AND 999))
			AND b.bettype <>10
			
		--Outright	
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			l.sporttype  AS sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,		
			b.refno,				
			b.transid,
			b.BetID,
			m.matchcode,
			m.GroupMatch AS Race,--VinhTrinh Add for Horseracing
			m.teamID AS homeID,
			0 AS awayID,
			0 AS hdp1,--hdp1, 
			0 AS hdp2,--hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			'' AS Betteam,--Betteam,    
			b.discount,
			0 AS liveindicator , 
			0 AS livehomescore, 
			0 AS liveawayscore, 
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM
			#TempBetList b 
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid 
			INNER JOIN league l WITH (NOLOCK) ON m.leagueID=l.leagueID		
		WHERE
			b.bettype = 10
			
		--Mix Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,						
			b.transid,
			b.BetID,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1, 
			0 AS hdp2, 
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore, 
			0 AS liveawayscore, 
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' As ShowTime
		FROM 
			#TempBetList b 
		WHERE
			b.bettype = 9	
			AND b.matchid = 9
			
		--Combination Mixed Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,						
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			b.BetID,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1, 
			0 AS hdp2, 
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore, 
			0 AS liveawayscore, 
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM 
			#TempBetList b 
		WHERE
			b.bettype = 29	
			AND b.matchid = 29
			
			
		--Number Game
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,	
			b.refno,					
			b.transid,
			b.BetID,
			m.matchcode,
			'' AS Race,
			m.homeID,
			m.awayID,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' As ShowTime
		FROM 
			#TempBetList b 
			INNER JOIN MATCH m WITH (NOLOCK) ON b.matchid = m.matchid		
		WHERE
			b.bettype BETWEEN 81 AND 120
	END

	IF @ShowSB = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,	
			b.refno,					
			b.transid,
			ISNULL(b.BetID,0),
			m.matchcode,
			'' AS Race,--VinhTrinh Add for Horseracing
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.modds,
			--b.status,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP AS IP,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM 
			bettrans b WITH (NOLOCK)			
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid		
		WHERE
			b.transdate>=@FromDate AND b.transdate<=@ToDate AND 
			b.custid=@CustID 
			AND b.matchid > 0
			AND b.statusID IN (0,1) 
			AND (b.bettype < 31 OR (b.bettype BETWEEN 121 AND 999))
			AND b.bettype NOT IN (9,29,10)
			AND b.transid NOT IN (SELECT transid FROM #TempBetList)
				
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	-- Outright
			l.sporttype AS sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,		
			b.refno,				
			b.transid,
			ISNULL(b.BetID,0),
			m.matchcode,
			m.GroupMatch AS Race,--VinhTrinh Add for Horseracing
			m.teamID AS homeID,
			0 AS awayID,
			0 AS hdp1,--hdp1, 
			0 AS hdp2,--hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			'' AS Betteam,--Betteam,    
			b.discount,
			0 AS liveindicator , 
			0 AS livehomescore, 
			0 AS liveawayscore, 
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM
			bettrans b WITH (NOLOCK)		
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid 
			INNER JOIN league l WITH (NOLOCK) ON m.leagueID=l.leagueID 	
		WHERE
			b.bettype = 10
			AND b.transdate>=@FromDate AND b.transdate<=@ToDate AND 
			b.custid=@CustID 
			AND b.statusID IN (0,1)
			AND b.transid NOT IN (SELECT transid FROM #TempBetList)
			
		--UNION ALL 
		-- Mix Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,						
			b.transid,
			ISNULL(b.BetID,0),
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1, 
			0 AS hdp2, 
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore, 
			0 AS liveawayscore, 
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM 
			bettrans b WITH (NOLOCK)
		WHERE
			b.transdate>=@FromDate AND b.transdate<=@ToDate AND 
			b.custid=@CustID 
			AND b.bettype = 9	
			AND b.matchid = 9
			AND b.statusID IN (0,1)
			AND b.transid NOT IN (SELECT transid FROM #TempBetList)
		
		--Combination Mixed Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,						
			CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
			ISNULL(b.BetID,0),
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1, 
			0 AS hdp2, 
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			0 AS liveindicator,
			0 AS livehomescore, 
			0 AS liveawayscore, 
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM 
			bettrans b WITH (NOLOCK)
		WHERE
			b.transdate>=@FromDate AND b.transdate<=@ToDate AND 
			b.custid=@CustID 
			AND b.bettype = 29	
			AND b.matchid = 29
			AND b.statusID IN (0,1)
			AND b.transid NOT IN (SELECT transid FROM #TempBetList)
			
			
	END

	--Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	-- Outright
			--151 AS sporttype,
			m.creator as sporttype, --using creator as sporttype
			@Username AS UserName,
			b.bettype,
			m.leagueID,		
			b.refno,				
			b.transid,
			ISNULL(b.BetID,0),
			m.matchcode,
			m.GroupMatch AS Race,--VinhTrinh Add for Horseracing
			m.teamID AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			--b.status,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			'' AS Betteam,--Betteam,    
			b.discount,
			0 AS liveindicator , 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			'' as ShowTime
		FROM
			bettrans b WITH (NOLOCK)		
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid 				
		WHERE
			b.bettype IN (31, 32, 33)
			AND b.transdate>=@FromDate AND b.transdate<=@ToDate AND 
			b.custid=@CustID 
			AND b.statusID IN (0,1)
	END
	
	--NUMBER GAME
	
	IF (@ShowNG = 1 OR @ShowLC=1 OR @ShowVS=1  )
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			m.sporttype,
			@Username AS UserName,
			b.bettype,
			m.leagueID,	
			b.refno,					
			b.transid,
			ISNULL(b.BetID,0),
			m.matchcode,
			'' AS Race,
			m.homeID,
			m.awayID,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			b.odds,
			b.modds,
			--b.status,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			CASE WHEN @ShowLC=1 THEN isnull(m.showtime,'') ELSE '' END as ShowTime
		FROM 
			bettrans b WITH (NOLOCK)			
			INNER JOIN MATCH m WITH (NOLOCK) ON b.matchid = m.matchid		
		WHERE
			b.transdate>= @FromDate AND b.transdate<= @ToDate AND 
			b.custid=@CustID 
			AND b.statusID IN (0,1) 
			AND ((@ShowNG=1 AND b.bettype BETWEEN 81 AND 120)
				OR (@ShowLC=1 AND b.bettype BETWEEN 1101 AND 1199)
				OR (@ShowVS=1 AND b.bettype BETWEEN 1201 AND 1299)
				)
	END
	--- RNG Casino
	IF @ShowCS=1 
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			251 sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,	
			b.refno,					
			b.transid,
			ISNULL(b.BetID,0),
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			b.odds,
			b.modds,
			--b.status,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			 '' as ShowTime
		FROM 
			bettrans b WITH (NOLOCK)			
		WHERE
			b.transdate>= @FromDate AND b.transdate<= @ToDate AND 
			b.custid=@CustID 
			AND b.statusID IN (0,1) 
			AND b.bettype=71
	END
	
	IF @ShowBG=1 
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			252 sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,	
			b.refno,					
			b.transid,
			ISNULL(b.BetID,0),
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			b.hdp1 AS hdp1, 
			b.hdp2 AS hdp2,
			b.odds,
			b.modds,
			--b.status,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,
			b.stake,
			b.actual_stake, 
			b.transdate,		
			b.betteam,
			b.discount,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore,
			b.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.playercomm,
			 '' as ShowTime
		FROM 
			bettrans b WITH (NOLOCK)			
		WHERE
			b.transdate>= @FromDate AND b.transdate<= @ToDate AND 
			b.custid=@CustID 
			AND b.statusID IN (0,1) 
			AND b.bettype=73
	END
	
DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @Today smalldatetime 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

IF @TotalRows = 0  
BEGIN 
	 SELECT @TotalRows = count(transid) FROM #BetListSelRunningByDateMem
END

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY transid desc) AS RowNum,
			b.* ,
			stake*e.USD stakeUSD,
			stake*e.EUR stakeEUR,
			actual_stake*e.USD actual_stakeUSD,
			actual_stake*e.EUR actual_stakeEUR,
			b.playercomm*e.USD PlayerCommUSD,
			b.playercomm*e.EUR PlayerCommEUR
	FROM #BetListSelRunningByDateMem b
	INNER JOIN 
		(SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	ON e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DECLARE @BetListDetail TABLE(
		refno bigint, 
		odds smallmoney, 
		stake money,
		status nvarchar(10),
		apositiontaking smallmoney, 
		bettype smallint,
		betteam nvarchar(20) ,
		stakeEUR MONEY,
		stakeUSD MONEY
		)


IF @ShowRB = 1
begin
	--get data FROM bettransm for bettype 33,43
	INSERT INTO @BetListDetail
	SELECT 
		BM.refno, 
		BM.odds, 
		BM.stake,
		BM.status ,
		BM.apositiontaking, 
		BM.bettype,
		'' as betteam ,
		BM.stake*e.EUR,
		BM.stake*e.USD
	FROM bettransm BM with (NOLOCK)
	INNER JOIN #BetListSelRunningByDateMem B ON BM.refno = B.transid
	INNER JOIN 
		(SELECT * FROM Lrf_f_GetExchangeDaily(@Fromdate,@Todate))e 
	ON  e.ExchangeDate = B.winlostdate AND e.exchangeid = b.currency
	WHERE B.Bettype IN (33,43)
END

IF @ShowLC = 1
BEGIN
	--get data from bettransg for bettype 1101
	INSERT INTO @BetListDetail
	SELECT 
		bg.refno, 
		bg.odds, 
		bg.stake,
		bg.status ,
		bg.apositiontaking, 
		b.bettype,
		bg.betteam,
		bg.stake*e.EUR,	
		bg.stake*e.USD
	FROM bettransg bg with (NOLOCK)
	INNER JOIN #BetListSelRunningByDateMem b ON bg.refno = b.refno
	INNER JOIN 
		(SELECT * FROM Lrf_f_GetExchangeDaily(@Fromdate,@Todate))e 
	ON  e.ExchangeDate = B.winlostdate AND e.exchangeid = b.currency
	WHERE b.Bettype between 1101 and 1199
END

SELECT * FROM @BetListDetail order by refno

DROP TABLE #BetListSelRunningByDateMem
DROP TABLE #TempBetList

GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByDate_Mem] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByDate_Mem] TO vnteam
