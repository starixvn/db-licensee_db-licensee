USE bodb02;
GO
CREATE OR ALTER FUNCTION [dbo].[LAP_f_WinlossAnalysis_SabaSportSel] ()
RETURNS TABLE
AS
RETURN
	WITH cteProduct AS (
		SELECT 1 AS ProductId, 
			'Sportsbook' AS ProductName, 
			-3 AS SportType, 
			'SABA Soccer' AS SportName, 
			'SB' AS ProductCode, 
			903 AS SportOrder, 
			'{"Sporttype":1, "LeagueGroupID": [42,74,108]}' AS SporttypeRef
		UNION ALL
		SELECT 1, 'Sportsbook', -4, 'SABA Soccer PinGoal', 'SB', 904,
			'{"Sporttype":1, "LeagueGroupID": [113]}'
		UNION ALL
		SELECT 1, 'Sportsbook', -5, 'SABA Basketball', 'SB', 905,
			'{"Sporttype":2, "LeagueGroupID": [42]}'
		UNION ALL
		SELECT 1, 'Sportsbook', -6, 'SABA Basketball PinGoal', 'SB', 906,
			'{"Sporttype":2, "LeagueGroupID": [122]}'
		UNION ALL
		SELECT 1, 'Sportsbook', -7, 'SABA ESports PinGoal', 'SB', 907,
			'{"Sporttype":43, "LeagueGroupID": [151]}'
		UNION ALL
		SELECT 1, 'Sportsbook', -8, 'SABA Cricket', 'SB', 908,
			'{"Sporttype":50, "LeagueGroupID": [42]}'
		UNION ALL
		SELECT 1, 'Sportsbook', -2, 'Castout', 'SB', 902, NULL
		UNION ALL
		SELECT 1, 'Sportsbook', -1, 'Parlay', 'SB', 901, NULL
	)
	SELECT ProductID, SportType, ProductName, SportName, ProductCode, SportOrder, SporttypeRef
	FROM cteProduct;