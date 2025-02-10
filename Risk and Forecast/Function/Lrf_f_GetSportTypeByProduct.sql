/*<info serverAlias="DBLIC-bodb_Licensee" selecters="wsv_lap" viewers="" isFunction="1"></info>*/

CREATE FUNCTION [dbo].[Lrf_f_GetSportTypeByProduct]  
(  
	@ProductCode VARCHAR(10)
)
RETURNS @Sports TABLE (Id SMALLINT)

/*
	Create: 20180207@Amanda
	Description: Get sports by product code
	DB: DBLIC.bodb_Licensee

	Revisions:
		- 20180207@Amanda: Get sports by product code [Redmine: #80941]
		- 20181218@Joseph: Add New Sport Virtual Soccer Asian Cup [Redmine: #105409]
		- 20181213@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190227@Joseph: Betting ticket center phase 3b [RedmineID: #108221]
		- 20200326@Vickie: Add New Sport Virtual Soccer English Premier and Virtual Soccer Champions Cup [RedmineID: #131168]
		- 20200408@Kos: Change to use SportBetTypeMatrix [RedmineID: #131447]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]

	Paramters Explanation:
		@ProductCode: Product code
*/
BEGIN

	INSERT INTO @Sports(Id)
	SELECT DISTINCT s.SportType
	FROM bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Products AS p WITH (NOLOCK) ON p.ProductID = s.ProductID
	WHERE p.ProductPrefix = @ProductCode
		AND s.SportType <> 154

	RETURN
END
GO