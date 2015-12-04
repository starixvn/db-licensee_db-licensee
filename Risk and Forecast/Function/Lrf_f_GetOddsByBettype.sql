  ALTER FUNCTION [dbo].[Lrf_f_GetOddsByBettype]
(	
	@Odds		MONEY,
	@bettype	INT,
	@OddsType	TINYINT = 1
)
RETURNS SMALLMONEY
/*	Created: Amy
	Date: 2011-04-08
	Task: Get the odds value added by bettype 
	DB: DB05.BODB02,DB052.BODB02, DB06.BODB02,DB06.BODB_Archive 

	Revisions: 		
		- 20110810@Henry: Add more bettype for number game
		- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
		
	Param's Explanation:
		+ Input: @Odds 
		+ Input: @bettype AND @oddsType: get the added values of odds (Dec AND American odds)		
*/
AS
BEGIN
	DECLARE	@OddsValue MONEY
	IF (@bettype IN (1,2,3,7,12,8,20) OR @bettype BETWEEN 81 AND 88 OR @bettype BETWEEN 90 AND 120) AND @OddsType = 1 SELECT @OddsValue = @Odds + 1
	ELSE IF (@bettype IN (1,2,3,7,12,8,20) OR @bettype BETWEEN 81 AND 88 OR @bettype BETWEEN 90 AND 120) AND @OddsType=5 SELECT @OddsValue = @Odds * 100 	
	ELSE SELECT @OddsValue = @Odds 
	RETURN @OddsValue 
END
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_GetOddsByBettype] TO [vnteam]
