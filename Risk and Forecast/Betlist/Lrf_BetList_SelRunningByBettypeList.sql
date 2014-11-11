USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByBettypeList]
	@LicenseeID INT,
	@UserID		INT,
	@CurrencyID INT=0,
	@LicenseeType VARCHAR(100) = NULL,
	@bettype VARCHAR(50),
	@Langkey VARCHAR(10) = 'en-US',
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT
 AS

/*
Created: Hannah@20140708
Task : Betlist
DB: DB052.bodb02
Original:[Lrf_BetList_SelRunningByBettype]
Revisions:
	- 20140708@Hannah: clone from Lrf_BetList_SelRunningByBettype to support muilti bettype.
	- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
*/

SET NOCOUNT ON

IF ISNULL(@Bettype,'')=''
SET @Bettype=''

CREATE TABLE #Data
(
	CustID INT,
	Sporttype INT,
	Username NVARCHAR(50),
	Bettype SMALLINT,
	Transid BIGINT,
	BetID BIGINT,
	refno BIGINT,
	Matchcode VARCHAR(50),
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	modds SMALLMONEY,
	status NVARCHAR(50),
	Stake MONEY, 
	Actual_Stake	MONEY,
	transdate DATETIME,
	betteam VARCHAR (50),
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	liveindicator INT,
	discount DECIMAL(9,8),
	LeagueID INT,
	ip NVARCHAR(30),
	IsNeutral BIT,
	oddstype TINYINT,
	winlostdate DATETIME,
	currency SMALLINT,
	statusid INT,
	playercomm MONEY ,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @tblbettype AS TABLE (bettype INT )
INSERT INTO @tblbettype (bettype)
SELECT CONVERT(INT,VAL) AS bettype
FROM strSplit(@Bettype,',')

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT DISTINCT CustID  
                FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc-- WITH ( NOLOCK )  
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE    [Description] = COALESCE(@LicenseeType,  
                                                     [Description]) 

IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype IN (9,29))
BEGIN
	INSERT INTO #Data
	SELECT 
		b.CustID,
		0 AS sporttype,
		b.username,		
		b.bettype,
		CASE WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,	
		ISNULL(b.BetID,0),
		b.refno,
		'' matchcode,
		0 AS homeID,
		0 AS awayID,
		0 hdp1,
		0 hdp2,
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake, 
		b.transdate,		
		b.betteam,
		0 AS livehomescore, 
		0 AS liveawayscore,
		0 AS liveindicator ,
		b.discount,
		0 AS LeagueID,
		b.IP AS IP,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS oddstype,
		b.winlostdate,
		b.currency,
		b.statusid,
		b.playercomm,
		'' As ShowTime
	FROM bettrans b WITH (NOLOCK)
		INNER JOIN @tblbettype bt ON b.bettype=bt.bettype
	WHERE
		b.Recommend IN (SELECT custid FROM @TempAg) AND
		b.bettype IN (9,29) AND
		b.matchid = bt.bettype AND 
		b.statusID IN (0,1) AND
		b.ruben = 0
	ORDER BY b.status, b.transid
END

ELSE IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype = 10)  -- Outright
BEGIN
	INSERT INTO #Data
	SELECT 
		b.CustID,
		l.sporttype AS sporttype,
		b.username,
		b.bettype,				
		b.transid,
		ISNULL(b.BetID,0),
		b.refno,
		m.matchcode,
		m.teamID AS homeID,
		0 AS awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		b.status,
		b.stake,
		b.actual_stake, 
		b.transdate,		
		b.betteam,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		b.discount,
		m.LeagueID,
		IP AS IP,
		CONVERT(BIT,0) AS IsNeutral,
		0 AS oddstype,
		b.winlostdate,
		b.currency,
		b.statusid,
		b.playercomm,
		'' As ShowTime
	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN outright AS m WITH (NOLOCK) ON  b.matchid=m.orid 		
		INNER JOIN league   AS l WITH (NOLOCK) ON m.leagueID=l.leagueID
	WHERE 
		b.Recommend IN (SELECT custid FROM @TempAg)
		AND b.bettype = 10
		AND b.statusID = 0
	ORDER BY b.status, b.transid
END

ELSE IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype <= 19000)
BEGIN
	INSERT INTO #Data
	SELECT
		b.CustID, 
		m.sporttype,
		b.username,
		b.bettype,		
		b.transid,
		ISNULL(b.BetID,0),
		b.refno,
		m.matchcode,
		m.homeID,
		m.awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		b.modds,
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status,
		b.stake,
		b.actual_stake, 
		b.transdate,		
		b.betteam,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator, 
		b.discount,
		m.leagueID, 
		IP AS IP,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.Oddstype,
		b.winlostdate,
		b.currency,
		b.statusid,
		b.playercomm,
		isnull(m.showtime,'') as showtime
 	FROM 
		bettrans b WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON  b.matchid=m.matchid 				
		INNER JOIN @tblbettype bt ON b.bettype=bt.bettype
	WHERE 
		b.Recommend IN (SELECT custid FROM @TempAg)
		AND b.bettype <= 19000
		AND b.statusID IN (0,1)
		AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
	ORDER BY b.status, b.transid
END

DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

IF @TotalRows = 0  
BEGIN 
	 SELECT @TotalRows = count(transid) FROM #Data
END

SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.transid) AS RowNum,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.* ,
			stake*e.USD stakeUSD,
			stake*e.EUR stakeEUR,
			actual_stake * e.USD actual_stakeUSD,
			actual_stake * e.EUR actual_stakeEUR,
			b.playercomm*e.USD PlayerCommUSD,
			b.playercomm*e.EUR PlayerCommEUR
	FROM 
		#Data b
		INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid	
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e 
		ON e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
-- live casino 
IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype BETWEEN 1101 AND 1199)
BEGIN
	--get data from bettransg for bettype 1101
	
SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@Today,@Today)
WHERE exchangeid IN (SELECT DISTINCT CurrencyID FROM #currency)
	SELECT 
		bg.refno, 
		bg.odds, 
		bg.stake,
		bg.status ,
		bg.apositiontaking, 
		bg.betteam ,
		bg.stake*e.EUR AS stakeEUR,	
		bg.stake*e.USD AS stakeUSD
	FROM bettransg bg with (NOLOCK)
	INNER JOIN bettrans B ON bg.refno = B.refno
	INNER JOIN @tblbettype tb ON b.bettype=tb.bettype
	INNER JOIN #TempExchange e 
	ON e.exchangeid = b.currency AND  e.ExchangeDate = B.winlostdate
	WHERE	b.Recommend IN (SELECT custid FROM @TempAg) and 	
			tb.bettype BETWEEN 1101 AND 1199 and
			b.statusID in (0,1)

	------------------------
	DROP TABLE #TempExchange
	------------------------	
END

-------------------------
DROP TABLE #currency
DROP TABLE #Data
-------------------------
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByBettypeList] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByBettypeList] TO vnteam