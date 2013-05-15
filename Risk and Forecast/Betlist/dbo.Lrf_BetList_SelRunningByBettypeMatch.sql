set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER   PROCEDURE [dbo].[Lrf_BetList_SelRunningByBettypeMatch]
	@MatchID INT,
	@LicenseeID INT,
	@CurrencyID INT=0,
	@UserID		INT,
	@LicenseeType VARCHAR(100) = NULL,
	@Bettype INT,
	@Langkey VARCHAR(10) = 'en-US',
	@betteam VARCHAR(20) = NULL,
	@liveindicator INT = -1,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT
AS

/*
Created: Henry@20101209
Task : Betlist
DB: DB052.bodb02
Original: [Age_BetList_SelRunningByBettypeMatch_Ag]
Revisions:    
   -- 20110216@Jacob: Add column nickname IN the result SET
   -- 20110303@Henry: suppport based currency
   -- 20110408@Amy: Change function to get Odds value AND odds type
   - 20110513@Henry: change bettype to new range
   - 20110630@Henry: add column discount
   - 20110714@Henry: remove apositiontaking
   - 20110729@Henry: offer 3 new bettypes for Number Game
   - 20110819@Henry: exclude BA tickets
   - 20111122@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
   - 20111212@Jim: change condition bettype<19000
   - 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
   - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  	
   - 20120706@Jim: get sporttype for Outright 
   - 20120726@Jim: add playercomm value 
   - 20120817@Henry: add live casino
   - 20121004@Jim: replace @currencyname input param by @currencyID
   - 20130411@Jim: support base currency USD
   - 20130514@Jim:Restrict permission of Licensee Users by currency
*/

SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )
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


if @bettype IN (10)
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
		b.bettype=@bettype AND
		b.recommend IN (SELECT custid FROM @TempAg) AND
		b.statusID = 0
	ORDER BY
		b.status, b.transid
END
--ELSE IF @bettype<=19000: old condition 
ELSE IF @bettype<=19000
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
	WHERE
		b.matchid=@matchid AND 
		b.bettype=@bettype AND
		b.recommend IN (SELECT custid FROM @TempAg) AND
		b.statusID IN (0,1) AND
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
			b.playercomm*e.USD PlayerCommUSD,
			b.playercomm*e.EUR PlayerCommEUR
	FROM #Data b
	INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid 
	INNER JOIN 
		(SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
	ON e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

---Live Casino
IF @Bettype BETWEEN 1101 AND 1199
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
		bg.stake*e.USD AS stakeUSD	
	FROM bettransg bg with (NOLOCK)
	INNER JOIN bettrans B with (NOLOCK) ON bg.refno = B.refno
	INNER JOIN #TempExchange e ON e.exchangeid = b.currency AND  e.ExchangeDate = B.winlostdate
	WHERE	bg.matchid=@matchid and 
			b.recommend IN (SELECT custid FROM @TempAg) AND
			b.statusID in (0,1) and 		
			b.bettype=@bettype 
			
	------------------------
    DROP TABLE #TempExchange 
	-----------------------

END 
------------------------
DROP TABLE #Currency
DROP TABLE #Data
------------------------
GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByBettypeMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByBettypeMatch] TO vnteam
GO

