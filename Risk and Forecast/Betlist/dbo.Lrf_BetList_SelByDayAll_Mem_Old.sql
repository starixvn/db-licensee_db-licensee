USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelByDayAll_Mem_Old]    Script Date: 07/21/2015 04:39:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_BetList_SelByDayAll_Mem_Old    Script Date: 5/6/2015 3:17:05 AM ******/
/****** Object:  Stored Procedure dbo.Lrf_BetList_SelByDayAll_Mem_Old    Script Date: 4/24/2015 3:55:41 PM ******/
ALTER PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem_Old]
	@LicenseeID 		INT ,
	@UserID				INT,
	@custid				INT,
	@fromdate			SMALLDATETIME,
	@language			NVARCHAR(10) = 'en-us',
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
	@SumPlayerCommUSD	MONEY=0 OUTPUT,
	@SumWinlostEUR 		MONEY=0 OUTPUT,
	@SumLicenseeWLEUR 	MONEY=0 OUTPUT,
	@SumCommEUR 		MONEY=0 OUTPUT,
	@SumPlayerCommEUR 	MONEY=0 OUTPUT,
	@SumWinlostGBP 		MONEY=0 OUTPUT,
	@SumLicenseeWLGBP 	MONEY=0 OUTPUT,
	@SumCommGBP			MONEY=0 OUTPUT,
	@SumPlayerCommGBP 	MONEY=0 OUTPUT,
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: Henry
Date: 2010-12-10 
Task : Bet List for Daily Statement History 
DB: DBRPT/bodb02 
Original: [Age_BetList_SelByDayAll_Mem_Old]

Revisions:
	-- 20110214@Jacob: Add column discount IN the result SET
	-- 20110303@Henry: suppport based currency
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

Param's Explanation: 

*/
BEGIN
	SET NOCOUNT ON;

	SELECT CurrencyID
		  ,LicenseeID
	INTO #Currency
	FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE  usrID=@userID 
		AND LicenseeID=@LicenseeID 
		AND SystemID=1
		AND isActive=1

	DECLARE @Username VARCHAR(30) 
	SELECT	@Username = c.username 
	FROM bodb02.dbo.Custinfo c WITH (NOLOCK) 
		INNER JOIN #Currency cy ON c.currency=cy.CurrencyID
	WHERE c.custid = @CustID 
	
	--select @Username, * from #Currency

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
		winlost 		MONEY,
		LicenseeWL 		MONEY,
		comm 			MONEY,
		playercomm 		MONEY,
		livehomescore 	SMALLINT, 
		liveawayscore 	SMALLINT, 
		liveindicator 	BIT,
		finalhomescore 	SMALLINT, 
		finalawayscore 	SMALLINT, 
		hthomescore 	SMALLINT, 
		htawayscore 	SMALLINT, 
		ip 				NVARCHAR(20), 
		username 		NVARCHAR(50),
		isNeutral 		BIT	,
		currency 		SMALLINT,
		showtime 		NVARCHAR(50) -- table - shoe - hand of Live Casino
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
				EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4
		
	DELETE sbt
	FROM @SportBettype sbt
	WHERE ProductID > 8 -- not suport for affiliate system
	-- end filer bettypes by sporttype
	
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
		--CASE WHEN b.bettype = 87 THEN b.betid ELSE 0 END, --- 87- High Low for NG: Current Live Ball 
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		modds, 
		b.Oddstype,
		b.Odds,	
		b.betteam,
		b.status AS status,
		m.betstatus, 
		b.stake,
		b.actual_stake, 
		(b.winlost-b.actual_stake) AS winlost, 
		CASE WHEN BA.transid IS NULL THEN - (b.winlost-b.actual_stake) ELSE 0 END AS LicenseeWL ,
		b.comm,
		b.playercomm,
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		m.finalhomescore, 
		m.finalawayscore,
		m.hthomescore, 
		m.htawayscore,
		b.IP AS IP,
		@Username,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.currency
		,CASE WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
		,CASE WHEN sbt.ProductID = 1 AND b.bettype IN (216,217) THEN b.betcheck ELSE '' END AS betcheck
	FROM	bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
			INNER JOIN bodb_archive.dbo.match_bk m WITH (NOLOCK) ON b.matchid = m.matchid		
			LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE	b.custid			= @custid 		
			AND b.winlostdate 	= @fromdate 
			--AND b.bettype NOT BETWEEN 1501 AND 1599 --exclude Keno
			--AND b.bettype NOT IN (10,31,32,33,1231,1232,1233,1237,1238) --exclude Racing and VHS
			--AND sbt.ProductID 	NOT IN (2, 5, 6, 7, 8)
			AND sbt.EventType 	= 1


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
		--CASE WHEN b.bettype = 87 THEN b.betid ELSE 0 END, --- 87- High Low for NG: Current Live Ball 
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		modds, 
		b.Oddstype,
		b.Odds,	
		b.betteam,
		b.status AS status,
		'' betstatus, 
		b.stake,
		b.actual_stake, 
		(b.winlost-b.actual_stake) AS winlost, 
		- (b.winlost-b.actual_stake) AS LicenseeWL ,
		b.comm,
		b.playercomm,
		b.livehomescore, 
		b.liveawayscore, 
		b.liveindicator, 
		0 finalhomescore, 
		0 finalawayscore,
		0 hthomescore, 
		0 htawayscore,
		b.IP AS IP,
		@Username,
		0 AS IsNeutral,
		b.currency,
		'' ShowTime 
		,'' AS betcheck
	FROM	bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE	b.custid			= @custid 
			AND b.winlostdate	= @fromdate 		
			--AND bettype IN(71,73)
			AND sbt.ProductID	IN (6, 7)
			AND sbt.EventType	= 0

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
		--CASE WHEN b.bettype = 87 THEN b.betid ELSE 0 END, --- 87- High Low for NG: Current Live Ball 
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		0 AS modds, 
		0 AS Oddstype,
		b.Odds,	
		fnc.ChoiceId AS betteam,
		b.status AS status,
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
		b.IP AS IP,
		@Username,
		CONVERT(BIT,0) AS IsNeutral,
		b.currency,
		'' AS ShowTime 
		,'' AS betcheck
	FROM	bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
		CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype) AS fnc
	WHERE	b.custid			= @custid 		
			AND b.winlostdate	= @fromdate 
			--AND b.bettype BETWEEN 1501 AND 1599 
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
		--CASE WHEN b.bettype = 87 THEN b.betid ELSE 0 END, --- 87- High Low for NG: Current Live Ball 
		b.betid,
		b.oddsid, 
		b.hdp1, 
		b.hdp2,
		modds, 
		b.Oddstype,
		b.Odds,	
		b.betteam,
		b.status AS status,
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
		0 as finalhomescore, 
		0 as finalawayscore,
		0 as hthomescore, 
		0 as htawayscore,
		b.IP AS IP,
		@Username,
		CONVERT(BIT,0) AS IsNeutral,
		b.currency,
		CONVERT(VARCHAR(20),r.eventTime)  AS ShowTime 
		,'' AS betcheck
	FROM	bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
			INNER JOIN bodb_Archive.dbo.VSOutright_bk o WITH (nolock) ON b.oddsid=o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE	b.custid			= @custid
			AND b.winlostdate	= @fromdate 			
			AND sbt.ProductId	= 5 
			AND sbt.EventType	= 3
			--AND b.bettype IN (1231, 1232, 1233, 1237, 1238)

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
		b.playercomm,
		0, 
		0, 
		0, 
		0, 
		0, 
		0, 
		0,
		b.IP AS IP,
		@Username,
		CONVERT(BIT,0) AS IsNeutral,
		b.currency,
		'' AS ShowTime 
		,'' AS betcheck
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
		--b.username creator,
		b.IP AS IP,
		@Username,
		CONVERT(BIT,0) AS IsNeutral,
		b.currency,
		'' AS ShowTime 
		,'' AS betcheck
	from 
		bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)
		inner join bodb_archive.dbo.outright_bk m WITH (NOLOCK) on b.matchid = m.orid	
		inner join dbo.league l WITH (NOLOCK) on m.leagueid = l.leagueid
		LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype

	WHERE b.custid			= @custid 
		AND b.winlostdate	= @fromdate
		--AND b.bettype IN (10,31,32,33)
		AND (sbt.ProductID	IN (1, 2) AND sbt.EventType	= 2)

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@fromdate,@fromdate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

	SELECT 
		@TotalRows				= COUNT(transid),
		@SumWinlost				= SUM(ISNULL(winlost,0)),
		@SumLicenseeWL			= SUM(ISNULL(LicenseeWL,0)),
		@SumComm				= SUM(ISNULL(comm,0)) ,
		@SumPlayerComm			= SUM(ISNULL(playercomm,0)) ,
		--USD
		@SumWinlostUSD			= SUM(ISNULL(winlost*e.USD,0)),
		@SumLicenseeWLUSD		= SUM(ISNULL(LicenseeWL*e.USD,0)),
		@SumCommUSD				= SUM(ISNULL(comm*e.USD,0)) ,
		@SumPlayerCommUSD		= SUM(ISNULL(playercomm*e.USD,0)) ,
		--EUR
		@SumWinlostEUR			= SUM(ISNULL(winlost*e.EUR,0)),
		@SumLicenseeWLEUR		= SUM(ISNULL(LicenseeWL*e.EUR,0)),
		@SumCommEUR				= SUM(ISNULL(comm*e.EUR,0)) ,
		@SumPlayerCommEUR		= SUM(ISNULL(playercomm*e.EUR,0)) ,
		--GBP
		@SumWinlostGBP			= SUM(ISNULL(winlost*e.GBP,0)),
		@SumLicenseeWLGBP		= SUM(ISNULL(LicenseeWL*e.GBP,0)),
		@SumCommGBP				= SUM(ISNULL(comm*e.GBP,0)) ,
		@SumPlayerCommGBP		= SUM(ISNULL(playercomm*e.GBP,0)) 
		
	FROM @Data b
	INNER JOIN #TempExchange e
		ON e.ExchangeDate = b.winlostdate 
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
				b.LicenseeWL   * e.EUR LicenseeWLEUR,
				b.comm * e.EUR commEUR,
				b.playercomm * e.EUR playercommEUR,
				--GBP
				b.stake * e.GBP stakeGBP,
				b.Actual_stake * e.GBP Actual_stakeGBP,
				b.winlost * e.GBP winlostGBP,
				b.LicenseeWL   * e.GBP LicenseeWLGBP,
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
		BG.stake*e.EUR,	
		BG.stake*e.USD,
		BG.stake*e.GBP
	FROM 	bodb_archive.dbo.bettransG BG WITH (NOLOCK)
			INNER JOIN @Data B ON BG.refno=b.refno AND BG.custID=@CustID 
			INNER JOIN #TempExchange e
			ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency	
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE --B.Bettype BETWEEN 1101 AND 1199
		sbt.ProductID 		= 4
		AND sbt.EventType 	= 1
	
	--Racing
	UNION ALL 
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
	FROM	bodb_archive.dbo.bettransm BM WITH (NOLOCK)
			INNER JOIN @Data B ON BM.refno = B.transid
			INNER JOIN #TempExchange e
			ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE	--B.Bettype IN (33,43)
		sbt.ProductID 		= 2
		AND sbt.EventType 	= 2
	
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
		BM.stake*e.EUR,	
		BM.stake*e.USD,
		BM.stake*e.GBP	
	FROM bodb_archive.dbo.bettransm BM with (NOLOCK)
		INNER JOIN @Data B ON BM.refno = B.refno
		INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   
			AND e.exchangeid = B.currency
		INNER JOIN @SportBettype sbt ON b.bettype = sbt.bettype
	WHERE --B.Bettype = 1233
		sbt.ProductID 		= 5
		AND sbt.EventType 	= 3
								 		
			
	SELECT * FROM @BettransDetail		
	ORDER BY refno, bettype
	RETURN

END

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelByDayAll_Mem_Old] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelByDayAll_Mem_Old] TO [vnteam] AS [dbo]