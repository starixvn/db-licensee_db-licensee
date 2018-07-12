/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelMatchByleague]
	@SportId 		INT,
	@LeagueID		INT,
	@Fromdate		SMALLDATETIME,
	@Todate		SMALLDATETIME
AS 
/*
WARNING: This SP only gets matches from SB
Created: 20140102@Florent
Task : Get matchID from LeagueID
DB: DBLIC/bodb_Licensee

Revisions: 
		- 20180709@Amanda: Add option @LeagueID = 0 to get all matches for SB [RedmineID: #80941]
		- 20180712@Joseph: Add param @SportId to get all matches for specific sport [RedmineID: #80941]
		
Param's Explanation:
		- @SportId = 0: all sports
		- @LeagueID = 0 : get all matches
	
*/
SET NOCOUNT ON
DECLARE @BalanceUpDay DATETIME,
		@MoveBetsDay DATETIME,
		@TempFromDate DATETIME,
		@TempToDate DATETIME

CREATE TABLE #tblBalanceDate (BalanceUpDay DATETIME, MoveBetsDay DATETIME)
	insert into #tblBalanceDate 
	exec bodb02.dbo.Lrf_SelBalanceUpDay

SELECT @MoveBetsDay = MoveBetsDay,@BalanceUpDay=BalanceUpDay
FROM #tblBalanceDate

CREATE TABLE #match (
	matchid INT,
	homeid INT,
	awayid INT,
	leagueid INT
)

IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay
		SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate

	INSERT INTO #match
	SELECT DISTINCT m.matchid,
		m.homeid,
		m.awayid,
		m.leagueid
	FROM bodb02.dbo.match AS m WITH (NOLOCK)
	WHERE m.eventdate BETWEEN @TempFromDate AND @Todate
		AND ((@LeagueID = 0 AND (m.sporttype < 100 OR m.sporttype=154)) OR m.leagueid = @LeagueID)
		AND m.leagueid > 0
		AND m.matchcode NOT LIKE 'hedge%'
		AND (@SportId = 0 OR m.sporttype = @SportId)
END

IF @Fromdate <= @MoveBetsDay 
BEGIN
	IF @ToDate >= @MoveBetsDay
		SET @TempToDate = @MoveBetsDay
	ELSE
		SET @TempToDate = @ToDate

	IF @BalanceUpDay < @FromDate
		SELECT @BalanceUpDay = @FromDate
	INSERT INTO #match
	SELECT DISTINCT m.matchid
		,m.homeid
		,m.awayid
		,m.leagueid
	FROM bodb02.dbo.match14 AS m WITH (NOLOCK)
	WHERE m.eventdate BETWEEN @BalanceUpDay AND @TempToDate
		AND ((@LeagueID = 0 AND (m.sporttype < 100 OR m.sporttype=154)) OR m.leagueid = @LeagueID)
		AND m.leagueid > 0
		AND m.matchcode NOT LIKE 'hedge%'
		AND (@SportId = 0 OR m.sporttype = @SportId)
END

IF @FromDate < @BalanceUpDay
BEGIN
	IF @todate >= DATEADD(dd, - 1, @BalanceUpDay)
		SET @TempToDate = DATEADD(dd, - 1, @BalanceUpDay)
	ELSE
		SET @TempToDate = @todate

	DECLARE @sql NVARCHAR(MAX)				
		
		 
		DECLARE @OPENQUERY nvarchar(4000), @TSQL nvarchar(4000), @LinkedServer nvarchar(4000)				
		SET @LinkedServer = 'DBARC'
		SET @OPENQUERY = 'SELECT * FROM OPENQUERY('+ @LinkedServer + ','''
		SET @TSQL = '	SELECT DISTINCT m.matchid
						,m.homeid
						,m.awayid
						,m.leagueid
						FROM bodb_archive.dbo.match_bk AS m WITH (NOLOCK)
						WHERE m.eventdate between '''''+CAST(@fromdate AS VARCHAR)+''''''+' AND '''''+ CAST( @TempToDate AS VARCHAR)+'''''
						AND (('+CAST(@leagueid AS VARCHAR)+' = 0 AND (m.sporttype < 100 OR m.sporttype=154)) OR m.leagueid = '+CAST(@leagueid AS VARCHAR)+') '+'
						AND m.leagueid > 0 
						AND m.matchcode NOT LIKE ''''hedge%''''	
						AND (' + CAST(@SportId AS VARCHAR) + ' = 0 OR m.sporttype = ' + CAST(@SportId AS VARCHAR) + ')
						'')' 	
		SELECT @sql=@OPENQUERY+@TSQL
		INSERT INTO #match
		EXEC (@sql)	
		
END

SELECT DISTINCT m.matchid
	,m.homeid
	,m.awayid
	,m.leagueid
FROM #match AS m
ORDER BY m.matchid DESC
	,m.homeid
	,m.awayid --m.leagueid,m.eventdate

DROP TABLE #match
GO