/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="bodbLicenseeNet" viewers="" isFunction="1"></info>*/

ALTER FUNCTION [dbo].[f_LicWinLoss_ProductSportType_Sel]  
(  
	@ProductCodes VARCHAR(500) = ''  
)   
/*  
	Create: 20170703@Harper  
	Description: Get sum_winloss condition  
	DB: DBEXT.bodb02/ DBACC.bodb02
    
	Revisions:  	  
		- 20170703@Harper: Get SportType by Product follow job sum [Redmine: #78241]
		- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
		- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180418@Amanda: LAP - Integrate PP [RedmineID: #92381]
		- 20180807@Amanda: Remove Racing, Bingo [RedmineID: #99378]
		- 20181218@Joseph: Add New Sport Virtual Soccer Asian Cup [Redmine: #105409]
		- 20181227@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]

	Paramters Explanation:  
		@ProductID: list of products  
*/  
RETURNS TABLE  
RETURN  
	SELECT ProductID, ProductCode, SportType, BetType  
	FROM (  
			VALUES (1, 'SB', 0, 0),		-- Sportsbook 
					(3, 'NG', 161, 0),(3, 'NG', 164, 0),	-- Number Game  					
					(5, 'VS', 180, 0),	-- Virtual Sports  								
					(6, 'CS', 251, 71), (6, 'CS', 208, 0), (6, 'CS', 209, 0), (6, 'CS', 210, 0), -- RNG Casino 
					(8, 'KN', 202, 0),	-- Keno
					(9, 'P2P', 253, 0),	-- P2P
					(11, 'AGC', 250, 0), -- AG Casino
					(12, 'GD ', 255, 0), -- Gold Deluxe 
					(13, 'MGCLC', 203, 0),	-- Microgaming - Live Casino 
					(14, 'VG', 249, 0),	 -- Macau
					(15, 'CB', 204, 0),	 -- Colossus Bets  
					(17, 'MGCRNG', 205, 0),	-- Microgaming - Live Casino					
					(21, 'AB', 211, 0),	-- Allbet  
					(22, 'VB', 212, 0), -- Macau Games 
					(24, 'FW', 219, 0), -- Fishing World  
					(27, 'VS2', 190, 0), (27, 'VS2', 193, 0),-- Betradar Virtual Sports  
					(27, 'VS2', 194, 0), --  Virtual Soccer Asian Cup
					(28, 'LT', 220, 0),	-- Lottery
					(32, 'PP', 248, 0)	-- PP
			) d(ProductID, ProductCode, SportType, BetType)  
	WHERE ',' + @ProductCodes + ',' LIKE '%,' + CAST(ProductCode as varchar(10)) + ',%'  
GO