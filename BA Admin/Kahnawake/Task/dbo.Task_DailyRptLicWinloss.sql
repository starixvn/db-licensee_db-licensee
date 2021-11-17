ALTER PROCEDURE [dbo].[Task_DailyRptLicWinloss]
	@winlostdate DATETIME
AS
/*
Created by:[Henry]
Date: 2012-02-20
Task: daily summary for Licensee
DB: bodb_MoveBet
Revisions:
	
   
 */

SET NOCOUNT ON 

--Delete before running
delete from rptLicWinloss with(rowlock) where winlostdate = @winlostdate

--Member Level
INSERT INTO rptLicWinloss
	(
	[winlostdate],[username],[custid],[roleid],[recommend],[mrecommend],[srecommend],[turnover]
    ,[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[BetCount],[Currency],[sporttype],[bettype],[statusID],[isMobile]
	)
SELECT @winlostdate,bettrans.username,bettrans.custid, 1, bettrans.recommend, bettrans.mrecommend, bettrans.srecommend,
	SUM(		
		case when bettrans.liveawayscore = 0 and bettrans.bettype IN(33,43) then ABS(bettrans.stake/2) else ABS(bettrans.stake) end		 
		) as TurnOver,
	SUM(winlost-actual_stake)  winlost,
	SUM(awinlost) awinlost,
	SUM(mwinlost) mwinlost,
	SUM(ISNULL(swinlost,0)) swinlost,
	SUM(playercomm) playercomm,
	SUM(comm) comm,
	SUM(acomm) acomm,
	SUM(ISNULL(scomm,0)) scomm,
	
	
	COUNT(bettrans.transid) BetCount,
	bettrans.currency,
	
	CASE
		WHEN bettype IN (71,72) THEN 251
		WHEN bettype = 73 THEN 252 --Bingo 
		WHEN bettype BETWEEN 81 AND 120 THEN 161 --Number Game 
		WHEN bettype BETWEEN 51 AND 69 THEN 201
		WHEN bettype IN (31,32,33,41,42,43) THEN 151
		ELSE 0 END sporttype,
	CASE WHEN bettype IN (71,72,73) THEN bettype ELSE 0 END bettype,
	
	--114: half win, 115: half lose
	CASE 
		WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
		WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
		ELSE bettrans.statusID END AS statusID,
	
	CASE 
		WHEN bettrans.betfrom IN ('s','m','h') THEN 1 ELSE 0 END AS isMobile	
		
		
FROM
	dbo.bettrans bettrans WITH (NOLOCK)
WHERE
	bettrans.winlostdate = @winlostdate AND
	bettrans.statusID IN (101,111,112,113) AND --REJECT, DRAW, WON, LOSE
	--bettrans.bettype <= 19000 : old condition
	bettrans.bettype<=999
	
GROUP BY
	bettrans.custid, bettrans.recommend, bettrans.mrecommend, bettrans.srecommend,
	bettrans.username,bettrans.currency,
	CASE
		WHEN bettype IN (71,72) THEN 251
		WHEN bettype = 73 THEN 252 --Bingo
		WHEN bettype BETWEEN 81 AND 120 THEN 161 --Number Game 
		WHEN bettype BETWEEN 51 AND 69 THEN 201
		WHEN bettype IN (31,32,33,41,42,43) THEN 151
		ELSE 0 END,
	CASE WHEN bettype IN (71,72,73) THEN bettype ELSE 0 END,
	CASE 
		WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
		WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
		ELSE bettrans.statusID END,
	CASE 
		WHEN bettrans.betfrom IN ('s','m','h') THEN 1 ELSE 0 END

--Agent Level (sum on member)
INSERT INTO rptLicWinloss
        (
        [winlostdate],[username],[custid],[roleid],[recommend],[mrecommend],[srecommend],[turnover]
        ,[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[BetCount],[Currency],[sporttype],[bettype],[statusID],[isMobile]
        )
    SELECT
        @winlostdate,'' as username,b.recommend,2 AS roleid,b.recommend,b.mrecommend,b.srecommend,
        SUM(turnover),
        SUM(winlost),
        SUM(awinlost),
        SUM(mwinlost),
        SUM(swinlost),
        SUM(playercomm),
        SUM(comm),
        SUM(acomm),
        SUM(scomm),
        SUM(BetCount),
        b.currency,
        b.sporttype,
        b.bettype,
        b.statusID,
		b.isMobile
    FROM
        rptLicWinloss b (nolock)
    WHERE
        b.winlostdate = @winlostdate
        and b.roleid = 1
    GROUP BY
        b.recommend,b.mrecommend,b.srecommend,
        b.currency,
        b.sporttype,
        b.bettype,
        b.statusID,
		b.isMobile

GO
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptLicWinloss] TO [vnteam]
GO  