CREATE PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem]
	@LicenseeID 		INT ,
	@UserID				INT,
	@custid				INT,
	@fromdate			SMALLDATETIME,
	@transtype			INT = 0, 
	@langkey			NVARCHAR(10) = 'en-US',
	@PageSize 			INT=1000,
	@PageIndex 			INT=1,
	@TotalRows 			INT=0 OUTPUT,
	@SumWinlost 		MONEY=0 OUTPUT,
	@SumLicenseeWL 		MONEY=0 OUTPUT,
	@SumComm 			MONEY=0 OUTPUT,
	@SumPlayerComm 		MONEY=0 OUTPUT,
	@SumWinlostUSD 		MONEY=0 OUTPUT,
	@SumLicenseeWLUSD 	MONEY=0 OUTPUT,
	@SumCommUSD 		MONEY=0 OUTPUT,
	@SumPlayerCommUSD 	MONEY=0 OUTPUT,
	@SumWinlostEUR 		MONEY=0 OUTPUT,
	@SumLicenseeWLEUR 	MONEY=0 OUTPUT,
	@SumCommEUR 		MONEY=0 OUTPUT,
	@SumPlayerCommEUR 	MONEY=0 OUTPUT,
	@SumWinlostGBP 		MONEY=0 OUTPUT,
	@SumLicenseeWLGBP 	MONEY=0 OUTPUT,
	@SumCommGBP 		MONEY=0 OUTPUT,
	@SumPlayerCommGBP 	MONEY=0 OUTPUT,
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: Henry@20101210
Task : Bet List for Daily Statement
DB: DB052.bodb02
Original: Age_BetList_SelByDayAll_Mem
Revisions:
    
	-- 20110214@Jacob: Add column discount IN the result SET
	-- 20110303@Henry: suppport based currency
	- 20110408@Amy: Change function to get Odds value AND odds type
	- 20110712@Henry: Add column LicenseeWL
	- 20110725@Henry: Get refund tickets
	- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
	- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
	- 20111212@Jim: Edit condition bettype<19000
	- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
	- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
	- 20120319@Henry: show main transid for sub-ticket of system parlay 
	- 20120724@Jim: add player commision value 
	- 20120817@Jim: add live casino
	- 20120913@Jim: add virtual sport 
	- 20130410@Jim: return betteam value for Parlay (mix parlay & system parlay) ticket
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130905@Jim: support VHR
	- 20140310@Hannah: offer Keno
	- 20140324@Daniel: fix show RNG Casino / Bingo bets due to matchid = 0
	- 20140411@Francis: fix incorrect sporttypes showing for VHR, Racing
	- 20140630@Hannah: offer BetRadar and Sporting Solution
	- 20141121@Jim: support multiple currency per one member
	- 20150128@Winnie: Add currency GBP 
	- 20150413@Bobby: Re-format code  & #32844 new 60 bettypes - betradar phase 2
	- 20150511@Kiwi: Fixed the bug (RedmineID: #35562)
	- 20150608@Edward: Support MicroGamming
	- 20150608@Edward: Support Bet Trade
Param's Explanation: 
	+ @transtype: 1-Betting Statement; 2-VOID/Cancelled Bet; 3-Outstanding Bet 
	
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @IsBet14 BIT


	/*
	WON: 112   LOSE: 113   DRAW: 111 REFUND: 103
	VOID: 102	REJECT: 101
	RUNNING: 0  WAITING: 1
	*/
	DECLARE	@tmpStatus TABLE ([statusID] INT)
	IF(@transtype = 1) 
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 111 UNION ALL SELECT 112 UNION ALL SELECT 113 UNION ALL SELECT 103
	END
	ELSE IF(@transtype = 2)
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 101 UNION ALL SELECT 102
	END 
	ELSE IF(@transtype = 3)
	BEGIN
		INSERT INTO @tmpStatus([statusID])
		SELECT 0 UNION ALL SELECT 1
	END

	CREATE TABLE #Currency (currencyID INT, LicenseeID INT)

	INSERT INTO #currency
	SELECT  currencyID
		, LicenseeID 
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)

	DECLARE @recommend INT
	SELECT @recommend = recommend
	FROM bodb_licensee.dbo.licenseeCustInfo WITH (NOLOCK)
	WHERE CustId = @custID 

	DECLARE @TempAg	TABLE( custID INT,currency INT)  
	INSERT INTO @TempAg (custID,currency) 
	SELECT lc.custID,lc.currency 
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID 
	WHERE lc.CustID = @recommend 
		 
	IF NOT EXISTS ( SELECT 1 FROM @TempAg )
	BEGIN 
		
		SELECT @ErrCode = 101
			, @ErrMsg	= 'You have not permission to view this CustID, please check again.'

		RETURN
	END 		
	 
	------------------------------------
	DROP TABLE #Currency
	------------------------------------

	DECLARE @Data TABLE (
		sporttype		INT, 
		leagueid		INT, 
		homeid			INT, 
		awayid			INT, 
		bettype			SMALLINT,	
		matchcode		NVARCHAR(50),
		race			NVARCHAR(50),
		matchid			INT, 
		transid			BIGINT, 
		transdate		DATETIME, 
		winlostdate		DATETIME,
		refno			NVARCHAR(50), 
		betid			BIGINT,
		oddsid			INT, 	
		hdp1			SMALLMONEY, 
		hdp2			SMALLMONEY, 
		Modds			SMALLMONEY,
		oddstype		tinyint,
		odds			SMALLMONEY, 
		betteam			NVARCHAR(50), 
		status			NVARCHAR(50), 
		betstatus		NVARCHAR(50), 
		Stake			MONEY, 
		Actual_Stake	MONEY,
		winlost			MONEY,
		licenseeWL 		MONEY,
		comm			MONEY,
		playercomm		MONEY,	
		discount		DECIMAL(9,8),
		livehomescore	SMALLINT, 
		liveawayscore	SMALLINT, 
		liveindicator	BIT,
		finalhomescore	SMALLINT, 
		finalawayscore	SMALLINT, 
		hthomescore		SMALLINT, 
		htawayscore		SMALLINT, 
		--creator VARCHAR(50), 
		ip				NVARCHAR(20), 
		username		NVARCHAR(50),
		isNeutral		BIT	,
		currency		SMALLINT,
		showtime		NVARCHAR(50) -- table - shoe - hand of Live Casino
		,betcheck		NVARCHAR(50)
	)

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

	DELETE sbt
	FROM @SportBettype sbt
	WHERE ProductID	> 8 -- not suport for LIC system

	-- end filer bettypes

	IF EXISTS (SELECT TOP 1 1 FROM dbo.match14 (NOLOCK) WHERE eventdate = @fromdate)
		SELECT @IsBet14 = 1
	ELSE 
		SELECT @IsBet14 = 0

	IF ( @IsBet14 = 1 )
	BEGIN
		-- single bet
		INSERT INTO @Data 
		SELECT
			m.sporttype, 
			m.leagueid,
			m.homeID,
			m.awayID,
			b.bettype,
			m.matchcode,
			'' AS race,
			m.matchid, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			b.oddsid, 
			b.hdp1, 
			b.hdp2,
			modds, 
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status AS status,
			m.betstatus, 
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost, 
			CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
			CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
			b.playercomm ,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			m.finalhomescore, 
			m.finalawayscore,
			m.hthomescore, 
			m.htawayscore,
			--b.username, 
			b.IP AS IP,
			b.Username,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency
			,CASE WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime
			,CASE WHEN sbt.ProductID = 1 AND b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck
		FROM 
			dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid		
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid			= @custid 		
			--AND b.winlostdate=@fromdate AND b.bettype<=19000: old condition 
			AND b.winlostdate	= @fromdate 
			--AND (b.bettype<=1299 OR (b.bettype BETWEEN 1301 AND 1399))
			--AND b.bettype NOT IN (10,31,32,33,1231,1232,1233,1237,1238) --exclude Racing and VHS
			--AND sbt.ProductID	NOT IN (2, 5, 6 ,7, 8)
			AND sbt.EventType	= 1
			AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)

		--RNG Casino & Bingo		
		INSERT INTO @Data 
		SELECT
			case b.bettype when 71 then 251 else 252 end sporttype, 
			0 leagueid,
			0 homeID,
			0 awayID,
			b.bettype,
			'' matchcode,
			'' AS race,
			b.bettype matchid, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			b.oddsid, 
			b.hdp1, 
			b.hdp2,
			modds, 
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status AS status,
			'' betstatus, 
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost, 
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			0 finalhomescore, 
			0 finalawayscore,
			0 hthomescore, 
			0 htawayscore,
			--b.username, 
			b.IP AS IP,
			b.Username,
			0 AS IsNeutral,
			b.currency,
			'' ShowTime
			,'' AS betcheck
		FROM	dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE	b.custid			= @custid 
				AND b.winlostdate	= @fromdate
				AND sbt.ProductID	IN (6,7)
				AND sbt.EventType	= 0
				AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)

		-- Keno
		IF( @transtype = 1 OR @transtype = 2 )
			INSERT INTO @Data 
			SELECT
				202 AS sporttype, 
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				t.gameid AS matchid, 
				b.transid AS transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				0 AS betid,
				0 AS oddsid, 
				0 AS hdp1, 
				0 AS hdp2,
				b.modds, 
				0 AS Oddstype,
				b.odds,
				t.choiceid AS betteam,
				b.status AS status,
				'' AS betstatus, 
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost, 
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm AS comm,
				b.playercomm ,
				b.discount,
				0 AS livehomescore, 
				0 AS liveawayscore, 
				0 AS liveindicator, 
				0 AS finalhomescore, 
				0 AS finalawayscore,
				0 AS hthomescore, 
				0 AS htawayscore,
				--b.username, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,'' AS betcheck
			FROM 
				dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) t
			WHERE
				b.custid			= @custid 		
				--AND b.winlostdate=@fromdate AND b.bettype<=19000: old condition 
				AND b.winlostdate	= @fromdate 
				AND sbt.ProductID	= 8
				AND sbt.EventType	= 0
				AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)

		-------VHR
		INSERT INTO @Data 
		SELECT
			r.sporttype, 
			r.leagueid,
			o.RacerID homeID,
			0 awayID,
			b.bettype,
			CONVERT (VARCHAR(50),o.RacerNum) matchcode,
			'' AS race,
			o.EventID matchid, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			b.oddsid, 
			b.hdp1, 
			b.hdp2,
			modds, 
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status AS status,
			r.betstatus, 
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost, 
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			0 as finalhomescore, 
			0 as finalawayscore,
			0 as hthomescore, 
			0 as htawayscore,
			--b.username, 
			b.IP AS IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20),r.eventTime) AS ShowTime
			,'' AS betcheck
		FROM 
			dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN VSOutright14 o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid			= @custid 		
			AND b.winlostdate	= @fromdate 
			--AND b.bettype IN (1231, 1232, 1233, 1237, 1238)
			AND sbt.ProductId	= 5 
			AND sbt.EventType	= 3
			AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)
			
		-- mixed parlay & system parlay
		INSERT INTO @Data 
		SELECT
			0,
			0, 
			0, 
			0, 
			b.bettype,		
			'', 
			'' AS race, 
			0, 
			--b.transid, 
			CASE WHEN (ISNULL(b.BetID,0)=0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid, 
			b.transdate, 
			b.winlostdate, 
			b.refno,
			0,
			0, 
			0, 
			0, 
			b.modds,
			0 AS OddsType,
			b.odds, 
			b.betteam,
			b.status, 
			'' betstatus, 
			b.stake,
			b.actual_stake, 
			(b.winlost-b.actual_stake) AS winlost, 
			CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.discount,
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0,
			--b.username creator, 
			b.IP AS IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime
			,'' AS betcheck
		FROM 
			dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid		
		WHERE
			b.custid			= @custid
			AND b.winlostdate	= @fromdate
			--AND b.matchid=0 
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 0
			AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)

		-- outright
		INSERT INTO @Data 
		SELECT
			l.sporttype,
			m.leagueID,
			m.teamID AS homeid,
			0 AS awayid,
			b.bettype, 
			m.matchcode,
			m.groupmatch AS race, 
			m.orid, 
			b.transid, 
			b.transdate, 
			b.winlostdate, 
			b.refno,
			0,
			10, 
			b.hdp1, 
			b.hdp2, 
			b.modds,
			0 AS OddsType,
			b.odds, 
			'',
			b.status, 
			'', 
			b.stake,
			b.actual_stake, 
			(b.winlost-b.actual_stake) AS winlost,
			CASE WHEN ISNULL(BA.transid,0)=0 AND b.bettype=10 THEN - (b.winlost-b.actual_stake) WHEN b.bettype IN (31,32,33) THEN awinlost ELSE 0 END AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			0, 
			0, 
			0, 
			0, 
			0,
			--b.username creator,
			b.IP AS IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime
			,'' AS betcheck
		FROM 
			dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN dbo.outright14 m WITH (NOLOCK) on b.matchid = m.orid	
			INNER JOIN dbo.league l WITH (NOLOCK) on m.leagueid = l.leagueid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid			= @custid 
			AND b.winlostdate	= @fromdate
			AND (sbt.ProductID	IN (1, 2) AND sbt.EventType	= 2)
			AND b.statusID 		IN (SELECT [statusID] FROM @tmpStatus)

		-- MicroGamming
		IF( @transtype = 1 OR @transtype = 2 )
			INSERT INTO @Data 
			SELECT
				203 AS sporttype, 
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				0 AS matchid, 
				b.transid AS transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				0 AS betid,
				0 AS oddsid, 
				0 AS hdp1, 
				0 AS hdp2,
				b.modds, 
				0 AS Oddstype,
				b.odds,
				'' AS betteam,
				b.status AS status,
				'' AS betstatus, 
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost, 
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm AS comm,
				b.playercomm ,
				b.discount,
				0 AS livehomescore, 
				0 AS liveawayscore, 
				0 AS liveindicator, 
				0 AS finalhomescore, 
				0 AS finalawayscore,
				0 AS hthomescore, 
				0 AS htawayscore,
				--b.username, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,'' AS betcheck
			FROM 
				dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			WHERE
				b.custid			= @custid
				AND b.winlostdate	= @fromdate 
				AND sbt.ProductID	= 203
				AND sbt.EventType	= 0
				AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)

	END
	ELSE
	BEGIN
		
		-- single bet
		INSERT INTO @Data 
		SELECT
			m.sporttype, 
			m.leagueid,
			m.homeID,
			m.awayID,
			b.bettype,
			m.matchcode, 
			'' AS race,
			m.matchid, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			b.oddsid, 
			b.hdp1, 
			b.hdp2, 
			b.modds,
			b.OddsType,
			b.odds,
			b.betteam,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
			ELSE b.status   
			END as status,
			m.betstatus, 
			b.stake,
			b.actual_stake,
			CASE WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) ELSE 0 END AS winlost,
			CASE WHEN b.statusID NOT IN (0,1) THEN 
				CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END 
			ELSE 0 END	AS LicenseeWL ,

			CASE 
				WHEN b.bettype = 903 THEN b.awinlost 
				ELSE 
					CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 
					END 
			END as comm,
			b.playercomm , 
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			m.finalhomescore, 
			m.finalawayscore,
			m.hthomescore, 
			m.htawayscore,
			b.IP AS IP,
			b.Username,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency
			,CASE WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
			,CASE WHEN sbt.ProductID = 1 THEN b.betcheck ELSE '' END AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid		
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid			= @custid 		
			--AND b.winlostdate=@fromdate AND b.bettype<=19000 : old condition 
			AND b.winlostdate	= @fromdate 
			--AND (b.bettype<=1299 OR (b.bettype BETWEEN 1301 AND 1399)) 
			--AND b.bettype NOT IN (10,31,32,33,1231,1232,1233,1237,1238) --exclude Racing and VHS
			--AND sbt.ProductID	NOT IN (2, 5, 6 ,7, 8)
			AND sbt.EventType	= 1
			AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)

		--RNG Casino & Bingo		
		INSERT INTO @Data 
		SELECT
			case b.bettype when 71 then 251 else 252 end sporttype, 
			0 leagueid,
			0 homeID,
			0 awayID,
			b.bettype,
			'' matchcode,
			'' AS race,
			b.bettype matchid, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			b.oddsid, 
			b.hdp1, 
			b.hdp2,
			modds, 
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status AS status,
			'' betstatus, 
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost, 
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			0 finalhomescore, 
			0 finalawayscore,
			0 hthomescore, 
			0 htawayscore,
			--b.username, 
			b.IP AS IP,
			b.Username,
			0 AS IsNeutral,
			b.currency,
			'' ShowTime
			,'' AS betcheck
		FROM	dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE	b.custid			= @custid 
				AND b.winlostdate	= @fromdate
				--AND bettype IN(71,73)
				AND sbt.ProductID	IN (6,7)
				AND sbt.EventType	= 0
				AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)
		
		-- Keno
		IF(@transtype = 1 or @transtype = 2)
			INSERT INTO @Data 
			SELECT
				202 AS sporttype, 
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				t.gameid AS matchid, 
				b.transid AS transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				0 AS betid,
				0 AS oddsid, 
				0 AS hdp1, 
				0 AS hdp2,
				b.modds, 
				0 AS Oddstype,
				b.odds,
				t.choiceid AS betteam,
				b.status AS status,
				0 AS betstatus, 
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost, 
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm AS comm,
				b.playercomm ,
				b.discount,
				0 AS livehomescore, 
				0 AS liveawayscore, 
				0 AS liveindicator, 
				0 AS finalhomescore, 
				0 AS finalawayscore,
				0 AS hthomescore, 
				0 AS htawayscore,
				--b.username, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,'' AS betcheck
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) t
			WHERE
				b.custid			= @custid 		
				--AND b.winlostdate=@fromdate AND b.bettype<=19000: old condition 
				AND b.winlostdate	= @fromdate 
				--AND b.bettype BETWEEN 1501 AND 1599
				AND sbt.ProductID	= 8
				AND sbt.EventType	= 0
				AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)	
		ELSE
			INSERT INTO @Data	 
			SELECT
				202 AS sporttype, 
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				t.gameID AS bettype,
				'' AS matchcode, 
				'' AS race,
				k.GameId AS matchid, 
				t.translogid, 
				t.transdate, 
				t.winlostdate,
				t.translogid, 
				0 as betid,
				0 as oddsid, 
				0 AS hdp1, 
				0 AS hdp2, 
				0 AS modds,
				0 AS OddsType,
				t.odds,
				k.ChoiceId AS betteam,
				t.status,
				0 AS betstatus, 
				t.stake,
				t.actual_stake,
				0 AS winlost,
				0 AS LicenseeWL ,				
				0 AS comm,
				0 AS playercomm , 
				t.discount,
				0 AS livehomescore, 
				0 AS liveawayscore, 
				0 AS liveindicator, 
				0 AS finalhomescore, 
				0 AS finalawayscore,
				0 AS hthomescore, 
				0 AS htawayscore,
				t.IP AS IP,
				t.Username,
				CONVERT(BIT,0) AS IsNeutral,
				t.currency,
				'' AS ShowTime 
				,'' AS betcheck
			FROM 
				dbo.translog t WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON t.gameID = sbt.bettype
				OUTER APPLY dbo.[f_ParseTransDesc](t.TransDesc, t.gameID) k
			WHERE
				t.custid			= @custid 		
				--AND b.winlostdate=@fromdate AND b.bettype<=19000 : old condition 
				AND t.winlostdate	= @fromdate 
				--AND (t.gameID BETWEEN 1501 AND 1599)
				AND sbt.ProductID	= 8
				AND sbt.EventType	= 0
				AND t.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-------VHR
		INSERT INTO @Data 
		SELECT
			r.sporttype, 
			r.leagueid,
			o.RacerID homeID,
			0 awayID,
			b.bettype,
			CONVERT (VARCHAR(50),o.RacerNum) matchcode,
			'' AS race,
			o.EventID matchid, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			b.oddsid, 
			b.hdp1, 
			b.hdp2,
			modds, 
			b.Oddstype,
			b.odds,
			b.betteam,
			b.status AS status,
			r.betstatus, 
			b.stake,
			b.actual_stake,
			(b.winlost-b.actual_stake) AS winlost, 
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm ,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			0 as finalhomescore, 
			0 as finalawayscore,
			0 as hthomescore, 
			0 as htawayscore,
			--b.username, 
			b.IP AS IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20),r.eventTime) AS ShowTime
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN VSOutright o with (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE
			b.custid			= @custid 		
			AND b.winlostdate	= @fromdate 
			--AND b.bettype IN (1231, 1232, 1233, 1237, 1238)
			AND sbt.ProductId	= 5 
			AND sbt.EventType	= 3
			AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)
				
		-- mixed parlay & system parlay
		INSERT INTO @Data 
		SELECT
			0, 
			0, 
			0, 
			0, 
			b.bettype,		
			'', 
			'', 
			0, 
			--b.transid, 
			CASE WHEN (ISNULL(b.BetID,0)=0 OR b.bettype = 9) THEN b.transid ELSE betid END AS transid, 
			b.transdate, 
			b.winlostdate, 
			b.refno,
			0,
			0, 
			0, 
			0, 
			b.modds,
			0 AS OddsType,
			b.odds, 
			b.betteam,
			b.status, 
			'' betstatus, 
			b.stake,
			b.actual_stake,
			CASE WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) ELSE 0 END AS winlost,
			CASE WHEN b.statusID NOT IN (0,1) THEN 
				CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END 
			ELSE 0 END	AS LicenseeWL ,
			CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 END as comm,
			b.playercomm  ,
			b.discount,
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0,
			--b.username creator, 
			b.IP AS IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)		
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid=@custid
			AND b.winlostdate=@fromdate
			--AND b.matchid=0 
			--AND b.matchid = 9
			--AND b.bettype=9
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 0
			AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		-- outright
		INSERT INTO @Data 
		SELECT
			l.sporttype,
			m.leagueID,
			m.teamID AS homeid,
			0 AS awayid,
			b.bettype, 
			m.matchcode, 
			m.groupmatch AS race, 
			m.orid, 
			b.transid, 
			b.transdate, 
			b.winlostdate, 
			b.refno,
			0,
			10, 
			b.hdp1, 
			b.hdp2, 
			b.modds,
			0 AS OddsType,
			b.odds, 
			'',
			b.status, 
			'', 
			b.stake,
			b.actual_stake,
			CASE WHEN b.statusID NOT IN (0,1) THEN (b.winlost-b.actual_stake) ELSE 0 END AS winlost,
			CASE WHEN b.statusID NOT IN (0,1) THEN 
				CASE WHEN ISNULL(BA.transid,0)=0 AND b.bettype=10 THEN - (b.winlost-b.actual_stake) WHEN b.bettype IN (31,32,33) THEN awinlost ELSE 0 END 
			ELSE 0 END AS LicenseeWL ,
			CASE WHEN b.statusID NOT IN (0,1) THEN b.comm  ELSE 0 END as comm,
			b.playercomm  AS PlayerComm,
			b.discount,
			b.livehomescore, 
			b.liveawayscore, 
			0, 
			0, 
			0, 
			0, 
			0,
			--b.username creator, 
			b.IP AS IP,
			b.Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.outright m WITH (NOLOCK) on b.matchid = m.orid	
			INNER JOIN dbo.league l WITH (NOLOCK) on m.leagueid = l.leagueid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.custid			= @custid 
			AND b.winlostdate	= @fromdate
			--AND b.bettype IN (10,31,32,33)
			AND (sbt.ProductID	IN (1, 2) AND sbt.EventType	= 2)
			AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)

		-- MicroGamming
		IF(@transtype = 1 or @transtype = 2)
			INSERT INTO @Data 
			SELECT
				203 AS sporttype, 
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				b.bettype,
				'' AS matchcode,
				'' AS race,
				0 AS matchid, 
				b.transid AS transid, 
				b.transdate, 
				b.winlostdate,
				b.refno, 
				0 AS betid,
				0 AS oddsid, 
				0 AS hdp1, 
				0 AS hdp2,
				b.modds, 
				0 AS Oddstype,
				b.odds,
				'' AS betteam,
				b.status AS status,
				0 AS betstatus, 
				b.stake,
				b.actual_stake,
				(b.winlost-b.actual_stake) AS winlost, 
				- (b.winlost-b.actual_stake) AS LicenseeWL ,
				b.comm AS comm,
				b.playercomm ,
				b.discount,
				0 AS livehomescore, 
				0 AS liveawayscore, 
				0 AS liveindicator, 
				0 AS finalhomescore, 
				0 AS finalawayscore,
				0 AS hthomescore, 
				0 AS htawayscore,
				--b.username, 
				b.IP AS IP,
				b.Username,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime
				,'' AS betcheck
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			WHERE
				b.custid			= @custid
				AND b.winlostdate	= @fromdate 
				AND sbt.ProductID	= 203
				AND sbt.EventType	= 0
				AND b.statusID		IN (SELECT [statusID] FROM @tmpStatus)	
		ELSE
			INSERT INTO @Data	 
			SELECT
				203 AS sporttype, 
				0 AS leagueid,
				0 AS homeID,
				0 AS awayID,
				0 AS bettype,
				'' AS matchcode, 
				'' AS race,
				k.GameId AS matchid, 
				t.translogid, 
				t.transdate, 
				t.winlostdate,
				t.translogid, 
				0 as betid,
				0 as oddsid, 
				0 AS hdp1, 
				0 AS hdp2, 
				0 AS modds,
				0 AS OddsType,
				t.odds,
				'' AS betteam,
				t.status,
				0 AS betstatus, 
				t.stake,
				t.actual_stake,
				0 AS winlost,
				0 AS LicenseeWL ,				
				0 AS comm,
				0 AS playercomm , 
				t.discount,
				0 AS livehomescore, 
				0 AS liveawayscore, 
				0 AS liveindicator, 
				0 AS finalhomescore, 
				0 AS finalawayscore,
				0 AS hthomescore, 
				0 AS htawayscore,
				t.IP AS IP,
				t.Username,
				CONVERT(BIT,0) AS IsNeutral,
				t.currency,
				'' AS ShowTime 
				,'' AS betcheck
			FROM 
				dbo.translog t WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON t.gameID = sbt.bettype
			WHERE
				t.custid			= @custid
				AND t.winlostdate	= @fromdate
				AND sbt.ProductID	= 203
				AND sbt.EventType	= 0
				AND t.statusID IN (SELECT [statusID] FROM @tmpStatus)
	END
	
	-- For BetTrade
	UPDATE betList
	SET betList.Odds	= originBetList.Odds
		,betList.Stake	= originBetList.Stake
		,betList.comm	= CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
	FROM @Data AS betList
		INNER JOIN @Data AS originBetList ON betList.RefNO = originBetList.TransID
		INNER JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO
	WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)
		AND commBetList.Bettype = 903

	DELETE @Data WHERE Sporttype = 1 AND Bettype = 903	
	-- End Bet Trade

	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate,@Today)
	WHERE exchangeid  IN (SELECT DISTINCT Currency FROM @TempAg)


	SELECT 
		@TotalRows 			= COUNT(transid),
		@SumWinlost			= SUM(ISNULL(winlost,0)),
		@SumLicenseeWL		= SUM(ISNULL(LicenseeWL,0)),
			
		@SumComm			= SUM(ISNULL(comm,0)) ,
		@SumPlayerComm		= SUM(ISNULL(playercomm,0)) ,
		--USD
		@SumWinlostUSD		= SUM(ISNULL(winlost*e.USD,0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(LicenseeWL*e.USD,0)),
			
		@SumCommUSD			= SUM(ISNULL(comm*e.USD,0)) ,
		@SumPlayerCommUSD	= SUM(ISNULL(playercomm*e.USD,0)) ,
		--EUR
		@SumWinlostEUR		= SUM(ISNULL(winlost*e.EUR,0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(LicenseeWL*e.EUR,0)),
			
		@SumCommEUR			= SUM(ISNULL(comm*e.EUR,0)) ,
		@SumPlayerCommEUR	= SUM(ISNULL(playercomm*e.EUR,0)),
		--GBP
		@SumWinlostGBP		= SUM(ISNULL(winlost*e.GBP,0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(LicenseeWL*e.GBP,0)),
			
		@SumCommGBP			= SUM(ISNULL(comm*e.GBP,0)) ,
		@SumPlayerCommGBP	= SUM(ISNULL(playercomm*e.GBP,0))
			
	FROM @Data b
		INNER JOIN #TempExchange e 
		ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)   
			AND e.exchangeid = b.currency

	SELECT A.* 
	FROM
	(
		SELECT  
				ROW_NUMBER() over(order by transid, refno) AS RowNum,
				b.* ,
				--USD
				b.stake*e.USD AS stakeUSD ,
				b.Actual_Stake * e.USD AS Actual_StakeUSD,
				b.winlost*e.USD AS winlostUSD ,
				b.LicenseeWL * e.USD AS LicenseeWLUSD,
					
				b.comm*e.USD AS commUSD ,
				b.playercomm*e.USD AS PlayerCommUSD ,
				--EUR
				b.stake*e.EUR AS stakeEUR ,
				b.Actual_Stake * e.EUR AS Actual_StakeEUR,
				b.winlost*e.EUR AS winlostEUR ,
				b.LicenseeWL * e.EUR AS LicenseeWLEUR,
					
				b.comm*e.EUR AS commEUR,
				b.playercomm*e.EUR AS PlayerCommEUR ,
				--GBP
				b.stake*e.GBP AS stakeGBP ,
				b.Actual_Stake * e.GBP AS Actual_StakeGBP,
				b.winlost*e.GBP AS winlostGBP ,
				b.LicenseeWL * e.GBP AS LicenseeWLGBP,
					
				b.comm*e.GBP AS commGBP,
				b.playercomm*e.GBP AS PlayerCommGBP		
		FROM 
			@Data b
		INNER JOIN 
		#TempExchange e 
		ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END)   AND e.exchangeid = b.currency
	) AS A 
	WHERE A.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	DECLARE @BettransDetail TABLE (  
		refno				BIGINT,  
		odds				SMALLMONEY,  
		stake				MONEY,
		status				NVARCHAR(10),  
		apositiontaking		SMALLMONEY,  
		bettype				SMALLINT,
		Betteam				NVARCHAR (10),
		stakeEUR			MONEY,
		stakeUSD			MONEY,
		stakeGBP			MONEY
	);   

	IF (@IsBet14 = 1)
	BEGIN
		--get data FROM bettransm14 for bettype 33,43
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
			BM.stake*e.USD,
			BM.stake*e.GBP
		FROM bettransm14 BM WITH (NOLOCK)
			INNER JOIN @Data B ON BM.refno = B.transid
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype IN (33,43)
			sbt.ProductID 		= 2
			AND sbt.EventType 	= 2
		UNION ALL
		--get data from bettransm14 for bettype 1233
		SELECT 
			BM.refno,
			BM.odds,		
			BM.Stake,
			BM.status,
			BM.apositiontaking,
			BM.bettype,
			BM.Betteam,
			BM.stake*e.EUR,	
			BM.stake*e.USD,
			BM.stake*e.GBP		
		FROM bettransm14 BM with (NOLOCK, INDEX =IX_bettransm14 )
			INNER JOIN @Data B ON BM.refno = B.refno
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype = 1233
			sbt.ProductID 		= 5
			AND sbt.EventType 	= 3
			
		UNION ALL
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam ,
			BG.stake*e.EUR,
			BG.stake*e.USD,
			BG.stake*e.GBP	
		FROM bettransg14 BG WITH (NOLOCK)
			INNER JOIN @Data B ON BG.refno = B.refno and BG.custid = @CustID
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype BETWEEN 1101 AND 1199
			sbt.ProductID 		= 4
			AND sbt.EventType 	= 1
	END
	ELSE
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
			BM.betteam,
			BM.stake*e.EUR,
			BM.stake*e.USD,
			BM.stake*e.GBP
		FROM bettransm BM WITH (NOLOCK)
			INNER JOIN @Data B ON BM.refno = B.transid
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype IN (33,43)
			sbt.ProductID 		= 2
			AND sbt.EventType 	= 2
		UNION ALL
		--get data from bettransm14 for bettype 1233
		SELECT 
			BM.refno,
			BM.odds,		
			BM.Stake,
			BM.status,
			BM.apositiontaking,
			BM.bettype,
			BM.Betteam,
			BM.stake*e.EUR,	
			BM.stake*e.USD,
			BM.stake*e.GBP		
		FROM bettransm BM with (NOLOCK)
			INNER JOIN @Data B ON BM.refno = B.refno
			INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   
				AND e.exchangeid = B.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype = 1233
			sbt.ProductID 		= 5
			AND sbt.EventType 	= 3
			
		UNION
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
		INNER JOIN @Data B ON BG.refno = B.refno and BG.custid = @CustID
		INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE --B.Bettype BETWEEN 1101 AND 1199
			sbt.ProductID 		= 4
			AND sbt.EventType 	= 1
	END


	SELECT * 
	FROM @BettransDetail 
	ORDER BY refno,bettype 

	DROP TABLE #TempExchange
	RETURN;

END
GO 

GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelByDayAll_Mem] TO [vnteam]
GO 

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelByDayAll_Mem] TO [bodbLicenseeNet]
GO 
