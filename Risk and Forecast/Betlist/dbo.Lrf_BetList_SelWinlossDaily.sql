USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinlossDaily]    Script Date: 11/30/2013 00:24:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Lrf_BetList_SelWinlossDaily    Script Date: 11/18/2013 10:59:36 PM ******/
/****** Object:  Stored Procedure dbo.Lrf_BetList_SelWinlossDaily    Script Date: 11/15/2013 12:33:11 PM ******/
/*
exec Lrf_BetList_SelWinlossDaily
@date='2012-09-04 00:00:00:000',
@LicenseeID=1,
@MoveBetsDay='2012-09-03 00:00:00:000',
@BalanceUpDay='2012-09-01 00:00:00:000'
*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossDaily_14877]
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
	@SumPlayerCommEUR MONEY=0 OUTPUT,
	@Sort VARCHAR(20) = 'Transid DESC'
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
	- 20131112@Victor: Enhance performance
	- 20131115@Jim: correct showtime value in Live Casino and Horse Racing Product
	- 20140403@Hannah: offer Keno
	- 20140421@Hannah: fix bug, add sporttype for Keno
	- 20140428@Hannah: Sort betlist

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
	betteam VARCHAR (300),
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
	showtime NVARCHAR(50), -- table - shoe - hand of Live Casino
	stakeUSD MONEY,
	WinlostUSD MONEY,
	LicenseeWLUSD MONEY,
	commUSD MONEY,
	PlayerCommUSD MONEY,
	stakeEUR MONEY,
	WinlostEUR MONEY,
	LicenseeWLEUR MONEY,
	commEUR MONEY,
	PlayerCommEUR MONEY
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

CREATE TABLE #TempAg (custid INT)
CREATE TABLE #TmpCondBettype(bettype INT primary key)

--Sports Book
IF ( @Product='SB' OR @Product='BA' )
BEGIN
INSERT INTO #TmpCondBettype
	SELECT typeid
	 FROM bettype   
	 WHERE typeid < 31 OR   
	   typeid BETWEEN 121 AND 999 OR   
	   typeid BETWEEN 1301 AND 1334;
END   
--Number Game
IF @Product='NG'
BEGIN 
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 81 AND 120;  
END
--Horse Racing
IF @Product='RB'
BEGIN 
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 31 AND 33;  
END
--Live Casino
IF @Product='LC'
BEGIN	
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 1101 AND 1199;
END
--Virtual Sports
IF @Product='VS'
BEGIN	
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 1201 AND 1299;
END
--RNG Casino
IF @Product='CS'
BEGIN	
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid =71;
END
--Bingo
IF @Product='BG'
BEGIN
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid = 73;
END
--Keno
IF @Product='KN'
BEGIN	
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid BETWEEN 1501 AND 1599;
END
IF @Product='ALL'
BEGIN
	INSERT INTO #TmpCondBettype
	SELECT typeid
	FROM bettype   
	WHERE typeid IN (71,73)
		OR (typeid < 31 OR   
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
		OR (
			typeid BETWEEN 1501 AND 1599
			)
END

INSERT INTO #TempAg (custid)
SELECT  CustID  
FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
		INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
DECLARE @sql NVARCHAR(2500)
DECLARE @SortTemp VARCHAR(250) 
DECLARE @LicenseeWL VARCHAR(150) 
SET @LicenseeWL =				
				'CASE  
					WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake) 
					ELSE awinlost 
				 END'

SElect @LicenseeWL
IF (@Sort LIKE '%USD%') OR (@Sort LIKE '%EUR%')
BEGIN
	DECLARE @charindex INT
	SELECT @charindex = CHARINDEX( ' ', @Sort, 1)
	IF @Sort LIKE '%LicenseeWL%'
	BEGIN
		SELECT @SortTemp = ' CASE  
								WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake) 
								ELSE awinlost 
							 END'
	 + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
	END
	ELSE
	BEGIN
		SELECT @SortTemp = substring (@Sort, 1, @charindex - 4) + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
	END	
END
ELSE
BEGIN
	SET @SortTemp = @Sort
	SELECT @SortTemp
END
--SELECT @SortTemp as '1'
/*
CREATE TABLE #TempExchange
(exchangedate DATETIME,ExchangeId INT,Code VARCHAR(5),MYR FLOAT, USD FLOAT, EUR FLOAT)
*/

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@wldate,@wldate)

--select * from #TempExchange 
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
		INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate = @wldate
		--AND b.matchid > 0
		AND b.bettype NOT IN (9,29,10)
		AND b.recommend IN (SELECT custid FROM #TempAg)	
		AND b.status=@status
		AND b.ruben = 1
	GROUP BY currency	
	
	CREATE TABLE #BetData1
	(
		RowNum INT,
		oddsid INT,
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
		betteam VARCHAR (300),
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
		showtime NVARCHAR(50),
		stakeUSD MONEY,
		WinlostUSD MONEY,
		LicenseeWLUSD MONEY,
		commUSD MONEY,
		PlayerCommUSD MONEY,
		stakeEUR MONEY,
		WinlostEUR MONEY,
		LicenseeWLEUR MONEY,
		commEUR MONEY,
		PlayerCommEUR MONEY
	)
	-- Get Betdata from bettrans and filter by row number
	--SELECT @SortTemp as '3'
	SET @sql = 
	'SELECT A.* 
	FROM (SELECT
		ROW_NUMBER() over(ORDER BY '+ @SortTemp + ') AS RowNum,
		b.oddsid,
		CAST(NULL AS INT) AS sporttype,
		b.username,
		SUBSTRING(c.username2,  CHARINDEX(''$'',c.username2)+1, 
		len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,
		b.bettype,
		CAST(NULL AS INT) AS leagueID,
		b.transid,
		CAST(NULL AS NVARCHAR(50)) AS matchcode,
		CAST('''' AS NVARCHAR(20)) AS Race,
		CAST(NULL AS INT) AS homeID,
		CAST(NULL AS INT) AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.status,
		b.stake,
		(b.winlost-actual_stake) winlost,
		CASE  
			WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake) 
			ELSE awinlost 
		END AS LicenseeWL,
		b.comm as comm,
		b.playercomm as PlayerComm,
		b.transdate,
		b.winlostdate,
		CASE  
			WHEN b.bettype BETWEEN 1501 AND 1599 THEN b.transdesc
			ELSE b.betteam 
		END AS betteam,		
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.matchid, 
		CAST(NULL AS NVARCHAR(50)) AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,		
		b.OddsType,
		b.betid,
		b.currency,
		b.refno,
		b.custid,
		CAST('''' AS NVARCHAR(50)) AS showtime,
		--USD
		b.stake*e.USD stakeUSD,
		b.Winlost*e.USD WinlostUSD,'
		+@LicenseeWL+'*e.USD LicenseeWLUSD,
		b.comm*e.USD commUSD,
		b.playercomm*e.USD as PlayerCommUSD,
		--EUR
		b.stake*e.EUR stakeEUR,
		b.Winlost*e.EUR WinlostEUR,'
		+@LicenseeWL+'*e.EUR LicenseeWLEUR,
		b.comm*e.EUR commEUR,
		b.playercomm*e.EUR as PlayerCommEUR
	FROM
		bettrans b WITH (nolock) 
		INNER JOIN customer c WITH (nolock) ON b.custid = c.custid
		INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
		INNER JOIN #TempExchange e ON  e.exchangeid = b.currency
	WHERE
		b.winlostdate = '''+CAST(@wldate AS VARCHAR(50))+
		''' AND ((b.tpositiontaking=0 AND '''+CAST(@Product AS VARCHAR(3)) +'''=''BA'') OR '''+CAST(@Product AS VARCHAR(3))+'''<>''BA'')
		AND b.status='''+CAST(@status AS VARCHAR(15))+
		''' AND b.bettype NOT IN (9,29,10)
		AND b.recommend IN (SELECT custid FROM #TempAg)	
		AND b.ruben = 1		
	) A WHERE A.RowNum BETWEEN '+CAST(@RowStart AS VARCHAR(50))+' AND '+ CAST(@RowEnd AS VARCHAR(50))
	
	INSERT INTO #BetData1
	(RowNum,Oddsid,Sporttype,Username,NickName,Bettype,LeagueID,Transid,Matchcode,Race,HomeID,AwayID,hdp1,hdp2,
	odds,status,stake,Winlost,LicenseeWL,comm,PlayerComm,transdate,Winlostdate,betteam,liveindicator,livehomescore,
	liveawayscore,MatchID,Betstatus ,IsNeutral,oddstype,betid,currency,RefNO,CustID,showtime,stakeUSD,WinlostUSD,LicenseeWLUSD,commUSD,PlayerCommUSD,
	stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR)


	EXEC (@sql)	
	--SELECT * FROM #betdata1
	select '#betdata1'
	select @sql

	-- Update LicenseeWL with LicenseeBATransaction table
	UPDATE b
	SET LicenseeWL = 0
	FROM #BetData1 b
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid

	UPDATE b
	SET betteam = t.ChoiceId,matchid = t.GameId,b.sporttype = 202
	FROM #BetData1 b
		CROSS APPLY dbo.[f_ParseTransDesc](b.betteam, b.bettype) t
	WHERE b.bettype BETWEEN 1501 AND 1599

	-- Update data with match table
	UPDATE b
	SET sporttype = CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.sporttype 
						ELSE NULL
					END,
		leagueID = 	CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.leagueid 
						ELSE NULL
					END,
		matchcode = CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.matchcode 
						ELSE NULL
					END,
		homeID = 	CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.homeid 
						ELSE NULL
					END,	
		awayID = 	CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.awayid 
						ELSE NULL
					END,
		betstatus = CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.betstatus 
						ELSE NULL
					END,
		IsNeutral = m.IsNeutral,
		showtime = CASE 
						WHEN (b.bettype BETWEEN 1101 AND 1199 ) 
						THEN  ISNULL(m.showtime,'') 
						ELSE '' 
					END
	FROM #BetData1 b
		INNER JOIN match m WITH (nolock) ON b.matchid=m.matchid
	WHERE b.bettype NOT BETWEEN 1501 AND 1599 -- exclude Keno

	-- Update data with @vhr table
	UPDATE b
	SET sporttype = v.sporttype,
		leagueID = v.leagueid,
		matchcode = v.matchcode,
		homeID = v.RacerID,
		awayID = v.AwayID,
		betstatus = v.BetStatus,
		showtime=v.showtime
	FROM #BetData1 b
		INNER JOIN @vhr  v ON b.oddsid=v.OrID
	WHERE b.bettype IN (1231, 1232, 1233, 1237, 1238)
	
	-- Update data with @hr table
	UPDATE b
	SET sporttype = r.sporttype,
		leagueID = r.leagueid,
		matchcode = r.matchcode,
		homeID = r.RacerID,
		awayID = r.AwayID,
		betstatus = r.BetStatus,
		Race = r.Race
	FROM #BetData1 b
		INNER JOIN @hr  r ON b.oddsid=r.OrID
	WHERE b.bettype IN (31, 32, 33)
	
	-- Insert and drop temp table
	INSERT INTO #Data
	SELECT RowNum,
		sporttype,username,nickname,
		bettype,leagueID,transid,matchcode,
		Race,homeID,awayID,hdp1, hdp2, 
		odds,status,stake,winlost,LicenseeWL,
		comm,PlayerComm,transdate,winlostdate,
		betteam,liveindicator,livehomescore,liveawayscore,matchid, 
		betstatus,IsNeutral,OddsType,betid,currency,refno,custid,showtime,
		stakeUSD,WinlostUSD,LicenseeWLUSD,commUSD,PlayerCommUSD,
		stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR
	FROM #BetData1
	--select '#data'
	--select * from #Data
	DROP TABLE #BetData1	
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
		INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
		LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
	WHERE
		b.winlostdate = @wldate
		AND b.bettype NOT IN (9,29,10)
		AND b.status=@status
		AND b.recommend IN (SELECT custid FROM #TempAg)
	GROUP BY b.currency	
	
	CREATE TABLE #BetData14
	(
		RowNum INT,
		oddsid INT,
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
		betteam VARCHAR (300),
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
		showtime NVARCHAR(50),
		stakeUSD MONEY,
		WinlostUSD MONEY,
		LicenseeWLUSD MONEY,
		commUSD MONEY,
		PlayerCommUSD MONEY,
		stakeEUR MONEY,
		WinlostEUR MONEY,
		LicenseeWLEUR MONEY,
		commEUR MONEY,
		PlayerCommEUR MONEY 
	)	
	SELECT @SortTemp as '3'
	-- Get Betdata from bettrans14 and filter by row number	
	SET @sql = 
	'SELECT A.* 
	FROM (SELECT
		ROW_NUMBER() over(ORDER BY '+ @SortTemp + ')AS RowNum,
		b.oddsid,
		CAST(NULL AS INT) AS sporttype,
		b.username,
		SUBSTRING(c.username2,  CHARINDEX(''$'',c.username2)+1, len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,
		b.bettype,
		CAST(NULL AS INT) AS leagueID,
		b.transid,
		CAST(NULL AS NVARCHAR(50)) AS matchcode,
		CAST('''' AS NVARCHAR(20)) AS Race,
		CAST(NULL AS INT) AS homeID,
		CAST(NULL AS INT) AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.status,
		b.stake,
		(b.winlost-actual_stake) winlost,
		CASE  
			WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake) 
			ELSE awinlost 
		END AS LicenseeWL,
		b.comm as comm,
		b.playercomm as PlayerComm,
		b.transdate,
		b.winlostdate,
		CASE  
			WHEN b.bettype BETWEEN 1501 AND 1599 THEN b.transdesc
			ELSE b.betteam 
		END AS betteam,		
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.matchid, 
		CAST(NULL AS NVARCHAR(50)) AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		
		b.OddsType,
		b.betid,
		b.currency,
		b.refno,
		b.custid,
		CAST('''' AS NVARCHAR(50)) AS showtime,
		--USD
		b.stake*e.USD stakeUSD,
		b.Winlost*e.USD WinlostUSD,'
		+ @LicenseeWL+'*e.USD LicenseeWLUSD,
		b.comm*e.USD commUSD,
		b.playercomm*e.USD as PlayerCommUSD,
		--EUR
		b.stake*e.EUR stakeEUR,
		b.Winlost*e.EUR WinlostEUR,'
		+ @LicenseeWL+'*e.EUR LicenseeWLEUR,
		b.comm*e.EUR commEUR,
		b.playercomm*e.EUR as PlayerCommEUR
	FROM
		bettrans14 b WITH (nolock) 
		INNER JOIN customer c WITH (nolock) ON b.custid = c.custid
		INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
		INNER JOIN #TempExchange e ON  e.exchangeid = b.currency
	WHERE
		b.winlostdate = '''+ CAST(@wldate AS VARCHAR(50))+
		''' AND ((b.tpositiontaking=0 AND '''+CAST(@Product AS VARCHAR(3))+'''=''BA'') OR '''+CAST(@Product AS VARCHAR(3))+'''<>''BA'')
		AND b.status='''+CAST(@status AS VARCHAR(15))+
		''' AND b.bettype NOT IN (9,29,10)
		AND b.recommend IN (SELECT custid FROM #TempAg)	
		AND b.ruben = 1
	) A WHERE A.RowNum BETWEEN '+CAST(@RowStart AS VARCHAR(50))+' AND '+ CAST(@RowEnd AS VARCHAR(50))
	
	INSERT INTO #BetData14
	(RowNum,Oddsid,Sporttype,Username,NickName,Bettype,LeagueID,Transid,Matchcode,Race,HomeID,AwayID,hdp1,hdp2,
	odds,status,stake,Winlost,LicenseeWL,comm,PlayerComm,transdate,Winlostdate,betteam,liveindicator,livehomescore,
	liveawayscore,MatchID,Betstatus ,IsNeutral,oddstype,betid,currency,RefNO,CustID,showtime,stakeUSD,WinlostUSD,LicenseeWLUSD,commUSD,PlayerCommUSD,
stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR)

	EXEC (@sql)	
	select @sql as 'bet14'
	--select * from #BetData14

	-- Update LicenseeWL with LicenseeBATransaction table
	UPDATE b
	SET LicenseeWL = 0
	FROM #BetData14 b
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid

	UPDATE b
	SET betteam = t.ChoiceId,matchid = t.GameId, b.sporttype = 202
	FROM #BetData14 b
		CROSS APPLY dbo.[f_ParseTransDesc](b.betteam, b.bettype) t
	WHERE b.bettype BETWEEN 1501 AND 1599

	-- Update data with match14 table
	UPDATE b
	SET sporttype = CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.sporttype 
						ELSE NULL
					END,
		leagueID = 	CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.leagueid 
						ELSE NULL
					END,
		matchcode = CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.matchcode 
						ELSE NULL
					END,
		homeID = 	CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.homeid 
						ELSE NULL
					END,	
		awayID = 	CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.awayid 
						ELSE NULL
					END,
		betstatus = CASE 
						WHEN b.bettype NOT IN (1231, 1232, 1233, 1237, 1238, 31, 32, 33) THEN m.betstatus 
						ELSE NULL
					END,
		IsNeutral = m.IsNeutral,
		showtime = CASE 
						WHEN (b.bettype BETWEEN 1101 AND 1199 ) 
						THEN  ISNULL(m.showtime,'') 
						ELSE '' 
					END
	FROM #BetData14 b
		INNER JOIN match14 m WITH (nolock) ON b.matchid=m.matchid
	WHERE b.bettype NOT BETWEEN 1501 AND 1599 -- exclude Keno

	-- Update data with @vhr table
	UPDATE b
	SET sporttype = v.sporttype,
		leagueID = v.leagueid,
		matchcode = v.matchcode,
		homeID = v.RacerID,
		awayID = v.AwayID,
		betstatus = v.BetStatus,
		showtime=v.showtime
	FROM #BetData14 b
		INNER JOIN @vhr  v ON b.oddsid=v.OrID
	WHERE b.bettype IN (1231, 1232, 1233, 1237, 1238)
	
	-- Update data with @hr table
	UPDATE b
	SET sporttype = r.sporttype,
		leagueID = r.leagueid,
		matchcode = r.matchcode,
		homeID = r.RacerID,
		awayID = r.AwayID,
		betstatus = r.BetStatus,
		Race = r.Race
	FROM #BetData14 b
		INNER JOIN @hr  r ON b.oddsid=r.OrID
	WHERE b.bettype IN (31, 32, 33)	
	select '#data'
	-- Insert and drop temp table
	INSERT INTO #Data
	SELECT RowNum,
		sporttype,username,nickname,
		bettype,leagueID,transid,matchcode,
		Race,homeID,awayID,hdp1, hdp2, 
		odds,status,stake,winlost,LicenseeWL,
		comm,PlayerComm,transdate,winlostdate,
		betteam,liveindicator,livehomescore,liveawayscore,matchid, 
		betstatus,IsNeutral,OddsType,betid,currency,refno,custid,showtime,
		stakeUSD,WinlostUSD,LicenseeWLUSD,commUSD,PlayerCommUSD,
		stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR
	FROM #BetData14
	
	--select * from  #Data
	DROP TABLE #BetData14
END

CREATE NONCLUSTERED INDEX IDX_Currency ON #Data(Currency)

--SELECT @SortTemp as '4'
--select * from #Data

SET @sql = 
'SELECT ROW_NUMBER() over(ORDER BY '+@SortTemp+') AS RowNum, 
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
ON  e.exchangeid = b.currency'+' 
ORDER BY ' +@SortTemp 
--EXEC (@sql) 
--SELECT @sql
select * from #Data

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

CREATE TABLE #BettransDetail(  
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
		INSERT INTO #BettransDetail
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
		INSERT INTO #BettransDetail
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
		INSERT INTO #BettransDetail
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
		INNER JOIN #Data B ON  BG.custid = B.custid
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE 
		(B.bettype=1233 AND ( BG.refno = B.Refno))
		OR (B.bettype IN (33,43) AND ( BG.refno = B.Transid))		
	END
	IF @wldate <= @MoveBetsDay_
	BEGIN
		INSERT INTO #BettransDetail
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
		INNER JOIN #Data B ON  BG.custid = B.custid
		INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
		WHERE
		(B.bettype=1233 AND ( BG.refno = B.Refno))
		OR (B.bettype IN (33,43) AND ( BG.refno = B.Transid))
	END
END

SELECT * FROM #BettransDetail ORDER BY RefNo ASC,Bettype

DROP TABLE #Currency
DROP TABLE #TempExchange
DROP TABLE #TempExchangeSum
DROP TABLE #Data
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossDaily_14877] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossDaily_14877] TO [vnteam] AS [dbo]

