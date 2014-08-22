USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DailyRptLicWinloss]    Script Date: 01/24/2013 02:49:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
ALTER PROCEDURE [dbo].[Task_DailyRptLicWinloss]
	@winlostdate DATETIME
AS
/*
Created by:[Henry]
Date: 2012-01-08
Task: daily summary for Licensee
DB: DBLIC/BODB02
Revisions:
    - 20130124@Daniel: Change link server alias

	
   
 */

SET NOCOUNT ON 

IF NOT EXISTS(SELECT TOP 1 1 FROM bettrans14 with(nolock) WHERE winlostdate = @winlostdate)
OR EXISTS(SELECT 1 FROM DBACC.bodb02.dbo.SystemSettings WITH (NOLOCK) WHERE VValue = '1' AND VName in ('isMovingBet','isArchivingBet'))
BEGIN
	print 'data not in bettrans14 OR movebet/archive process is now running!!!!'
	RETURN
END

delete from bodb_Licensee.dbo.rptLicWinloss with(rowlock) where winlostdate = @winlostdate

--Member Level
INSERT INTO bodb_Licensee.dbo.rptLicWinloss
	(
	[winlostdate],[username],[username2],[custid],[roleid],[recommend],[mrecommend],[srecommend],[turnover]
    ,[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[winlostvirtual],[commvirtual],[BetCount],[Currency],[sporttype],[bettype],[statusID],[isBA],[isMobile],[betfrom]
	)
SELECT @winlostdate,customer.username,customer.username2,customer.custid, 1, customer.recommend, customer.mrecommend, customer.srecommend,
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
	SUM((winlost - actual_stake)*virtualrate) AS WinlostVirtual,
	SUM ((comm)*virtualrate) AS CommVirtual,
	
	COUNT(bettrans.transid) BetCount,
	bettrans.currency,
	
	CASE
		WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 81 AND 120 THEN 161 --Number Game 
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live casino
		WHEN bettype BETWEEN 1201 AND 1299 THEN 180 --Virtual Sport
		WHEN bettype BETWEEN 51 AND 69 THEN 201
		WHEN bettype IN (31,32,33,41,42,43) THEN 151
		ELSE 0 END sporttype,
	CASE WHEN bettype IN (71,72,1000) THEN bettype ELSE 0 END bettype,
	
	--114: half win, 115: half lose
	CASE 
		WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
		WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
		ELSE bettrans.statusID END AS statusID,
	CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END AS isBA,
	CASE 
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN 1 ELSE 0 END AS isMobile	,
	CASE    
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN bettrans.betfrom ELSE '' END AS betfrom 	
		
		
FROM
	dbo.bettrans14 bettrans WITH (NOLOCK)
	INNER JOIN dbo.customer WITH (NOLOCK) ON bettrans.custid=customer.custid
	LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON bettrans.transid = BA.transid
WHERE
	bettrans.winlostdate = @winlostdate AND
	customer.srecommend IN (SELECT custid FROM f_DepSuper_1('All')) AND
	bettrans.statusID IN (101,111,112,113) AND --REJECT, DRAW, WON, LOSE
	--bettrans.bettype <= 19000 : old condition
	bettrans.bettype<=19999
	
GROUP BY
	customer.custid, customer.recommend, customer.mrecommend, customer.srecommend,
	customer.username,customer.username2,bettrans.currency,
	CASE
		WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 81 AND 120 THEN 161 --Number Game 
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live casino
		WHEN bettype BETWEEN 1201 AND 1299 THEN 180 --Virtual Sport
		WHEN bettype BETWEEN 51 AND 69 THEN 201
		WHEN bettype IN (31,32,33,41,42,43) THEN 151
		ELSE 0 END,
	CASE WHEN bettype IN (71,72,1000) THEN bettype ELSE 0 END,
	CASE 
		WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
		WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
		ELSE bettrans.statusID END,
	CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END,
	CASE 
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN 1 ELSE 0 END,
	CASE    
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN bettrans.betfrom ELSE '' END   	

--Agent Level (sum on member)
INSERT INTO bodb_Licensee.dbo.rptLicWinloss
        (
        [winlostdate],[username],[username2],[custid],[roleid],[recommend],[mrecommend],[srecommend],[turnover]
        ,[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[winlostvirtual],[commvirtual],[BetCount],[Currency],[sporttype],[bettype],[statusID],[isBA],[isMobile],[betfrom]
        )
    SELECT
        @winlostdate,c.username,c.username2,c.custid,2 AS roleid,b.recommend,b.mrecommend,b.srecommend,
        SUM(turnover),
        SUM(winlost),
        SUM(awinlost),
        SUM(mwinlost),
        SUM(swinlost),
        SUM(playercomm),
        SUM(comm),
        SUM(acomm),
        SUM(scomm),
        SUM(winlostvirtual),
        SUM(commvirtual),
        SUM(BetCount),
        b.currency,
        b.sporttype,
        b.bettype,
        b.statusID,
		b.isBA,
		b.isMobile,
		b.betfrom 
    FROM
        bodb_Licensee.dbo.rptLicWinloss b (nolock)
        INNER join customer c (nolock) ON b.recommend = c.custid
    WHERE
        b.winlostdate = @winlostdate
        and b.roleid = 1
        and c.roleid = 2
    GROUP BY
        c.username,c.username2,c.custid,b.recommend,b.mrecommend,b.srecommend,
        b.currency,
        b.sporttype,
        b.bettype,
        b.statusID,
		b.isBA,
		b.isMobile,
		b.betfrom 

--Master Level (sum on member)
INSERT INTO bodb_Licensee.dbo.rptLicWinloss
        (
        [winlostdate],[username],[username2],[custid],[roleid],[recommend],[mrecommend],[srecommend],[turnover]
        ,[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[winlostvirtual],[commvirtual],[BetCount],[Currency],[sporttype],[bettype],[statusID],[isBA],[isMobile],[betfrom]
        )
SELECT
    @winlostdate,c.username,c.username2,c.custid,3 AS roleid,0,b.mrecommend,b.srecommend,
    SUM(turnover),
    SUM(winlost),
    SUM(awinlost),
    SUM(mwinlost),
    SUM(swinlost),
    SUM(playercomm),
    SUM(comm),
    SUM(acomm),
    SUM(scomm),
    SUM(winlostvirtual),
    SUM(commvirtual),
    SUM(BetCount),
    b.currency,
    b.sporttype,
    b.bettype,
    b.statusID,
	b.isBA,
	b.isMobile,
	b.betfrom 
FROM
    bodb_Licensee.dbo.rptLicWinloss b (nolock)
    INNER join customer c (nolock) ON b.mrecommend = c.custid
WHERE
    b.winlostdate = @winlostdate
    and b.roleid = 1
    and c.roleid = 3
GROUP BY
    c.username,c.username2,c.custid,b.mrecommend,b.srecommend,
    b.currency,
    b.sporttype,
    b.bettype,
    b.statusID,
	b.isBA,
	b.isMobile,
	b.betfrom 

--Super Level (Sum on member)
INSERT INTO bodb_Licensee.dbo.rptLicWinloss
        (
        [winlostdate],[username],[username2],[custid],[roleid],[recommend],[mrecommend],[srecommend],[turnover]
        ,[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[winlostvirtual],[commvirtual],[BetCount],[Currency],[sporttype],[bettype],[statusID],[isBA],[isMobile],[betfrom]
        )
SELECT
    @winlostdate,c.username,c.username2,c.custid,4 AS roleid,0,0,b.srecommend,
    SUM(turnover),
    SUM(winlost),
    SUM(awinlost),
    SUM(mwinlost),
    SUM(swinlost),
    SUM(playercomm),
    SUM(comm),
    SUM(acomm),
    SUM(scomm),
    SUM(winlostvirtual),
    SUM(commvirtual),
    SUM(BetCount),
    b.currency,
    b.sporttype,
    b.bettype,
    b.statusID,
	b.isBA,
	b.isMobile,
	b.betfrom 
FROM
    bodb_Licensee.dbo.rptLicWinloss b (nolock)
    INNER join customer c (nolock) ON b.srecommend = c.custid
WHERE
    b.winlostdate = @winlostdate
    and b.roleid = 1
    and c.roleid = 4
GROUP BY
    c.username,c.username2,c.custid,b.srecommend,
    b.currency,
    b.sporttype,
    b.bettype,
    b.statusID,
	b.isBA,
	b.isMobile,
	b.betfrom 




GO
GRANT VIEW DEFINITION ON [dbo].[Task_DailyRptLicWinloss] TO [vnteam] AS [dbo]