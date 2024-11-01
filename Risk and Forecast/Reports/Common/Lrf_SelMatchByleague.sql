/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelMatchByLeague]
	@AgentList		VARCHAR(MAX),
	@SportId 		INT,
	@LeagueId		INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 20140102@Florent
	Task: Get matchID from LeagueID (only from SB)
	DB: DBEXT.bodb02

	Revisions:
		- 20180709@Amanda: Add option @LeagueID = 0 to get all matches for SB [RedmineID: #80941]
		- 20180712@Joseph: Add param @SportId to get all matches for specific sport [RedmineID: #80941]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20210622@Mark: Change on MoveBet - Add param MoveBetsDay, BalanceUpDay [RedmineID: #154866]
		- 20211112@Kos: Exclude league and match which IsDeleted = 1 [RedmineID: #163733]
		- 20230620@Kos: Support filter Saba Sports in BTC [RedmineID: #183841]
		- 20241101@Kos: Hotfix - BTC Advanced Search Match filter [RedmineID: #213124]
					- Remove input param @BalanceUpDay SMALLDATETIME
					- Add new input param @AgentList VARCHAR(MAX)
					- Move SP to DBEXT.bodb02

	Param's Explanation:
		- @SportId = 0: All sports
		- @LeagueId = 0: All leagues
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	DECLARE @TempFromDate	DATETIME,
		@TempToDate			DATETIME

	CREATE TABLE #Match (
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		LeagueId		INT,
		LeagueGroupID	SMALLINT,
		DateRange		TINYINT
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO #Match
		SELECT DISTINCT
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END AS matchid,		-- Get main match
			m.homeid,
			m.awayid,
			m.leagueid,
			l.LeagueGroupID,
			1 AS DateRange
		FROM dbo.match AS m WITH (NOLOCK)
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
		WHERE m.eventdate BETWEEN @TempFromDate AND @ToDate
			AND ((@LeagueID = 0 AND (m.sporttype < 100 OR m.sporttype = 154))
				OR m.leagueid = @LeagueID)
			AND m.leagueid > 0
			AND m.matchcode NOT LIKE 'hedge%'
			AND (@SportId = 0 OR m.sporttype = @SportId)
			AND m.IsDeleted = 0

		DELETE m
		FROM #Match m
		WHERE NOT EXISTS ( SELECT 1
						FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN #TempAg AS a ON a.CustId = b.recommend
						WHERE b.matchid = m.MatchId AND b.statusID NOT IN (0, 1))
	END

	IF @Fromdate <= @MoveBetsDay 
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO #Match
		SELECT DISTINCT
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID
				ELSE m.matchid
			END AS matchid,		-- Get main match
			m.homeid,
			m.awayid,
			m.leagueid,
			l.LeagueGroupID,
			2 AS DateRange
		FROM dbo.match14 AS m WITH (NOLOCK)
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
		WHERE m.eventdate BETWEEN @Fromdate AND @TempToDate
			AND ((@LeagueID = 0 AND (m.sporttype < 100 OR m.sporttype = 154))
				OR m.leagueid = @LeagueID)
			AND m.leagueid > 0
			AND m.matchcode NOT LIKE 'hedge%'
			AND (@SportId = 0 OR m.sporttype = @SportId)

		DELETE m
		FROM #match AS m
		WHERE m.DateRange = 2
			AND NOT EXISTS (SELECT 1
							FROM dbo.bettrans14 AS b WITH (NOLOCK)
								INNER JOIN #TempAg AS a ON a.CustId = b.recommend
							WHERE b.matchid = m.MatchId AND b.statusID NOT IN (0, 1))
	END

	SELECT DISTINCT
		MatchId,
		HomeId,
		AwayId,
		LeagueId,
		LeagueGroupID
	FROM #Match
	ORDER BY MatchId DESC

	DROP TABLE #Match
	DROP TABLE #TempAg
END
GO
