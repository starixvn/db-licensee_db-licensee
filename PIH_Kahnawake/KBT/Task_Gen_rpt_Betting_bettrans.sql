ALTER PROCEDURE [dbo].[Task_Gen_rpt_Betting_bettrans]
    @date datetime
AS
/*
Created: 20120719@Viet
Task: 
DB: DB054.bodb_PIH

Revisions:

Param's Explanation:

*/
select TOP 1 1 from bodb02.dbo.bettrans with(nolock) where winlostdate = @date and bettype < 19999 and currency = 3
IF @@rowcount = 0 RETURN

DELETE dbo.rpt_Betting WHERE rptDate = @date

INSERT INTO dbo.rpt_Betting (rptDate, SiteID, CurrencyID, Status, BetCount, Turnover, WinLoss)
SELECT @date as winlostdate,
	1003 as site, --789y
	currency,
	statusid as [status],
	COUNT(1) as betcount,
	sum(stake) as turnover,
	sum(winlost-actual_stake) winloss
FROM (	
		SELECT         
			ABS(stake) stake,
			actual_stake,
			winlost,       
			case when bettype in (1, 3, 7, 8, 17, 18, 124, 125) and ABS(modds) = 0.25 and status = 'WON' then 114 --half WON
				 when bettype in (1, 3, 7, 8, 17, 18, 124, 125) and ABS(modds) = 0.25 and status = 'LOSE' then 115 --half LOSE
				 when bettype in (33,43) AND liveawayscore = 0 AND status = 'WON' then 114 --half WON
				 when bettype in (33,43) AND liveawayscore = 0 AND status = 'LOSE' then 115 --half LOSE
			else statusid end as statusid,    
			currency   
		FROM bodb02.dbo.bettrans b (NOLOCK)
			INNER JOIN (
					select custid from bodb02.dbo.customer with(nolock) where roleid = 2 and site = '789y'
				) a on b.recommend = a.custid
		WHERE winlostdate=@date
			AND (bettype<31 OR bettype between 121 and 999)
			AND statusid not in (0,101,102,121)
	) X
GROUP BY currency, statusid


GO
GRANT VIEW DEFINITION ON [dbo].[Task_Gen_rpt_Betting_bettrans] TO [vnTeam] AS [dbo]