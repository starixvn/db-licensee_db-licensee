/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[LAP_f_WinlossAnalysis_SabaSportSel] ()
RETURNS TABLE
AS
/*
	Created: 20230209@Bobby
	Task: 172604 - LAP - Winloss Analysis - SABA sporttype config
	DB: DBEXT.bodb02

	Revisions:
		- 20230209@Bobby: Created [RedmineID: #172604]
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]
		- 20240304@Evan: Integrate Saba Ice Hockey [RedmineID: #201283]
		- 20240508@Bobby: Integrate Saba Kabaddi [RedmineID: #203612]
		- 20240915@Bobby: Deploy WL SettleTime [RedmineID: #209631]
		- 20250425@Kelvin: Integrate Saba Soccer Marble [RedmineID: #225015]
*/
RETURN
	WITH cteProduct AS (
		SELECT 1 AS ProductId, 
			'Sportsbook' AS ProductName, 
			-2 AS SabaSportType, 
			'SABA Soccer' AS SportName, 
			'SB' AS ProductCode, 
			902 AS SportOrder, 
			'{"Sporttype":1, "LeagueGroupID": [42,74]}' AS SporttypeRef,
			CAST (1 AS BIT) AS IsShowUI,
			CAST (NULL AS SMALLDATETIME) AS CutOffDate
		UNION ALL
		SELECT 1, 'Sportsbook', -5, 'SABA Basketball', 'SB', 903,
			'{"Sporttype":2, "LeagueGroupID": [42]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -8, 'SABA Cricket', 'SB', 904,
			'{"Sporttype":50, "LeagueGroupID": [42]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -3, 'SABA Futsal', 'SB', 905,
			'{"Sporttype":1, "LeagueGroupID": [108]}', 1, NULL
		UNION ALL	
		SELECT 1, 'Sportsbook', -9, 'SABA Tennis', 'SB', 906,
			'{"Sporttype":5, "LeagueGroupID": [42]}', 1, '2023-07-01'
		UNION ALL
		SELECT 1, 'Sportsbook', -10, 'SABA Ice Hockey', 'SB', 907, 
			'{"Sporttype":4, "LeagueGroupID": [42]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -11, 'SABA Kabaddi', 'SB', 908, 
			'{"Sporttype":47, "LeagueGroupID": [42]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -4, 'SABA Soccer PinGoal', 'SB', 909,
			'{"Sporttype":1, "LeagueGroupID": [113]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -12, 'SABA Soccer Marble ', 'SB', 910,
			'{"Sporttype":1, "LeagueGroupID": [252]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -6, 'SABA Basketball PinGoal', 'SB', 911,
			'{"Sporttype":2, "LeagueGroupID": [122]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -7, 'SABA ESports PinGoal', 'SB', 912,
			'{"Sporttype":43, "LeagueGroupID": [151]}', 1, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -1, 'Parlay', 'SB', 913, 
			'{"Sporttype":1, "LeagueGroupID": []}', 1, NULL
	)
	SELECT ProductID, SabaSportType, ProductName, SportName, ProductCode, SportOrder, SporttypeRef, IsShowUI, CutOffDate
	FROM cteProduct;