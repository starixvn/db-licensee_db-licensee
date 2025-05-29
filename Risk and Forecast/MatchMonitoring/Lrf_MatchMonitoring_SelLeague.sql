/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

CREATE OR ALTER PROCEDURE [dbo].[Lrf_MatchMonitoring_SelLeague]
	@LicenseeID		INT
AS

/*
	Created: 20250522@Kelvin
	Task: Get League for Match Monitoring
	DB: DBBOF-bodb02

	Revisions:
		- 20250522@Kelvin: Match Monitoring Center [Redmine #227673]
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT l.leagueid, l.sporttype
	FROM bodb_licensee.dbo.LicenseeMatchMonitoring (NOLOCK) lm
		INNER JOIN dbo.match (NOLOCK) m ON m.matchid = lm.MatchID
		INNER JOIN dbo.League (NOLOCK) l ON l.leagueid = m.leagueid
	WHERE lm.LicenseeId = @LicenseeID AND lm.IsActive = 1 AND lm.BetType = 20
	ORDER BY l.leagueid DESC
END
GO
