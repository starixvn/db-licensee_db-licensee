/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_SabaVirtualSettingSel]
	@DangerLevel VARCHAR(200) = ''
AS
/*
	Created: 20221114@Tacy
	Task: LAP - Player Segmentation - Saba Virtual Setting 
	DB: DBCUST/CUSTDB
		
	Revisions:
		- 20221114@Tacy: Create SP [RedmineID: #179078]
	Paramter's Explanations:
		@DangerLevel = [0-15] : DangerLevel
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tblDangerLevel (DangerLevel TINYINT)

	INSERT INTO #tblDangerLevel (DangerLevel)
	SELECT CASE WHEN ISNUMERIC(RTRIM(LTRIM(value)))=1 THEN RTRIM(LTRIM(value)) ELSE 0 END AS DangerLevel
	FROM string_split(@DangerLevel,',')

	;WITH t_DangerLevelPolicy AS (
		SELECT DISTINCT DangerLevel, SportType, LeagueGroupID
		FROM DangerLevelPolicy WITH (NOLOCK)
	),
	tmp AS (
		SELECT DISTINCT
				p.DangerLevel, 
				p.sporttype, 
				p.LeagueGroupID,
				CASE WHEN p.LeagueGroupID=-1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS ApplyParlay,
				CASE WHEN p.DangerLevel=1 THEN NULL
					 WHEN p3.ActionType=3	THEN p3.Value*10000 END AS MaxperMatch,
				CASE WHEN p.DangerLevel=1 THEN NULL
					 WHEN p5.ActionType=5	THEN p5.Value*100 END AS BetDelay,
				CASE WHEN p.DangerLevel=1 THEN NULL
					 WHEN p6.ActionType=6	THEN p6.Value END AS NextBetInterval
		FROM t_DangerLevelPolicy p WITH (NOLOCK)
			OUTER APPLY (SELECT p3.ActionType, p3.Value 
						 FROM DangerLevelPolicy p3 WITH (NOLOCK) 
						 WHERE p.SportType=p3.SportType
							 AND p.DangerLevel=p3.DangerLevel
							 AND p.LeagueGroupID=p3.LeagueGroupID
							 AND p3.ActionType=3) p3
			OUTER APPLY (SELECT p5.ActionType, p5.Value 
						 FROM DangerLevelPolicy p5 WITH (NOLOCK) 
						 WHERE p.SportType=p5.SportType
							 AND p.DangerLevel=p5.DangerLevel
							 AND p.LeagueGroupID=p5.LeagueGroupID
							 AND p5.ActionType=5) p5
			OUTER APPLY (SELECT p6.ActionType, p6.Value 
						 FROM DangerLevelPolicy p6 WITH (NOLOCK) 
						 WHERE p.SportType=p6.SportType
							 AND p.DangerLevel=p6.DangerLevel
							 AND p.LeagueGroupID=p6.LeagueGroupID
							 AND p6.ActionType=6) p6
		WHERE p.DangerLevel IN (SELECT DangerLevel FROM #tblDangerLevel)
	)
	SELECT	DangerLevel, sporttype, LeagueGroupID, ApplyParlay,
			MaxperMatch, BetDelay, NextBetInterval
	FROM tmp
	ORDER BY DangerLevel, sporttype

	DROP TABLE #tblDangerLevel
END
GO