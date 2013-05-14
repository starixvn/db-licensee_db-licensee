  
ALTER PROCEDURE Lrf_LeagueMatchSelRunning   
 @sporttype tinyint=1        
AS    
        
/*          
Created: 20130418@Scott        
Task: Get league, match running        
DB: DB052.bodb02          
Revisions:        
*/    
          
BEGIN        
        
SET NOCOUNT ON          
        
SELECT  match.sporttype, match.leagueid, match.matchid, match.homeid, match.awayid    
FROM league WITH ( NOLOCK )          
  INNER JOIN match WITH ( NOLOCK ) ON league.leagueid = match.leagueid          
WHERE match.sporttype =  @sporttype and        
   match.eventstatus ='running' and      
   match.matchcode not like '%hedge%' --and match.eventdate= CONVERT(VARCHAR(10), getdate(), 111)      

UNION ALL

SELECT l.sporttype, o.leagueid,o.orid ,o.teamid, 0
FROM outright o WITH(NOLOCK)
	INNER JOIN  League l With(nolock) on o.leagueid = l.leagueid
WHERE l.sporttype =  @sporttype  and   	
	o.oddsstatus = 'running'
         
END          
       

GO
GRANT EXECUTE ON [dbo].[Lrf_LeagueMatchSelRunning] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LeagueMatchSelRunning] TO [vnteam] AS [dbo]