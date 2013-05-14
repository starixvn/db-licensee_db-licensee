ALTER PROCEDURE  [Lrf_GroupCommLog_Sel]    
	@LicenseeID int,
	@FromDate DATETIME,      
	@ToDate DATETIME    
AS       
/*     
Created:20130218@Scott    
Task: Get log for lrf Group commission
DB: bodb_CustomerLog      
      
Revisions:   
	20130411@Scott : Check Customer belong Licensee   
       
Param's Explaination:          
 - @FromDate: date range to view log      
 - @ToDate: date range to view log      
*/      
      
BEGIN      
SET NOCOUNT ON     
    
--### GET DATA     
SELECT Logid, LogDate,u.username 'Editedby',l.Actionid, actionnameen ActionName,  
	trackingvalue , trackingvalue2 as trackingvalueold    
FROM dbo.UserLog_RunSP l   with(nolock)  
	INNER JOIN  bodb_licensee.dbo.users u with(nolock) ON u.userid = l.userid    
	INNER JOIN LogAction a with(nolock) ON a.actionid = l.actionid    
	INNER JOIN bodb_licensee.dbo.LicenseeGroupComm  c with(nolock) on l.custid=c.id
WHERE	convert(varchar(12), Logdate ,113)  BETWEEN  @FromDate  AND  @ToDate AND  
		a.actionid in (2609,2610) and
		c.LicenseeID = @Licenseeid
		
UNION ALL

SELECT Logid, LogDate,u.username 'Editedby',l.Actionid, actionnameen ActionName,  
	trackingvalue , trackingvalue2 as trackingvalueold    
FROM dbo.UserLog_RunSP l   with(nolock)  
	INNER JOIN  bodb_licensee.dbo.users u with(nolock) ON u.userid = l.userid    
	INNER JOIN LogAction a with(nolock) ON a.actionid = l.actionid    
WHERE convert(varchar(12), Logdate ,113)  BETWEEN  @FromDate  AND  @ToDate    AND
	a.actionid = 2611 AND
	l.custid = @Licenseeid
ORDER BY logid desc

/*    
==========Execute sample=================    
exec  [Lrf_GroupCommLog_Sel]    
    @FromDate ='2013-01-05',      
    @ToDate = '2013-02-07'        
*/    
END    

GO
GRANT EXECUTE ON [dbo].[Lrf_GroupCommLog_Sel] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_GroupCommLog_Sel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GroupCommLog_Sel] TO [vnteam] 
