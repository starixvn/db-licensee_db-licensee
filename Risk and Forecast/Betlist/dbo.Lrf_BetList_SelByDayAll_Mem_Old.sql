USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelByDayAll_Mem_Old]    Script Date: 03/25/2014 00:47:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_BetList_SelByDayAll_Mem_Old    Script Date: 10/3/2013 2:52:14 PM ******/
ALTER PROCEDURE [dbo].[Lrf_BetList_SelByDayAll_Mem_Old]
	@LicenseeID INT ,
	@UserID		INT,
	@custid		INT,
	@fromdate	smalldatetime,
	@language	nvarchar(10) = 'en-us',
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY=0 OUTPUT,
	@SumLicenseeWL MONEY=0 OUTPUT,
	@SumComm MONEY=0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY=0 OUTPUT,
	@SumLicenseeWLUSD MONEY=0 OUTPUT,
	@SumCommUSD MONEY=0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY=0 OUTPUT,
	@SumLicenseeWLEUR MONEY=0 OUTPUT,
	@SumCommEUR MONEY=0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT
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
	- 20140324@Daniel: fix show RNG Casino / Bingo bets due to matchid = 0
Param's Explanation: 

*/

SET NOCOUNT ON

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
FROM Custinfo c WITH (NOLOCK) 
	INNER JOIN #Currency cy ON c.currency=cy.CurrencyID
WHERE c.custid = @CustID 
------------------------------------
DROP TABLE #Currency
------------------------------------
DECLARE @Data TABLE (
	sporttype INT, 
	leagueid INT, 
	homeid INT, 
	awayid INT, 
	bettype SMALLINT,	
	matchcode nvarchar(50),
	race nvarchar(50),
	matchid INT, 
	transid bigint, 
	transdate DATETIME, 
	winlostdate DATETIME,
	refno nvarchar(50), 
	betid bigint,
	oddsid INT, 	
	hdp1 SMALLMONEY, 
	hdp2 SMALLMONEY, 
	Modds SMALLMONEY,
	oddstype tinyint,
	odds SMALLMONEY, 
	betteam nvarchar(50), 
	status nvarchar(50), 
	betstatus nvarchar(50), 
	Stake MONEY, 
	Actual_Stake	MONEY,
	winlost MONEY,
	LicenseeWL 		MONEY,
	comm MONEY,
	playercomm MONEY,
	livehomescore SMALLINT, 
	liveawayscore SMALLINT, 
	liveindicator BIT,
	finalhomescore SMALLINT, 
	finalawayscore SMALLINT, 
	hthomescore SMALLINT, 
	htawayscore SMALLINT, 
	ip nvarchar(20), 
	username nvarchar(50),
	isNeutral BIT	,
	currency SMALLINT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)

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
	b.currency,
	CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime 
FROM	bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK)
		INNER JOIN bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON b.matchid = m.matchid		
		LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
WHERE	b.custid=@custid 		
		AND b.winlostdate = @fromdate 

--RNG Casino & Bingo		
INSERT INTO @Data 
SELECT
	case bettype when 71 then 251 else 252 end sporttype, 
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
FROM	bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK)
WHERE	b.custid=@custid 
		AND bettype IN(71,73)
		AND b.winlostdate = @fromdate 		
		
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
FROM	bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK)
		INNER JOIN DBARC.bodb_Archive.dbo.VSOutright_bk o WITH (nolock) ON b.oddsid=o.Orid
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID	
WHERE	b.custid=@custid 		
		AND b.winlostdate = @fromdate 			

-- mix parlay
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
	b.transid, 
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
FROM
	bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK)	
	LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
WHERE
	b.custid=@custid
	AND b.winlostdate=@fromdate
	--AND b.matchid=0 
	AND b.matchid IN (0,9) -- Should not remove 0 for Archive
	AND b.bettype=9

--Combination Mixed Parlay
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
	CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
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
FROM
	bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK)	
	LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
WHERE
	b.custid=@custid
	AND b.winlostdate=@fromdate
	AND b.bettype=29
	AND b.matchid = 29



-- outright
INSERT INTO @Data 
SELECT
	l.sporttype,
	m.leagueID,
	m.teamID AS homeid,
	0 AS awayid,
	bettype, 
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
from 
	bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK)
	inner join bodb_Archive.dbo.outright_bk m WITH (NOLOCK) on b.matchid = m.orid	
	inner join dbo.league l WITH (NOLOCK) on m.leagueid = l.leagueid
	LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid	
WHERE
	b.custid=@custid AND b.bettype IN (10,31,32,33)
	AND b.winlostdate = @fromdate

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@fromdate,@fromdate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM @Data)

SELECT 
	@TotalRows = COUNT(transid),
	@SumWinlost=SUM(ISNULL(winlost,0)),
	@SumLicenseeWL=SUM(ISNULL(LicenseeWL,0)),
	@SumComm=SUM(ISNULL(comm,0)) ,
	@SumPlayerComm=SUM(ISNULL(playercomm,0)) ,
	--USD
	@SumWinlostUSD=SUM(ISNULL(winlost*e.USD,0)),
	@SumLicenseeWLUSD=SUM(ISNULL(LicenseeWL*e.USD,0)),
	@SumCommUSD=SUM(ISNULL(comm*e.USD,0)) ,
	@SumPlayerCommUSD=SUM(ISNULL(playercomm*e.USD,0)) ,
	--EUR
	@SumWinlostEUR=SUM(ISNULL(winlost*e.EUR,0)),
	@SumLicenseeWLEUR=SUM(ISNULL(LicenseeWL*e.EUR,0)),
	@SumCommEUR=SUM(ISNULL(comm*e.EUR,0)) ,
	@SumPlayerCommEUR=SUM(ISNULL(playercomm*e.EUR,0)) 
	
FROM @Data b
INNER JOIN #TempExchange e
ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency



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
			b.playercomm * e.EUR playercommEUR
	FROM 
		@Data b
		INNER JOIN #TempExchange e
		ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd



--get data from bettransm for bettype 33,43
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
	 
IF EXISTS (SELECT TOP 1 1 FROM @Data WHERE Bettype BETWEEN 1101 AND 1199)
BEGIN 
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
		BG.stake*e.USD
	FROM 	bodb_archive.dbo.bettransG BG WITH (NOLOCK)
			INNER JOIN @Data B ON BG.refno=b.refno AND BG.custID=@CustID 
			INNER JOIN #TempExchange e
			ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency	
	WHERE B.Bettype BETWEEN 1101 AND 1199
END	 

IF EXISTS (SELECT TOP 1 1 FROM @Data WHERE Bettype IN (33,43))
BEGIN 
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
	FROM	bodb_Archive.dbo.bettransm BM WITH (NOLOCK)
			INNER JOIN @Data B ON BM.refno = B.transid
			INNER JOIN #TempExchange e
			ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
	WHERE	B.Bettype IN (33,43)
	
END
IF EXISTS (SELECT TOP 1 1 FROM @Data WHERE Bettype =1233)
BEGIN
	 --get data from bettransm14 for bettype 1233
	INSERT INTO @BettransDetail 
	SELECT 
		BM.refno,
		BM.odds,		
		BM.Stake,
		BM.status,
		BM.apositiontaking,
		BM.bettype,
		BM.Betteam,
		BM.stake*e.EUR,	
		BM.stake*e.USD		
	FROM bodb_Archive.dbo.bettransm BM with (NOLOCK)
	INNER JOIN @Data B ON BM.refno = B.refno
	INNER JOIN #TempExchange e ON  e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
	WHERE B.Bettype = 1233
END			
		
SELECT * FROM @BettransDetail		
ORDER BY refno, bettype
