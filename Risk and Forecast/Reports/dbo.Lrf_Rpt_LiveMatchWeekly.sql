ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveMatchWeekly]
	@LicenseeID INT =1
	,@UserID 	INT
	,@FromDate  DATETIME
	,@ToDate    DATETIME
	,@MoveBetsDay		DATETIME
	,@BalanceUpDay		DATETIME
	,@excludeTest BIT =1
AS	
/*
	Created: Jim
	Date: 2016-03-03
	Task : LRF - Weekly live matches [Redmine #52886]
	DB: DBEXT/bodb02
*/
-- Sec1: declare variable
DECLARE @TempFromDate DATETIME
		,@TempToDate DATETIME
		,@last_day_in_week_1 DATETIME
		,@last_day_in_week_2   DATETIME
		,@Cols VARCHAR(5000)
		,@query nvarchar(max)=null	
CREATE TABLE #tmpRaw (EventDate DATETIME,first_day_in_week VARCHAR(500),last_day_in_week VARCHAR(500),Sporttype INT,SportName VARCHAR(200),MatchCount INT)
CREATE TABLE #tmpStr (ID INT IDENTITY (1,1),week VARCHAR(500),eventdate DATETIME)	
CREATE TABLE #tmpSport (Sporttype INT,SportName VARCHAR(200))	
INSERT INTO #tmpSport (Sporttype, SportName)
SELECT DISTINCT m.Sporttype,s.SportName
FROM dbo.SportBettypeMatrix m WITH (NOLOCK) 
	INNER JOIN dbo.Sports s WITH (NOLOCK) ON m.Sporttype = s.Sporttype
WHERE m.ProductID =1 
-- Sec2: retrieve raw data
IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate
		INSERT INTO #tmpRaw (EventDate,first_day_in_week , last_day_in_week, Sporttype,SportName,MatchCount)
		SELECT   
				m.EventDate
				,CONVERT(VARCHAR,DATEADD (DAY, -DATEPART (WEEKDAY, EventDate) + 1, EventDate),106) AS first_day_in_week
				,CONVERT(VARCHAR,DATEADD(d,6,(DATEADD (DAY, -DATEPART (WEEKDAY, EventDate) + 1, EventDate))),106) last_day_in_week
			   ,l.sporttype
			   ,s.SportName
			   ,SUM(m.MatchCount) AS MatchCount
			   
		FROM (
		SELECT    leagueid
				  ,EventDate 
				  ,COUNT (matchid) MatchCount
		FROM  dbo.Match WITH ( NOLOCK )
		WHERE Match.EventDate BETWEEN @TempFromDate AND @ToDate
			  AND Match.haslive = 1
		GROUP BY leagueid
				  ,EventDate 	  
		 
		 )AS M
			INNER JOIN dbo.League l WITH (NOLOCK) ON m.LeagueId = l.LeagueId
			INNER JOIN #tmpSport s WITH (NOLOCK) ON l.sporttype= s.sporttype
		GROUP BY EventDate
			   ,l.sporttype					 
			  ,s.SportName
		ORDER BY EventDate ASC 	 
	END
IF @fromdate <= @MoveBetsDay
	BEGIN
		IF @todate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @todate
	
		IF @BalanceUpDay < @fromdate 
			SELECT @BalanceUpDay = @fromdate
								 
		INSERT INTO #tmpRaw (EventDate,first_day_in_week , last_day_in_week, Sporttype,SportName,MatchCount)
		SELECT   
				m.EventDate
				,CONVERT(VARCHAR,DATEADD (DAY, -DATEPART (WEEKDAY, EventDate) + 1, EventDate),106) AS first_day_in_week
				,CONVERT(VARCHAR,DATEADD(d,6,(DATEADD (DAY, -DATEPART (WEEKDAY, EventDate) + 1, EventDate))),106) last_day_in_week
			   ,l.sporttype
			   ,s.SportName
			   ,SUM(m.MatchCount) AS MatchCount
			   
		FROM (
				
			SELECT COUNT(DISTINCT MatchID) MatchCount,rptdate EventDate,leagueId
			 FROM [DBDWH].[bodb_Account].[dbo].[rptMatch] b WITH (NOLOCK) 
			 WHERE b.rptdate BETWEEN @fromdate AND @TempToDate
				  AND isLive =1	
			 GROUP BY rptdate,leagueId
		
			)AS M
			INNER JOIN dbo.League l WITH (NOLOCK) ON m.LeagueId = l.LeagueId
			INNER JOIN #tmpSport s WITH (NOLOCK) ON l.sporttype= s.sporttype
		GROUP BY EventDate
			   ,l.sporttype					 
			  ,s.SportName
		ORDER BY EventDate ASC 	 
	END
		
 -- Sec3: format template


;WITH cte_tmpRaw
AS
	(
	SELECT @FromDate As [Date]
	UNION ALL
	SELECT DATEADD(dd, 1, [Date])
	FROM cte_tmpRaw
	WHERE DATEADD(dd, 1, [Date]) <= @ToDate --AND NOT EXISTS (SELECT 1 FROM #tmpRaw WHERE EventDate = DATEADD(dd, 1, [Date]))
	
	)
INSERT INTO #tmpRaw (EventDate,first_day_in_week , last_day_in_week, Sporttype,SportName,MatchCount)
SELECT [Date]
	   ,CONVERT(VARCHAR,DATEADD (DAY, -DATEPART (WEEKDAY, [Date]) + 1, [Date]),106)
	   ,CONVERT(VARCHAR,DATEADD(d,6,(DATEADD (DAY, -DATEPART (WEEKDAY, [Date]) + 1, [Date]))),106) last_day_in_week	
	   ,1 Sporttype
	   ,'Soccer' SportName
	   ,NULL MatchCount
FROM cte_tmpRaw c LEFT JOIN #tmpRaw t ON c.[Date] = t.EventDate
WHERE ISNULL(t.EventDate,'')=''

SELECT @last_day_in_week_1= CONVERT(VARCHAR,last_day_in_week,106)
FROM #tmpRaw
WHERE EventDate = @FromDate

SELECT @last_day_in_week_2= CONVERT(VARCHAR,last_day_in_week,106)
FROM #tmpRaw
WHERE EventDate = @ToDate
	
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
                select sporttype,sportname, matchcount
                  , week as seq
                from #tmpReturn 
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
 GO
 
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveMatchWeekly] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveMatchWeekly] TO [vnteam] 