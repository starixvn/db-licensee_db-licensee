USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptCustomerMatch_Bettrans_bk]    Script Date: 19/03/2014 11:23:02 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Task_rptCustomerMatch_Bettrans_bk]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: Winloss By League
	Date: 2013-11-25
	DB: DBACC.bodb02
	Original: 
	Revision: 
	Parameter's Explanation:			
*/
SET NOCOUNT ON;

;WITH cte_bettrans
AS (
	SELECT a.CustID		
		,a.recommend
		,a.matchid
		,a.oddsid
		,a.bettype
		,SUM(CASE 
				WHEN a.liveawayscore = 0 AND a.bettype IN(33,43) 
					THEN ABS(a.stake/2) 
				ELSE ABS(a.stake) 
				END) AS stake
		,sum(a.winlost- a.actual_stake) winlost		
		,a.Odds
		,a.oddstype
		,CASE 
		WHEN a.statusID = 112
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
			THEN 114		
		WHEN a.statusID = 113
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
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
	FROM bodb_archive.dbo.bettrans_bk a WITH (NOLOCK)
	INNER JOIN DBLIC.bodb_licensee.dbo.LicenseeCust LC WITH (NOLOCK)  ON a.recommend = lc.custid
	LEFT JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON a.transid=ba.transid
	WHERE a.winlostdate BETWEEN @fromdate AND @todate
	AND a.statusID IN (111,112,113) 
	GROUP BY 
		a.CustID		
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
		WHEN a.statusID = 113
			AND a.bettype IN (1, 3, 7, 8, 17, 18)
			AND ABS(modds) = 0.25
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
	FROM bodb_archive.dbo.VSOutright_bk o WITH (NOLOCK)
	INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
	WHERE EventDate BETWEEN @fromdate AND @todate
)

INSERT INTO bodb_report.dbo.rptCustomerMatch
SELECT
	a.CustID
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
LEFT JOIN bodb_archive.dbo.MATCH_BK b WITH (NOLOCK) ON a.matchid = b.matchid
LEFT JOIN cte_raceinfo result ON a.oddsid = result.Orid
LEFT JOIN bodb_archive.dbo.outright_bk AS ob WITH (NOLOCK) ON a.matchid = ob.orid
GROUP BY
	a.CustID
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
GO
