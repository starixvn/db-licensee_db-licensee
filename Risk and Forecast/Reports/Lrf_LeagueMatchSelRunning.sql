/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_LeagueMatchSelRunning
	@sporttype tinyint=1,
	@IsIncludeTestLeague 	BIT = 0
AS

/*
	Created: 20130418@Scott
	Task: Get league, match running
	DB: DBBOF.bodb02
	Revisions:
		- 20190104@Joseph: Add param @IsIncludeTestLeague to exclude test leagues[Redmine: #107473]
		- 20210304@Hogan: Integrate Cricket AIO [RedmineID: #150386]
*/

BEGIN

	SET NOCOUNT ON

	SELECT  match.sporttype, match.leagueid, match.matchid, match.homeid, match.awayid
	FROM league WITH ( NOLOCK )
		INNER JOIN match WITH ( NOLOCK ) ON league.leagueid = match.leagueid
	WHERE 
		(@IsIncludeTestLeague = 1 OR league.isTest = 0 )
		AND match.sporttype =  @sporttype
		AND match.eventstatus ='running'
		AND match.matchcode not like '%hedge%' --and match.eventdate= CONVERT(VARCHAR(10), getdate(), 111)
		AND (match.sporttype <> 50 OR ISNULL(match.ChildMatchType, 0) <> 200) -- exclude child match

	UNION ALL

	SELECT l.sporttype, o.leagueid,o.orid ,o.teamid, 0
	FROM outright o WITH(NOLOCK)
		INNER JOIN  League l With(nolock) on o.leagueid = l.leagueid AND (@IsIncludeTestLeague = 1 OR l.isTest = 0 )
	WHERE l.sporttype =  @sporttype
		AND o.oddsstatus = 'running'

END
GO