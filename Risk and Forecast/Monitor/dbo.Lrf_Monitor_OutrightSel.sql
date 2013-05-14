ALTER PROCEDURE [dbo].[Lrf_Monitor_OutrightSel]
AS

/*	
Created	: Henry
Task: Monitor lastest bets list- get outright running
Date: 2011/10/11
DB: DB052.BODB02
Revision:
Original: Age_Monitor_OutrightSel
Parameter's Explanation:		
	
*/ 

BEGIN
SET NOCOUNT ON


SELECT 
	l.sporttype AS sporttype,
	m.oddsstatus AS status,
	m.orid AS matchid,		
	m.leagueid,
	m.matchcode,		
	m.teamid AS homeid,
	0 AS awayid,
	ISNULL(m.groupmatch,'') AS race
FROM outright m WITH(NOLOCK)
	INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
WHERE oddsstatus <> 'completed' 
	AND eventdate >= CONVERT(varchar(10),DATEADD(dd,-1,CURRENT_TIMESTAMP),120)
END
 
 
 
GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_OutrightSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_OutrightSel] TO [vnteam] 