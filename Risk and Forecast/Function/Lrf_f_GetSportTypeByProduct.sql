/*<info serverAlias="DBLIC-bodb_Licensee" selecters="bodbLicenseeNet" viewers="" isFunction="1"></info>*/

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
		- 20181218@Joseph: Add New Sport Virtual Soccer Asian Cup [Redmine: #105409]
		- 20181213@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190227@Joseph: Betting ticket center phase 3b [RedmineID: #108221]
		- 20200326@Vickie: Add New Sport Virtual Soccer English Premier and Virtual Soccer Champions Cup [RedmineID: #131168]

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
		SELECT id
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
		(193),
		(194),
		(195),
		(196)
	END
	-- NG --
	IF @ProductCode = 'NG'
	BEGIN
		INSERT INTO @sports(ID)
		VALUES (161),(164)
	END
	-- Keno --
	IF @ProductCode = 'KN'
	BEGIN
		INSERT INTO @sports(ID)
		VALUES (202)
	END

	-- Lottery --
	IF @ProductCode = 'LT'
	BEGIN
		INSERT INTO @sports(ID)
		VALUES (220)
	END

	-- Cash Out --
	IF @ProductCode = 'CO'
	BEGIN
		INSERT INTO @sports(ID)
		VALUES (1)
	END

RETURN
END
GO