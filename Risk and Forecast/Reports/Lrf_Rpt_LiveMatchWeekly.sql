/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveMatchWeekly]
	@FromDate  DATETIME
	,@ToDate    DATETIME
	
AS	
/*
	Created: Jim
	Date: 2016-03-03
	Task : LRF - Weekly live matches [Redmine #52886]
	DB: DBEXT/bodb02
	Revisions: 20160518@Jim: use view instead of table league to filter test leaguage
			   20160602@Jim: change formula to calculate total match of E-sport and set monday is the first day of week	
			   20160621@Jim: modify sp to adapt new specs	
			   20160803@Francis: Revise SP to enhance performance
			   20181101@Amanda: Remove parameter @LicenseeId & @UserId [Redmine: #103935]
*/
/*
[Lrf_Rpt_LiveMatchWeekly]
	,@FromDate  ='20160401'
	,@ToDate    ='20160520'
*/
-- Sec1: declare variable
DECLARE @FromDate_  DATETIME
	   ,@ToDate_    DATETIME
SELECT 	@FromDate_ = @FromDate
		,@ToDate_ = @ToDate
		
DECLARE @TempFromDate DATETIME
		,@TempToDate DATETIME
		,@last_day_in_week_1 DATETIME
		,@last_day_in_week_2   DATETIME
		,@Cols VARCHAR(5000)
		,@query nvarchar(max)=null	
CREATE TABLE #tmpRaw (EventDate DATETIME,first_day_in_week VARCHAR(500),last_day_in_week VARCHAR(500),Sporttype INT,SportName VARCHAR(200),MatchCount INT)
CREATE TABLE #tmpStr (ID INT IDENTITY (1,1),week VARCHAR(500),eventdate DATETIME)	
CREATE TABLE #tmpSport (Sporttype INT,SportName VARCHAR(200))
CREATE TABLE #tblMatchHedge(matchid INT,matchcode VARCHAR(500))
	
INSERT INTO #tmpSport (Sporttype, SportName)
SELECT DISTINCT m.Sporttype,s.SportName
FROM dbo.SportBettypeMatrix m WITH (NOLOCK) 
	INNER JOIN dbo.Sports s WITH (NOLOCK) ON m.Sporttype = s.Sporttype
WHERE m.ProductID =1 

INSERT INTO #tblMatchHedge
	SELECT m.Matchid, matchcode
	FROM[DBWH].[bodb_Account].[dbo].match m WITH(NOLOCK)
	WHERE m.eventdate BETWEEN @fromdate_ AND @ToDate_
		AND matchcode like '%Hedge%'
	UNION
	SELECT m.Matchid,matchcode
	FROM [DBWH].[bodb_archive].[dbo].match m WITH(NOLOCK)
	WHERE m.eventdate BETWEEN @fromdate_ AND @ToDate_
		AND matchcode like '%Hedge%'
		
-- Sec2: retrieve raw data
/*
 SELECT teamID 
INTO #ExTeam
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%(PEN)%' 
	   OR teamname   LIKE '%1st Goal%' 
	   OR teamname   LIKE '%2nd Goal%' 
	   OR teamname   LIKE '%3rd Goal%' 
	   OR teamname   LIKE '%th Goal%' 
	   OR teamname   LIKE '%free kick%' 
	   OR teamname   LIKE '%throw in%' 
	   OR teamname   LIKE '%offside%' 
	   OR teamname   LIKE '%penalty award%' 
	   OR teamname   LIKE '%goal kick%' 
	   OR teamname   LIKE '%penalty to score%' 
*/
SELECT a.teamID 
INTO #ExTeam
 FROM (SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%(PEN)%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%1st Goal%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%2nd Goal%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%3rd Goal%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%th Goal%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%free kick%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%throw in%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%offside%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%penalty award%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%goal kick%' 
 UNION ALL
 SELECT teamID 
 FROM dbo.Team WITH (NOLOCK) 
 WHERE teamname   LIKE '%penalty to score%' 
 ) a
 GROUP BY a.teamid
	   /*
DECLARE @SQL VARCHAR(4000)	   
CREATE TABLE #tmpRptMatch (MatchID INT, EventDate DATETIME, LeagueID INT,teamhomeID INT, teamawayID INT)
SELECT @SQL='SELECT  MatchID ,  EventDate,leagueId,teamhomeID,teamawayID
				  FROM OPENQUERY (DBWH,''SELECT  b.MatchID ,rptdate EventDate,leagueId,teamhomeID,teamawayID
										 FROM [bodb_Account].[dbo].[rptMatch] b WITH (NOLOCK)
										 WHERE b.rptdate BETWEEN ''''' + CONVERT(VARCHAR(10),@FromDate,120) +''''' AND ''''' + CONVERT(VARCHAR(10),@ToDate,120) +'''''
										 AND isLive =1	
										 AND customercategory NOT IN (27,28,30)
										 '')'
INSERT INTO #tmpRptMatch
EXEC (@SQL)
*/
 		
DECLARE @tmpRptMatch AS TABLE (MatchID INT, EventDate DATETIME, LeagueID INT, teamhomeID INT, teamawayID INT);

--CREATE TABLE #tmpRptMatch (MatchID INT, EventDate DATETIME, LeagueID INT, teamhomeID INT, teamawayID INT)
--CREATE CLUSTERED INDEX IX_MatchID ON #tmpRptMatch (MatchID, teamhomeID, teamawayID) WITH (STATISTICS_NORECOMPUTE = ON) 
							 
INSERT INTO @tmpRptMatch (MatchID,EventDate,LeagueID,teamhomeID,teamawayID)
SELECT b.MatchID ,rptdate EventDate,leagueId,teamhomeID,teamawayID
FROM [DBWH].[bodb_Account].[dbo].[rptMatch] b WITH (NOLOCK) 
WHERE b.rptdate BETWEEN @fromdate_ AND @ToDate_
	  AND isLive =1	
	  AND customercategory NOT IN (27,28,30) --- BARM, 8RM, Accountest
GROUP BY b.MatchID, rptdate,leagueId,teamhomeID,teamawayID
OPTION (RECOMPILE)

DELETE @tmpRptMatch
WHERE matchID IN (SELECT matchID FROM #tblMatchHedge)
	OR 	teamhomeID  IN (SELECT teamID FROM #ExTeam)	
	OR  teamawayID  IN (SELECT teamID FROM #ExTeam)

INSERT INTO #tmpRaw (EventDate,first_day_in_week , last_day_in_week, Sporttype,SportName,MatchCount)
SELECT   
		m.EventDate
		,CONVERT(VARCHAR,DATEADD(d,-1 * cast(EventDate as integer) % 7,EventDate),106) AS first_day_in_week
		,CONVERT(VARCHAR,DATEADD(d,6,DATEADD(d,-1 * cast(EventDate as integer) % 7,EventDate)),106) last_day_in_week
	    ,l.sporttype
	    ,s.SportName
	    ,SUM(m.MatchCount) AS MatchCount
	   
FROM (
		
	SELECT COUNT(DISTINCT b.MatchID) MatchCount,  EventDate,leagueId 
	 FROM @tmpRptMatch b  
	GROUP BY EventDate,leagueId 

	)AS M
	INNER JOIN dbo.view_LiveMatch_LeagueEx l   ON m.LeagueId = l.LeagueId
	INNER JOIN #tmpSport s WITH (NOLOCK) ON l.sporttype= s.sporttype
GROUP BY EventDate
	   ,l.sporttype					 
	  ,s.SportName
ORDER BY EventDate ASC 	 
 
DROP TABLE #ExTeam
 -- Sec3: format template


;WITH cte_tmpRaw
AS
	(
	SELECT @FromDate_ As [Date]
	UNION ALL
	SELECT DATEADD(dd, 1, [Date])
	FROM cte_tmpRaw
	WHERE DATEADD(dd, 1, [Date]) <= @ToDate --AND NOT EXISTS (SELECT 1 FROM #tmpRaw WHERE EventDate = DATEADD(dd, 1, [Date]))
	
	)
INSERT INTO #tmpRaw (EventDate,first_day_in_week , last_day_in_week, Sporttype,SportName,MatchCount)
SELECT [Date]
		,CONVERT (VARCHAR,DATEADD(d,-1 * cast([Date] as integer) % 7,[Date]),106) AS first_day_in_week
		,CONVERT(VARCHAR,DATEADD(d,6,DATEADD(d,-1 * cast([Date] as integer) % 7,[Date])),106) last_day_in_week
	   ,1 Sporttype
	   ,'Soccer' SportName
	   ,NULL MatchCount
FROM cte_tmpRaw c LEFT JOIN #tmpRaw t ON c.[Date] = t.EventDate
WHERE ISNULL(t.EventDate,'')=''
OPTION (maxrecursion 0)

SELECT @last_day_in_week_1= CONVERT(VARCHAR,last_day_in_week,106)
FROM #tmpRaw
WHERE EventDate = @FromDate_

SELECT @last_day_in_week_2= CONVERT(VARCHAR,last_day_in_week,106)
FROM #tmpRaw
WHERE EventDate = @ToDate_
	
UPDATE #tmpRaw
SET first_day_in_week = CASE WHEN EventDate BETWEEN @FromDate AND @last_day_in_week_1 AND EventDate>first_day_in_week THEN CONVERT(VARCHAR,@FromDate,106) ELSE first_day_in_week END 

UPDATE #tmpRaw
SET last_day_in_week = CASE WHEN EventDate BETWEEN @last_day_in_week_2-6 AND @last_day_in_week_2 AND EventDate<last_day_in_week THEN CONVERT(VARCHAR,@ToDate,106) ELSE last_day_in_week END  


SELECT 
	eventdate
	,first_day_in_week+'-'+last_day_in_week  AS	[week]
	,Sporttype
	,SportName
	,SUM(MatchCount) MatchCount
	 into #tmpReturn
FROM #tmpRaw
GROUP BY 
		 eventdate
		 ,first_day_in_week +'-'+ last_day_in_week 
		,Sporttype
		,SportName
ORDER BY eventdate  	
 --
INSERT INTO #tmpReturn (eventdate,[week],Sporttype,SportName,MatchCount)	
SELECT eventdate
	  ,[week]
	  ,s.Sporttype
	  ,s.SportName
	  ,MatchCount
FROM #tmpSport s
	LEFT JOIN #tmpReturn t ON s.sporttype=t.sporttype
WHERE ISNULL(t.Sporttype,0)=0

UPDATE 	#tmpReturn
SET Sporttype = 27
WHERE Sporttype = 50 -- combine two Cricket sport into this one
	
INSERT INTO #tmpStr (week,eventdate)
SELECT  DISTINCT first_day_in_week+'-'+last_day_in_week AS week
		,MAX(eventdate)
FROM #tmpRaw 
GROUP BY first_day_in_week+'-'+last_day_in_week
ORDER BY  MAX(eventdate) 
 
 -- Sec5: return result
SELECT @cols= STUFF((SELECT ',' + QUOTENAME(seq )
                    FROM 
                    (
                      select     [week]  AS seq
                     from #tmpStr  
                     
                    )d
					FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)') 
				,1,1,'')
 
SET @query='select  sporttype, sportname,' + @cols + ' 
            from
            (
              select s.sporttype, s.sportname, matchcount ,seq
              from
              (
                select sporttype
					   ,sportname
					   ,case when sporttype=43   then CONVERT(INT,ROUND(sum(matchcount)/2.7,0)) else sum(matchcount) end matchcount
                  , week as seq
                from #tmpReturn 
				group by sporttype,sportname,week
              ) s
              
            ) x
            pivot 
            (
                max(matchcount)
                for seq in (' + CONVERT(VARCHAR(1000),@cols) + ')
            ) p 
            order by sporttype '
			
	 EXECUTE sp_executesql @query;
	--	print @query
					
 DROP TABLE #tmpRaw
 DROP TABLE #tmpReturn
 DROP TABLE #tmpStr
 DROP TABLE #tmpSport
 DROP TABLE #tblMatchHedge
 --DROP TABLE #tmpRptMatch

GO