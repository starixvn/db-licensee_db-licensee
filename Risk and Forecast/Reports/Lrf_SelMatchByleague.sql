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
SET NOCOUNT ON
DECLARE @BalanceUpDay DATETIME
	,@MoveBetsDay DATETIME
	,@TempFromDate DATETIME
	,@TempToDate DATETIME

CREATE TABLE #tblBalanceDate (BalanceUpDay DATETIME, MoveBetsDay DATETIME)
	insert into #tblBalanceDate 
	exec bodb02.dbo.Lrf_SelBalanceUpDay



SELECT @MoveBetsDay = MoveBetsDay,@BalanceUpDay=BalanceUpDay
FROM #tblBalanceDate

CREATE TABLE #match (
	matchid INT
	,homeid INT
	,awayid INT
	,leagueid INT
	)

IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay
		SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
	ELSE
		SET @TempFromDate = @FromDate

	INSERT INTO #match
	SELECT DISTINCT m.matchid
		,m.homeid
		,m.awayid
		,m.leagueid
	FROM bodb02.dbo.match AS m WITH (NOLOCK)
	WHERE m.eventdate BETWEEN @TempFromDate AND @Todate
		AND m.leagueid = @LeagueID
		AND m.matchcode NOT LIKE 'hedge%'
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
		AND m.leagueid = @LeagueID
		AND m.matchcode NOT LIKE 'hedge%'
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
						AND m.leagueid = '+CAST(@leagueid AS VARCHAR)+'
						AND m.matchcode NOT LIKE ''''hedge%''''					
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

GRANT EXECUTE
	ON [dbo].[Lrf_SelMatchByleague]
	TO [bodbLicenseeNet] AS [dbo]
GO

GRANT VIEW DEFINITION
	ON [dbo].[Lrf_SelMatchByleague]
	TO [vnteam] AS [dbo]
GO


