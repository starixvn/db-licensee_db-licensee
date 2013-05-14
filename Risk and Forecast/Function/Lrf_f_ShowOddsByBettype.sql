ALTER FUNCTION [dbo].[Lrf_f_ShowOddsByBettype]
(	@bettype	INT,
	@OddsType	TINYINT = 1
)
RETURNS TINYINT
/*	Created: Henry
	Date: 2010-12-25
	Task: Get the odds value added by bettype For Licensee Site
	DB: DB05.BODB02,DB052.BODB02, DB06.BODB02,DB06.BODB_Archive 
	Original: [f_ShowOddsByBettype]
	
	Revisions: 		
		20110408@Amy: Modify to show American odds (oddstype=5)	
		20110810@Henry: Add more bettype for number game
	Param's Explanation:
		+ Input: @bettype AND @oddsType: show the added values of odds 
		+ Input @bettype AND default @OddsType = 1 to indicate the odds type whether shown or not 
*/
AS
BEGIN
	DECLARE	@ShowOdds TINYINT
	IF @bettype IN (1,2,3,7,12,8,20) OR @bettype BETWEEN 81 AND 88 OR @bettype BETWEEN 90 AND 120 SELECT @ShowOdds = @OddsType	
	ELSE SELECT @ShowOdds = 0 
	RETURN @ShowOdds 
END
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_ShowOddsByBettype] TO [vnteam]
