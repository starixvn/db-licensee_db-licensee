USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/*
exec Lrf_BetList_SelWinlossDaily_xtest
@date='2012-09-04 00:00:00:000',
@LicenseeID=1,
@MoveBetsDay='2012-09-03 00:00:00:000',
@BalanceUpDay='2012-09-01 00:00:00:000'
*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossDaily]
	@date SMALLDATETIME,
	@LicenseeID INT,
	@UserID		INT,
	@CurrencyID INT=0,
	@Product  VARCHAR(10)='ALL',
	@Status   VARCHAR(10)='won',
	@Langkey VARCHAR(10) = 'en-US',
	@MoveBetsDay SMALLDATETIME,
	@BalanceUpDay SMALLDATETIME,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT,
	@SumWinlost MONEY = 0 OUTPUT,
	@SumLicenseeWL MONEY = 0 OUTPUT,
	@SumComm MONEY = 0 OUTPUT,
	@SumPlayerComm MONEY=0 OUTPUT,
	@SumWinlostUSD MONEY = 0 OUTPUT,
	@SumLicenseeWLUSD MONEY = 0 OUTPUT,
	@SumCommUSD MONEY = 0 OUTPUT,
	@SumPlayerCommUSD MONEY=0 OUTPUT,
	@SumWinlostEUR MONEY = 0 OUTPUT,
	@SumLicenseeWLEUR MONEY = 0 OUTPUT,
	@SumCommEUR MONEY = 0 OUTPUT,
	@SumPlayerCommEUR MONEY=0 OUTPUT
AS

/*
Created: 20111904@Henry
Task : Betlist
DB: DB052.bodb02
Original:
Revisions:
	- 20110523@Henry: Support Number Game
	- 20110616@Henry: Suport filter BA tickets  
	- 20110712@Henry: Output Licensee WL + remove BA filter
	- 20110729@Henry: offer 3 new bettypes for Number Game
	- 20110927@Henry: return output params instead of secondary table
	- 20111208@Jim: change condition bettype <31 
	- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120723@Jim: add playercomm value 
	- 20120817@Jim: add live casino
	- 20120912@Jim: add virtual sport
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20121016@Henry: enhance SP
	- 20130305@Jim: change input param @winlostdate by @date
	- 20130320@Jim: fix bug wrong Total Rows's value 
	- 20130328@Scott: Support RNG Casino and Bingo
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20130619@Jim: fix bug missing RNG Casino data 
	- 20130716@Jim: update matchid for RNG Casino and Bingo
	- 20131007@Jim: Enhance the usability of Daily Bet List report and offer Virtual Horse Racing & Virtual Tennis
	- 20131108@Don: Improve performance temporarily

Param's Explanation: 
	
*/


SET NOCOUNT ON
--- to Deal With Parameter Sniffing

DECLARE 
		@wldate SMALLDATETIME,
		@MoveBetsDay_  SMALLDATETIME,
		@BalanceUpDay_ SMALLDATETIME
SELECT 
		@wldate = @date,
		@MoveBetsDay_ =@MoveBetsDay,
		@BalanceUpDay_=@BalanceUpDay
		
CREATE TABLE #Data
(
	RowNum INT,
	Sporttype INT,
	Username nvarchar(50),
	NickName NVARCHAR(50),
	Bettype INT,
	LeagueID INT,
	Transid BIGINT,
	Matchcode VARCHAR(50),
	Race NVARCHAR(20),
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	status nvarchar(50),
	stake MONEY,
	Winlost MONEY,
	LicenseeWL   MONEY,
	comm MONEY,
	PlayerComm MONEY,
	transdate DATETIME,
	Winlostdate DATETIME,
	betteam VARCHAR (50),
	liveindicator INT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	MatchID INT,
	--ip nvarchar(30),
	Betstatus nvarchar(50),
	IsNeutral BIT,
	oddstype INT,
	betid BIGINT,
	currency SMALLINT,
	RefNO			BIGINT,	
	CustID	INT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)



DECLARE @DataSum TABLE
(
	currency INT,
	totalrows INT,
	SumWinlost 	 MONEY,
	SumLicenseeWL MONEY,
	SumComm MONEY,
	SumPlayerComm MONEY
)
DECLARE @Vhr TABLE 
(
OriD INT
,Sporttype INT
,LeagueID INT
,matchcode VARCHAR (20)
,RacerID INT
,BetStatus VARCHAR (100)
,ShowTime DATETIME
,AwayID INT
,IsNeutral INT
)	

DECLARE @hr TABLE 
(
 OriD INT
 ,Sporttype INT
,LeagueID INT
,matchcode VARCHAR (20)
,Race NVARCHAR(20)
,RacerID INT
,BetStatus VARCHAR (100)
,ShowTime DATETIME
,AwayID INT
,IsNeutral INT
)	

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
DECLARE @TmpCondBettype AS TABLE (bettype INT primary key)


--Sports Book
IF ( @Product='SB' OR @Product='BA' )
BEGIN
INSERT INTO @TmpCondBettype
	SELECT typeid
	 FROM bettype   
	 WHERE typeid < 31 OR   
	   typeid BETWEEN 121 AND 999 OR   
	   typeid BETWEEN 1301 AND 1334;
END   
--Number Game
IF @Product='NG'
BEGIN 
	INSERT INTO @TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 81 AND 120;  
END
--Horse Racing
IF @Product='RB'
BEGIN 
	INSERT INTO @TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 31 AND 33;  
END
--Live Casino
IF @Product='LC'
BEGIN	
	INSERT INTO @TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 1101 AND 1199;
END
--Virtual Sports
IF @Product='VS'
BEGIN	
	INSERT INTO @TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 1201 AND 1299;
END
--RNG Casino
IF @Product='CS'
BEGIN	
	INSERT INTO @TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid =71;
END
--Bingo
IF @Product='BG'
BEGIN
	INSERT INTO @TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid = 73;
END
IF @Product='ALL'
BEGIN
	INSERT INTO @TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid IN (71,73)
		OR 	(typeid < 31 OR   
	   typeid BETWEEN 121 AND 999 OR   
	   typeid BETWEEN 1301 AND 1334
		)
		OR 
			(
			typeid BETWEEN 31 AND 33
			)
		OR 
			(
			typeid BETWEEN 81 AND 120
			)
		OR (
			typeid BETWEEN 1101 AND 1199
			
			)
		OR (
			typeid BETWEEN 1201 AND 1299
			)
END



INSERT INTO @TempAg (custid)
SELECT  CustID  
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
		INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1


IF @wldate > @MoveBetsDay_
BEGIN
	IF (@Product='VS' OR @Product='ALL')
	BEGIN 
		INSERT INTO @Vhr
		SELECT 
			o.OriD
			,r.Sporttype
			,r.LeagueID
			,CONVERT (VARCHAR(50),o.RacerNum) matchcode
			,o.RacerID  
			,r.BetStatus BetStatus
			,r.EventTime   ShowTime
			,NULL as AwayID
			,NULL as IsNeutral
	
		FROM VSOutright o with (nolock) 
		INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE  o.EventDate =@wldate
	END 	
	IF (@Product='RB' OR @Product='ALL')
	BEGIN 
		INSERT INTO @hr
		SELECT 
			m.OrId,
			l.sporttype,
			m.LeagueID,
			m.MatchCode,
			m.GroupMatch,	
			m.TeamID ,
			0 BetStatus,
			'' ShowTime,
			NULL as  AwayID,
			CONVERT(BIT,0) AS IsNeutral
		FROM dbo.Outright AS m WITH (NOLOCK) 
			 INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE m.eventdate=@wldate	 
	END 
	
	INSERT INTO @DataSum
	SELECT 
		currency,
		COUNT(b.transid),
		SUM(ISNULL(b.winlost-b.actual_stake,0)),
		SUM(ISNULL(CASE WHEN ISNULL(BA.transid,0)=0 THEN - (b.winlost-b.actual_stake) ELSE 0 END,0)),
		SUM(ISNULL(b.comm,0)),
		SUM(b.playercomm )  AS  SumPlayerComm
	FROM bettrans b WITH (nolock) 
		/*LEFT JOIN match m WITH (nolock) ON b.matchid=m.matchid	
		LEFT JOIN @vhr  vs  ON b.oddsid=vs.Orid
		LEFT JOIN @hr	r   ON b.oddsid=r.Orid*/
		INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate = @wldate
		--AND b.matchid > 0
		AND b.bettype NOT IN (9,29,10)
		AND b.recommend IN (SELECT custid FROM @TempAg)	
		AND b.status=@status
		AND b.ruben = 1
	GROUP BY currency
	
	
	INSERT INTO #Data
	SELECT A.* 
	FROM	
	(	
		SELECT
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.sporttype 
				 WHEN b.bettype IN (31,32,33) THEN r.sporttype		
						ELSE m.sporttype END sporttype,
			b.username,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.bettype,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.leagueID 
				WHEN b.bettype IN (31,32,33) THEN r.leagueID		
				ELSE m.leagueID END leagueID,			
			b.transid,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.matchcode 
				 WHEN b.bettype IN (31,32,33) THEN r.matchcode
				 ELSE m.matchcode END matchcode,
			CASE WHEN b.bettype IN (31,32,33) THEN r.Race 
				 ELSE '' END Race,	
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.RacerID 
				 WHEN b.bettype IN (31,32,33) THEN r.RacerID
				 ELSE m.homeID END homeID,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.awayID 
				 WHEN b.bettype IN (31,32,33) THEN r.awayID
				 ELSE m.awayID END awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			CASE WHEN BA.transid IS NULL 
				THEN CASE  WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake) 
							ELSE awinlost END 
				ELSE 0					
				END 
				AS LicenseeWL ,
			b.comm as comm,
			b.playercomm as PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			--b.IP AS IP,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.betstatus 
				 WHEN b.bettype IN (31,32,33) THEN r.betstatus
				 ELSE m.betstatus END betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			b.custid,
			CASE WHEN (b.bettype BETWEEN 1101 AND 1199 AND b.bettype IN (1231, 1232, 1233, 1237, 1238)) THEN  ISNULL(m.showtime,'') ELSE '' END AS ShowTime
		FROM
			bettrans b WITH (nolock) 
			LEFT JOIN match m WITH (nolock) ON b.matchid=m.matchid
			LEFT JOIN @vhr  v ON b.oddsid=v.OrID
			LEFT JOIN @hr  r ON b.oddsid=r.OrID
			INNER JOIN customer c WITH (nolock) ON b.custid = c.custid
			INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate = @wldate
			AND ((b.tpositiontaking=0 AND @Product='BA') OR @Product<>'BA')
			--AND b.matchid > 0
			AND b.status=@status
			AND b.bettype NOT IN (9,29,10)
			AND b.recommend IN (SELECT custid FROM @TempAg)	
			AND b.ruben = 1
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
	
END

IF @wldate <= @MoveBetsDay_ AND @wldate >=@BalanceUpDay_
BEGIN
	IF (@Product='VS' OR @Product='ALL')
	BEGIN 
		INSERT INTO @Vhr
			SELECT 
				o.OriD
				,r.Sporttype
				,r.LeagueID
				,CONVERT (VARCHAR(50),o.RacerNum) matchcode
				,o.RacerID  
				,r.BetStatus BetStatus
				,r.EventTime   ShowTime
				,NULL as AwayID
				,NULL as IsNeutral
			FROM VSOutright14 o with (nolock) 
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE  o.EventDate =@wldate
	END 	
	IF (@Product='RB' OR @Product='ALL')
	BEGIN 
		INSERT INTO @hr
		SELECT 
			m.OrId,
			l.sporttype,
			m.LeagueID,
			m.MatchCode,
			m.GroupMatch,		
			m.TeamID ,
			0 BetStatus,
			'' ShowTime,
			NULL as  AwayID,
			CONVERT(BIT,0) AS IsNeutral
		FROM dbo.Outright14 AS m WITH (NOLOCK) 
			 INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE m.eventdate=@wldate	 
	END 
	
	INSERT INTO @DataSum
	SELECT 
		b.currency,
		COUNT(b.transid),
		SUM(ISNULL(b.winlost - b.actual_stake,0)),
		-SUM(ISNULL(CASE WHEN BA.transid IS NULL THEN  (b.winlost-b.actual_stake) ELSE 0 END,0)),
		SUM(ISNULL(b.comm ,0)),
		SUM(b.playercomm )  AS  SumPlayerComm
	FROM bettrans14 b WITH (NOLOCK)	
		/*LEFT JOIN match14 m WITH (nolock) ON b.matchid=m.matchid 
		LEFT JOIN @vhr vs  ON b.oddsid=vs.Orid
		LEFT JOIN @hr r   ON b.oddsid=r.Orid*/
		INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate = @wldate
		AND b.bettype NOT IN (9,29,10)
		AND b.status=@status
		AND b.recommend IN (SELECT custid FROM @TempAg)
	GROUP BY b.currency	
		
	INSERT INTO #Data
	SELECT A.* 
	FROM	
	(
		SELECT
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.sporttype 
				 WHEN b.bettype IN (31,32,33) THEN r.sporttype		
						ELSE m.sporttype END sporttype,
			b.username,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.bettype,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.leagueID 
				WHEN b.bettype IN (31,32,33) THEN r.leagueID		
				ELSE m.leagueID END leagueID,			
			b.transid,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.matchcode 
				 WHEN b.bettype IN (31,32,33) THEN r.matchcode
				 ELSE m.matchcode END matchcode,
			CASE WHEN b.bettype IN (31,32,33) THEN r.Race 
				 ELSE '' END Race,	 
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.RacerID 
				 WHEN b.bettype IN (31,32,33) THEN r.RacerID
				 ELSE m.homeID END homeID,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.awayID 
				 WHEN b.bettype IN (31,32,33) THEN r.awayID
				 ELSE m.awayID END awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake) winlost,
			CASE WHEN BA.transid IS NULL 
				THEN CASE  WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake) 
							ELSE awinlost END 
				ELSE 0					
				END 
				AS LicenseeWL ,
			b.comm as comm,
			b.playercomm as PlayerComm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid, 
			--b.IP AS IP,
			CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN v.betstatus 
				 WHEN b.bettype IN (31,32,33) THEN r.betstatus
				 ELSE m.betstatus END betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.OddsType,
			b.betid,
			b.currency,
			b.refno,
			b.custid,
			CASE WHEN (b.bettype BETWEEN 1101 AND 1199 AND b.bettype IN (1231, 1232, 1233, 1237, 1238)) THEN  ISNULL(m.showtime,'') ELSE '' END AS ShowTime
		FROM
			bettrans14 b WITH (NOLOCK)	
			LEFT JOIN match14 m WITH (nolock) ON b.matchid=m.matchid 
			LEFT JOIN @vhr  v ON b.oddsid=v.OrID		
			LEFT JOIN @hr   r ON b.oddsid=r.OrID
			INNER JOIN customer c WITH (nolock) ON b.custid = c.custid 	
			INNER JOIN @TmpCondBettype bt ON b.bettype = bt.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate = @wldate
			AND ((b.tpositiontaking=0 AND @Product='BA') OR @Product<>'BA')
			AND b.bettype NOT IN (9,29,10)
			AND b.recommend IN (SELECT custid FROM @TempAg)
			AND b.status=@status
			
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd	

END

CREATE NONCLUSTERED INDEX IDX_Currency ON #Data(Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@wldate,@wldate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

SELECT  
		b.* ,
		--USD
		stake*e.USD stakeUSD,
		Winlost*e.USD WinlostUSD,
		LicenseeWL*e.USD LicenseeWLUSD,
		comm*e.USD commUSD,
		playercomm*e.USD as PlayerCommUSD,
		--EUR
		stake*e.EUR stakeEUR,
		Winlost*e.EUR WinlostEUR,
		LicenseeWL*e.EUR LicenseeWLEUR,
		comm*e.EUR commEUR,
		playercomm*e.EUR as PlayerCommEUR
FROM #Data b
	INNER JOIN #TempExchange e 
ON  e.exchangeid = b.currency



--SUM
SELECT * INTO #TempExchangeSum 
FROM Lrf_f_GetExchangeDaily(@wldate,@wldate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM @DataSum)

SELECT 
	@TotalRows = SUM(TotalRows),
	@SumWinlost = SUM(SumWinlost),
	@SumLicenseeWL = SUM(SumLicenseeWL),
	@SumComm = SUM(SumComm),
	@SumPlayerComm=SUM(ISNULL(SumPlayerComm,0)),
	--USD
	@SumWinlostUSD = SUM(SumWinlost*e.USD),
	@SumLicenseeWLUSD = SUM(SumLicenseeWL*e.USD),
	@SumCommUSD = SUM(SumComm * e.USD),
	@SumPlayerCommUSD=SUM(ISNULL(SumPlayerComm,0)*e.USD),
	--EUR
	@SumWinlostEUR = SUM(SumWinlost*e.EUR),
	@SumLicenseeWLEUR = SUM(SumLicenseeWL*e.EUR),
	@SumCommEUR = SUM(SumComm * e.EUR),
	@SumPlayerCommEUR=SUM(ISNULL(SumPlayerComm,0)*e.EUR)
FROM @DataSum b 
INNER JOIN #TempExchangeSum e 
ON b.currency = e.exchangeid


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
	 
	 
IF EXISTS(SELECT TOP 1 1 FROM #Data WHERE Bettype BETWEEN 1101 AND 1199)
BEGIN
	IF @wldate > @MoveBetsDay_ 
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
			BG.stake * e.EUR AS stakeEUR,
			BG.stake * e.USD AS stakeUSD
		FROM bettransg BG WITH (NOLOCK)
		INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.CustID
		INNER JOIN #TempExchange e ON B.currency = e.exchangeid
		WHERE B.Bettype BETWEEN 1101 AND 1199
	END
		
	IF @wldate <= @MoveBetsDay_
	BEGIN
		INSERT INTO @BettransDetail
		SELECT 
			BG.refno, 
			BG.odds, 
			BG.stake,         
			BG.status, 
			BG.apositiontaking, 
			BG.bettype  ,
			BG.Betteam  ,
			BG.stake * e.EUR AS stakeEUR,
			BG.stake * e.USD AS stakeUSD
		FROM bettransg14 BG WITH (NOLOCK)
		INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.CustID
		INNER JOIN #TempExchange e ON B.currency = e.exchangeid
		WHERE B.Bettype BETWEEN 1101 AND 1199
	END	
END	 


IF EXISTS(SELECT TOP 1 1 FROM #Data WHERE Bettype IN (33,43,1233))
BEGIN 	
		IF @wldate > @MoveBetsDay_ 
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
			INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype IN (33,43,1233)
		END
		IF @wldate <= @MoveBetsDay_
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
			FROM bettransm14 BG WITH (NOLOCK)
			INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = B.custid
			INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
			WHERE B.Bettype IN (33,43,1233)
		END
END

SELECT * FROM @BettransDetail ORDER BY RefNo,Bettype

DROP TABLE #Currency
DROP TABLE #TempExchange
DROP TABLE #TempExchangeSum
DROP TABLE #Data
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossDaily] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossDaily] TO [vnteam] AS [dbo]