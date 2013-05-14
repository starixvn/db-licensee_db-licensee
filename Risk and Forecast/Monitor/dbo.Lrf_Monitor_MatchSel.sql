ALTER PROCEDURE [dbo].[Lrf_Monitor_MatchSel]
AS

/*	
Created	: Henry
Task: Monitor lastest bets list- get match running
Date: 2011/10/11
DB: DB052.BODB02
Original: Age_Monitor_MatchSel
Revision:

Parameter's Explanation:		
	
*/ 

BEGIN
SET NOCOUNT ON

SELECT 
	sporttype AS sporttype,
	eventstatus AS status,
	matchid,
	leagueid,
	matchcode,
	homeid,
	awayid,
	'' AS race
FROM MATCH WITH(NOLOCK)
WHERE eventstatus <> 'completed' 

END
 
GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_MatchSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_MatchSel] TO [vnteam] 