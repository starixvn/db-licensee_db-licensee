ALTER   PROCEDURE  [Lrf_CustomerSettingLog_Sel]    
	@LicenseeID INT ,
	@UserName AS VARCHAR(50),     
	@FilterBy SMALLINT=0,     
	@FromDate DATETIME,      
	@ToDate DATETIME    
AS       
/*     
Created:20130206@Scott    
Task: Get log for lrf customer setting    
DB: bodb_CustomerLog      
      
Revisions:      
	20130411Scott : Check Customer belong Licensee
	20131126@Jim: return result-table with NULL value if search condition are not match
       
Param's Explaination:          
 - @UserName: customer name type in textbox to search      
 - @FilterBy : 0 - View All    
      1 - View BA    
      2 - View by Status    
      3 - View by Commission    
      4 - View by Special Level.
	  5	- View by Currency
           
 - @FromDate: date range to view log      
 - @ToDate: date range to view log 
 
==========Execute sample=================    
exec  Lrf_CustomerSettingLog_Sel    
	@LicenseeID = 1,
	@UserName=N'AlogIN01002',    
    @FromDate ='2013-02-05',      
    @ToDate = '2013-02-07'        
 
*/      
      
BEGIN      
SET NOCOUNT ON     
     
--### DECLARE VARIABLE ###--    
DECLARE @custid INT ,@status int   
DECLARE @RowFilter table ( Actionid int)
declare @UserName2 varchar(50)   

IF (@UserName is null or @UserName= '')
	return;

SELECT @UserName2=licenseeName+'$'+@Username 
FROM bodb_Licensee.dbo.Licensees 
WHERE LicenseeID = @LicenseeID
    
--### SET VALUE FOR VARIABLE ###--      
SELECT	@Custid = c.custid       
FROM bodb02.dbo.customer c WITH(NOLOCK) 
	INNER JOIN bodb_Licensee.dbo.LicenseeCust l WITH(NOLOCK) on c.recommend = l.custid         
WHERE   ( username = @Username or username2 = @Username2 ) 	AND 
		l.licenseeid = @LicenseeID  and c.roleid = 1
/*
IF @Custid IS NULL
	Return;
*/	
 
--### set actionid by @rowfilter    
    
--Default view all    

INSERT INTO @RowFilter VALUES (2401)    
INSERT INTO @RowFilter VALUES (2403)    
INSERT INTO @RowFilter VALUES (2200)    
INSERT INTO @RowFilter VALUES (2201)    
INSERT INTO @RowFilter VALUES (2612)    
INSERT INTO @RowFilter VALUES (2407)    

 
 
IF @filterby=1     
	DELETE @RowFilter WHERE actionid not in (2401,2403)    
IF @filterby=2    
	DELETE @RowFilter WHERE actionid not in (2200,2201)    
IF @filterby=3    
	DELETE @RowFilter WHERE actionid not in (2612)    
IF @filterby=4    
	DELETE @RowFilter WHERE actionid not in (2407)    
   
--### GET DATA     
SELECT Logid, LogDate,u.username 'Editedby',l.Actionid,    
		CASE	WHEN l.Actionid = 2401 then 'Turn On BA'     
				WHEN l.Actionid = 2403 then 'Turn Off BA'    
		ELSE actionnameen END ActionName,     
	trackingvalue , trackingvalue2 as trackingvalueold    
FROM dbo.UserLog_RunSP l     
	INNER JOIN  bodb_licensee.dbo.users u ON u.userid = l.userid    
	INNER JOIN LogAction a ON a.actionid = l.actionid    
	INNER JOIN @RowFilter r ON r.actionid = l.actionid    
WHERE custid = @custid   And
	convert(varchar(12), Logdate ,113)  BETWEEN  @FromDate  AND  @ToDate   
ORDER BY logdate      
  

END    

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSettingLog_Sel] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSettingLog_Sel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSettingLog_Sel] TO [vnteam] 
