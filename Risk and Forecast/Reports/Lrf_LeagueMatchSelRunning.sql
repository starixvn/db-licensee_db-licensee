/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE Lrf_LeagueMatchSelRunning
	@SportType				TINYINT	= 1,
	@IsIncludeTestLeague	BIT		= 0
AS

/*
	Created: 20130418@Scott
	Task: Get league, match running
	DB: DBBOF.bodb02

	Revisions:
		- 20190104@Joseph: Add param @IsIncludeTestLeague to exclude test leagues[Redmine: #107473]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]
		- 20211112@Kos: Exclude league and match which IsDeleted = 1 [RedmineID: #163733]
		- 20220308@Kos: Return league group ID [RedmineID: #167824]
		- 20000609@Kos: Remove IsDeleted for League and Team [Redmine: #171991]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		m.sporttype,
		m.leagueid,
		l.LeagueGroupID,
		m.matchid,
		m.homeid,
		m.awayid
	FROM dbo.League AS l WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON l.leagueid = m.leagueid
	WHERE
		(@IsIncludeTestLeague = 1 OR l.isTest = 0)
		AND m.IsDeleted = 0
		AND m.sporttype = @SportType
		AND m.eventstatus = 'running'
		AND m.matchcode NOT LIKE '%hedge%'
		AND (m.sporttype <> 50 OR ISNULL(m.ChildMatchType, 0) <> 200)	-- exclude child match

	UNION ALL

	SELECT
		l.sporttype,
		o.leagueid,
		l.LeagueGroupID,
		o.orid,
		o.teamid,
		0
	FROM dbo.outright AS o WITH (NOLOCK)
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
	WHERE (@IsIncludeTestLeague = 1 OR l.isTest = 0)
		AND l.sporttype = @SportType
		AND o.oddsstatus = 'running'
		AND o.IsDeleted = 0
END
GO
