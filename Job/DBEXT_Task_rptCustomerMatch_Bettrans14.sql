USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptCustomerMatch_Bettrans14]    Script Date: 14/02/2014 11:32:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Task_rptCustomerMatch_Bettrans14] @Date SMALLDATETIME
AS
/*	
	Created	: Florent Nguyen
	Task: Customer Performance Report  
	Date: 2013-11-25
	DB: DBEXT.bodb02
	Original: 
	Revision:
	Parameter's Explanation:			
*/
SET NOCOUNT ON;
	--DECLARE @Fromdate DATETIME,
	--	@Todate DATETIME
	--SELECT @Fromdate='2013-10-17',@todate='2013-10-17'
IF exists(SELECT TOP 1 1 FROM bodb_LicenseeReport.dbo.rptCustomerMatch AS rct WITH (NOLOCK) WHERE rct.winlostdate=@date)
	BEGIN
		DELETE bodb_LicenseeReport.dbo.rptCustomerMatch WHERE winlostdate=@Date
	END 	
;WITH cte_isBATrans
AS (
	--SELECT transid
	--FROM bodb_licensee.dbo.LicenseeBATransaction WITH (NOLOCK)
	--WHERE Transdate=@Date	
	select transid from dbo.bettrans14 with (nolock) 
	WHERE winlostdate =@Date
	and ( bettype < 31 OR (bettype BETWEEN 121 AND 999))
	and tpositiontaking=0
	)
	,cte_tempLicenseeCust
AS (
	SELECT currency
		,custid
	FROM bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK)
	)
	,cte_bettrans
AS (
	SELECT a.CustID		
		,a.recommend
		,a.matchid
		,a.oddsid
		,a.bettype
		,SUM(ABS(a.stake)) as stake
		,sum(a.winlost- a.actual_stake) winlost		
		,a.Odds
		,a.oddstype
		,CASE 
		WHEN a.statusID = 112
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 114
		WHEN a.statusID = 112
			AND a.liveawayscore = 0 
			AND a.bettype IN(33,43) 
			THEN 114
		WHEN a.statusID = 113
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 115
		WHEN a.statusID = 113
			AND a.liveawayscore = 0 
			AND a.bettype IN(33,43)
			THEN 115
		ELSE a.statusID
		END AS statusID
		,a.winlostdate
		,COUNT(a.custid) betcount
		,CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END AS isBA
		,sum(awinlost) awinlost
		,sum(comm) comm
		,sum(playercomm) playercomm
	FROM dbo.bettrans14 a WITH (NOLOCK)
	INNER JOIN cte_tempLicenseeCust lc ON a.recommend = lc.custid
	LEFT JOIN cte_isBATrans AS BA ON a.transid = ba.transid
	WHERE a.winlostdate =@date 
			AND a.statusID IN (111, 112, 113)
	GROUP BY a.CustID		
		,a.recommend
		,a.matchid
		,a.oddsid
		,a.bettype
		,a.Odds
		,a.oddstype
		,CASE 
		WHEN a.statusID = 112
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 114
		WHEN a.statusID = 112
			AND a.liveawayscore = 0 
			AND a.bettype IN(33,43) 
			THEN 114
		WHEN a.statusID = 113
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 115
		WHEN a.statusID = 113
			AND a.liveawayscore = 0 
			AND a.bettype IN(33,43)
			THEN 115
		ELSE a.statusID
		END
		,a.winlostdate
		,CASE 
		WHEN BA.transid IS NULL THEN 0
		WHEN BA.transid IS NOT NULL THEN 1 END
	)
	,cte_raceinfo
AS (
	SELECT o.Orid
		,r.SportType
		,r.LeagueID
	FROM dbo.VSOutright14 o WITH (NOLOCK)
	INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
	WHERE EventDate =@Date
	)
INSERT INTO bodb_LicenseeReport.dbo.rptCustomerMatch
SELECT a.CustID
	,a.matchid
	,a.oddsid
	,CASE 
		WHEN a.bettype IN (9, 29)
			THEN - 9
		WHEN a.bettype = 10
			OR (
				a.bettype > 30
				AND a.bettype < 50
				)
			THEN ISNULL(ob.leagueid, - 1)
		WHEN a.bettype IN (1231, 1232, 1233, 1237, 1238)
			THEN isnull(result.LeagueID,-1)
		ELSE isnull(b.LeagueID, - 1)
		END LeagueID
	,a.bettype
	,a.Odds
	,a.oddstype
	,a.statusID
	,sum(stake)stake
	,sum(winlost) winlost  
	,winlostdate	
	,sum(awinlost) awinlost
	,sum(comm) Comm
	,sum(playercomm) playercomm
	,a.recommend
	,a.isba		
	,sum(a.betcount) betcount
FROM cte_bettrans a
LEFT JOIN dbo.match14 b WITH (NOLOCK) ON a.matchid = b.matchid
LEFT JOIN cte_raceinfo result ON a.oddsid = result.Orid
LEFT JOIN dbo.outright14 AS ob WITH (NOLOCK) ON a.matchid = ob.orid
GROUP BY a.CustID
	,a.matchid
	,a.oddsid
	,a.bettype
	,a.Odds
	,a.oddstype
	,a.statusID
	,winlostdate	
	,a.recommend
	,a.isba
	,CASE 
		WHEN a.bettype IN (9, 29)
			THEN - 9
		WHEN a.bettype = 10
			OR (
				a.bettype > 30
				AND a.bettype < 50
				)
			THEN ISNULL(ob.leagueid, - 1)
		WHEN a.bettype IN (1231, 1232, 1233, 1237, 1238)
			THEN isnull(result.LeagueID,-1)
		ELSE isnull(b.LeagueID, - 1)
		END 