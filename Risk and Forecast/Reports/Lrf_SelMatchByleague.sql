USE [bodb_licensee]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Lrf_SelMatchByleague]
	 @LeagueID INT 
	,@Fromdate SMALLDATETIME
	,@Todate SMALLDATETIME
AS 
/*
Created: 20140102@Florent
Task : Get matchID from LeagueID
DB: DBLIC/bodb_Licensee

Revisions:
Param's Explanation:
	
*/

DECLARE @match TABLE (
	MatchID smallint
	,matchName nvarchar(100)
	,SportID SMALLINT 
)

--SELECT val into #league FROM bodb02.dbo.strSplit(@LeagueList,',') 

;WITH cte_match
as (
	SELECT DISTINCT m.matchid,m.homeid,m.awayid,m.leagueid
	  FROM bodb02.dbo.match AS m WITH (NOLOCK) WHERE m.eventdate BETWEEN @Fromdate AND @Todate
	  AND m.leagueid =@LeagueID
	UNION
	SELECT DISTINCT m.matchid,m.homeid,m.awayid,m.leagueid
	 FROM bodb02.dbo.match14 AS m WITH (NOLOCK) WHERE m.eventdate BETWEEN @Fromdate AND @Todate
	 AND m.leagueid =@LeagueID
	 UNION
	SELECT DISTINCT m.matchid,m.homeid,m.awayid,m.leagueid
	 FROM DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) WHERE m.eventdate BETWEEN @Fromdate AND @Todate
	 AND m.leagueid =@LeagueID
)

SELECT DISTINCT m.matchid,m.homeid,m.awayid,m.leagueid
FROM cte_match AS m
ORDER BY m.leagueid 


GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] AS [dbo]
GO