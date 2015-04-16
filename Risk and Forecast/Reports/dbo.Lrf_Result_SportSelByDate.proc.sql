USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_Result_SportSelByDate]    Script Date: 12/02/2014 10:07:48 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Result_SportSelByDate]
	@EventDate DATETIME,
	@LicenseeID INT
AS
/*
Created: 20101201@Jacob
Task:
DB: DB052.bodb02
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
	20140117@Florent: add new sport 154
	20140506@Hannah: support :				
				183 - Virtual Speedway
				185 - Virtual Cycling
	20150414@Sophia: Support BetRadar
	20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar
*/
/* sample test case:
	exec Lrf_Result_SportSelByDate @EventDate='2013-10-06 00:00:00',@licenseeid=1

*/

SET NOCOUNT ON

DECLARE @toDate		DATETIME,
		@matchcode	VARCHAR(10) --HRDummy
SELECT  @toDate = dateadd(s,-1, dateadd(d, 1, @EventDate))

SELECT DISTINCT ProductID INTO #LicenseeProduct
FROM bodb_licensee.dbo.LicenseeProduct3rd WITH (NOLOCK)
WHERE licenseeID=@LicenseeID
DECLARE @LicenseeProduct AS TABLE (SportID INT)
IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID=1) -- Racing
	BEGIN 
		INSERT INTO @LicenseeProduct
		SELECT 151
	END
	
IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID=2) -- Number Game
	BEGIN 
		INSERT INTO @LicenseeProduct
		SELECT 161
	END

IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID=4) -- LIve Casino
	BEGIN 
		INSERT INTO @LicenseeProduct
		SELECT 162
	END	
IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID=5) -- Virtual Sports
	BEGIN 
	
		INSERT INTO @LicenseeProduct
		SELECT 180
		UNION ALL 
		SELECT 181
		UNION ALL 
		SELECT 183
		UNION ALL 
		SELECT 185
		UNION ALL 
		SELECT 186
		
	END	

IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID=6) -- RNG Casino
	BEGIN 
		INSERT INTO @LicenseeProduct
		SELECT 251
	END	
IF EXISTS (SELECT TOP 1 1 FROM #LicenseeProduct WHERE ProductID=7) -- Bingo
	BEGIN 
		INSERT INTO @LicenseeProduct
		SELECT 252
	END		
	
SELECT distinct sports.sporttype, sportname 
from sports with (nolock)
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
LEFT JOIN ( SELECT DISTINCT MatchID FROM dbo.ResultDetail R WITH (NOLOCK) WHERE SettlementStatusID > 0
			UNION ALL  
			SELECT DISTINCT MatchID FROM dbo.ResultDetail14 R WITH (NOLOCK) WHERE SettlementStatusID > 0
			) SS
		ON match.Matchid = SS.MatchId AND Match.sporttype = 5
LEFT JOIN ( SELECT DISTINCT MatchID FROM dbo.ResultDetail R WITH (NOLOCK) WHERE SettlementStatusID > 0 AND ResourceID NOT IN ('00','01','08')
			UNION ALL  
			SELECT DISTINCT MatchID FROM dbo.ResultDetail14 R WITH (NOLOCK) WHERE SettlementStatusID > 0 AND ResourceID NOT IN ('00','01','08')
			) BR
		ON match.Matchid = BR.MatchId AND Match.sporttype = 1		
WHERE
	match.eventdate >= @EventDate
	AND match.eventdate <= @toDate
	AND (match.sporttype<100 OR match.sporttype IN (SELECT SportID FROM @LicenseeProduct) OR match.sporttype=154)
	AND ( match.eventstatus NOT IN ('internal','closed','running')
			OR ( mr.IsPending=1 AND match.eventstatus IN ('running','closed') )
			OR ( mr.IsHTCal = 1 AND match.eventstatus ='running')
			OR ( ISNULL(SS.MatchID,0) <> 0 AND match.eventstatus = 'running')  --- condition for Sportting Solution show running Match but settled least one type
			OR ( ISNULL(BR.MatchID,0) <> 0 AND match.eventstatus = 'running')  --- condition for BetRadar show running Match but settled least one type
		 )	
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
	) t 
	 INNER JOIN sports s WITH(NOLOCK) ON t.sporttype = s.sporttype 	
	INNER JOIN @LicenseeProduct lp  ON lp.sportID = s.sporttype  
	
WHERE t.RowNumber < 2  

ORDER BY sports.sporttype, sports.sportname

GO
GRANT EXECUTE ON [dbo].Lrf_Result_SportSelByDate TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].Lrf_Result_SportSelByDate TO [vnteam]
GO