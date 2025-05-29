/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Lrf_MatchMonitoring_SelMatchByLeague]
	@LicenseeID		INT,
	@LeagueIDList	VARCHAR(MAX) = 'ALL'
AS

/*
	Created: 20250522@Kelvin
	Task: Get Match By League for Match Monitoring
	DB: DBBOF-bodb02

	Revisions:
		- 20250522@Kelvin: Match Monitoring Center [Redmine #227673]

	Param's Explanation:
		@LeagueID:
			+ -1: ALL
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempLeague AS TABLE (LeagueID INT)

	IF @LeagueIDList <> 'ALL'
	BEGIN
		INSERT INTO @TempLeague (LeagueID)
		SELECT value
		FROM STRING_SPLIT(@LeagueIDList,',')
	END

	SELECT DISTINCT m.MatchID, m.homeid, m.awayid, m.IsNeutral
	FROM bodb_licensee.dbo.LicenseeMatchMonitoring (NOLOCK) lm
		INNER JOIN dbo.match (NOLOCK) m ON m.matchid = lm.MatchID
		INNER JOIN dbo.League (NOLOCK) l ON l.leagueid = m.leagueid
	WHERE lm.LicenseeId = @LicenseeID AND lm.IsActive = 1 AND lm.BetType = 20
		AND (@LeagueIDList = 'ALL' OR l.leagueid IN (SELECT LeagueID FROM @TempLeague))
	ORDER BY m.MatchID DESC

END
GO
