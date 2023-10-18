/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="bodbLicenseeNet" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION dbo.Lrf_f_SelPromotionType (
	@ProductList VARCHAR(500) = '',
	@PromotionTypeList	VARCHAR(500)	= ''
)
RETURNS TABLE
AS
/*
	Created:20231018@Evan
	Task: Get Promotion Bet Types from Reports Extra Payout WL 
	DB: DBEXT-bodb02,DBACC-bodb02
	Revisions:
		- 20231018@Evan: Initialize SP [redmine: #194505]
	
	Param's Explanation:
		+ @PromotionTypeList: promotion type list separated by ','
			- 2101: Allbet - Promotion (BetType: 2499)
			- 3201: PP - Tournament Prize (BetType: 4299)
			- 3202: PP - Promotion Prize (BetType: 4300)
			- 3203: PP - Jackpot Prize (BetType: 4298)
			- 3204: PP - Jackpot Contribution (BetType: 4297)
			- 3401: Arcadia Gaming - Bonus (BetType: 1906)
			- 3601: SG - Jackpot Prize (BetType: 4600)
			- 3602: SG - Jackpot Contribution (BetType: 4599)
			- 3701: Saba Lucky Spin (BetType: 17000)
			- 3702: Saba Lucky Spot (BetType: 17001)
			- 3703: Non - Cash Prize (BetType: 17002)
			- 3704: Saba Loyalty Points Exchange (BetType: 17003)
			- 3705: Saba Red Envelope (BetType: 17004)
			- 3706: Saba Casino Royale Tournament Prize (BetType: 17006)
			- 3901: SA Gaming - Tip (BetType: 3007)
			- 4201: Saba.club - Free Bets (SportType: 150)
			- 4202: Saba.club - Jackpot Prize (BetType: 1699)
			- 4203: Saba.club - Jackpot Contribution (BetType: 1698)
			- 4501: AE Sexy - Lucky Draw (BetType: 3150)
			- 6601: Vgaming - Free Bets (SportType: 173)
			- 6602: Vgaming - Jackpot Prize (BetType: 3899)
			- 6603: Vgaming - Jackpot Contribution (BetType: 3898)
			- 7401: Player Tips (BetType: 8700)
			- 3603: SG - Promotion Prize (BetType: 4598)
			- 7301: MGRNG - Promotion Prize (BetType: 8695)
			
 */
RETURN (
	SELECT d.PromotionType, d.Bettype, d.ProductCode, d.SportType
	FROM (
		VALUES (2101, 2499, 'AB', NULL)
		     , (3201, 4299, 'PP', NULL)
		     , (3202, 4300, 'PP', NULL)
		     , (3203, 4298, 'PP', NULL)
		     , (3204, 4297, 'PP', NULL)
		     , (3401, 1906, 'CC', NULL)
		     , (3601, 4600, 'SG', NULL)
		     , (3602, 4599, 'SG', NULL)
		     , (3603, 4598, 'SG', NULL)
		     , (3701, 17000, 'SPR', NULL)
		     , (3702, 17001, 'SPR', NULL)
		     , (3703, 17002, 'SPR', NULL)
		     , (3704, 17003, 'SPR', NULL)
		     , (3705, 17004, 'SPR', NULL)
		     , (3706, 17006, 'SPR', NULL)
		     , (3901, 3007, 'SAG', NULL)
		     , (4201, NULL,'SBC', 150)
		     , (4202, 1699,'SBC', 200)
		     , (4203, 1698,'SBC', 200)
		     , (4501, 3150, 'SXG', NULL)
		     , (6601, NULL, 'VGA', 173)
		     , (6602, 3899, 'VGA', 171)
		     , (6603, 3898, 'VGA', 171)
		     , (7401, 8700, 'TIP', NULL)
		     , (7301, 8695, 'MGRNG', NULL)
		) AS d (PromotionType, Bettype, ProductCode, SportType)
	WHERE (@ProductList = '' OR ProductCode IN (SELECT value FROM STRING_SPLIT(@ProductList,',')))
		AND (@PromotionTypeList = '' OR d.PromotionType IN (SELECT value FROM STRING_SPLIT(@PromotionTypeList,',')))
)
GO