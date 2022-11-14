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
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tblDangerLevel (DangerLevel TINYINT)

	INSERT INTO #tblDangerLevel (DangerLevel)
	SELECT RTRIM(LTRIM(value)) AS DangerLevel
	FROM string_split(@DangerLevel,',')

	;WITH tmp AS (
		SELECT DISTINCT
				DangerLevel, 
				s.sportname, 
				LeagueGroupID,
				CASE WHEN LeagueGroupID=-1 THEN 'All' ELSE 'No' END AS ApplyParlay,
				CASE WHEN DangerLevel=1 THEN NULL
					 WHEN ActionType=3	THEN Value*10000 END AS MaxperMatch,
				CASE WHEN DangerLevel=1 THEN NULL
					 WHEN ActionType=5	THEN Value*100 END AS BetDelay,
				CASE WHEN DangerLevel=1 THEN NULL
					 WHEN ActionType=6	THEN Value END AS NextBetInterval
		FROM DangerLevelPolicy p WITH (NOLOCK)
		INNER JOIN DBACC.bodb02.dbo.Sports s WITH (NOLOCK) ON p.sporttype=s.sporttype
		WHERE DangerLevel IN (SELECT DangerLevel FROM #tblDangerLevel)
	)
	SELECT	DangerLevel, sportname, LeagueGroupID, ApplyParlay,
			ISNULL(CAST(MaxperMatch AS varchar),'-') MaxperMatch,
			ISNULL(CAST(BetDelay AS varchar),'-') BetDelay,
			ISNULL(CAST(NextBetInterval AS varchar),'-') NextBetInterval
	FROM tmp
	ORDER BY DangerLevel

	DROP TABLE #tblDangerLevel
END
GO