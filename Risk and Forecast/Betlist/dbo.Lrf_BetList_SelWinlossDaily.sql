USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinlossDaily_xtest]    Script Date: 04/20/2015 13:43:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
exec Lrf_BetList_SelWinlossDaily
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
	@SumPlayerCommEUR MONEY=0 OUTPUT,
	@SumWinlostGBP MONEY = 0 OUTPUT,
	@SumLicenseeWLGBP MONEY = 0 OUTPUT,
	@SumCommGBP MONEY = 0 OUTPUT,
	@SumPlayerCommGBP MONEY=0 OUTPUT,
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
	- 20140520@Hannah: Fix bug Sort betlist
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20140717@Hannah: HotFix for Exporting excel file
	- 20140718@Jim: fix bug 'wrong to get licensee winloss/comm for Horse Racing' (#19165)
	- 20140718@Jim: fix bug 'Win loss and Licensee WL showed on web are incorrect when product is BA' (#19261)
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150114@Winnie: remove hardcode bettype, use spottype bettype matrix
	- 20150128@Winnie: Add base currency GBP 
	- 20150410@Jim: support betradar and apply report-bettype matrix
	- 20150604@Edward: Support MicroGamming
	- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
	- 20150623@Edward: Fix bug Missing Sporttype for Microgaming tickets (#38450)
	- 20150729@Edward: Return betcheck for MicroGamming

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
	betcheck NVARCHAR(100),
	stakeUSD MONEY,
	WinlostUSD MONEY,
	LicenseeWLUSD MONEY,
	commUSD MONEY,
	PlayerCommUSD MONEY,
	stakeEUR MONEY,
	WinlostEUR MONEY,
	LicenseeWLEUR MONEY,
	commEUR MONEY,
	PlayerCommEUR MONEY,
	stakeGBP MONEY,
	WinlostGBP MONEY,
	LicenseeWLGBP MONEY,
	commGBP MONEY,
	PlayerCommGBP MONEY
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

CREATE TABLE #TempAg (custid INT, Currency INT)
--CREATE TABLE #TmpCondBettype(bettype INT primary key)
------------
CREATE TABLE #SportBettype  (ProductID INT,Bettype INT,EventType INT)
------------
DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1
SELECT @RowStart = @PageSize * @PageIndex + 1
SELECT @RowEnd = (@RowStart -1)  + @PageSize

DECLARE @sql NVARCHAR(2500)
DECLARE @SortTemp VARCHAR(250) 
DECLARE @LicenseeWL VARCHAR(150) 
DECLARE @Winlost VARCHAR(150) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

INSERT INTO #TempAg (custid,currency)
SELECT   lc.CustID  
		,lc.currency
FROM    bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc  
INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@wldate,@wldate)


--Sports Book
IF ( @Product='SB' OR @Product='BA' )
BEGIN
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel  @mode=4, @ProductID=1
 
DELETE #SportBettype WHERE ProductID = 1 AND Bettype IN (901,902,903)
END   
--Number Game
IF @Product='NG'
BEGIN 
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=3
	   
END
--Horse Racing
IF @Product='RB'
BEGIN 
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=2
	   
END
--Live Casino
IF @Product='LC'
BEGIN	
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=4
 
END
--Virtual Sports
IF @Product='VS'
BEGIN	
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=5
	
END
--RNG Casino
IF @Product='CS'
BEGIN	
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=6
 
END
--Bingo
IF @Product='BG'
BEGIN
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=7
	 
END
--Keno
IF @Product='KN'
BEGIN	
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=8
	 
END

--MicroGamming
IF @Product='MGC'
BEGIN	
INSERT INTO #SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4, @ProductID=13
	 
END

SET @LicenseeWL =				
				'CASE  
					WHEN b.bettype NOT IN (31,32,33) THEN - (b.winlost-b.actual_stake) 
					ELSE b.awinlost 
				 END'

SET @Winlost = '(b.winlost-b.actual_stake)'

IF (@Sort LIKE '%USD%') OR (@Sort LIKE '%EUR%') OR (@Sort LIKE '%GBP%')
	BEGIN
		DECLARE @charindex INT
		SELECT @charindex = CHARINDEX( ' ', @Sort, 1)
		
		IF @Sort LIKE '%Winlost%'
		BEGIN
			SELECT @SortTemp = @Winlost
		 + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
		ELSE
		IF @Sort LIKE '%LicenseeWL%'
		BEGIN
			SELECT @SortTemp = @LicenseeWL
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
	END


IF @wldate > @MoveBetsDay_
BEGIN
	IF (@Product='VS' )
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
	IF (@Product='RB' )
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
	IF (@Product='BA' )
		BEGIN
			INSERT INTO @DataSum
			SELECT 
				b.currency,
				COUNT(b.transid),
				SUM(ISNULL(b.winlost-b.actual_stake,0)),
				0,
				SUM(ISNULL(b.comm,0)),
				SUM(b.playercomm )  AS  SumPlayerComm
			FROM bettrans b WITH (nolock) 
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
				--INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
				INNER JOIN #SportBettype sbt ON sbt.Bettype=b.bettype
				INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9,29,10)
				AND b.status=@status
				AND b.ruben = 1
				AND b.tpositiontaking=0
			GROUP BY b.currency	
		END
	IF (@Product<>'BA' )	
		BEGIN
			INSERT INTO @DataSum
			SELECT 
				b.currency,
				COUNT(b.transid),
				SUM(ISNULL(b.winlost-b.actual_stake,0)),
				-SUM(ISNULL(CASE WHEN  b.bettype IN (31,32,33) THEN awinlost
												ELSE (b.winlost-b.actual_stake) 
												END	
								,0)
					),
				SUM(ISNULL(b.comm,0)),
				SUM(b.playercomm )  AS  SumPlayerComm
			FROM bettrans b WITH (nolock) 
				--INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
				INNER JOIN #SportBettype sbt ON sbt.Bettype=b.bettype
				INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9,29,10)
				AND b.status=@status
				AND b.ruben = 1
				AND (
					(@Product='SB' AND b.tpositiontaking<>0)
					OR @Product<>'SB'
					)
			GROUP BY b.currency	
		END	
	CREATE TABLE #BetData1
	(
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
		betcheck NVARCHAR(100),
		stakeUSD MONEY,
		WinlostUSD MONEY,
		LicenseeWLUSD MONEY,
		commUSD MONEY,
		PlayerCommUSD MONEY,
		stakeEUR MONEY,
		WinlostEUR MONEY,
		LicenseeWLEUR MONEY,
		commEUR MONEY,
		PlayerCommEUR MONEY,
		stakeGBP MONEY,
		WinlostGBP MONEY,
		LicenseeWLGBP MONEY,
		commGBP MONEY,
		PlayerCommGBP MONEY
		
	)

	-- Get Betdata from bettrans and filter by row number
	SET @sql = 
	'SELECT
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
		b.betcheck,
		--USD
		b.stake*e.USD stakeUSD,'
		+@Winlost+'*e.USD WinlostUSD,'
		+@LicenseeWL+'*e.USD LicenseeWLUSD,
		b.comm*e.USD commUSD,
		b.playercomm*e.USD as PlayerCommUSD,
		--EUR
		b.stake*e.EUR stakeEUR,'
		+@Winlost+'*e.EUR WinlostEUR,'
		+@LicenseeWL+'*e.EUR LicenseeWLEUR,
		b.comm*e.EUR commEUR,
		b.playercomm*e.EUR as PlayerCommEUR,
		--GBP
		b.stake*e.GBP stakeGBP,'
		+@Winlost+'*e.GBP WinlostGBP,'
		+@LicenseeWL+'*e.GBP LicenseeWLGBP,
		b.comm*e.GBP commGBP,
		b.playercomm*e.GBP as PlayerCommGBP
	FROM
		bettrans b WITH (nolock) 
		INNER JOIN customer c WITH (nolock) ON b.custid = c.custid
		INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency
		INNER JOIN #SportBettype sbt ON sbt.Bettype=b.bettype
		INNER JOIN #TempExchange e ON  e.exchangeid = b.currency'+char(13)+
	CASE WHEN @Product='BA' THEN 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid'	
							ELSE ''
							END+char(13)+
	'WHERE
		b.winlostdate = '''+CAST(@wldate AS VARCHAR(50))+''''+char(13)+
		'AND b.status='''+CAST(@status AS VARCHAR(15))+''''+char(13)+
		'AND b.bettype NOT IN (9,29,10)
		AND b.ruben = 1'+char(13)+
		CASE WHEN @Product='SB' THEN 'AND b.tpositiontaking<>0'	
								ELSE ''
								END+char(13)			
	
	INSERT INTO #BetData1
	(Oddsid,Sporttype,Username,NickName,Bettype,LeagueID,Transid,Matchcode,Race,HomeID,AwayID,hdp1,hdp2,
	odds,status,stake,Winlost,LicenseeWL,comm,PlayerComm,transdate,Winlostdate,betteam,liveindicator,livehomescore,
	liveawayscore,MatchID,Betstatus ,IsNeutral,oddstype,betid,currency,RefNO,CustID,showtime,betcheck,stakeUSD,WinlostUSD,LicenseeWLUSD,commUSD,PlayerCommUSD,
	stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR,stakeGBP,WinlostGBP,LicenseeWLGBP,commGBP,PlayerCommGBP)
	EXEC (@sql)	

	-- Update LicenseeWL with LicenseeBATransaction table
	UPDATE b
	SET LicenseeWL = 0
		,LicenseeWLUSD=0
		,LicenseeWLEUR=0
		,LicenseeWLGBP=0
	FROM #BetData1 b
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid

	UPDATE b
	SET betteam = t.ChoiceId,matchid = t.GameId,b.sporttype = 202
	FROM #BetData1 b
		CROSS APPLY dbo.[f_ParseTransDesc](b.betteam, b.bettype) t
	WHERE b.bettype BETWEEN 1501 AND 1599

	-- Update data with match table
	UPDATE b
	SET sporttype = m.sporttype, 
		leagueID = 	m.leagueid, 
		matchcode = m.matchcode, 
		homeID = 	m.homeid, 
		awayID = 	m.awayid, 
		betstatus = m.betstatus, 
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
	
	-- Update data for MicroGamming
	UPDATE b
	SET b.sporttype = 203
	FROM #BetData1 b
	WHERE b.bettype BETWEEN 2001 AND 2009

	-- Insert and drop temp table
	INSERT INTO #Data
	SELECT 
		sporttype,username,nickname,
		bettype,leagueID,transid,matchcode,
		Race,homeID,awayID,hdp1, hdp2, 
		odds,status,stake,winlost,LicenseeWL,
		comm,PlayerComm,transdate,winlostdate,
		betteam,liveindicator,livehomescore,liveawayscore,matchid, 
		betstatus,IsNeutral,OddsType,betid,currency,refno,custid,showtime,betcheck ,
		stakeUSD,WinlostUSD,LicenseeWLUSD,commUSD,PlayerCommUSD,
		stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR,
		stakeGBP,WinlostGBP,LicenseeWLGBP,commGBP,PlayerCommGBP
	FROM #BetData1

	DROP TABLE #BetData1	
END

IF @wldate <= @MoveBetsDay_ AND @wldate >=@BalanceUpDay_
BEGIN
	IF (@Product='VS' )
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
	IF (@Product='RB' )
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
	IF (@Product='BA' )
		BEGIN
			INSERT INTO @DataSum
			SELECT 
				b.currency,
				COUNT(b.transid),
				SUM(ISNULL(b.winlost - b.actual_stake,0)),
				0,
				SUM(ISNULL(b.comm ,0)),
				SUM(b.playercomm )  AS  SumPlayerComm
			FROM bettrans14 b WITH (NOLOCK)	
				--INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
				INNER JOIN #SportBettype sbt ON sbt.Bettype=b.bettype
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
				INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9,29,10)
				AND b.status=@status
				 
			GROUP BY b.currency	
		END
	IF (@Product<>'BA' )	
		BEGIN
			INSERT INTO @DataSum
			SELECT 
				b.currency,
				COUNT(b.transid),
				SUM(ISNULL(b.winlost - b.actual_stake,0)),
				-SUM(ISNULL(CASE WHEN  b.bettype IN (31,32,33) THEN awinlost
												ELSE (b.winlost-b.actual_stake) 
												END	
								,0)
					),
				SUM(ISNULL(b.comm ,0)),
				SUM(b.playercomm )  AS  SumPlayerComm
			FROM bettrans14 b WITH (NOLOCK)	
				--INNER JOIN #TmpCondBettype bt ON b.bettype = bt.bettype
				INNER JOIN #SportBettype sbt ON sbt.Bettype=b.bettype
				INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency
			WHERE
				b.winlostdate = @wldate
				AND b.bettype NOT IN (9,29,10)
				AND b.status=@status
				AND (
					(@Product='SB' AND b.tpositiontaking<>0)
					OR (@Product<>'SB')
					)
			GROUP BY b.currency	
		END
	CREATE TABLE #BetData14
	(
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
		betcheck NVARCHAR(100),
		stakeUSD MONEY,
		WinlostUSD MONEY,
		LicenseeWLUSD MONEY,
		commUSD MONEY,
		PlayerCommUSD MONEY,
		stakeEUR MONEY,
		WinlostEUR MONEY,
		LicenseeWLEUR MONEY,
		commEUR MONEY,
		PlayerCommEUR MONEY,
		stakeGBP MONEY,
		WinlostGBP MONEY,
		LicenseeWLGBP MONEY,
		commGBP MONEY,
		PlayerCommGBP MONEY 		
	)	

	-- Get Betdata from bettrans14 and filter by row number	
	SET @sql = 
	'SELECT
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
		b.betcheck,
		--USD
		b.stake*e.USD stakeUSD,'
		+@Winlost+'*e.USD WinlostUSD,'
		+ @LicenseeWL+'*e.USD LicenseeWLUSD,
		b.comm*e.USD commUSD,
		b.playercomm*e.USD as PlayerCommUSD,
		--EUR
		b.stake*e.EUR stakeEUR,'
		+@Winlost+'*e.EUR WinlostEUR,'
		+ @LicenseeWL+'*e.EUR LicenseeWLEUR,
		b.comm*e.EUR commEUR,
		b.playercomm*e.EUR as PlayerCommEUR,
		--GBP
		b.stake*e.GBP stakeGBP,'
		+@Winlost+'*e.GBP WinlostGBP,'
		+ @LicenseeWL+'*e.GBP LicenseeWLGBP,
		b.comm*e.GBP commGBP,
		b.playercomm*e.GBP as PlayerCommGBP
	FROM
		bettrans14 b WITH (nolock) 
		INNER JOIN customer c WITH (nolock) ON b.custid = c.custid
		INNER JOIN #TempAg ag ON b.recommend = ag.custid AND b.currency = ag.Currency		
		INNER JOIN #TempExchange e ON  e.exchangeid = b.currency'+char(13)+
		'INNER JOIN #SportBettype sbt ON sbt.Bettype=b.bettype'+char(13)+
	CASE WHEN @Product='BA' THEN 'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid'	
							ELSE ''
							END+char(13)+
	'WHERE
		b.winlostdate = '''+ CAST(@wldate AS VARCHAR(50))+''''+char(13)+
		'AND b.status='''+CAST(@status AS VARCHAR(15))+''''+char(13)+
		' AND b.bettype NOT IN (9,29,10)
		AND b.ruben = 1'+char(13)+
		CASE WHEN @Product='SB' THEN 'AND b.tpositiontaking<>0'
								ELSE ''
								END+char(13)		
	
	INSERT INTO #BetData14
	(Oddsid,Sporttype,Username,NickName,Bettype,LeagueID,Transid,Matchcode,Race,HomeID,AwayID,hdp1,hdp2,
	odds,status,stake,Winlost,LicenseeWL,comm,PlayerComm,transdate,Winlostdate,betteam,liveindicator,livehomescore,
	liveawayscore,MatchID,Betstatus ,IsNeutral,oddstype,betid,currency,RefNO,CustID,showtime,betcheck,stakeUSD,WinlostUSD,
	LicenseeWLUSD,commUSD,PlayerCommUSD,stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR,stakeGBP,WinlostGBP,LicenseeWLGBP,commGBP,PlayerCommGBP)
	EXEC (@sql)	

	-- Update LicenseeWL with LicenseeBATransaction table
	UPDATE b
	SET LicenseeWL = 0
		,LicenseeWLUSD=0
		,LicenseeWLEUR=0
		,LicenseeWLGBP=0
	FROM #BetData14 b
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid

	UPDATE b
	SET betteam = t.ChoiceId,matchid = t.GameId, b.sporttype = 202
	FROM #BetData14 b
		CROSS APPLY dbo.[f_ParseTransDesc](b.betteam, b.bettype) t
	WHERE b.bettype BETWEEN 1501 AND 1599

	-- Update data with match14 table
	UPDATE b
	SET sporttype = m.sporttype, 
		leagueID = 	m.leagueid, 
		matchcode = m.matchcode, 
		homeID = 	m.homeid, 
		awayID = 	m.awayid ,
		betstatus = m.betstatus, 
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

	-- Update data for MicroGamming
	UPDATE b
	SET b.sporttype = 203
	FROM #BetData14 b
	WHERE b.bettype BETWEEN 2001 AND 2009

	-- Insert and drop temp table
	INSERT INTO #Data
	SELECT 
		sporttype,username,nickname,
		bettype,leagueID,transid,matchcode,
		Race,homeID,awayID,hdp1, hdp2, 
		odds,status,stake,winlost,LicenseeWL,
		comm,PlayerComm,transdate,winlostdate,
		betteam,liveindicator,livehomescore,liveawayscore,matchid, 
		betstatus,IsNeutral,OddsType,betid,currency,refno,custid,showtime,betcheck,
		stakeUSD,WinlostUSD,LicenseeWLUSD,commUSD,PlayerCommUSD,
		stakeEUR,WinlostEUR,LicenseeWLEUR,commEUR,PlayerCommEUR,
		stakeGBP,WinlostGBP,LicenseeWLGBP,commGBP,PlayerCommGBP
	FROM #BetData14
	
	DROP TABLE #BetData14
END

CREATE NONCLUSTERED INDEX IDX_Currency ON #Data(Currency)

SET @sql = 
'SELECT A.*
FROM
(
	SELECT
		ROW_NUMBER() over(ORDER BY '+ @Sort + ') AS RowNum,
		d.* 
	FROM #Data d
) A 
WHERE A.RowNum BETWEEN '+CAST(@RowStart AS VARCHAR(50))+' AND '+ CAST(@RowEnd AS VARCHAR(50))
+' ORDER BY A.RowNum'
EXEC (@sql)	

--SUM
SELECT * INTO #TempExchangeSum 
FROM Lrf_f_GetExchangeDaily(@wldate,@wldate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM @DataSum)

SELECT 
	@TotalRows = SUM(totalrows) ,
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
	@SumPlayerCommEUR=SUM(ISNULL(SumPlayerComm,0)*e.EUR),
	--GBP
	@SumWinlostGBP = SUM(SumWinlost*e.GBP),
	@SumLicenseeWLGBP = SUM(SumLicenseeWL*e.GBP),
	@SumCommGBP = SUM(SumComm * e.GBP),
	@SumPlayerCommGBP=SUM(ISNULL(SumPlayerComm,0)*e.GBP)
FROM @DataSum b 
INNER JOIN #TempExchangeSum e ON b.currency = e.exchangeid

CREATE TABLE #BettransDetail(  
	refno BIGINT,  
	odds SMALLMONEY,  
	stake MONEY,
	status NVARCHAR(10),  
	apositiontaking SMALLMONEY,  
	bettype SMALLINT,
	Betteam nvarchar (10),
	stakeEUR MONEY,
	stakeUSD MONEY,
	stakeGBP MONEY
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
			BG.stake * e.USD AS stakeUSD,
			BG.stake * e.GBP AS stakeGBP
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
			BG.stake * e.USD AS stakeUSD,
			BG.stake * e.GBP AS stakeGBP
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
			BG.stake*e.USD,
			BG.stake*e.GBP
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
			BG.stake*e.USD,
			BG.stake*e.GBP
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
DROP TABLE #SportBettype
DROP TABLE #TempAg
DROP TABLE #BettransDetail


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossDaily] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossDaily] TO [vnteam]