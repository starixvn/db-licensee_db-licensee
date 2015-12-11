ALTER PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem_Old]
	@LicenseeID 		INT,
	@UserID				INT,
	@custid				INT,
	@fromdate			SMALLDATETIME,
	@transtype			TINYINT			= 0, 
	@language			NVARCHAR(10)	= 'en-us',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinlostUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD 	MONEY			= 0 OUTPUT,
	@SumCommUSD 		MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinlostEUR 		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR 	MONEY			= 0 OUTPUT,
	@SumCommEUR 		MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR 	MONEY			= 0 OUTPUT,
	@SumWinlostGBP 		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP 	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP 	MONEY			= 0 OUTPUT,
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT
AS

/*
	Created: Henry
	Date: 2010-12-10 
	Task : Bet List for Daily Statement History 
	DB: DBACC.bodb02 
	Original: [Age_BetList_SelByDayAll_Mem_Old]

	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110712@Henry: Add column LicenseeWL
		- 20110725@Henry: Get refund tickets
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
		- 20110825@Henry: Add more bettype for euro site
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120724@Jim: add player commision value 
		- 20120817@Jim: add live casino 
		- 20120913@Jim: add virtual sport 
		- 20130123@Daniel: Change link server alias
		- 20130410@Jim: return betteam,modd value for Parlay ticket (Mix parlay & system parlay)
		- 20130411@Jim: support base currency USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130905@Jim: support VHR
		- 20140310@Hannah: offer Keno
		- 20140324@Daniel: fix show RNG Casino / Bingo bets due to matchid = 0
		- 20140411@Francis: fix incorrect sporttypes showing for VHR, Racing
		- 20140411@Francis: add bettype restriction for VHR
		- 20150130@Winnie: Add base currency GBP
		- 20150413@Bobby: Re-format code  & #32844 new 60 bettypes - betradar phase 2
		- 20150511@Kiwi: Fixed the bug (RedmineID: #35562)
		- 20150608@Edward: Support Microgaming
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150923@Kos: Support AG Casino
		- 20151029@Kos: Change ProductId, SportType of Microgaming RNG Casino
		- 20151124@Kos: Support Microgaming RNG Casino Jackpot Grand Prize ticket

	Param's Explanation: 
		+ @transtype:
			1: Won/Lose/Draw/Refund ticket
			4: Grand Prize ticket (Microgaming RNG Casino)
*/

BEGIN
	SET NOCOUNT ON;

	SELECT CurrencyID
		, LicenseeID
	INTO #Currency
	FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @userID 
		AND LicenseeID = @LicenseeID 
		AND SystemID = 1
		AND isActive = 1

	DECLARE @Username VARCHAR(30)

	SELECT	@Username = c.username 
	FROM bodb02.dbo.Custinfo c WITH (NOLOCK) 
		INNER JOIN #Currency cy ON c.currency = cy.CurrencyID
	WHERE c.custid = @CustID 
	
	IF ( @Username IS NULL )
	BEGIN 
		SELECT @ErrCode = 101
			, @ErrMsg	= 'Account was not found.'

		RETURN
	END
	
	------------------------------------
	DROP TABLE #Currency
	------------------------------------
	
	DECLARE @Data TABLE (
		sporttype 		INT, 
		leagueid 		INT, 
		homeid 			INT, 
		awayid 			INT, 
		bettype 		SMALLINT,	
		matchcode 		NVARCHAR(50),
		race 			NVARCHAR(50),
		matchid 		INT, 
		transid 		BIGINT, 
		transdate 		DATETIME, 
		winlostdate 	DATETIME,
		refno 			NVARCHAR(50), 
		betid 			BIGINT,
		oddsid 			INT,
		hdp1 			SMALLMONEY, 
		hdp2 			SMALLMONEY, 
		Modds 			SMALLMONEY,
		oddstype 		TINYINT,
		odds 			SMALLMONEY, 
		betteam 		NVARCHAR(50), 
		status 			NVARCHAR(50), 
		betstatus 		NVARCHAR(50), 
		Stake 			MONEY, 
		Actual_Stake	MONEY,
		winlost			MONEY,
		LicenseeWL		MONEY,
		comm 			MONEY,
		playercomm		MONEY,
		livehomescore	SMALLINT, 
		liveawayscore	SMALLINT, 
		liveindicator	BIT,
		finalhomescore 	SMALLINT, 
		finalawayscore 	SMALLINT, 
		hthomescore 	SMALLINT, 
		htawayscore 	SMALLINT, 
		ip 				NVARCHAR(20), 
		username 		NVARCHAR(50),
		isNeutral 		BIT	,
		currency 		SMALLINT,
		showtime 		NVARCHAR(50), -- table - shoe - hand of Live Casino
		betcheck		NVARCHAR(50),
		transdesc		NVARCHAR(300)
	)
	
	-- filer bettypes by sporttype
	DECLARE @SportBettype TABLE ( 
		ProductID	TINYINT
		,Bettype	SMALLINT
		,EventType	TINYINT
	)
	
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

	DELETE @SportBettype
	WHERE ProductID > 8 -- not suport for affiliate system
		AND ProductID NOT IN (11, 13, 17)

	IF @transtype = 4	-- support only for Microgaming RNG Casino
	BEGIN
		DELETE @SportBettype
		WHERE ProductID NOT IN (17)
	END
	-- end filer bettypes by sporttype
	
	IF @transtype = 1
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
			b.Odds,	
			b.betteam,
			b.status,
			m.betstatus, 
			b.stake,
			b.actual_stake, 
			(b.winlost-b.actual_stake) AS winlost, 
			CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
			CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
			b.playercomm,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			m.finalhomescore, 
			m.finalawayscore,
			m.hthomescore, 
			m.htawayscore,
			b.IP,
			@Username,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.currency
			,CASE WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
			,CASE WHEN sbt.ProductID = 1 AND b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck
			,'' AS transdesc
		FROM bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
			INNER JOIN bodb_archive.dbo.match_bk m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE b.custid			= @custid
			AND b.winlostdate 	= @fromdate
			AND sbt.EventType 	= 1
	
		UPDATE betList
		SET betList.Odds	= originBetList.Odds
			,betList.Stake	= originBetList.Stake
			,betList.comm	= CASE WHEN betList.Bettype = 902 THEN ISNULL(commBetList.comm,0) ELSE betList.comm END
			,betList.BetID	= originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN bodb_archive.dbo.bettrans_bk AS originBetList WITH (NOLOCK) ON betList.RefNO = originBetList.TransID
			LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
		WHERE betList.Sporttype = 1 AND betList.Bettype IN (901, 902)

		DELETE @Data WHERE Sporttype = 1 AND Bettype = 903

		-- Keno 
		INSERT INTO @Data 
		SELECT
			202 AS sporttype, 
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.bettype,
			'' AS matchcode,
			'' AS race,
			fnc.GameId AS matchid, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			b.oddsid, 
			b.hdp1, 
			b.hdp2,
			0 AS modds, 
			0 AS Oddstype,
			b.Odds,	
			fnc.ChoiceId AS betteam,
			b.status,
			'' AS betstatus, 
			b.stake,
			b.actual_stake, 
			(b.winlost-b.actual_stake) AS winlost, 
			- (b.winlost-b.actual_stake) AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			0 AS finalhomescore, 
			0 AS finalawayscore,
			0 AS hthomescore, 
			0 AS htawayscore,
			b.IP,
			@Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
			,'' AS transdesc
		FROM	bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
			CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype) AS fnc
		WHERE	b.custid		= @custid
			AND b.winlostdate	= @fromdate 
			AND sbt.ProductID	= 8
			AND sbt.EventType	= 0

		-- VHR
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
			b.Odds,	
			b.betteam,
			b.status,
			r.betstatus, 
			b.stake,
			b.actual_stake, 
			(b.winlost-b.actual_stake) AS winlost, 
			 - (b.winlost-b.actual_stake)  AS LicenseeWL ,
			b.comm,
			b.playercomm,
			b.livehomescore, 
			b.liveawayscore, 
			b.liveindicator, 
			0 AS finalhomescore, 
			0 AS finalawayscore,
			0 AS hthomescore, 
			0 AS htawayscore,
			b.IP,
			@Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			CONVERT(VARCHAR(20),r.eventTime) AS ShowTime 
			,'' AS betcheck
			,'' AS transdesc
		FROM	bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.VSOutright_bk o WITH (NOLOCK) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE	b.custid		= @custid
			AND b.winlostdate	= @fromdate
			AND sbt.ProductId	= 5 
			AND sbt.EventType	= 3

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
			b.playercomm,
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0,
			b.IP,
			@Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
			,'' AS transdesc
		FROM
			bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)	
			LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE b.custid			= @custid
			AND b.winlostdate	= @fromdate
			AND b.matchid		IN (0, 9, 29) -- Should not remove 0 for Archive
			AND sbt.ProductID	= 1
			AND sbt.EventType	= 0

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
			modds,
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
			b.playercomm,
			b.livehomescore, 
			b.liveawayscore, 
			0, 
			0, 
			0, 
			0, 
			0,
			b.IP,
			@Username,
			CONVERT(BIT,0) AS IsNeutral,
			b.currency,
			'' AS ShowTime 
			,'' AS betcheck
			,'' AS transdesc
		FROM 
			bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
			INNER JOIN bodb_archive.dbo.outright_bk m WITH (NOLOCK) on b.matchid = m.orid
			INNER JOIN dbo.league l WITH (NOLOCK) on m.leagueid = l.leagueid
			LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		WHERE b.custid			= @custid 
			AND b.winlostdate	= @fromdate
			AND sbt.ProductID	IN (1, 2) 
			AND sbt.EventType	= 2

		-- RNG Casino, Bingo, AG Casino, Microgaming Live Casino, Microgaming RNG Game
		INSERT INTO @Data 
		SELECT
			CASE
				WHEN sbt.ProductID = 6 THEN 251
				WHEN sbt.ProductID = 7 THEN 252
				WHEN sbt.ProductID = 11 THEN 250
				WHEN sbt.ProductID = 13 THEN 203
				WHEN sbt.ProductID = 17 THEN 205
			END AS SportType,
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.bettype,
			'' AS matchcode,
			'' AS race,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.bettype
				ELSE 0
			END AS MatchId, 
			b.transid, 
			b.transdate, 
			b.winlostdate,
			b.refno, 
			b.betid,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.oddsid
				ELSE 0
			END AS oddsid,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.hdp1
				ELSE 0
			END AS hdp1,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.hdp2
				ELSE 0
			END AS hdp2,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.modds
				ELSE 0
			END AS modds,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.Oddstype
				ELSE 0
			END AS Oddstype,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.Odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.betteam
				ELSE ''
			END AS betteam,
			b.status,
			'' AS betstatus, 
			b.stake,
			b.actual_stake, 
			(b.winlost - b.actual_stake) AS winlost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.livehomescore
				ELSE 0
			END AS livehomescore,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.liveawayscore
				ELSE 0
			END AS liveawayscore,
			CASE
				WHEN sbt.ProductID IN (6, 7) THEN b.liveindicator
				ELSE 0
			END AS liveindicator,
			0 AS finalhomescore, 
			0 AS finalawayscore,
			0 AS hthomescore, 
			0 AS htawayscore,
			b.IP,
			@Username,
			CONVERT(BIT, 0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			CASE
				WHEN sbt.ProductID = 13 THEN b.betcheck
				ELSE ''
			END AS BetCheck
			,'' AS transdesc
		FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
		WHERE b.custid		= @custid
			AND b.winlostdate	= @fromdate
			AND sbt.ProductID	IN (6, 7, 11, 13, 17)
			AND sbt.EventType	= 0
	END
	ELSE IF @transtype = 4
	BEGIN
		-- Microgaming RNG Casino Jackpot Win
		INSERT INTO @Data 
		SELECT
			205 AS SportType,
			0 AS leagueid,
			0 AS homeID,
			0 AS awayID,
			b.gameID AS BetType,
			'' AS matchcode,
			'' AS race,
			0 AS MatchId, 
			b.transid, 
			pt.transdate, 
			pt.winlostdate,
			b.refno, 
			0 AS betid,
			0 AS oddsid,
			0 AS hdp1,
			0 AS hdp2,
			0 AS modds,
			0 AS Oddstype,
			0 AS odds,
			'' AS betteam,
			b.status,
			'' AS betstatus, 
			b.stake,
			b.actual_stake, 
			pt.WinAmount AS WinLost,
			0 AS LicenseeWL,
			0 AS comm,
			0 AS playercomm,
			0 AS livehomescore,
			0 AS liveawayscore,
			0 AS liveindicator,
			0 AS finalhomescore, 
			0 AS finalawayscore,
			0 AS hthomescore, 
			0 AS htawayscore,
			b.IP,
			@Username,
			CONVERT(BIT, 0) AS IsNeutral,
			b.currency,
			'' AS ShowTime,
			b.TranId3rd AS BetCheck,
			b.transdesc
		FROM
			dbo.PayoutTrans AS pt WITH (NOLOCK)
			INNER JOIN bodb_archive.dbo.bettransRnG_bk AS b WITH (NOLOCK) ON pt.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.bettype
		WHERE pt.custid = @custid
			AND pt.winlostdate = @fromdate
			AND sbt.ProductID = 17
			AND b.statusID	IN (111, 112, 113)
	END

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@fromdate,@fromdate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

	SELECT 
		@TotalRows			= COUNT(transid),
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
		@SumPlayerCommEUR	= SUM(ISNULL(playercomm*e.EUR,0)) ,
		--GBP
		@SumWinlostGBP		= SUM(ISNULL(winlost*e.GBP,0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(LicenseeWL*e.GBP,0)),
		@SumCommGBP			= SUM(ISNULL(comm*e.GBP,0)) ,
		@SumPlayerCommGBP	= SUM(ISNULL(playercomm*e.GBP,0)) 
	FROM @Data b
		INNER JOIN #TempExchange e ON e.ExchangeDate = b.winlostdate 
			AND e.exchangeid = b.currency

	SELECT A.* 
	FROM
	(
		SELECT  
			ROW_NUMBER() over(ORDER BY transid, refno) AS RowNum,
			b.* ,
			--USD
			b.stake * e.USD stakeUSD,
			b.Actual_stake * e.USD Actual_stakeUSD,
			b.winlost * e.USD winlostUSD,
			b.LicenseeWL * e.USD LicenseeWLUSD,
			b.comm * e.USD commUSD,
			b.playercomm * e.USD playercommUSD,
			--EUR
			b.stake * e.EUR stakeEUR,
			b.Actual_stake * e.EUR Actual_stakeEUR,
			b.winlost * e.EUR winlostEUR,
			b.LicenseeWL * e.EUR LicenseeWLEUR,
			b.comm * e.EUR commEUR,
			b.playercomm * e.EUR playercommEUR,
			--GBP
			b.stake * e.GBP stakeGBP,
			b.Actual_stake * e.GBP Actual_stakeGBP,
			b.winlost * e.GBP winlostGBP,
			b.LicenseeWL * e.GBP LicenseeWLGBP,
			b.comm * e.GBP commGBP,
			b.playercomm * e.GBP playercommGBP
		FROM 
			@Data b
			INNER JOIN #TempExchange e
				ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
	) AS A 
	WHERE A.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	--get data from bettransm for bettype 33,43
	DECLARE @BettransDetail TABLE(
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
	)
	
	-- Live Casino
	INSERT INTO @BettransDetail 
	SELECT 
		BG.refno, 
		BG.odds, 
		BG.stake,
		BG.status, 
		BG.apositiontaking, 
		BG.bettype,
		BG.betteam ,
		BG.stake * e.EUR,
		BG.stake * e.USD,
		BG.stake * e.GBP
	FROM bodb_archive.dbo.bettransG BG WITH (NOLOCK)
		INNER JOIN @Data B ON BG.refno=b.refno AND BG.custID=@CustID 
		INNER JOIN #TempExchange e
			ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency	
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE sbt.ProductID = 4 AND sbt.EventType = 1
	
	-- Racing
	UNION ALL 
	SELECT 
		BM.refno, 
		BM.odds, 
		BM.stake,
		BM.status, 
		BM.apositiontaking, 
		BM.bettype,
		BM.betteam ,
		BM.stake * e.EUR,
		BM.stake * e.USD,
		BM.stake * e.GBP
	FROM bodb_archive.dbo.bettransm BM WITH (NOLOCK)
		INNER JOIN @Data B ON BM.refno = B.transid
		INNER JOIN #TempExchange e
			ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE sbt.ProductID = 2 AND sbt.EventType = 2
	
	-- Virtual Sports
	UNION ALL 
	SELECT 
		BM.refno,
		BM.odds,
		BM.Stake,
		BM.status,
		BM.apositiontaking,
		BM.bettype,
		BM.Betteam,
		BM.stake * e.EUR,
		BM.stake * e.USD,
		BM.stake * e.GBP
	FROM bodb_archive.dbo.bettransm BM with (NOLOCK)
		INNER JOIN @Data B ON BM.refno = B.refno
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate
			AND e.exchangeid = B.currency
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE sbt.ProductID = 5 AND sbt.EventType = 3

	SELECT * FROM @BettransDetail
	ORDER BY refno, bettype
	RETURN

	DROP TABLE #TempExchange
END


GO 

GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelByDayAll_Mem_Old] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelByDayAll_Mem_Old] TO [bodbLicenseeNet]
GO 