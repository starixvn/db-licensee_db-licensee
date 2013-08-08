SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE Lrf_Forecast_MatchList 
(
	@LeagueID INT
)
AS

/*
Created: Victor@20130802
Task : Forecast
DB: DB052.bodb02
Original: [Lrf_Forecast_MatchList]
Revisions:    

*/

BEGIN
	SET NOCOUNT ON

	SELECT matchid, homeid, awayid, IsNeutral
	FROM bodb02.dbo.Match (NOLOCK)
	WHERE leagueid = @LeagueID AND eventstatus LIKE 'running'
END
GO

GRANT EXECUTE ON [dbo].[Lrf_Forecast_MatchList] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast_MatchList] TO vnteam
GO