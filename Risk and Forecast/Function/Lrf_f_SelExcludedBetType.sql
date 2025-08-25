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
		- 20250801@Kelvin: LAP/MPA - Betradar VS2 - Integrate new VS Tournament [RedmineID: #234844]
		- 20250722@Kelvin: Enhancement to speed up integrate new casino product - Phase 2 [RedmineID: #232697]


		+ @PromotionTypeList: promotion type list separated by ','
			- 101: Sportsbook - Odds Boost Adjustment (BetType: 997)
			- 2101: Allbet - Promotion (BetType: 2499)
			- 2701: VS2 - VS Tournament (BetType: 2798)
			- 3201: PP - Tournament Prize (BetType: 4299)
			- 3202: PP - Promotion Prize (BetType: 4300)
			- 3203: PP - Jackpot Prize (BetType: 4298)
			- 3204: PP - Jackpot Contribution (BetType: 4297)
			- 3401: Arcadia Gaming - Bonus (BetType: 1906)
			- 3601: SG - Jackpot Prize (BetType: 4600)
			- 3602: SG - Jackpot Contribution (BetType: 4599)
			- 3603: SG - Promotion Prize (BetType: 4598)
			- 3701: Saba Lucky Spin (BetType: 17000)
			- 3702: Saba Lucky Spot (BetType: 17001)
			- 3703: Non - Cash Prize (BetType: 17002)
			- 3704: Saba Loyalty Points Exchange (BetType: 17003)
			- 3705: Saba Red Envelope (BetType: 17004)
			- 3706: Casino Royale Tournament (BetType: 17006)
			- 3707: Saba Reward Risk-free Rebate (BetType: 17007)
			- 3708: Saba Coins Cash Exchange (BetType: 17008)
			- 3709: Promotion Jackpot Prize (BetType: 17009)
			- 3710: Promotion Cash Prize (BetType: 17010)
			- 3711: Number Game Lucky Draw Promotion (BetType: 17031)
			- 3712: NBA Playoffs Lottery (BetType: 17011)
			- 3713: Balance Adjustment (BetType: 17012)
			- 3714: FIFA CWC Score Challenge (BetType: 17013)
			- 3901: SA Gaming - Tip (BetType: 3007)
			- 4201: Saba.club - Free Bets (SportType: 150)
			- 4202: Saba.club - Jackpot Prize (BetType: 1699)
			- 4203: Saba.club - Jackpot Contribution (BetType: 1698)
			- 4501: AE Sexy - Lucky Draw (BetType: 3150)
			- 6601: Vgaming - Free Bets (SportType: 173)
			- 6602: Vgaming - Jackpot Prize (BetType: 3899)
			- 6603: Vgaming - Jackpot Contribution (BetType: 3898)
			- 6604: Vgaming - Promotion Prize (BetType: 3897)
			- 7301: MGRNG - Promotion Prize (BetType: 8695)
			- 7401: Player Tips (BetType: 8700)
			- 7901: Live22 - Promotion Prize (BetType: 7698)
			- 8701: FastSpin - Promotion Prize (BetType: 11295)
			- 8901: FACHAI - Promotion Prize (BetType: 11399)
			- 9501: HOTDOG - Promotion Prize (BetType: 11999)
			- 10001: Playtech  - Jackpot Contribution (BetType: 12998)
			- 10002: Playtech  - Jackpot Prize (BetType: 12999)
			- 10101: Playtech Live - Jackpot Contribution (BetType: 15798)
			- 10102: Playtech Live - Jackpot Prize (BetType: 15799)
			- 10301: ASKMESLOT - Promotion Prize (BetType: 15199)
			- 10701: Microgaming Live - Promotion Prize (BetType: 13995)
			- 10801: RichGaming - Promotion Prize (BetType: 15899)

*/

RETURN
	SELECT 'SB' AS ProductCode	, 999 AS BetType	, 99 AS SportType	, NULL AS PromotionType		-- Licensee Spread Setting
	UNION ALL
	SELECT 'SB'					, 997				, 99				, 101						-- Odds Boost Bonus
	UNION ALL
	SELECT 'PP'					, 4297				, 248				, 3204						-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'PP'					, 4298				, 248				, 3203						-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'PP'					, 4299				, 248				, 3201						-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'PP'					, 4300	 			, 248				, 3202						-- Pragmatic Play - Promotion Prize
	UNION ALL
	SELECT 'SPR'				, 17000				, 246				, 3701						-- Saba Loyalty
	UNION ALL
	SELECT 'SPR'				, 17003				, 246				, 3704						-- Saba Loyalty
	UNION ALL
	SELECT 'SPR'				, 17004				, 246				, 3705						-- Saba Red Envelope
	UNION ALL
	SELECT 'SPR'				, 17006				, 246				, 3706						-- Casino Royale Tournament
	UNION ALL
	SELECT 'SPR'				, 17007				, 246				, 3707						-- Saba Reward Risk-free Rebate
	UNION ALL
	SELECT 'SPR'				, 17008				, 246				, 3708						-- Saba Coins Cash Exchange
	UNION ALL
	SELECT 'SPR'				, 17009				, 246				, 3709						-- Promotion Jackpot Prize
	UNION ALL
	SELECT 'SPR'				, 17010				, 246				, 3710						-- Promotion Cash Prize
	UNION ALL
	SELECT 'SPR'				, 17031				, 246				, 3711						-- Number Game Lucky Draw Promotion
	UNION ALL
	SELECT 'SPR'				, 17011				, 246				, 3712						-- NBA Playoffs Lottery
	UNION ALL
	SELECT 'SPR'				, 17012				, 246				, 3713						-- Balance Adjustment
	UNION ALL
	SELECT 'SPR'				, 17013				, 246				, 3714						-- FIFA CWC Score Challenge
	UNION ALL
	SELECT 'SAG'				, 3007				, 244				, 3901						-- SA Gaming Tip ticket
	UNION ALL
	SELECT 'CC'					, 1906				, 165				, 3401						-- Arcadia Gaming Bonus
	UNION ALL
	SELECT 'SBC'				, 1698				, 200				, 4203						-- Saba club Jackpot Contribution
	UNION ALL
	SELECT 'SBC'				, 1699				, 200				, 4202						-- Saba club Jackpot Prize
	UNION ALL
	SELECT 'SXG'				, 3150				, 243				, 4501						-- AE Casino Lucky Draw
	UNION ALL
	SELECT 'VGA'				, 3897				, 171				, 6604						-- Vgaming Promotion Prize
	UNION ALL
	SELECT 'VGA'				, 3898				, 171				, 6603						-- Vgaming Jackpot Contribution
	UNION ALL
	SELECT 'VGA'				, 3899				, 171				, 6602						-- Vgaming Jackpot Prize
	UNION ALL
	SELECT 'SG'					, 4598				, 247				, 3603						-- SG promotion prize
	UNION ALL
	SELECT 'SG'					, 4599				, 247				, 3602						-- Spadegaming Jackpot Contribution
	UNION ALL
	SELECT 'SG'					, 4600				, 247				, 3601						-- Spadegaming Jackpot Prize
	UNION ALL
	SELECT 'AB'					, 2499				, 211				, 2101						-- Allbet Promotion
	UNION ALL
	SELECT 'MGRNG'				, 8695				, 155				, 7301						-- MG-RNG promotion prize
	UNION ALL
	SELECT 'L22'				, 7698				, 227				, 7901						-- L22 promotion prize
	UNION ALL
	SELECT 'FS'					, 11295				, 230				, 8701						-- FastSpin promotion prize
	UNION ALL
	SELECT 'FAC'				, 11399				, 146				, 8901						-- FA CHAI promotion prize
	UNION ALL
	SELECT 'ASK'				, 15199				, 130				, 10301						-- ASKMESLOT promotion prize
	UNION ALL
	SELECT 'HOT'				, 11999				, 139				, 9501						-- HOTDOG promotion prize
	UNION ALL
	SELECT 'MGLC'				, 13995				, 124				, 10701						-- Microgaming Live promotion prize
	UNION ALL
	SELECT 'RGRNG'				, 15899				, 123				, 10801						-- RichGaming promotion prize
	UNION ALL
	SELECT 'PTRNG'				, 12998				, 148				, 10001						-- Playtech RNG Jackpot Contribution
	UNION ALL
	SELECT 'PTRNG'				, 12999				, 148				, 10002						-- Playtech RNG Jackpot Prize
	UNION ALL
	SELECT 'VS2'				, 2798				, 190				, 2701						-- VS Tournament
	UNION ALL
	SELECT 'PTLC'				, 15798				, 129				, 10101						-- Playtech Live Jackpot Contribution
	UNION ALL
	SELECT 'PTLC'				, 15799				, 129				, 10102						-- Playtech Live Jackpot Prize
GO