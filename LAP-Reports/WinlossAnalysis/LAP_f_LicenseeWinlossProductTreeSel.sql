CREATE OR ALTER FUNCTION [dbo].[LAP_f_LicenseeAnalysis_SabaSportSel] ()
RETURNS TABLE
AS
RETURN
	WITH cteProduct AS (
		SELECT 1 AS ProductId, 'Sportsbook' AS ProductName, -1 AS SportType, 'SABA Soccer' AS SportName, 'SB' AS ProductCode, 155 AS SportOrder
		UNION ALL
		SELECT 1, 'Sportsbook', -2, 'SABA Soccer PinGoal', 'SB', 156
		UNION ALL
		SELECT 1, 'Sportsbook', -3, 'SABA Basketball', 'SB', 157
		UNION ALL
		SELECT 1, 'Sportsbook', -4, 'SABA Basketball PinGoal', 'SB', 158
		UNION ALL
		SELECT 1, 'Sportsbook', -5, 'SABA ESports PinGoal', 'SB', 159
		UNION ALL
		SELECT 1, 'Sportsbook', -6, 'SABA Cricket', 'SB', 160
		UNION ALL
		SELECT 1, 'Sportsbook', -98, 'Castout', 'SB', 161
		UNION ALL
		SELECT 1, 'Sportsbook', -99, 'Parlay', 'SB', 162
	)
	SELECT ProductID, SportType, ProductName, SportName, ProductCode, SportOrder
	FROM cteProduct;