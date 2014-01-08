USE [bodb02]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Task_rptWinlostbyleague_Bettrans_bk] 
	 @Fromdate SMALLDATETIME
	,@Todate SMALLDATETIME
AS
/*	
	Created	: Florent Nguyen
	Task: Gen data for table bodb_report.dbo.rptWinlostbyLeague
	Date: 2013-11-30
	DB: DBACC.bodb02
	Original: 
	Revision:
	Parameter's Explanation:			
*/
SET NOCOUNT ON;

DELETE bodb_report.dbo.rptWinlostbyLeague
WHERE winlostdate BETWEEN @Fromdate AND @Todate;

WITH cte_isBATrans
AS (
	SELECT transid
	FROM DBLIC.bodb_licensee.dbo.LicenseeBATransaction WITH (NOLOCK)
	WHERE Transdate BETWEEN @fromdate AND DATEADD(DAY, 2, @Todate)
	)
	,cte_tempLicenseeCust
AS (
	SELECT DISTINCT currency
		,custid
	FROM DBLIC.bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK)
	)
	,cte_bettrans
AS (
	SELECT a.winlostdate
		,isnull(a.matchid, ISNULL(a.oddsid, 0)) matchid
		,a.oddsid
		,a.Odds
		,a.bettype
		,SUM(ABS(a.stake)) stake
		,sum(a.winlost - a.actual_stake) winlost
		,SUM(a.awinlost) awinlost
		,SUM(a.comm) comm
		,SUM(a.playercomm) playercomm
		,a.recommend
		,CASE 
			WHEN a.statusID = 112
				AND a.bettype IN (1, 3, 7, 8, 17, 18)
				AND ABS(modds) = 0.25
				THEN 114
			WHEN a.statusID = 112
				AND a.liveawayscore = 0
				AND a.bettype IN (33, 43)
				THEN 114
			WHEN a.statusID = 113
				AND a.bettype IN (1, 3, 7, 8, 17, 18)
				AND ABS(modds) = 0.25
				THEN 115
			WHEN a.statusID = 113
				AND a.liveawayscore = 0
				AND a.bettype IN (33, 43)
				THEN 115
			ELSE a.statusID
			END AS statusID
		,count(1) betcount
		,CASE 
			WHEN BA.transid IS NULL
				THEN 0
			WHEN BA.transid IS NOT NULL
				THEN 1
			END AS isBA
	FROM bodb_archive.dbo.bettrans_bk a WITH (NOLOCK)
	INNER JOIN cte_tempLicenseeCust lc ON a.recommend = lc.custid
	LEFT JOIN cte_isBATrans AS BA ON a.transid = ba.transid
	WHERE a.winlostdate BETWEEN @fromdate AND @todate
		AND a.statusID IN (111, 112, 113) -- win lost draw
	GROUP BY a.matchid
		,a.recommend
		,a.bettype
		,a.Odds
		,a.oddsid
		,CASE 
			WHEN a.statusID = 112
				AND a.bettype IN (1, 3, 7, 8, 17, 18)
				AND ABS(modds) = 0.25
				THEN 114
			WHEN a.statusID = 112
				AND a.liveawayscore = 0
				AND a.bettype IN (33, 43)
				THEN 114
			WHEN a.statusID = 113
				AND a.bettype IN (1, 3, 7, 8, 17, 18)
				AND ABS(modds) = 0.25
				THEN 115
			WHEN a.statusID = 113
				AND a.liveawayscore = 0
				AND a.bettype IN (33, 43)
				THEN 115
			ELSE a.statusID
			END
		,a.winlostdate
		,CASE 
			WHEN BA.transid IS NULL
				THEN 0
			WHEN BA.transid IS NOT NULL
				THEN 1
			END
	)
	,cte_raceinfo
AS (
	SELECT o.Orid
		,r.SportType
		,r.LeagueID
		,r.EventTime
		,o.EventID
		,o.RacerID
	FROM bodb_archive.dbo.VSOutright_bk o WITH (NOLOCK)
	INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
	WHERE o.EventDate BETWEEN @fromdate AND @todate
)

INSERT INTO bodb_report.dbo.rptWinlostbyLeague
SELECT a.winlostdate
	,a.matchid
	,a.oddsid
	,a.Odds
	,bettype
	,sum(stake) stake
	,sum(winlost) winlost
	,sum(awinlost) awinlost
	,sum(comm) comm
	,sum(playercomm) playercomm
	,a.recommend
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
			THEN isnull(result.LeagueID, - 1)
		ELSE isnull(b.LeagueID, - 1)
		END LeagueID
	,statusID	
	,sum(betcount) betcount
	,isba
FROM cte_bettrans a
LEFT JOIN bodb_archive.dbo.MATCH_BK b WITH (NOLOCK) ON a.matchid = b.matchid
LEFT JOIN cte_raceinfo result ON a.oddsid = result.Orid
LEFT JOIN bodb_archive.dbo.outright_bk AS ob WITH (NOLOCK) ON a.matchid = ob.orid
GROUP BY a.winlostdate
	,a.matchid
	,a.oddsid
	,a.Odds
	,a.recommend
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
			THEN isnull(result.LeagueID, - 1)
		ELSE isnull(b.LeagueID, - 1)
		END
	,statusID
	,bettype
	,isba
