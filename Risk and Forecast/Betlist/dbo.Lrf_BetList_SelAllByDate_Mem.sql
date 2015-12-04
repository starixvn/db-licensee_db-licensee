USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelAllByDate_Mem_xtest]    Script Date: 7/7/2015 2:27:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelAllByDate_Mem]
	@LicenseeID 		INT,
	@UserID				INT,
	@custid 			INT			= NULL,
	@FromDate 			DATETIME,
	@ToDate 			DATETIME,
	@Langkey 			VARCHAR(10) = 'en-US',
	@username 			VARCHAR(50) = NULL, -- for API
	@PageSize 			INT			= 1000,
	@PageIndex 			INT			= 1,
	-- check for showing product
	@ShowSB 			BIT = 0,
	@ShowRB 			BIT = 0,
	@ShowNG 			BIT = 0,
	@ShowBA 			BIT = 0,
	@ShowLC				BIT = 0,
	@ShowVS 			BIT = 0,
	@ShowCS				BIT = 0, -- RNG Casino
	@ShowBG				BIT = 0, -- Bingo 
	@ShowKN				BIT = 0, -- Keno
	@ShowMGCLC			BIT = 0, -- Microgaming Live Casino
	@ShowMGCRNG			BIT = 0, -- Microgaming RNG Game
	@ShowAGC			BIT = 0, -- AG Casino
	@ShowBT				BIT = 0, -- Bet Trade
	-- output info
	@SumWinlost 		MONEY			= 0 OUTPUT,
	@SumLicenseeWL 		MONEY			= 0 OUTPUT,
	@SumComm 			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinlostUSD 		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD 	MONEY			= 0 OUTPUT,
	@SumCommUSD 		MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD 	MONEY			= 0 OUTPUT,
	@SumWinlostEUR 		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR 	MONEY			= 0 OUTPUT,
	@SumCommEUR 		MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR 	MONEY			= 0 OUTPUT,
	@SumWinlostGBP 		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP 	MONEY			= 0 OUTPUT,
	@SumCommGBP 		MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP 	MONEY			= 0 OUTPUT,
	@TotalRows 			INT				= 0	OUTPUT,
	@ErrorCode 			INT				= 0	OUTPUT,
	@ErrorMsg			NVARCHAR(100)	= '' OUTPUT
AS

/*
	Created: Henry@20101209
	TASk : Bet List
	DB: DBEXT.bodb02
	Original [Age_BetList_SelAllByDate_Mem]
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110303@Henry: suppport bASed currency
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
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20150130@Winnie: Add base currency GBP
		- 20150403@Bobby: Apply sporttype matrix & #32844 new 60 bettypes - betradar phase 2
		- 20150605@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150828@Edward: Return refNo value instead of '' for BetTrade tickets
		- 20150828@Edward: Update Odds and Stake in the same time insert to temporary table
		- 20150917@Kos: Support Microgaming RNG Game
		- 20150922@Kos: Support AG Casino
		- 20151028@Kos: Change ProductId, SportType of Microgaming RNG Game
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/

BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Recommend	INT
		,@Today			SMALLDATETIME 

	SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
	
	IF @custid IS NULL
	BEGIN
		SELECT @custid = custid 
		FROM dbo.customer WITH (NOLOCK) 
		WHERE username = @username
	END
	
	SELECT currencyID
		,LicenseeID 
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)

	SELECT @Recommend 	= Recommend
		, @UserName 	= Username 
	FROM dbo.custinfo AS c WITH(NOLOCK) 
		INNER JOIN #Currency cy ON cy.CurrencyID = c.Currency
	WHERE CustID = @CustID
	------------------------------
	DROP TABLE #currency
	------------------------------
	
	IF (@custid IS NULL
		OR @username IS NULL)
	BEGIN
		SELECT @ErrorCode	= 100
			, @ErrorMsg		= 'The customer was not found.'
		RETURN;
	END
	
	CREATE TABLE #BetListSelAllByDateMem (
		Username		NVARCHAR(50), 
		Sporttype		INT,
		Bettype			SMALLINT,
		refno			NVARCHAR(50),
		TransID			BIGINT,
		BetID			BIGINT,
		MatchCode		NVARCHAR(50),
		MatchID			INT,
		Race			NVARCHAR(50),
		HomeID			INT,
		AwayID			INT, 
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		Odds			MONEY, 
		modds			MONEY, 
		Status			NVARCHAR(50),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		Winlost			MONEY,
		LicenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		discount		DECIMAL(9,8),
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Betteam			NVARCHAR(50),
		LeagueID		INT,
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(15),
		Betstatus		NVARCHAR(50),
		isNeutral		BIT,
		oddstype		INT NULL,
		currency		SMALLINT,
		showtime		NVARCHAR(50) -- table - shoe - hand of Live Casino
		,betcheck		NVARCHAR(50)
	)

	CREATE TABLE #TempBATicket(
		Bettype			INT,
		RefNO			BIGINT,	
		TransID			BIGINT,
		BetID			BIGINT,
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		Odds			MONEY, 
		modds			MONEY, 
		Status			NVARCHAR(10),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		Winlost			MONEY,
		LicenseeWL		MONEY,
		comm			MONEY,
		playercomm		MONEY,
		discount 		DECIMAL(9,8),
		Transdate		DATETIME,
		Winlostdate		DATETIME,
		Betteam			NVARCHAR(20),
		Liveindicator	BIT,
		Livehomescore	SMALLINT,
		Liveawayscore	SMALLINT,
		IP				NVARCHAR(50),
		OddsType		TINYINT,
		currency 		INT,
		MatchID 		INT,
		custid			INT 
		,betcheck		NVARCHAR(50)
	)
	
	-- filer bettypes by sporttype
	DECLARE @SportBettype TABLE ( 
		ProductID 	TINYINT
		, Bettype 	SMALLINT
		, EventType	TINYINT
	)
	
	INSERT INTO @SportBettype
	EXEC dbo.Acc_SportBettypeMatrix_Sel @mode = 4

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype WHERE ProductID = 1 AND Bettype IN (901, 902, 903)
	END

	DELETE sbt
	FROM @SportBettype sbt
	WHERE ProductID		= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 AND @ShowBT = 0 THEN 1 END
		OR ProductID	= CASE WHEN @ShowRB		= 0 THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG		= 0 THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC		= 0 THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS		= 0 THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS		= 0 THEN 6 END
		OR ProductID	= CASE WHEN @ShowBG		= 0 THEN 7 END
		OR ProductID	= CASE WHEN @ShowKN		= 0 THEN 8 END
		OR ProductID	= CASE WHEN @ShowMGCLC	= 0 THEN 13 END
		OR ProductID	= CASE WHEN @ShowMGCRNG	= 0 THEN 17 END
		OR ProductID	= CASE WHEN @ShowAGC	= 0 THEN 11 END
		OR (ProductID 	> 8 AND sbt.ProductID NOT IN (11, 13, 17)) -- not suport for LIC system
	-- end filer bettypes by sporttype
	
	--general
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
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END AS status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) winlost,
		0 AS LicenseeWL ,
		b.comm,
		b.playercomm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.liveindicator, 
		b.livehomescore, 
		b.liveawayscore, 
		b.IP,
		b.Oddstype,
		b.currency,
		b.matchid,
		b.custid 
		,b.betcheck
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) 
		ON b.transid = BA.transid	
		INNER JOIN @SportBettype sbt
		ON b.bettype = sbt.Bettype
	WHERE b.CustID 			=	@CustID 
		AND b.recommend		=	@Recommend  
		AND sbt.ProductId	=	1
		AND b.transdate		>=	@FromDate AND b.transdate<=@ToDate
		AND b.bettype NOT IN (901,902,903)

	IF @ShowBA = 1
	BEGIN
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
			b.status,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.LicenseeWL ,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.Oddstype,
			b.currency,
			'' AS ShowTime
			,b.betcheck
		FROM 
			#TempBATicket b
			INNER JOIN match m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE
			sbt.ProductID		= 1
			AND sbt.EventType	= 1
			
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
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS Betteam,
			m.leagueID,
			0 AS liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP, 
			'' betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType ,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
		FROM
			#TempBATicket b
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH (NOLOCK) ON m.leagueID = l.leagueID
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE
			sbt.ProductID		= 1
			AND sbt.EventType	= 2

		-- MixParlay & System Parlay
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			0 AS sporttype,
			b.bettype,
			CONVERT(NVARCHAR(20),b.refno) AS refno,
			CASE WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid, 
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
			b.playercomm AS playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			0 AS leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP,
			'' AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
		FROM 
			#TempBATicket b
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE
			sbt.ProductID		= 1
			AND sbt.EventType	= 0
	END

	IF ( @ShowSB = 1 )
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
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.Oddstype,
			b.currency,
			'' AS ShowTime 
			,CASE WHEN b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck
		FROM 
			bettrans b WITH (NOLOCK)
			INNER JOIN match m WITH (NOLOCK) ON b.matchid=m.matchid	
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE b.CustID			=	@CustID 
			AND	b.recommend		=	@Recommend  
			AND	b.matchid		>	0
			AND sbt.ProductID	=	1
			AND sbt.EventType	=	1
			AND b.transid		NOT IN (SELECT TransId FROM #TempBATicket )
			AND b.transdate		>=	@FromDate AND b.transdate<=@ToDate
			AND b.bettype NOT IN (901,902,903)
			
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
			(winlost-actual_stake) winlost,
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
			b.IP, 
			'' betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType ,
			b.currency,
			'' AS ShowTime
			,'' AS betcheck
		FROM
			bettrans b WITH (NOLOCK)
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN league l WITH (NOLOCK) ON m.leagueID = l.leagueID 
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE b.CustID			= @CustID
			AND b.recommend		= @Recommend 
			AND b.matchid		> 0
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 2
			AND b.transid		NOT IN ( SELECT TransId FROM #TempBATicket )
			AND b.transdate >= @FromDate AND b.transdate<=@ToDate

		-- MixParlay & System Parlay
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			0 AS sporttype,
			b.bettype,
			CONVERT(NVARCHAR(20),b.refno) AS refno,
			CASE WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid,
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
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			0 AS leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP,
			'' AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType ,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE b.CustID			= @CustID 
			AND	b.recommend		= @Recommend  
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 0
			AND b.matchid		IN (9, 29) 
			AND b.transid		NOT IN ( SELECT TransId FROM #TempBATicket )
			AND b.transdate		>= @FromDate AND b.transdate <= @ToDate
	END

	-- Bet trade
	IF @ShowBT = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		--Single bets
		SELECT 
			@UserName AS UserName,
			m.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(ob.bettype,0),
			m.matchcode, 
			m.matchid,
			'' AS Race, 
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			ob.odds,
			b.modds,
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status
			END AS status,
			ob.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) winlost,
			- (b.winlost - b.actual_stake) AS LicenseeWL ,
			CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.Oddstype,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.bettrans ob WITH(NOLOCK) ON b.refno = ob.transid
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE b.CustID			=	@CustID 
			AND	b.recommend		=	@Recommend  
			AND	b.matchid		>	0
			AND sbt.ProductID	=	1
			AND sbt.EventType	=	1
			AND b.transdate		>=	@FromDate AND b.transdate<=@ToDate
			AND b.bettype IN (901,902,903)

		UPDATE betList
		SET betList.comm = CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
		FROM #BetListSelAllByDateMem AS betList
			INNER JOIN #BetListSelAllByDateMem AS commBetList ON betList.RefNO = commBetList.RefNO
		WHERE betList.Sporttype = 1 
			AND betList.Bettype IN (901, 902)
			AND commBetList.Bettype = 903

		DELETE #BetListSelAllByDateMem WHERE Sporttype = 1 AND Bettype = 903
	END

	DROP TABLE #TempBATicket;

	-- Horse Racing
	IF ( @ShowRB = 1 )
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
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake)  winlost,
			b.awinlost,
			b.comm ,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS Betteam,
			m.leagueID,
			0 AS liveindicator, 
			b.livehomescore, 
			b.liveawayscore, 
			b.IP, 
			'' betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype	
		WHERE b.CustID			= @CustID 
			AND	b.recommend		= @Recommend
			AND b.matchid		> 0
			AND sbt.ProductID	= 2
			AND sbt.EventType	= 2
			AND b.transdate		>= @FromDate AND b.transdate<=@ToDate	
	END

	-- Number Game
	IF ( @ShowNG	= 1
		OR @ShowLC	= 1
		OR @ShowVS	= 1
	)
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
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END AS status,
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
			b.IP,
			m.betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.CustID			=	@CustID 
			AND	b.recommend		=	@Recommend  
			AND sbt.ProductID	IN	(3, 4, 5)
			AND sbt.EventType	=	1
			AND b.transdate		>=	@FromDate AND b.transdate<=@ToDate

		UNION 
		SELECT 
			@UserName AS UserName,
			r.sporttype,
			b.bettype,
			CONVERT(NVARCHAR(20),b.refno) AS refno,		
			b.transid,
			ISNULL(b.BetID,0),
			CONVERT(varchar(50),o.RacerNum) AS matchcode, 
			o.EventID matchid,
			b.oddsid AS Race, 
			o.RacerID AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2,  
			b.odds,
			b.modds,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END AS status,
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
			r.leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore,
			b.IP,
			r.betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			CONVERT(VARCHAR(20),r.EventTime) AS ShowTime 
			,'' AS betcheck
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
		WHERE
			b.CustID			=	@CustID 
			AND	b.recommend		=	@Recommend  
			AND sbt.ProductID	=	5
			AND sbt.EventType	=	3
			AND b.transdate		>=	@FromDate AND b.transdate <= @ToDate
	END

	-- Casino
	IF ( @ShowCS = 1 )
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
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm ,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			0 AS leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore,
			b.IP,
			0 AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			''  AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype	
		WHERE
			b.CustID			=	@CustID 
			AND	b.recommend		=	@Recommend  
			AND sbt.ProductID	=	6
			AND sbt.EventType	=	0
			AND b.transdate		>=	@FromDate AND b.transdate <= @ToDate
	END

	-- Bingo
	IF ( @ShowBG = 1 )
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
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			0 AS leagueID,
			b.liveindicator, 
			b.livehomescore, 
			b.liveawayscore,
			b.IP,
			0 AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			''  AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype	
		WHERE
			b.CustID			=	@CustID 
			AND	b.recommend		=	@Recommend  
			AND sbt.ProductID	=	7
			AND sbt.EventType	=	0
			AND b.transdate		>=	@FromDate AND b.transdate <= @ToDate
	END

	--Keno
	IF ( @ShowKN = 1 )
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			202 AS sporttype,
			b.bettype,
			b.refno,
			b.transid AS transid,
			ISNULL(b.BetID,0),
			'' AS matchcode, 
			t.GameId AS matchid,
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
			(winlost-actual_stake) winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			t.ChoiceId AS betteam,
			0 AS leagueID,
			0 AS liveindicator, 
			0 AS livehomescore, 
			0 AS liveawayscore,
			b.IP,
			0 AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			''  AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
			CROSS APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) t
		WHERE
			b.CustID			=	@CustID 
			AND	b.recommend		=	@Recommend  
			AND sbt.ProductID	=	8
			AND sbt.EventType	=	0
			AND b.transdate		>=	@FromDate AND b.transdate <= @ToDate 
			AND	b.statusID		NOT IN (0,1)	

		UNION ALL
		SELECT 
			@UserName AS UserName,
			202 AS sporttype,
			t.gameid AS bettype,
			t.translogid AS refno,
			t.translogid AS transid,
			0 AS BetID, 
			'' AS matchcode, 
			k.GameId AS matchid,
			'' AS Race, 
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1, 
			0 AS hdp2,  
			t.odds ,
			0 AS modds,
			t.status,
			t.stake,
			t.actual_stake,
			(0-actual_stake) winlost,
			- (0-t.actual_stake) AS LicenseeWL ,
			0 AS comm,
			0 AS PlayerComm,
			t.discount,
			t.transdate,
			t.winlostdate,
			k.ChoiceId AS betteam,
			0 AS leagueID,
			0 AS liveindicator, 
			0 AS livehomescore, 
			0 AS liveawayscore,
			t.IP,
			0 AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS Oddstype,
			t.currency,
			''  AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.translog AS t WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON t.gameID = sbt.Bettype	
			CROSS APPLY dbo.[f_ParseTransDesc](t.TransDesc, t.gameid) k
		WHERE
			t.CustID			=	@CustID 
			AND	t.recommend		=	@Recommend 
			AND sbt.ProductID	=	8
			AND sbt.EventType	=	0
			AND	t.transdate		>=	@FromDate AND t.transdate <= @ToDate 
			AND t.statusID		IN (0,1)	
	END

	-- Microgaming Live Casino
	IF ( @ShowMGCLC = 1 )
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			203 AS sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost - actual_stake) AS winlost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.IP,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			b.betcheck
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.CustID = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 13
			AND sbt.EventType = 0
			AND b.transdate BETWEEN @FromDate AND @ToDate 
			AND b.statusID NOT IN (0, 1)

		UNION ALL
		SELECT 
			@UserName AS UserName,
			203 AS sporttype,
			t.gameid AS bettype,
			t.translogid AS refno,
			t.translogid AS transid,
			0 AS BetID,
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			t.status,
			t.stake,
			t.actual_stake,
			(0 - actual_stake) AS winlost,
			- (0 - t.actual_stake) AS LicenseeWL ,
			0 AS comm,
			0 AS PlayerComm,
			t.discount,
			t.transdate,
			t.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			t.IP,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			t.currency,
			'' AS ShowTime,
			'' AS betcheck
		FROM 
			dbo.translog AS t WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.Bettype
		WHERE
			t.CustID = @CustID 
			AND t.recommend = @Recommend 
			AND sbt.ProductID = 13
			AND sbt.EventType = 0
			AND t.transdate BETWEEN @FromDate AND @ToDate 
			AND t.statusID IN (0, 1)
	END

	-- Microgaming RNG Game
	IF ( @ShowMGCRNG = 1 )
	BEGIN
		-- Up to yesterday settled ticket
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			205 AS sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost - actual_stake) AS winlost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.IP,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.CustID = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 17
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.transdate < DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- not today
			AND b.statusID NOT IN (0, 1)

		IF @ToDate >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			AND @FromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
		BEGIN
			-- Today running ticket
			INSERT INTO #BetListSelAllByDateMem
			SELECT 
				@UserName AS UserName,
				205 AS sporttype,
				b.bettype,
				b.refno,
				b.transid,
				ISNULL(b.BetID, 0),
				'' AS matchcode,
				0 AS matchid,
				'' AS Race,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				'Running' AS Status,
				SUM(brng.stake) AS Stake,
				SUM(brng.actual_stake) AS Actual_Stake,
				0 AS Winlost,
				0 AS LicenseeWL,
				0 AS comm,
				0 AS playercomm,
				0 AS discount,
				b.transdate,
				b.winlostdate,
				'' AS betteam,
				0 AS leagueID,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				0 AS betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS Oddstype,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck
			FROM 
				dbo.bettransRnG AS brng WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.CustID = @CustID
				AND b.recommend = @Recommend
				AND sbt.ProductID = 17
				AND sbt.EventType = 0
				AND b.transdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0) AND @ToDate	-- today
				AND brng.statusID = 0
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.IP,
				b.currency

			-- Today settled ticket
			INSERT INTO #BetListSelAllByDateMem
			SELECT 
				@UserName AS UserName,
				205 AS sporttype,
				b.bettype,
				b.refno,
				b.transid,
				ISNULL(b.BetID, 0),
				'' AS matchcode,
				0 AS matchid,
				'' AS Race,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				CASE 
					WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
					WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
					WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
				END AS Status,
				SUM(brng.stake) AS Stake,
				SUM(brng.actual_stake) AS Actual_Stake,
				SUM(brng.winlost - brng.actual_stake) AS Winlost,
				SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
				SUM(brng.comm) AS comm,
				SUM(brng.playercomm) AS playercomm,
				b.discount,
				b.transdate,
				b.winlostdate,
				'' AS betteam,
				0 AS leagueID,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				0 AS betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS Oddstype,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck
			FROM 
				dbo.bettransRnG AS brng WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.CustID = @CustID
				AND b.recommend = @Recommend
				AND sbt.ProductID = 17
				AND sbt.EventType = 0
				AND b.transdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0) AND @ToDate	-- today
				AND brng.statusID <> 0
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.refno,
				b.discount,
				b.transdate,
				b.winlostdate,
				b.IP,
				b.currency
		END
	END

	-- AG Casino
	IF ( @ShowAGC = 1 )
	BEGIN
		-- AG Casino (up to yesterday settled ticket)
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			250 AS sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost - actual_stake) AS winlost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.IP,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.CustID = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 11
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.transdate < DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- not today
			AND b.statusID NOT IN (0, 1)

		IF @ToDate >= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			AND @FromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
		BEGIN
			-- Today running ticket
			INSERT INTO #BetListSelAllByDateMem
			SELECT 
				@UserName AS UserName,
				250 AS sporttype,
				b.bettype,
				b.refno,
				b.transid,
				ISNULL(b.BetID, 0),
				'' AS matchcode,
				0 AS matchid,
				'' AS Race,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				'Running' AS Status,
				SUM(blc.stake) AS Stake,
				SUM(blc.actual_stake) AS Actual_Stake,
				0 AS Winlost,
				0 AS LicenseeWL,
				0 AS comm,
				0 AS playercomm,
				0 AS discount,
				b.transdate,
				b.winlostdate,
				'' AS betteam,
				0 AS leagueID,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				0 AS betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS Oddstype,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck
			FROM 
				dbo.bettransLC AS blc WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.CustID = @CustID
				AND b.recommend = @Recommend
				AND sbt.ProductID = 11
				AND sbt.EventType = 0
				AND b.transdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0) AND @ToDate	-- today
				AND blc.statusID = 0
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.refno,
				b.transdate,
				b.winlostdate,
				b.IP,
				b.currency

			-- Today settled ticket
			INSERT INTO #BetListSelAllByDateMem
			SELECT 
				@UserName AS UserName,
				250 AS sporttype,
				b.bettype,
				b.refno,
				b.transid,
				ISNULL(b.BetID, 0),
				'' AS matchcode,
				0 AS matchid,
				'' AS Race,
				0 AS homeID,
				0 AS awayID,
				0 AS hdp1,
				0 AS hdp2,
				0 AS odds,
				0 AS modds,
				CASE 
					WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
					WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
					WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
				END AS Status,
				SUM(blc.stake) AS Stake,
				SUM(blc.actual_stake) AS Actual_Stake,
				SUM(blc.winlost - blc.actual_stake) AS Winlost,
				SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
				SUM(blc.comm) AS comm,
				SUM(blc.playercomm) AS playercomm,
				b.discount,
				b.transdate,
				b.winlostdate,
				'' AS betteam,
				0 AS leagueID,
				0 AS liveindicator,
				0 AS livehomescore,
				0 AS liveawayscore,
				b.IP,
				0 AS betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS Oddstype,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck
			FROM 
				dbo.bettransLC AS blc WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.CustID = @CustID
				AND b.recommend = @Recommend
				AND sbt.ProductID = 11
				AND sbt.EventType = 0
				AND b.transdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0) AND @ToDate	-- today
				AND blc.statusID <> 0
			GROUP BY
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.refno,
				b.discount,
				b.transdate,
				b.winlostdate,
				b.IP,
				b.currency
		END
	END

	CREATE NONCLUSTERED INDEX IDX_Index_betlist ON #BetListSelAllByDateMem(Currency)
	
	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate) ex
	WHERE ex.ExchangeId IN (SELECT DISTINCT Currency FROM #BetListSelAllByDateMem)

	SELECT 
		@TotalRows			= COUNT(1),
		@SumWinlost			= SUM(ISNULL(winlost, 0)),
		@SumWinlostUSD		= SUM(ISNULL(winlost * e.USD, 0)),
		@SumWinlostEUR		= SUM(ISNULL(winlost * e.EUR, 0)),
		@SumWinlostGBP		= SUM(ISNULL(winlost * e.GBP, 0)),
		@SumLicenseeWL		= SUM(ISNULL(LicenseeWL, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(LicenseeWL * e.USD, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(LicenseeWL * e.EUR, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(LicenseeWL * e.GBP, 0)),
		@SumComm			= SUM(ISNULL(comm, 0)) ,
		@SumCommUSD			= SUM(ISNULL(comm * e.USD, 0)),
		@SumCommEUR			= SUM(ISNULL(comm * e.EUR, 0)),
		@SumCommGBP			= SUM(ISNULL(comm * e.GBP, 0)),
		@SumPlayerComm		= SUM(ISNULL(playercomm, 0)) ,
		@SumPlayerCommUSD	= SUM(ISNULL(playercomm * e.USD, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(playercomm * e.EUR, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(playercomm * e.GBP, 0))
	FROM 
		#BetListSelAllByDateMem b
		INNER JOIN #TempExchange e 
			ON e.ExchangeDate		= (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END) 
				AND e.exchangeid	= b.currency
		WHERE b.[status] <> 'running'

	-- return betlist single ticket
	SELECT T.* 
	FROM 
	(
		SELECT 
			ROW_NUMBER() OVER(ORDER BY b.transid DESC) AS RowNum,
			b.*,
			--bASe USD currency
			Stake*e.USD AS StakeUSD,
			Actual_Stake * e.USD AS Actual_StakeUSD,
			Winlost*e.USD AS WinlostUSD,
			LicenseeWL * e.USD AS LicenseeWLUSD,
			comm*e.USD AS commUSD,
			playercomm*e.USD AS PlayerCommUSD,
			--bASe EUR currency
			Stake*e.EUR AS StakeEUR,
			Actual_Stake * e.EUR AS Actual_StakeEUR,
			Winlost*e.EUR AS WinlostEUR,
			LicenseeWL * e.EUR AS LicenseeWLEUR,
			comm*e.EUR AS commEUR,
			playercomm*e.EUR AS PlayerCommEUR,
			--bASe GBP currency
			Stake*e.GBP AS StakeGBP,
			Actual_Stake * e.GBP AS Actual_StakeGBP,
			Winlost*e.GBP AS WinlostGBP,
			LicenseeWL * e.GBP AS LicenseeWLGBP,
			comm*e.GBP AS commGBP,
			playercomm*e.GBP AS PlayerCommGBP
		FROM	
			#BetListSelAllByDateMem b
			INNER JOIN #TempExchange e 
				ON e.ExchangeDate		= (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)   
					AND e.exchangeid	= b.currency
	) AS T
	WHERE T.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	-- get ticket in more detail
	DECLARE @BettransDetail TABLE(
		refno			BIGINT,
		odds			MONEY,
		stake			MONEY,
		status			NVARCHAR(10),
		apositiontaking SMALLMONEY,
		bettype			SMALLINT,
		Betteam			NVARCHAR(10),
		stakeEUR		MONEY,
		stakeUSD		MONEY,
		stakeGBP		MONEY
	)

	IF ( @ShowRB = 1 )
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
			BM.stake*e.USD,
			BM.stake*e.GBP
		FROM bettransm BM WITH (NOLOCK)
			INNER JOIN #BetListSelAllByDateMem B ON BM.refno = B.transid
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype IN (33,43)
			sbt.ProductID 		= 2
			AND sbt.EventType 	= 2
	END

	IF ( @ShowLC = 1 )
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
			BG.stake*e.USD,
			BG.stake*e.GBP
		FROM bettransg BG WITH (NOLOCK)
			INNER JOIN #BetListSelAllByDateMem B ON BG.refno = B.refno 
				AND BG.custid = @CustID
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt 
			ON b.bettype = sbt.bettype
		WHERE --B.Bettype BETWEEN 1101 AND 1199	
			sbt.ProductID 		= 4
			AND sbt.EventType 	= 1
	END 

	IF ( @ShowVS = 1 )
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype,
			BG.Betteam,
			BG.stake*e.EUR,
			BG.stake*e.USD,
			BG.stake*e.GBP
		FROM bettransm BG WITH (NOLOCK)
			INNER JOIN #BetListSelAllByDateMem B ON BG.refno = B.refno 
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype=1233
			sbt.ProductID 		= 5
			AND sbt.EventType 	= 3
	END

	SELECT bd.* 
	FROM @BettransDetail bd
	ORDER BY RefNo
		, Bettype 

	DROP TABLE #TempExchange 
	DROP TABLE #BetListSelAllByDateMem
	
END

GO
GRANT  EXECUTE  ON [dbo].[Lrf_BetList_SelAllByDate_Mem]  TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelAllByDate_Mem] TO [vnteam]
GO
