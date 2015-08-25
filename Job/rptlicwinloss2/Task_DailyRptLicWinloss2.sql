USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_DailyRptLicWinloss2]    Script Date: 07/01/2015 09:28:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DailyRptLicWinloss2]
	@winlostdate DATETIME
AS
/*
Created by:[Henry]
Date: 2011-09-20
Task: daily summary for Licensee
DB: DBEXT.BODB02
Revisions:
	- 20111208@Jim: Change bettype condition (bettype<=19000=>bettype<999)
	- 20120116@Henry: Add column IsMobile and Sum the bets that from mobile
	- 20120803@Henry: fix the commission formula
	- 20120814@Henry: sum Livecasino, games, virtual sport
	- 20120816@Henry: include betfrom "l" for smartphone
	- 20120109@Henry: sum wap & smartphone betfrom
	- 20130903@Jim: support Virtual Horse Racing
	- 20131014@Jim: support Virtual Tennis
	- 20131128@Jim: revert code to Group by All Virtual Sport into sporttypeID=180
	- 20140310@Jim: offer KENO 
	- 20140820@Jim: support to add more value bet BetEffective (RedmineID : #20518)
	- 20150618@Patrick: #36263: Fix super balance issue for: AGC, GD & VG
    - 20150630@Jim: add MicroGaming 
	- 20150702@Patrick: Support BetTrade
	- 20150824@Patrick: Not category BA's bettrade ticket
 */

SET NOCOUNT ON 

IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.bettrans14 WITH(nolock) WHERE winlostdate = @winlostdate)
OR EXISTS(SELECT 1 FROM DB06.bodb02.dbo.SystemSettings WITH (NOLOCK) WHERE VValue = '1' AND VName in ('isMovingBet','isArchivingBet'))
BEGIN
	PRINT 'data not in bettrans14 OR movebet/archive process is now running!!!!'
	RETURN
END

DELETE FROM bodb_Licensee.dbo.rptLicWinloss2 WITH (rowlock) WHERE winlostdate = @winlostdate

DECLARE @MinTransId BIGINT, @MaxTransId BIGINT
SELECT @MinTransId = MIN(TransId), @MaxTransId = MAX(TransId)
FROM dbo.bettrans14 bt WITH (NOLOCK)
WHERE WinlostDate = @WinlostDate

DECLARE @BATransIds TABLE (TransId BIGINT)
INSERT INTO @BATransIds(TransId)
SELECT TransId
FROM bodb_Licensee.dbo.LicenseeBATransaction WITH(NOLOCK)
WHERE TransId BETWEEN @MinTransId AND @MaxTransId

--get more BA's bettrade ticket
INSERT INTO @BATransIds(TransId)
SELECT TransId
FROM dbo.bettrans14 WITH(NOLOCK)
WHERE WinlostDate = @winlostdate 
	AND refno IN (SELECT TransId FROM @BATransIds)
	AND transid NOT IN (SELECT TransId FROM @BATransIds)

--Member Level
INSERT INTO bodb_Licensee.dbo.rptLicWinloss2
		(
		[winlostdate]
		,[username]
		,[username2]
		,[custid]
		,[roleid]
		,[recommend]
		,[mrecommend]
		,[srecommend]
		,[turnover]
		,[winlost]
		,[BetEffective]
		,[awinlost]
		,[mwinlost]
		,[swinlost]
		,[playercomm]
		,[comm]
		,[acomm]
		,[scomm]
		,[winlostvirtual]
		,[commvirtual]
		,[BetCount]
		,[Currency]
		,[sporttype]
		,[bettype]
		,[statusID]
		,[isBA]
		,[isMobile]
		,[betfrom]
		)
SELECT @winlostdate
	  ,customer.username
	  ,customer.username2
	  ,customer.custid
	  ,1
	  ,customer.recommend
	  ,customer.mrecommend
	  ,customer.srecommend
	,SUM(		
		CASE WHEN bettrans.liveawayscore = 0 AND bettrans.bettype IN(33,43) 
			 THEN ABS(bettrans.stake/2) ELSE ABS(bettrans.stake) 
			 END
		) AS TurnOver
	,SUM(winlost-actual_stake)  winlost
	,CASE WHEN bettrans.statusID IN (112,113) 
		  THEN SUM(ABS(winlost-actual_stake)) 
		  ELSE 0
		  END BetEffective 
	,SUM(awinlost) awinlost
	,SUM(mwinlost) mwinlost
	,SUM(ISNULL(swinlost,0)) swinlost
	,SUM(playercomm) playercomm
	,SUM(comm) comm
	,SUM(acomm) acomm
	,SUM(ISNULL(scomm,0)) scomm
	,SUM((winlost - actual_stake)*virtualrate) AS WinlostVirtual
	,SUM ((comm)*virtualrate) AS CommVirtual
	,COUNT(bettrans.transid) BetCount
	,bettrans.currency
	,CASE
		WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 81 AND 120 THEN 161 --Number Game 
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live casino
		WHEN (bettype BETWEEN 1201 AND 1299 ) THEN 180  --Virtual Sport
		WHEN bettype BETWEEN 51 AND 69 THEN 201
		WHEN bettype IN (31,32,33,41,42,43) THEN 151
		WHEN bettype BETWEEN 1501  AND 1599 THEN 202 -- Keno
		WHEN bettype BETWEEN 1800 AND 1899 THEN 250 -- AGC
		WHEN bettype BETWEEN 1700 AND 1799 THEN 255 -- GD
		WHEN bettype BETWEEN 1900 AND 1999 THEN 249 -- VG
		WHEN bettype BETWEEN 2001 AND 2099 THEN 203
		ELSE 0 END sporttype
	,CASE WHEN bettype IN (71,72,1000,901,902,903) THEN bettype ELSE 0 END bettype
	--114: half win, 115: half lose
	,CASE 
		WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
		WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
		ELSE bettrans.statusID END AS statusID
	,CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END AS isBA
	,CASE 
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN 1 ELSE 0 END AS isMobile	
	,CASE    
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN bettrans.betfrom ELSE '' END AS betfrom	
FROM
	dbo.bettrans14 bettrans WITH (NOLOCK)
	INNER JOIN dbo.customer WITH (NOLOCK) ON bettrans.custid=customer.custid
	LEFT JOIN @BATransIds ba ON bettrans.transid = BA.transid
WHERE
	bettrans.winlostdate = @winlostdate AND
	customer.srecommend IN (SELECT custid FROM f_DepSuper_1('All')) AND
	bettrans.statusID IN (101,111,112,113) AND --REJECT, DRAW, WON, LOSE
	bettrans.bettype<=19999
GROUP BY
	customer.custid
	,customer.recommend
	,customer.mrecommend
	,customer.srecommend
	,customer.username
	,customer.username2
	,bettrans.currency
	,bettrans.statusID
	,CASE
		WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 81 AND 120 THEN 161 --Number Game 
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live casino
		WHEN (bettype BETWEEN 1201 AND 1299 ) THEN 180  --Virtual Sport
		WHEN bettype BETWEEN 51 AND 69 THEN 201
		WHEN bettype IN (31,32,33,41,42,43) THEN 151
		WHEN bettype BETWEEN 1501  AND 1599 THEN 202
		WHEN bettype BETWEEN 1800 AND 1899 THEN 250 -- AGC
		WHEN bettype BETWEEN 1700 AND 1799 THEN 255 -- GD
		WHEN bettype BETWEEN 1900 AND 1999 THEN 249 -- VG
		WHEN bettype BETWEEN 2001 AND 2099 THEN 203 -- Microgame
		ELSE 0 END
	,CASE WHEN bettype IN (71,72,1000,901,902,903) THEN bettype ELSE 0 END
	,CASE 
		WHEN bettrans.statusID = 112 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 114 
		WHEN bettrans.statusID = 113 AND bettrans.bettype IN(1,3,7,8,17,18) AND ABS(modds) = 0.25 THEN 115
		ELSE bettrans.statusID END
	,CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END
	,CASE 
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN 1 ELSE 0 END
	,CASE    
		WHEN bettrans.betfrom IN ('s','m','h','l') THEN bettrans.betfrom ELSE '' END

--Agent Level (sum on member)
INSERT INTO bodb_Licensee.dbo.rptLicWinloss2
        (
        [winlostdate]
		,[username]
		,[username2]
		,[custid]
		,[roleid]
		,[recommend]
		,[mrecommend]
		,[srecommend]
		,[turnover]
        ,[winlost]
		,[BetEffective]
		,[awinlost]
		,[mwinlost]
		,[swinlost]
		,[playercomm]
		,[comm]
		,[acomm]
		,[scomm]
		,[winlostvirtual]
		,[commvirtual]
		,[BetCount]
		,[Currency]
		,[sporttype]
		,[bettype]
		,[statusID]
		,[isBA]
		,[isMobile]
		,[betfrom]
        )
    SELECT
        @winlostdate
		,c.username
		,c.username2
		,c.custid
		,2 AS roleid
		,b.recommend
		,b.mrecommend
		,b.srecommend
        ,SUM(turnover)
        ,SUM(winlost)
		,SUM(BetEffective)
        ,SUM(awinlost)
        ,SUM(mwinlost)
        ,SUM(swinlost)
        ,SUM(playercomm)
        ,SUM(comm)
        ,SUM(acomm)
        ,SUM(scomm)
        ,SUM(winlostvirtual)
        ,SUM(commvirtual)
        ,SUM(BetCount)
        ,b.currency
        ,b.sporttype
        ,b.bettype
        ,b.statusID
		,b.isBA
		,b.isMobile
		,b.betfrom
    FROM
        bodb_Licensee.dbo.rptLicWinloss2 b (nolock)
        INNER JOIN dbo.customer c (nolock) ON b.recommend = c.custid
    WHERE
        b.winlostdate = @winlostdate
        and b.roleid = 1
        and c.roleid = 2
    GROUP BY
        c.username
		,c.username2
		,c.custid
		,b.recommend
		,b.mrecommend
		,b.srecommend
        ,b.currency
        ,b.sporttype
        ,b.bettype
        ,b.statusID
		,b.isBA
		,b.isMobile
		,b.betfrom

--Master Level (sum on member)
INSERT INTO bodb_Licensee.dbo.rptLicWinloss2
        (
        [winlostdate]
		,[username]
		,[username2]
		,[custid]
		,[roleid]
		,[recommend]
		,[mrecommend]
		,[srecommend]
		,[turnover]
        ,[winlost]
		,[BetEffective]
		,[awinlost]
		,[mwinlost]
		,[swinlost]
		,[playercomm]
		,[comm]
		,[acomm]
		,[scomm]
		,[winlostvirtual]
		,[commvirtual]
		,[BetCount]
		,[Currency]
		,[sporttype]
		,[bettype]
		,[statusID]
		,[isBA]
		,[isMobile]
		,[betfrom]
        )
SELECT
    @winlostdate
	,c.username
	,c.username2
	,c.custid
	,3 AS roleid
	,0
	,b.mrecommend
	,b.srecommend
    ,SUM(turnover)
    ,SUM(winlost)
	,SUM(BetEffective)
    ,SUM(awinlost)
    ,SUM(mwinlost)
    ,SUM(swinlost)
    ,SUM(playercomm)
    ,SUM(comm)
    ,SUM(acomm)
    ,SUM(scomm)
    ,SUM(winlostvirtual)
    ,SUM(commvirtual)
    ,SUM(BetCount)
    ,b.currency
    ,b.sporttype
    ,b.bettype
    ,b.statusID
	,b.isBA
	,b.isMobile
	,b.betfrom
FROM
    bodb_Licensee.dbo.rptLicWinloss2 b (NOLOCK)
    INNER JOIN dbo.customer c (NOLOCK) ON b.mrecommend = c.custid
WHERE
    b.winlostdate = @winlostdate
    AND b.roleid = 1
    AND c.roleid = 3
GROUP BY
    c.username
	,c.username2
	,c.custid
	,b.mrecommend
	,b.srecommend
    ,b.currency
    ,b.sporttype
    ,b.bettype
    ,b.statusID
	,b.isBA
	,b.isMobile
	,b.betfrom

--Super Level (Sum on member)
INSERT INTO bodb_Licensee.dbo.rptLicWinloss2
        (
        [winlostdate]
		,[username]
		,[username2]
		,[custid]
		,[roleid]
		,[recommend]
		,[mrecommend]
		,[srecommend]
		,[turnover]
        ,[winlost]
		,[BetEffective]
		,[awinlost]
		,[mwinlost]
		,[swinlost]
		,[playercomm]
		,[comm]
		,[acomm]
		,[scomm]
		,[winlostvirtual]
		,[commvirtual]
		,[BetCount]
		,[Currency]
		,[sporttype]
		,[bettype]
		,[statusID]
		,[isBA]
		,[isMobile]
		,[betfrom]
        )
SELECT
	@winlostdate
	,c.username
	,c.username2
	,c.custid
	,4 AS roleid
	,0
	,0
	,b.srecommend
	,SUM(turnover)
	,SUM(winlost)
	,SUM(BetEffective)
	,SUM(awinlost)
	,SUM(mwinlost)
	,SUM(swinlost)
	,SUM(playercomm)
	,SUM(comm)
	,SUM(acomm)
	,SUM(scomm)
	,SUM(winlostvirtual)
	,SUM(commvirtual)
	,SUM(BetCount)
	,b.currency
	,b.sporttype
	,b.bettype
	,b.statusID
	,b.isBA
	,b.isMobile
	,b.betfrom
FROM
    bodb_Licensee.dbo.rptLicWinloss2 b (nolock)
    INNER join dbo.customer c (nolock) ON b.srecommend = c.custid
WHERE
    b.winlostdate = @winlostdate
    and b.roleid = 1
    and c.roleid = 4
GROUP BY
    c.username
	,c.username2
	,c.custid
	,b.srecommend
    ,b.currency
    ,b.sporttype
    ,b.bettype
    ,b.statusID
	,b.isBA
	,b.isMobile
	,b.betfrom
