ALTER PROCEDURE [dbo].[Lrf_BettransSelBetSlip_Old]
	@transid bigint,
	@Language VARCHAR(10) = 'en-us'
AS
/*
Created: 20101210@Henry
Task : 
DB: DB06.bodb02
Original: [Age_BettransSelBetSlip_Old]

Revisions:
 -- 20110222@Alex: Add more column "nickname"
 -- 20110303@Henry: suppport based currency
 -- 20110408@Amy: Change function to get Odds value AND odds type
 -- 20111229@Jim: remove function :f_GetOddsByBettype,f_ShowOddsByBettype,f_GetChoice
 -- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
   
*/

SET NOCOUNT ON

DECLARE @FromDate DATETIME
DECLARE @ToDate DATETIME
SELECT @Fromdate=MAX( m.eventdate),@Todate=CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
FROM dbo.match14 m (NOLOCK)
GROUP BY  m.eventdate 
	

SELECT 
	c.username,
   substring(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) as nickname,
	b.bettype,
	b.transid,
	m.matchcode, 
	m.matchid, 
	m.homeID,
	m.awayID,		
	b.hdp1,
	b.hdp2,
	b.betid,
	--dbo.Lrf_f_ShowOddsByBettype(b.bettype,b.oddstype) as OddsType ,
	b.OddsType,
	--dbo.Lrf_f_GetOddsByBettype(b.odds,b.bettype,b.oddstype) as odds,
	b.odds,
	b.winlostdate,
	b.status as Status,
	b.stake,
	b.stake*e.USD stakeUSD,
	b.stake*e.EUR stakeEUR,
	b.transdate,
	b.betteam,
	--dbo.Lrf_f_GetChoice(b.betteam, b.bettype,@Language) betteam,
	b.livehomescore,
	b.liveawayscore,
	m.finalhomescore, 
	m.finalawayscore,
	m.hthomescore, 
	m.htawayscore, 
	(b.winlost-actual_stake) as winlost,
	(b.winlost-actual_stake)*e.USD as winlostUSD,
	(b.winlost-actual_stake)*e.EUR as winlostEUR,
	b.liveindicator, 
	IP as IP,
	isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
from 	
	bodb_Archive.dbo.bettrans_bk b with (nolock)

	INNER JOIN customer c with (nolock) on b.custid=c.custid
	LEFT OUTER JOIN bodb_Archive.dbo.match_bk m with (nolock) ON b.matchid=m.matchid	
    INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate))e  
	ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency	
WHERE
	b.transid= @transid

GO

GRANT EXECUTE ON [dbo].[Lrf_BettransSelBetSlip_Old] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BettransSelBetSlip_Old] TO [VNTeam]