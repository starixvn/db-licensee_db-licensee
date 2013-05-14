
ALTER PROCEDURE [dbo].[Lrf_UserLog_LoginSel]        
 @LicenseeID  as INT,       
 @UserName AS VARCHAR(50)    
AS         
/*       
Created:20130204@Scott      
Task: Get Log status user login      
DB: DB06.BODB02        
        
Revisions:        
 20130314@Scott : fix bug validation input parameter  
 20130325@Scott : remove  parameter @FromDate, @ToDate    
 20130411@Scott : Check Customer belong Licensee  
         
Param's Explaination:            
 - @UserName: customer name type in textbox to search        
 - @FromDate: date range to view log        
 - @ToDate: date range to view log
==========Execute sample=================      
exec  [Lrf_UserLog_LoginSel]  
	@LicenseeID=4
	@UserName=N'AlogIN01002',
*/        
        
SET NOCOUNT ON       
      
--### DECLARE VARIABLE ###--      
DECLARE @Custid int      
DECLARE @CreatedDate DATETIME,@LastLogin DATETIME, @LastTransactionDate DATETIME   
declare @UserName2 varchar(50)   

IF (@UserName is null or @UserName= '')
	return;

SELECT @UserName2=licenseeName+'$'+@Username 
FROM bodb_Licensee.dbo.Licensees WITH(NOLOCK)  
WHERE LicenseeID = @LicenseeID
    
--### SET VALUE FOR VARIABLE ###--      
SELECT	@CreatedDate=creatdate, 
		@Custid = c.custid       
FROM customer c WITH(NOLOCK) 
	INNER JOIN bodb_Licensee.dbo.LicenseeCust l WITH(NOLOCK) on c.recommend = l.custid         
WHERE   ( username = @Username or username2 = @Username2 ) 	AND 
		l.licenseeid = @LicenseeID  and c.roleid = 1

IF @Custid IS NULL
	Return;
      
--### CALCULATE LAST @LastTransactionDate        
SELECT @LastTransactionDate = MAX(transdate)       
FROM bettrans WITH (NOLOCK)        
WHERE custid = @Custid      

--### RESULTSET      
IF (@CreatedDate IS NOT NULL OR @LastTransactionDate IS NOT NULL)
	SELECT @UserName username, @CreatedDate Createddate, @LastTransactionDate LastTxn
GO 


GRANT VIEW DEFINITION ON [dbo].[Lrf_UserLog_LoginSel] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[Lrf_UserLog_LoginSel] TO [bodbLicenseeNet]
GO 
GRANT EXECUTE ON [dbo].[Lrf_UserLog_LoginSel] TO [bodbAdminNet]
GO 
