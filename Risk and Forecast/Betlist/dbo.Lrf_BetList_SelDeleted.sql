set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_SelDeleted]
	@LicenseeID INT ,
	@UserID		INT,
	@CustID INT,
	@Langkey NVARCHAR(10)='en-US'	,
	@PageSize INT=1000,
	@PageIndex INT=1,
	@TotalRows INT=0 OUTPUT 
	
AS

/*
Create: Henry@20101210
Task : 
DB: DB052.bodb02
Original: Age_BetList_SelDeleted

Revisions:
	
	-- 20110216@Jacob: Add column nickname in the result SET
	-- 20110303@Henry: suppport based currency
	- 20110408@Amy: Change function to get Odds value AND odds type
	- 20110714@Henry: remove apositiontaking
	- 20110729@Henry: offer 3 new bettypes for Number Game
	- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120614@Jim: optimize code 	
	- 20120816@Henry: add ShowLiveCasino 
	- 20130411@Jim: support base currency
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
Param's Explanation:
+ @CustID: AgentID
*/

SET NOCOUNT ON

DECLARE @recommend INT
DECLARE @Fromdate DATETIME
DECLARE @Todate DATETIME

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)

SELECT @recommend = recommend 
from customer c WITH(NOLOCK)
inner join 	#currency cy ON c.currency=cy.currencyID						
 WHERE custid=@custid
------------------------------------------
DROP TABLE #Currency 
-----------------------------------------
CREATE TABLE #Data 
(
	Sporttype SMALLINT,
	username NVARCHAR(50),
	CustID INT,
	transid BIGINT,	
	transdate DATETIME,
	winlostdate DATETIME, 
	refno NVARCHAR(50),		
	homeid INT, 
	awayid INT, 
	betteam NVARCHAR(50),
	bettype SMALLINT,		
	hdp1 SMALLMONEY,
	hdp2 SMALLMONEY,
	Modds SMALLMONEY,
	oddstype TINYINT,
	odds SMALLMONEY,
	stake MONEY,
	status NVARCHAR(50),
	liveindicator BIT,
	livehomescore SMALLINT,
	liveawayscore SMALLINT,
	leagueid INT, 
	matchid INT, 
	matchcode NVARCHAR(50),
	race NVARCHAR(50),
	eventdate DATETIME,
	IP VARCHAR(30),
	isNeutral BIT,
	betid BIGINT,
	currency SMALLINT,
	showtime NVARCHAR(50) -- table - shoe - hand of Live Casino
)


INSERT INTO #Data
SELECT 
	m.Sporttype,
	b.Username,   
	b.CustID, 
	b.TransID,     
	b.Transdate,   
	b.winlostdate,  
	b.refno,  
	m.HomeID,  
	m.AwayID,  
	b.betteam,
	Bettype, 
	CONVERT(FLOAT, b.hdp1) AS Hdp1,    
	CONVERT(FLOAT, b.hdp2) AS Hdp2,    
	modds,
	b.OddsType,
	b.odds,
	b.Stake,  
	b.Status,
	b.Liveindicator, 
	b.Livehomescore, 
	b.Liveawayscore, 		 
	m.LeagueID,
	m.matchid,
	m.matchcode,
	'' AS Race,
	eventdate,
	b.IP AS IP,
	ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
	b.betid,
	b.currency,
	CASE WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime
FROM 
	bettrans AS b WITH (NOLOCK)
	INNER JOIN (SELECT sporttype, homeid, awayid, leagueid, matchid, matchcode, eventdate, isneutral,showtime FROM match (NOLOCK) WHERE eventdate > DATEADD(DAY,-3,CURRENT_TIMESTAMP)
				) AS m ON b.matchid = m.matchid
WHERE
	b.custid = @CustID
	AND b.recommend = @recommend
	AND b.statusID IN (101,102)
	
	
UNION ALL
SELECT 
	l.Sporttype,
	b.Username,  
	b.CustID, 
	b.TransID,     
	b.Transdate,   
	b.winlostdate,  
	b.refno, 
	CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN vhr.HomeID ELSE m.HomeID END ,  
	0 AS AwayID,  
	'' AS Betteam,    
	Bettype, 
	0 AS Hdp1,    
	0 AS Hdp2, 
	modds,   
	0 AS OddsType, 
	b.odds AS odds,
	b.Stake,  
	b.status,
	0 AS Liveindicator, 
	0 AS Livehomescore, 
	0 AS Liveawayscore,  
	CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN  vhr.HomeID ELSE m.LeagueID END,
	CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN vhr.orid ELSE b.matchID END AS matchid,
	CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN vhr.matchcode ELSE m.matchcode END,
	CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN vhr.groupmatch ELSE m.groupmatch END AS Race,
	CASE WHEN b.bettype IN (1231, 1232, 1233, 1237, 1238) THEN vhr.eventdate ELSE m.eventdate END ,
	b.IP AS IP,
	CONVERT(BIT,0) AS IsNeutral,
	b.betid,
	b.currency,
	'' AS ShowTime
FROM 
	bettrans AS b WITH (NOLOCK)
	INNER JOIN (SELECT teamid AS homeid, leagueid, orid, matchcode, groupmatch, eventdate
				FROM outright (NOLOCK) WHERE eventdate > DATEADD(DAY,-3,CURRENT_TIMESTAMP)
				) AS m ON b.matchid = m.orid
	INNER JOIN league l WITH (NOLOCK) ON m.leagueid = l.leagueid
	INNER JOIN (
				SELECT vso.RacerID as homeid,
						vsr.LeagueID,
						vso.Orid,
						CONVERT(VARCHAR(20),vso.RacerNum) as matchcode,
						'' groupmatch,
						vso.EventDate
				FROM dbo.VSOutright vso (NOLOCK) 
				INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso.EventID=vsr.EventID
				WHERE 	vso.eventdate > DATEADD(DAY,-3,CURRENT_TIMESTAMP)
				) as vhr ON b.oddsid=vhr.Orid
				
WHERE		
	b.bettype in (10,31,32,33,41,42,43,1231, 1232, 1233, 1237, 1238 )
	AND b.recommend = @recommend
	AND b.custid = @CustID
	AND b.statusID IN (101,102)
	
DECLARE @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

SELECT @FromDate = MIN(winlostdate) from #Data
SELECT @ToDate = MAX(winlostdate) FROM #Data

IF @TotalRows = 0  
BEGIN 
	 SELECT @TotalRows = COUNT(transid) FROM #Data
END

CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)
		

		
SELECT A.* 
FROM
(
	SELECT  
			ROW_NUMBER() over(ORDER BY eventdate, matchid, b.custid, transid DESC) AS RowNum,
			SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
			b.* ,
			stake*e.USD stakeUSD,
			stake*e.EUR stakeEUR
			
	FROM #Data b
	INNER JOIN customer c WITH(NOLOCK) ON c.custid=b.custid 
	INNER JOIN #TempExchange e
    ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Todate THEN @Todate ELSE b.winlostdate END)  AND e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd	

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

IF EXISTS (SELECT TOP 1 1 FROM #Data WHERE Bettype BETWEEN 1101 AND 1199)
BEGIN 
	INSERT INTO @BettransDetail
	SELECT 
		BG.refno, 
		BG.odds, 
		BG.stake,
		BG.status, 
		BG.apositiontaking, 
		BG.bettype,
		BG.betteam,
		BG.stake*e.EUR,	
		BG.stake*e.USD
	FROM bettransg BG WITH (NOLOCK)
	INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = b.custid
	INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
	WHERE B.Bettype BETWEEN 1101 AND 1199	
END 

IF EXISTS (SELECT TOP 1 1 FROM #Data WHERE Bettype=1233)
BEGIN 
	INSERT INTO @BettransDetail
	SELECT 
		BG.refno, 
		BG.odds, 
		BG.stake,
		BG.status, 
		BG.apositiontaking, 
		BG.bettype,
		BG.betteam,
		BG.stake*e.EUR,	
		BG.stake*e.USD
	FROM bettransm BG WITH (NOLOCK)
	INNER JOIN #Data B ON BG.refno = B.refno and BG.custid = b.custid
	INNER JOIN #TempExchange e ON e.ExchangeDate = B.winlostdate   AND e.exchangeid = B.currency
	WHERE B.Bettype=1233
END 

SELECT * FROM @BettransDetail 
ORDER BY RefNo,Bettype 


DROP TABLE #TempExchange 
DROP TABLE #Data 

GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelDeleted] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelDeleted] TO [vnteam]

