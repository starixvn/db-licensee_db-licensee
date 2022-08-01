/*<info serverAlias="DBBOF-bodb02,DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
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
DB: DB042.bodb02, DBSID-bodb02
Original: [Lrf_Forecast_MatchList]
Revisions:    
	-20220801@Victoria: Add DBSID-bodb02 to metadata [Redmine: #175297]
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