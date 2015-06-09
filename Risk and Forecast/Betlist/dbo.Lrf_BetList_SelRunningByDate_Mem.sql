ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByDate_Mem]
	@LicenseeID INT ,
	@UserID		INT,
	@CustID		INT=NULL,
	@CurrencyId INT = 0,
	@FromDate	DATETIME = '',
	@ToDate		DATETIME  = '',
	@Langkey	VARCHAR(10) = 'en-US',
	@username	VARCHAR(30) = NULL, -- for API
	@PageSize	INT=1000,
	@PageIndex	INT=1,
	-- check for showing product
	@ShowSB		BIT = 0,
	@ShowRB		BIT = 0,
	@ShowNG		BIT = 0,
	@ShowBA		BIT = 0,
	@ShowLC		BIT = 0,
	@ShowVS		BIT = 0,
	@ShowCS		BIT = 0, -- RNG Casino
	@ShowBG		BIT = 0,  -- Bingo
	@ShowKN		BIT = 0,  -- Keno
	@ShowMGC		BIT = 0  -- MicroGamming
	-- output info
	,@TotalRows INT=0 OUTPUT
	,@ErrorCode INT=0 OUTPUT
	,@ErrorMsg	NVARCHAR(100)='' OUTPUT
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
   - 20130903@Jim: support Virtual Horse Racing
   - 20140310@Hannah: offer Keno
   - 20140319@Hannah: fix bug for showing DrawID 
   - 20140630@Hannah: offer BetRadar and Sporting Solution 
   - 20141128@Jim: add more input param @CurrencyID
   - 20150126@Winnie: add base currency GBP 
   - 20150402@Bobby: Apply sporttype matrix & #32844 new 60 bettypes - betradar phase 2
   - 20150608@Edward: Support MicroGamming
   - 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
*/
BEGIN

	SET NOCOUNT ON;
	
	DECLARE @Today SMALLDATETIME 
	
	SELECT @Today	= CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
	 ,@TotalRows	= 0
	 ,@ErrorCode	= 0
	 ,@ErrorMsg		= ''

	-- validate customer info
	SELECT  currencyID
		, LicenseeID 
	INTO #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)

	SELECT TOP 1 
		@custid		= CASE WHEN @custid IS NULL		THEN c.custid	ELSE @custid END
		, @username = CASE WHEN @username IS NULL	THEN c.username ELSE @username END 
	FROM dbo.customer c WITH (NOLOCK) 
		INNER JOIN #currency cy 
		ON c.Currency=cy.CurrencyID
	WHERE username	= @username
		OR CustID	= @CustID
	

	IF (@custid IS NULL
		OR @username IS NULL)
	BEGIN
		SELECT @ErrorCode	= 100
			, @ErrorMsg		= 'The customer was not found.'
		RETURN;
	END

	-- filer bettypes by sporttype
	DECLARE @SportBettype TABLE ( 
		ProductID 			INT
		,Bettype 			INT
		,EventType 			INT
	)
	
	INSERT INTO @SportBettype (
		ProductID
		,Bettype
		,EventType
	)
	EXEC dbo.Acc_SportBettypeMatrix_Sel @mode = 4
	
	DELETE @SportBettype WHERE ProductID = 1 AND Bettype IN (901,902,903)

	DELETE sbt
	FROM @SportBettype sbt
	WHERE ProductID		= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowRB	= 0 THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG	= 0 THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC	= 0 THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS	= 0 THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS	= 0 THEN 6 END
		OR ProductID	= CASE WHEN @ShowBG	= 0 THEN 7 END
		OR ProductID	= CASE WHEN @ShowKN	= 0 THEN 8 END
		OR ProductID	= CASE WHEN @ShowMGC	= 0 THEN 203 END
		OR ProductID 	> 8 -- not suport for LIC system
	-- end filer bettypes by sporttype


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
		showtime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		MatchID 		INT
		,betcheck		NVARCHAR(50)
	)

	CREATE TABLE #TempBATicket
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
		Stake 			MONEY, 
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
		,betcheck		NVARCHAR(50)
	)
	
	IF ( @ShowBA = 1 )
	BEGIN
		--Receive BA Ticket - SB ticket only
		INSERT INTO #TempBATicket
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
			,b.betcheck
		FROM 
			bettrans b WITH (NOLOCK)			
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) 
			ON b.transid = BA.transid
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			b.transdate			>= @FromDate AND b.transdate<=@ToDate
			AND b.custid		= @CustID 
			AND sbt.ProductId	= 1
			AND b.statusID		IN (0,1) 

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
			'' as ShowTime,
			m.matchid
			,CASE WHEN b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck
		FROM 
			#TempBATicket b 
			INNER JOIN match m WITH (NOLOCK) 
			ON b.matchid=m.matchid		
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			sbt.ProductID		= 1
			AND sbt.EventType	= 1

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
			'' as ShowTime,
			0 as matchid
			, NULL AS betcheck
		FROM
			#TempBATicket b 
			INNER JOIN dbo.outright m WITH (NOLOCK) 
			ON b.matchid=m.orid 
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON m.leagueID=l.leagueID		
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			sbt.ProductID		= 1
			AND sbt.EventType	= 2
			
		--Mix Parlay & System Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,						
			CASE WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid, 
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
			'' As ShowTime,
			0 as matchid
			, NULL AS betcheck
		FROM 
			#TempBATicket b 
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			sbt.ProductID		= 1
			AND sbt.EventType	= 0
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
			'' as ShowTime,
			m.matchid
			,CASE WHEN b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck
		FROM 
			bettrans b WITH (NOLOCK)			
			INNER JOIN match m WITH (NOLOCK) 
			ON b.matchid=m.matchid		
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
			
		WHERE
			b.transdate			>= @FromDate AND b.transdate<=@ToDate 
			AND b.custid		= @CustID 
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 1
			AND b.matchid		> 0
			AND b.statusID		IN (0,1) 
			AND b.transid		NOT IN (SELECT transid FROM #TempBATicket)
				
		-- Outright Ticket
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	
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
			'' as ShowTime,
			0 as matchid
			,'' AS betcheck
		FROM
			bettrans b WITH (NOLOCK)		
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid 
			INNER JOIN league l WITH (NOLOCK) ON m.leagueID=l.leagueID 	
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			b.transdate			>= @FromDate AND b.transdate<=@ToDate 
			AND b.custid		= @CustID 
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 2
			AND b.statusID		IN (0,1)
			AND b.transid		NOT IN (SELECT transid FROM #TempBATicket)
			
		--UNION ALL 
		-- Mix Parlay & System Parlay
		INSERT INTO #BetListSelRunningByDateMem
		SELECT 	
			0 AS sporttype,
			@Username AS UserName,
			b.bettype,
			0 AS leagueID,
			b.refno,						
			CASE WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid, 
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
			'' as ShowTime,
			0 as matchid
			,'' AS betcheck
		FROM 
			bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			b.transdate			>= @FromDate AND b.transdate<=@ToDate 
			AND b.custid		= @CustID 
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 0
			AND b.statusID		IN (0,1)
			AND b.transid		NOT IN (SELECT transid FROM #TempBATicket)	
	END

	-- release mem for tempdb
	DROP TABLE #TempBATicket;

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
			'' as ShowTime,
			0 as matchid
			,'' AS betcheck
		FROM
			bettrans b WITH (NOLOCK)		
			INNER JOIN outright m WITH (NOLOCK) 
			ON b.matchid=m.orid 				
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.custid = @CustID 
			AND sbt.ProductID	= 2
			AND sbt.EventType	= 2
			AND b.statusID IN (0,1)
	END
	
	--NUMBER GAME
	IF ( @ShowNG	= 1 
		OR @ShowLC	= 1 
		OR @ShowVS	= 1  
	)
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
			CASE WHEN @ShowLC=1 THEN isnull(m.showtime,'') ELSE '' END as ShowTime,
			m.matchid 
			,'' AS betcheck
		FROM 
			bettrans b WITH (NOLOCK)			
			INNER JOIN MATCH m WITH (NOLOCK) 
			ON b.matchid = m.matchid		
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			b.transdate			>= @FromDate AND b.transdate <= @ToDate 
			AND b.custid		= @CustID 
			AND sbt.ProductID	IN (3, 4, 5)
			AND sbt.EventType	= 1
			AND b.statusID		IN (0,1) 

		UNION
			SELECT
			r.sporttype,
			@Username AS UserName,
			b.bettype,
			r.leagueID,	
			b.refno,					
			b.transid,
			ISNULL(b.BetID,0),
			CONVERT(VARCHAR(50),o.RacerNum) as matchcode,
			b.oddsid AS Race,
			o.RacerID as homeID,
			0 as awayID,
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
			CONVERT(VARCHAR(20),r.EventTime) as ShowTime,
			0 as matchid
			,'' AS betcheck
		FROM 
			bettrans b WITH (NOLOCK)			
			INNER JOIN VSOutright o with (nolock) 
			ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype
		WHERE
			b.transdate			>= @FromDate AND b.transdate <= @ToDate 
			AND b.custid		= @CustID 
			AND sbt.ProductID	= 5
			AND sbt.EventType	= 3
			AND b.statusID		IN (0,1) 
	END
	
	--RNG Casino
	IF ( @ShowCS = 1 )
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
			'' as ShowTime,
			71 as MatchID
			,'' AS betcheck
		FROM 
			bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype			
		WHERE
			b.transdate			>= @FromDate AND b.transdate<= @ToDate 
			AND b.custid		= @CustID 
			AND sbt.ProductID	= 6
			AND sbt.EventType	= 0
			AND b.statusID		IN (0,1) 
			
	END
	
	--Bingo
	IF ( @ShowBG = 1 )
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
			'' as ShowTime,
			73 as matchid
			,'' AS betcheck
		FROM 
			bettrans b WITH (NOLOCK)	
			INNER JOIN @SportBettype sbt
			ON b.bettype = sbt.Bettype				
		WHERE
			b.transdate			>= @FromDate AND b.transdate<= @ToDate 
			AND b.custid		= @CustID 
			AND sbt.ProductID	= 7
			AND sbt.EventType	= 0
			AND b.statusID		IN (0,1) 
	END

	--Keno
	IF @ShowKN = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			202 AS sporttype,
			@Username AS UserName,
			t.gameid AS bettype,
			0 AS leagueID,	
			t.translogid AS refno,					
			t.translogid AS transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,--VinhTrinh Add for Horseracing
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1, 
			0 AS hdp2, 
			t.odds,
			0 AS modds,
			--b.status,
			t.status,
			t.stake,
			t.actual_stake, 
			t.transdate,		
			fnc.ChoiceId AS betteam,
			t.discount,
			0 AS liveindicator, 
			0 AS livehomescore, 
			0 AS liveawayscore, 
			t.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			t.winlostdate,
			t.currency,
			0 AS playercomm,
			'' AS ShowTime,
			fnc.GameId AS matchid
			,'' AS betcheck
		FROM 
			translog t WITH (NOLOCK)			
			INNER JOIN @SportBettype sbt
			ON t.gameID = sbt.Bettype	
			CROSS APPLY dbo.f_ParseTransDesc(t.transdesc, t.gameid) fnc	
		WHERE
			t.transdate			>= @FromDate AND t.transdate <= @ToDate 
			AND t.custid		= @CustID 
			AND sbt.ProductID	= 8
			AND sbt.EventType	= 0
			AND t.statusID		IN (0,1) 
	END

	--MicroGamming
	IF @ShowMGC = 1
	BEGIN
		INSERT INTO #BetListSelRunningByDateMem
		SELECT
			203 AS sporttype,
			@Username AS UserName,
			t.gameid AS bettype,
			0 AS leagueID,	
			t.translogid AS refno,					
			t.translogid AS transid,
			0 AS BetID,
			'' AS matchcode,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1, 
			0 AS hdp2, 
			t.odds,
			0 AS modds,
			--b.status,
			t.status,
			t.stake,
			t.actual_stake, 
			t.transdate,		
			'' AS betteam,
			t.discount,
			0 AS liveindicator, 
			0 AS livehomescore, 
			0 AS liveawayscore, 
			t.IP AS IP,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			t.winlostdate,
			t.currency,
			0 AS playercomm,
			'' AS ShowTime,
			0 AS matchid
			,'' AS betcheck
		FROM 
			translog t WITH (NOLOCK)			
			INNER JOIN @SportBettype sbt
			ON t.gameID = sbt.Bettype
		WHERE
			t.transdate			>= @FromDate AND t.transdate <= @ToDate 
			AND t.custid		= @CustID 
			AND sbt.ProductID	= 203
			AND sbt.EventType	= 0
			AND t.statusID		IN (0,1) 
	END
	-- check for filtering by currency
	IF @CurrencyID <> 0 
	BEGIN 
		DELETE #BetListSelRunningByDateMem
		WHERE Currency <> @CurrencyID
	END

	-- set totalrows
	SELECT @TotalRows = COUNT(1) 
	FROM #BetListSelRunningByDateMem

	-- select to paging
	SELECT A.* 
	FROM
	(
		SELECT  
				ROW_NUMBER() OVER(ORDER BY transid desc) AS RowNum,
				b.* ,
				stake*e.USD stakeUSD,
				stake*e.EUR stakeEUR,
				stake*e.GBP stakeGBP,
				actual_stake*e.USD actual_stakeUSD,
				actual_stake*e.EUR actual_stakeEUR,
				actual_stake*e.GBP actual_stakeGBP,
				b.playercomm*e.USD PlayerCommUSD,
				b.playercomm*e.EUR PlayerCommEUR,
				b.playercomm*e.GBP PlayerCommGBP
		FROM #BetListSelRunningByDateMem b
		INNER JOIN 
			(SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) AS e 
			ON e.exchangeid = b.currency
	) AS A 
	WHERE A.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	DECLARE @BetListDetail TABLE(
			refno bigint, 
			odds smallmoney, 
			stake money,
			status nvarchar(10),
			apositiontaking smallmoney, 
			bettype smallint,
			betteam nvarchar(20) ,
			stakeEUR MONEY,
			stakeUSD MONEY,
			stakeGBP MONEY
	);

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
			BM.stake*e.USD,
			BM.stake*e.GBP
		FROM bettransm BM with (NOLOCK)
			INNER JOIN #BetListSelRunningByDateMem B ON BM.refno = B.transid
			INNER JOIN 
				(SELECT * FROM Lrf_f_GetExchangeDaily(@Fromdate,@Todate))e 
				ON  e.ExchangeDate = B.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype IN (33,43)
			sbt.ProductID 		= 2
			AND sbt.EventType 	= 2
	END

	IF @ShowVS = 1
	begin
		--get data FROM bettransm for bettype 1233
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
			BM.stake*e.USD,
			BM.stake*e.GBP
		FROM bettransm BM with (NOLOCK)
			INNER JOIN #BetListSelRunningByDateMem B ON BM.refno = B.refno
			INNER JOIN 
				(SELECT * FROM Lrf_f_GetExchangeDaily(@Fromdate,@Todate))e 
				ON  e.ExchangeDate = B.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype =1233
			sbt.ProductID 		= 5
			AND sbt.EventType 	= 3
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
			bg.stake*e.USD,
			bg.stake*e.GBP
		FROM bettransg bg with (NOLOCK)
			INNER JOIN #BetListSelRunningByDateMem b ON bg.refno = b.refno
			INNER JOIN ( SELECT * FROM Lrf_f_GetExchangeDaily(@Fromdate,@Todate) ) AS e 
				ON  e.ExchangeDate = B.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --b.Bettype between 1101 and 1199
			sbt.ProductID 		= 4
			AND sbt.EventType 	= 1
	END

	SELECT * FROM @BetListDetail 
	ORDER BY refno

	DROP TABLE #BetListSelRunningByDateMem;

END
GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByDate_Mem] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByDate_Mem] TO vnteam
GO


