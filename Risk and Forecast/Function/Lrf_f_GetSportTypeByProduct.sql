/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="1"></info>*/

CREATE FUNCTION [dbo].[Lrf_f_GetSportTypeByProduct]  
(  
	@ProductCode VARCHAR(10)
)   
/*  
	Create: 20180207@Amanda
	Description: Get sports by product code  
	DB: DBLIC-bodb_Licensee
    
	Revisions:
		- 20180207@Amanda: Get sports by product code [Redmine: #80941]

	Paramters Explanation:
		@ProductCode: Product code
*/  
RETURNS @sports TABLE (ID INT)
BEGIN
	-- SB, BA --
	IF @ProductCode = 'SB' OR @ProductCode = 'BA'
	BEGIN
		;WITH cte_tmpSport AS (SELECT 1 AS id UNION ALL SELECT id + 1 FROM cte_tmpSport WHERE id + 1 <= 99)
		INSERT INTO @sports(ID)
		SELECT id, 0
		FROM cte_tmpSport
		OPTION (MAXRECURSION 100)
		
		INSERT INTO @sports(ID)
		VALUES (154)
	END	
	-- VS --
	IF @ProductCode = 'VS'
	BEGIN
		INSERT INTO @sports(ID)
		VALUES	
		(180),
		(186),
		(184),
		(181),
		(182),
		(183),
		(185)
	END
	-- VS2 --
	IF @ProductCode = 'VS2'
	BEGIN
		INSERT INTO @sports(ID)
		VALUES 
		(190),
		(191),
		(192),
		(193)
	END
	-- NG --
	IF @ProductCode = 'NG'
	BEGIN
		INSERT INTO @sports(ID)
		VALUES (161)
	END

RETURN
END
GO

GRANT SELECT ON [dbo].[Lrf_f_GetSportTypeByProduct] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_GetSportTypeByProduct] TO [vnteam]
GO