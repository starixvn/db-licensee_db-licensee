USE bodb02
GO

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

	Paramters Explanation:  
		@ProductID: list of products  
*/  
RETURNS TABLE  
RETURN  
	SELECT ProductID, ProductCode, SportType, BetType  
	FROM (  
			VALUES (1, 'SB', 0, 0),		-- Sportsbook 
					(2, 'RB', 151, 0),	-- Racing 					
					(3, 'NG', 161, 0),	-- Number Game  
					(4, 'LC', 162, 0),	-- Live Casino
					(5, 'VS', 180, 0),	-- Virtual Sports  								
					(6, 'CS', 251, 71), (6, 'CS', 208, 0), (6, 'CS', 209, 0), (6, 'CS', 210, 0), -- RNG Casino 
					(7, 'BG', 252, 0),	-- Bingo
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
					(27, 'VS2', 190, 0)-- Betradar Virtual Sports  
			) d(ProductID, ProductCode, SportType, BetType)  
	WHERE ',' + @ProductCodes + ',' LIKE '%,' + CAST(ProductCode as varchar(10)) + ',%'  
GO