USE [bodb02]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Alter PROCEDURE [dbo].[Task_rptWinlostbyleague_Bettrans14] 
	 @Date SMALLDATETIME
AS
/*	
	Created	: Florent Nguyen
	Task: Gen data for table bodb_report.dbo.rptWinlostbyLeague
	Date: 2013-11-30
	DB: DBEXT.bodb02
	Original: 
	Revision:
	Parameter's Explanation:			
*/
SET NOCOUNT ON;

IF EXISTS (SELECT TOP 1 1 FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague WHERE winlostdate =@Date)
BEGIN 
DELETE bodb_LicenseeReport.dbo.rptWinlostbyLeague
WHERE winlostdate =@Date
END;

WITH cte_isBATrans
AS (	
	select transid from dbo.bettrans14with (nolock) 
	WHERE Winlostdate =@Date
	and ( bettype < 31 OR (bettype BETWEEN 121 AND 999))
	and tpositiontaking=0
	)
	,cte_tempLicenseeCust
AS (
	SELECT DISTINCT currency
		,custid
	FROM bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK)
	)
	,cte_bettrans
AS (
	SELECT a.winlostdate
		,isnull(a.matchid, ISNULL(a.oddsid, 0)) matchid
		,a.oddsid
		,a.Odds
		,a.oddstype
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
	FROM dbo.bettrans14 a WITH (NOLOCK)
	INNER JOIN cte_tempLicenseeCust lc ON a.recommend = lc.custid
	LEFT JOIN cte_isBATrans AS BA ON a.transid = ba.transid
	WHERE a.winlostdate =@Date
		AND a.statusID IN (111, 112, 113) -- win lost draw
	GROUP BY a.matchid
		,a.recommend
		,a.bettype
		,a.Odds
		,a.oddstype
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
	FROM dbo.VSOutright14 o WITH (NOLOCK)
	INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
	WHERE o.EventDate BETWEEN @Date AND DATEADD(DAY, 1, @Date)
)

INSERT INTO bodb_LicenseeReport.dbo.rptWinlostbyLeague
SELECT a.winlostdate
	,a.matchid
	,a.oddsid
	,a.Odds
	,a.oddstype
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
LEFT JOIN dbo.match14 b WITH (NOLOCK) ON a.matchid = b.matchid
LEFT JOIN cte_raceinfo result ON a.oddsid = result.Orid
LEFT JOIN dbo.outright14 AS ob WITH (NOLOCK) ON a.matchid = ob.orid
GROUP BY a.winlostdate
	,a.matchid
	,a.oddsid
	,a.Odds
	,a.oddstype
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

GO 
GRANT EXECUTE ON dbo.Task_rptWinlostbyleague_Bettrans14 TO bodblicenseeNet
GRANT VIEW DEFINITION ON dbo.Task_rptWinlostbyleague_Bettrans14 TO vnteam