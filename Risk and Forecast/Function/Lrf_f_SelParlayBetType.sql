/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBSID-bodb02" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[Lrf_f_SelParlayBetType]()
RETURNS TABLE

/*
	Creator: Kelvin
	Date: 2025-05-09
	Task: Get Parlay Bet Types
	DB: DBEXT-bodb02,DBACC-bodb02,DBSID-bodb02
	Revision:
		- 20250509@Kelvin: Created [RedmineID: #226292]

*/

RETURN
	SELECT 'SB' AS ProductCode, 9 AS BetType			-- Mix Parlay
	UNION ALL
	SELECT 'SB', 29										-- System Parlay
	UNION ALL
	SELECT 'VS', 2799 									-- Mix Parlay VS2
	UNION ALL
	SELECT 'VS', 10449 									-- Mix Parlay VS4
	UNION ALL
	SELECT 'VS', 11099									-- Mix Parlay VS5
GO