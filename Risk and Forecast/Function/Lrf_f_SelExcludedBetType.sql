/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBSID-bodb02" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/

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
		- 20231018@Evan: Integrate Saba Casino Royale Tournament Prize [redmine: #194505]
		- 20231018@Evan: Integrate Saba Reward Risk-free Rebate [redmine: #196881]
		- 20231213@Evan: Integrate Live22 Promotion [RedmineID: #197702]
		- 20240416@Evan: Integrate Saba Coins [RedmineID: #202281]
		- 20240701@Kelvin: Integrate Integrate FastSpin [RedmineID: #207099]
		- 20240725@Kelvin: Vgaming - Integrate Promotion Prize [RedmineID: #208144]
		- 20240827@Lewis: FA CHAI - Integrate Promotion Prize [RedmineID: #209881]
		- 20240812@Bobby: Grant wsv_lap permission [RedmineID: #209041]
		- 20240910@Kelvin: Support Odds Boost Voucher [RedmineID: #199292]
		- 20250213@Kelvin: Integrate ASKMESLOT [RedmineID: #217785]
		- 20250314@Kelvin: Integrate Saba Promotion - Number Game Lucky Draw Promotion [RedmineID: #219835]
		- 20250213@Kelvin: Add new Saba Promotion for Sportsbook - NBA event [RedmineID: #221485]
		- 20250320@Kelvin: Integrate HOTDOG [RedmineID: #219979]
		- 20250402@Kelvin: Integrate Microgaming Live product [RedmineID: #222437]
		- 20250421@Kelvin: Integrate RichGaming [RedmineID: #224191]
		- 20250519@Kelvin: Add new Saba Promotion - FIFA CWC Score Challenge [RedmineID: #227537]
		- 20250725@Kelvin: LAP - Integrate Playtech - Jackpot [RedmineID: #233781]

*/

RETURN
	SELECT 'SB' AS ProductCode, 999 AS BetType			-- Licensee Spread Setting
	UNION ALL
	SELECT 'SB', 997									-- Odds Boost Bonus
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
	SELECT 'SPR', 17006									-- Casino Royale Tournament
	UNION ALL
	SELECT 'SPR', 17007									-- Saba Reward Risk-free Rebate
	UNION ALL
	SELECT 'SPR', 17008									-- Saba Coins Cash Exchange
	UNION ALL
	SELECT 'SPR', 17009									-- Promotion Jackpot Prize
	UNION ALL
	SELECT 'SPR', 17010									-- Promotion Cash Prize
	UNION ALL
	SELECT 'SPR', 17031									-- Number Game Lucky Draw Promotion
	UNION ALL
	SELECT 'SPR', 17011									-- NBA Playoffs Lottery
	UNION ALL
	SELECT 'SPR', 17012									-- Balance Adjustment
	UNION ALL
	SELECT 'SPR', 17013									-- FIFA CWC Score Challenge
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
	SELECT 'VGA', 3897									-- Vgaming Promotion Prize
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
	UNION ALL
	SELECT 'L22', 7698									-- L22 promotion prize
	UNION ALL
	SELECT 'FS', 11295									-- FastSpin promotion prize
	UNION ALL
	SELECT 'FAC', 11399									-- FA CHAI promotion prize
	UNION ALL
	SELECT 'ASK', 15199									-- ASKMESLOT promotion prize
	UNION ALL
	SELECT 'HOT', 11999									-- HOTDOG promotion prize
	UNION ALL
	SELECT 'MGLC', 13995								-- Microgaming Live promotion prize
	UNION ALL
	SELECT 'RGRNG', 15899								-- RichGaming promotion prize
	UNION ALL
	SELECT 'PTRNG', 12998								-- Jackpot Contribution
	UNION ALL
	SELECT 'PTRNG', 12999								-- Jackpot Prize

GO