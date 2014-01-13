USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_SelLeagueBySport_8828]    Script Date: 10/01/2014 9:09:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Lrf_SelLeagueBySport]
	@LicenseeID int,
	@sportId INT 
	,@Fromdate SMALLDATETIME
	,@Todate SMALLDATETIME
AS 
/*
Created: 20140102@Florent
Task : Get LeagueID from sport type
DB: DBLIC/bodb_Licensee

Revisions:
Param's Explanation:	
*/

DECLARE @sport INT

SET NOCOUNT ON
CREATE TABLE #tblReturn (leagueid INT, leaguename VARCHAR(100),sportid SMALLINT) 


BEGIN
INSERT INTO #tblReturn 
	SELECT DISTINCT l.leagueid, leaguename, l.sporttype
	FROM 
		(
			SELECT DISTINCT m.leagueid
			  FROM bodb02.dbo.match AS m WITH (NOLOCK) WHERE m.eventdate BETWEEN @Fromdate AND @Todate
			UNION
			SELECT DISTINCT m.leagueid
			 FROM bodb02.dbo.match14 AS m WITH (NOLOCK) WHERE m.eventdate BETWEEN @Fromdate AND @Todate
			UNION
			SELECT DISTINCT leagueid
			 FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS rwl WITH (NOLOCK) WHERE rwl.winlostdate BETWEEN @Fromdate AND @Todate
		)MATCH
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON match.leagueid = l.leagueid
	WHERE ((@sportId='0') OR (l.sporttype =@sportId))
		AND l.sporttype<100
	ORDER BY leaguename
END 
SELECT DISTINCT leagueid,leaguename,sportid
FROM #tblReturn 
ORDER BY leaguename

DROP TABLE #tblReturn 


GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerTurnOver] TO [vnteam] AS [dbo]
GO