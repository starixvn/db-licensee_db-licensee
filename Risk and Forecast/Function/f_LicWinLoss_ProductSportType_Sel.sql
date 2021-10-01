/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[f_LicWinLoss_ProductSportType_Sel]
(
	@ProductCodes VARCHAR(500) = ''
)

/*
	Create: 20170703@Harper
	Description: Get sum_winloss condition  
	DB: DBEXT.bodb02, DBACC.bodb02

	Revisions:
		- 20170703@Harper: Get SportType by Product follow job sum [Redmine: #78241]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180418@Amanda: LAP - Integrate PP [RedmineID: #92381]
		- 20180807@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181218@Joseph: Add New Sport Virtual Soccer Asian Cup [Redmine: #105409]
		- 20181227@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
		- 20190708@Amanda: Add new product Card Club [RedmineID: #115449]
		- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
		- 20200108@Vickie: Add new product Virtual Games [RedmineID: #124911]
		- 20200326@Vickie: Add New Sport Virtual Soccer English Premier and Virtual Soccer Champions Cup [RedmineID: #131168]
		- 20200408@Vickie: Add New Sport Virtual Soccer Euro Cup [RedmineID: #132064]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200423@Hogan: Add new product Sexy Gaming [RedmineID: #132829]
		- 20200423@Vickie: Integrate Saba Club [RedmineID: #132702]
		- 20200615@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20201022@Louis: Integrate PG Soft [RedmineID: #139182]
		- 20201126@Hogan: Integrate Joker [RedmineID: #141408]
		- 20201202@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369] 
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]
		- 20200122@Hogan: Integrate GDG [RedmineID: #147267]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]
		- 20210416@Hogan: Integrate Habanero RNG Games [RedmineID: #150843]
		- 20210428@Hogan: Integrate WM Live Casino [RedmineID: #140944]
		- 20210519@Louis: Integrate Big Gaming product [RedmineID: #146773]
		- 20210525@Hogan: Integrate Vgaming [RedmineID: #151583]
		- 20210630@Hogan: Integrate Creative Gaming [RedmineID: #152619]
		- 20210727@Percy: Add Exchange, Saba Promotion for LA [RedmineID: #155593]
*/
RETURNS TABLE
RETURN
	SELECT ProductID, ProductCode, SportType, BetType
	FROM (
			VALUES (1, 'SB', 0, 0), -- Sportsbook
					(3, 'NG', 161, 0),(3, 'NG', 164, 0),(3, 'NG', 168, 0),	-- Number Game
					(5, 'VS', 180, 0),	-- Virtual Sports
					(6, 'CS', 251, 71), (6, 'CS', 208, 0), (6, 'CS', 209, 0), (6, 'CS', 210, 0), -- RNG Casino
					(8, 'KN', 202, 0),	-- Keno
					(11, 'AGC', 250, 0), -- AG Casino
					(12, 'GD ', 255, 0), -- Gold Deluxe
					(14, 'VG', 249, 0),	 -- Macau
					(15, 'CB', 204, 0),	 -- Colossus Bets
					(21, 'AB', 211, 0),	-- Allbet
					(22, 'VB', 212, 0), -- Macau Games
					(24, 'FW', 219, 0), -- Fishing World
					(27, 'VS2', 190, 0), (27, 'VS2', 193, 0),-- Betradar Virtual Sports
					(27, 'VS2', 194, 0), --  Virtual Soccer Asian Cup
					(27, 'VS2', 195, 0), --  Virtual Soccer English Premier
					(27, 'VS2', 196, 0), --  Virtual Soccer Champions Cup
					(27, 'VS2', 197, 0), --  Virtual Soccer Euro Cup
					(28, 'LT', 220, 0),	-- Lottery
					(31, 'BX', 221, 0), -- Exchange
					(32, 'PP', 248, 0),	-- PP
					(34, 'CC', 165, 0),	-- Card club
					(36, 'SG', 247, 0),	-- Spadegaming
					(37, 'SPR', 246, 0), -- Saba Promotion
					(38, 'VRG', 245, 0),	-- Virtual Games
					(40, 'TG', 222, 0),		-- Table Games
					(43, 'I4D', 223, 0),	-- Indo 4D
					(45, 'SXG', 243, 0),	-- Sexy Gaming
					(42, 'SBC', 200, 0),	-- Saba Club
					(42, 'SBC', 150, 0),	-- Saba Club
					(39, 'SAG', 244, 0),	-- SA Gaming
					(51, 'WM', 233, 0),		-- WM Live Casino
					(55, 'PGS', 232, 0),	-- PG Soft
					(56, 'JK', 234, 0),		-- Joker
					(59, 'GDG', 236, 0),	-- GDG
					(63, 'SLT', 169, 0),	-- Sports Lottery
					(61, 'HB', 238, 0),		-- Habanero RNG Games
					(57, 'BGG', 239, 0),	-- Big Gaming
					(66, 'VGA', 171, 0),	-- Vgaming
					(66, 'VGA', 173, 0),	-- Vgaming Free Bets
					(62, 'CG', 167, 0)		-- Creative Gaming
			) d(ProductID, ProductCode, SportType, BetType)  
	WHERE ',' + @ProductCodes + ',' LIKE '%,' + CAST(ProductCode AS VARCHAR(10)) + ',%'  
GO