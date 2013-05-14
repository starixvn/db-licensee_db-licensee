ALTER PROCEDURE [dbo].[PIH_BettransSel]  
	@tstamp timestamp
AS  
/*  Created: Viet  
	Date: 2012-07-16
    TASk : Get ticket Kahnawake server
    DB: DB054.bodb_PIH
   
    Revisions:  
		
	Param's Explanation:  
*/  
SET NOCOUNT ON  

SELECT TOP 500
	[transid]
	,b.[custid]
	,[transdate]
	,[oddsid]
	,[hdp1]
	,[hdp2]
	,[odds]
	,[stake]
	,[status]
	,[winlost]
	,[awinlost]
	,[mwinlost]
	,[playercomm]
	,[comm]
	,[acomm]
	,[apositiontaking]
	,[mpositiontaking]
	,[tpositiontaking]
	,[playerdiscount]
	,[discount]
	,[adiscount]
	,[livehomescore]
	,[liveawayscore]
	,[liveindicator]
	,[betteam]
	,[creator]
	,[refno]
	,[winlostdate]
	,[betfrom]
	,[betcheck]
	,[checktime]
	,[oddsspread]
	,[actualrate]
	,[matchid]
	,[recommend]
	,[mrecommend]
	,[ruben]
	,[betid]
	,[statuswinlost]
	,[modds]
	,[bettype]
	,[betdaqid]
	,[actual_stake]
	,[currency]
	,[transdesc]
	,[sdiscount]
	,[scomm]
	,[spositiontaking]
	,[swinlost]
	,[srecommend]
	,[username]
	,[virtualrate]
	,[oddstype]
	,[statusid]
	,[currency2]
	,[tstamp]
	
FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN (
		select custid from bodb02.dbo.Customer with(nolock) where roleid=2 and site='789y'
	)a on b.recommend = a.custid		
WHERE
	tstamp > @tstamp
	AND (b.bettype < 31 OR (b.Bettype BETWEEN 121 AND 999))		
	AND statusID <> 1
ORDER BY tstamp ASC
FOR XML PATH('bettrans'), ROOT ('root')
	
GO
GRANT EXECUTE ON [dbo].[PIH_BettransSel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PIH_BettransSel] TO [vnTeam] AS [dbo]