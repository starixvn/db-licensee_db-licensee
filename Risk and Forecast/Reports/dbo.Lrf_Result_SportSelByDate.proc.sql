ALTER PROCEDURE Lrf_Result_SportSelByDate
	@EventDate DATETIME
AS
/*
Created: 20101201@Jacob
Task:
DB: DB053.bodb02
Original: Age_Result_SportSelByDate
Revisions:
	20101201@Jacob: Copy source code from Age_Result_SportSelByDate
	20110803@Henry: get more sporttype 152, 153
	20110908@Sophia: Add Condition Where : OR (eventstatus = 'running' AND (mr.ishtcal=1 OR mr.calculate=1)) 
	20111004@Henry:  Edit condition OR to show the row which have mr.IsPending=1  AND (m.eventstatus = 'running' OR m.eventstatus = 'closed') 
	20111025@Henry: Edit condition OR to show the rows which have eventstatus IN ('running','closed') 
	20120321@Henry: Fix bug to not show Casino
	20120815@Jim: add live casino
	20120906@Jim: add virtual sport
	20130722@Jim: add Virtual Horse Racing (Sporttype=181)
	20130916@Jim: add Virtual Tennis (sporttype=186)
*/

SET NOCOUNT ON

DECLARE @toDate		DATETIME,
		@matchcode	VARCHAR(10) --HRDummy
SELECT  @toDate = dateadd(s,-1, dateadd(d, 1, @EventDate))

SELECT distinct sports.sporttype, sportname from sports with (nolock)
	inner join (
	SELECT matchid, eventdate, eventstatus, sporttype 
	from match (nolock)
	UNION ALL
	SELECT matchid, eventdate, eventstatus, sporttype 
	from match14 (nolock)	
	UNION ALL 
	SELECT vso.EventID as matchid,vso.EventDate,vso.EventStatus,vsr.Sporttype
	FROM dbo.VSOutright vso WITH (NOLOCK)
		INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso.EventID=vsr.EventID
	UNION ALL 
	SELECT vso14.EventID as matchid,vso14.EventDate,vso14.EventStatus,vsr.Sporttype
	FROM dbo.VSOutright14 vso14 WITH (NOLOCK)
		INNER JOIN dbo.VSRaceInfo vsr with (nolock) ON vso14.EventID=vsr.EventID
	) match on match.sporttype = sports.sporttype
LEFT JOIN match_remark mr ON match.matchid = mr.matchid
WHERE
	match.eventdate >= @EventDate
	AND match.eventdate <= @toDate
	AND ( match.eventstatus NOT IN ('internal','closed','running')
			OR ( mr.IsPending=1 AND match.eventstatus IN ('running','closed') )
			OR ( mr.IsHTCal = 1 AND match.eventstatus ='running')
		 )
	AND (sports.sporttype <= 99 OR sports.sporttype IN( 161,162,180,181,186))
UNION ALL 
SELECT s.sporttype, s.sportname  
FROM (  
	  SELECT ROW_NUMBER() OVER (PARTITION BY sporttype ORDER BY l.leagueid) AS RowNumber, l.sporttype, l.leagueid  
	  FROM league l with (nolock)   
	  INNER JOIN  
			( 
			SELECT leagueid, oddsstatus, eventdate FROM outright WITH (nolock)  
			 WHERE eventdate >= @EventDate AND eventdate <= @toDate  
			 UNION ALL  
			 SELECT leagueid, oddsstatus, eventdate FROM outright14 WITH (nolock)   
			 WHERE eventdate >= @EventDate AND eventdate <= @toDate  
			) o ON o.leagueid = l.leagueid   
	  WHERE l.sporttype BETWEEN 151 AND 153 AND o.oddsstatus='completed'  
	) t INNER JOIN sports s WITH(NOLOCK) ON t.sporttype = s.sporttype  
WHERE t.RowNumber < 2  

ORDER BY sports.sporttype, sports.sportname
GO
GRANT EXECUTE ON [dbo].Lrf_Result_SportSelByDate TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].Lrf_Result_SportSelByDate TO [vnteam]
GO



