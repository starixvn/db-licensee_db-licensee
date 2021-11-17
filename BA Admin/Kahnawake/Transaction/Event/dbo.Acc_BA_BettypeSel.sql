ALTER PROCEDURE [dbo].[Acc_BA_BettypeSel]
	
AS

/*
Created: Henry  
Date: 2011-08-08
Task : Get Bettype for BA Bet List
DB: DB052.bodb02

Revisions:
	- 20111107@Henry: exclude NextGoal bettype
	- 20111208@Jim: change condition typeid<31 
Param's Explanation:
*/

SET NOCOUNT ON


SELECT 
	typeid AS Bettype,
	typenamee AS BettypeName 
	
FROM Bettype (NOLOCK)
WHERE (typeid < 31  OR  (typeid BETWEEN 121 AND 999))
AND typeid <> 22 --next goal


GO
GRANT EXECUTE ON [dbo].[Acc_BA_BettypeSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BA_BettypeSel] TO [vnteam] 