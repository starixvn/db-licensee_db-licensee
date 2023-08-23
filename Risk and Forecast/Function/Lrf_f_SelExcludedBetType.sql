/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[Lrf_f_SelExcludedBetType]()
RETURNS TABLE

/*
	Creator: Louis
	Date: 2020-10-08
	Task: Get Excluded Bet Types from Reports
	DB: DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBSID-bodb02
	Revision:
		- 20201008@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20210203@Louis: Saba Red Envelope [RedmineID: #149923]
		- 20210208@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210322@Hogan: Integrate AE Casino Lucky Draw [RedmineID: #151984]
		- 20210518@Hogan: Integrate Vgaming [RedmineID: #151583]
		- 20220126@Kos: Integrate Spadegaming Jackpot [RedmineID: #167035]
		- 20220223@Kos: Integrate Allbet Promotion [RedmineID: #167524]
		- 20220801@Victoria: Add DBSID-bodb02 to metadata [Redmine: #175297]
		- 20230208@Evan: Inteagrate SG promotion prize [RedmineID: #183497]
		- 20230626@Evan: Integrate MG-RNG (Promotion Game) [RedmineID: #189988]
		- 20230822@Evan: Integrate Parlay Boost - [RedmineID: #192238]

*/

RETURN
	SELECT 'SB' AS ProductCode, 999 AS BetType			-- Licensee Spread Setting
	UNION ALL
	SELECT 'SB', 998									-- Parlay Boost Adjustment
	UNION ALL
	SELECT 'PP', 4297 									-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'PP', 4298 									-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'PP', 4299									-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'PP', 4300	 								-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'SPR', 17000									-- Saba Loyalty
	UNION ALL
	SELECT 'SPR', 17003									-- Saba Loyalty
	UNION ALL
	SELECT 'SPR', 17004									-- Saba Red Envelope
	UNION ALL
	SELECT 'SAG', 3007									-- SA Gaming Tip ticket
	UNION ALL
	SELECT 'CC', 1906									-- Arcadia Gaming Bonus
	UNION ALL
	SELECT 'SBC', 1698									-- Saba club Jackpot Contribution
	UNION ALL
	SELECT 'SBC', 1699									-- Saba club Jackpot Prize
	UNION ALL
	SELECT 'SXG', 3150									-- AE Casino Lucky Draw
	UNION ALL
	SELECT 'VGA', 3898									-- Vgaming Jackpot Contribution
	UNION ALL
	SELECT 'VGA', 3899									-- Vgaming Jackpot Prize
	UNION ALL
	SELECT 'SG', 4599									-- Spadegaming Jackpot Contribution
	UNION ALL
	SELECT 'SG', 4600									-- Spadegaming Jackpot Prize
	UNION ALL
	SELECT 'AB', 2499									-- Allbet Promotion
	UNION ALL
	SELECT 'SG', 4598									-- SG promotion prize
	UNION ALL
	SELECT 'MGRNG', 8695								-- MG-RNG promotion prize

GO