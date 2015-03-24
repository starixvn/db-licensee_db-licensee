USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER  PROCEDURE [dbo].[Lrf_BetList_SelRunningByMultipleBettypeMatch]
	@MatchID INT,
	@LicenseeID INT,
	@CurrencyID INT=0,
	@UserID		INT,
	@LicenseeType VARCHAR(100) = NULL,
	@Bettype VARCHAR(300),
	@Langkey VARCHAR(10) = 'en-US',
	@betteam VARCHAR(20) = NULL,
	@liveindicator INT = -1,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT
AS

/*
Created: 20140522@Jim
Task : Betlist
DB: DB052.bodb02
Original: [Lrf_BetList_SelRunningByBettypeMatch]
Revisions:    
	-20140522@Jim: clone from Lrf_BetList_SelRunningByBettypeMatch to support muilti bettype.
	-20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
	- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
	- 20150124@Winnie: Add base currency GBP  
*/

SET NOCOUNT ON

IF ISNULL(@Bettype,'')=''
SET @Bettype=''

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @tblbettype AS TABLE (bettype INT )
INSERT INTO @tblbettype (bettype)
SELECT CONVERT(INT,VAL) AS bettype
FROM strSplit(@Bettype,',')
	
DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID		
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description]) 

SET @betteam = RTRIM(LTRIM(ISNULL(@betteam,'')))

CREATE TABLE #Data
(
	CustID INT,
	Sporttype INT,
	Username NVARCHAR(50),
	Bettype SMALLINT,
	Transid BIGINT,
	Matchcode VARCHAR(50),
	Race VARCHAR(50),
	LeagueID INT,
	HomeID INT,
	AwayID INT,
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	odds SMALLMONEY,
	status NVARCHAR(50),
	stake MONEY,
	transdate DATETIME,
	betteam VARCHAR (50),
	liveindicator INT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	discount DECIMAL(9,8),
	ip NVARCHAR(20),
	IsNeutral BIT,
	oddstype TINYINT,
	betid BIGINT,
	winlostdate DATETIME,
	currency SMALLINT,
	playercomm MONEY,
	refno BIGINT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)


IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype=10)
BEGIN
	
	INSERT INTO #Data
	SELECT 
		b.CustID,
		l.sporttype AS Sporttype,
		b.Username,   
		b.Bettype,     
		b.TransID,     
		m.Matchcode, 
		m.GroupMatch AS Race,
		m.leagueid,
		m.TeamID AS HomeID,
		0 AS AwayID, 
		0 AS hdp1,--hdp1, 
		0 AS hdp2,--hdp2, 
		b.odds,   
		b.status,     
		b.stake,  
		b.Transdate, 		
		'' AS Betteam,--Betteam,    
		0 AS Liveindicator,--b.Liveindicator,
		0 AS Livehomescore,--b.Livehomescore, 
		0 AS Liveawayscore, 		 				
		b.discount,
		b.IP AS IP,
		CONVERT(BIT,0) AS isNeutral,
		0 AS oddstype,
		b.betid,
		b.winlostdate,
		b.currency,
		b.playercomm,
		b.refno,
		'' As ShowTime
	FROM 
		Bettrans b WITH (NOLOCK)
		INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid	
		INNER JOIN league l WITH (NOLOCK) ON m.leagueID=l.leagueID 
	WHERE
		b.matchid=@matchid AND 
		b.bettype=10 AND
		b.recommend IN (SELECT custid FROM @TempAg) AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
		b.statusID = 0
	ORDER BY
		b.status, b.transid
END

ELSE IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype<=19000)
BEGIN
	
	INSERT INTO #Data
	SELECT 
		b.CustID,
		m.sporttype,
		b.Username,      		
		b.Bettype,     
		b.TransID,     
		m.Matchcode,   
		'' AS Race,
		m.leagueid, 
		m.HomeID,
		m.AwayID, 
		CONVERT(FLOAT, b.hdp1) AS hdp1, 
		CONVERT(FLOAT, b.hdp2) AS hdp2, 
		b.odds,
		--b.status,   
		CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
		ELSE b.status   
		END as status, 
		b.stake,  
		b.Transdate,   		
		b.betteam,
		b.Liveindicator,
		b.Livehomescore, 
		b.Liveawayscore, 		 	
		b.discount,
		b.IP AS IP,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.Oddstype,
		b.betid,
		b.winlostdate,
		b.currency,
		b.playercomm,
		b.refno,
		isnull(m.showtime,'') as showtime
	FROM 
		Bettrans b WITH (NOLOCK) 
		INNER JOIN Match m WITH (NOLOCK) ON b.matchid=m.matchid 
		INNER JOIN @tblbettype bt ON b.bettype=bt.bettype
	WHERE
		b.matchid=@matchid AND 
		bt.bettype<=19000 AND
		b.recommend IN (SELECT custid FROM @TempAg) AND
			((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))   OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
		b.statusID IN (0,1) AND
		b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype()) AND
		((@Liveindicator=-1) OR (@Liveindicator=0 AND b.Liveindicator = 0) OR (@Liveindicator=1 AND b.Liveindicator = 1)) AND
		((@betteam='') OR (@betteam<>'' AND b.betteam = @betteam))
			
	ORDER BY
		b.status, b.transid
END


DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

IF @TotalRows = 0  
BEGIN 
	 SELECT @TotalRows = COUNT(transid) FROM #Data
END


SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY b.status, b.transid) AS RowNum,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,   
			b.* ,
			stake*e.USD stakeUSD,
			stake*e.EUR stakeEUR,
			stake*e.GBP stakeGBP,
			b.playercomm*e.USD PlayerCommUSD,
			b.playercomm*e.EUR PlayerCommEUR,
			b.playercomm*e.GBP PlayerCommGBP
	FROM #Data b
	INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid 
	INNER JOIN 
		(SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	ON e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

---Live Casino
IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype BETWEEN 1101 AND 1199)
BEGIN 
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
		bg.stake*e.USD AS stakeUSD,
		bg.stake*e.GBP AS stakeGBP
	FROM bettransg bg with (NOLOCK)
	INNER JOIN bettrans B with (NOLOCK) ON bg.refno = B.refno
	INNER JOIN @tblbettype tb ON b.bettype=tb.bettype
	INNER JOIN #TempExchange e ON e.exchangeid = b.currency AND  e.ExchangeDate = B.winlostdate
	WHERE	bg.matchid=@matchid and 
			b.recommend IN (SELECT custid FROM @TempAg) AND
				((@CurrencyID=0 AND currency IN (SELECT currencyId FROM #currency))  OR (@CurrencyID<>0 AND Currency=@CurrencyID)) AND
			b.statusID in (0,1) and 		
			tb.bettype BETWEEN 1101 AND 1199
			
	------------------------
    DROP TABLE #TempExchange 
	-----------------------

END 
------------------------
DROP TABLE #Currency
DROP TABLE #Data
------------------------



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByMultipleBettypeMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByMultipleBettypeMatch] TO [vnteam]