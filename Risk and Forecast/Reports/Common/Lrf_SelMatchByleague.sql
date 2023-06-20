/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelMatchByleague]
	@SportId 		INT,
	@LeagueId		INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	WARNING: This SP only gets matches from SB
	Created: 20140102@Florent
	Task: Get matchID from LeagueID
	DB: DBLIC/bodb_Licensee

	Revisions:
		- 20180709@Amanda: Add option @LeagueID = 0 to get all matches for SB [RedmineID: #80941]
		- 20180712@Joseph: Add param @SportId to get all matches for specific sport [RedmineID: #80941]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210622@Mark: Change on MoveBet - Add param MoveBetsDay, BalanceUpDay [RedmineID: #154866]
		- 20211112@Kos: Exclude league and match which IsDeleted = 1 [RedmineID: #163733]
		- 20230620@Kos: Support filter Saba Sports in BTC [RedmineID: #183841]

	Param's Explanation:
		- @SportId = 0: all sports
		- @LeagueId = 0 : get all matches
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempFromDate	DATETIME,
		@TempToDate			DATETIME

	CREATE TABLE #match (
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		LeagueId		INT,
		LeagueGroupID	SMALLINT
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO #match
		SELECT DISTINCT
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END AS matchid, -- get main match
			m.homeid,
			m.awayid,
			m.leagueid,
			l.LeagueGroupID
		FROM bodb02.dbo.match AS m WITH (NOLOCK)
			INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
		WHERE m.eventdate BETWEEN @TempFromDate AND @ToDate
			AND ((@LeagueID = 0 AND (m.sporttype < 100 OR m.sporttype = 154))
				OR m.leagueid = @LeagueID)
			AND m.leagueid > 0
			AND m.matchcode NOT LIKE 'hedge%'
			AND (@SportId = 0 OR m.sporttype = @SportId)
			AND m.IsDeleted = 0
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
		SELECT DISTINCT
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END AS matchid, -- get main match
			m.homeid,
			m.awayid,
			m.leagueid,
			l.LeagueGroupID
		FROM bodb02.dbo.match14 AS m WITH (NOLOCK)
			INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
		WHERE m.eventdate BETWEEN @BalanceUpDay AND @TempToDate
			AND ((@LeagueID = 0 AND (m.sporttype < 100 OR m.sporttype = 154))
				OR m.leagueid = @LeagueID)
			AND m.leagueid > 0
			AND m.matchcode NOT LIKE 'hedge%'
			AND (@SportId = 0 OR m.sporttype = @SportId)
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @Todate >= DATEADD(dd, - 1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, - 1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate

		DECLARE @sql NVARCHAR(MAX)
		DECLARE @OPENQUERY NVARCHAR(4000),
			@TSQL NVARCHAR(4000),
			@LinkedServer NVARCHAR(4000)

		SET @LinkedServer = 'DBARC'
		SET @OPENQUERY = 'SELECT * FROM OPENQUERY('+ @LinkedServer + ','''
		SET @TSQL = '	SELECT 
						DISTINCT CASE WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID ELSE m.matchid END AS matchid,
							m.homeid,
							m.awayid,
							m.leagueid,
							l.LeagueGroupID
						FROM bodb_archive.dbo.match_bk AS m WITH (NOLOCK)
							INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
						WHERE m.eventdate between ''''' + CAST(@FromDate AS VARCHAR)+'''''' + ' AND ''''' + CAST(@TempToDate AS VARCHAR) + '''''
							AND ((' + CAST(@LeagueId AS VARCHAR)+' = 0 AND (m.sporttype < 100 OR m.sporttype=154)) OR m.leagueid = ' + CAST(@leagueid AS VARCHAR)+') ' + '
							AND m.leagueid > 0 
							AND m.matchcode NOT LIKE ''''hedge%''''
							AND (' + CAST(@SportId AS VARCHAR) + ' = 0 OR m.sporttype = ' + CAST(@SportId AS VARCHAR) + ')
							'')' 

		SELECT @sql = @OPENQUERY + @TSQL

		INSERT INTO #match
		EXEC (@sql)
	END

	SELECT DISTINCT
		m.matchid,
		m.homeid,
		m.awayid,
		m.leagueid,
		m.LeagueGroupID
	FROM #match AS m
	ORDER BY m.matchid DESC
		,m.homeid
		,m.awayid

	DROP TABLE #match
END
GO
