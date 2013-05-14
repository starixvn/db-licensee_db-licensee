ALTER PROCEDURE [dbo].[WriteLog_UserLog_Login]
    @UserID INT,  
    @ServerID INT,   
    @LoginIP VARCHAR(20)='', 
    @DomainName NVARCHAR(253) = NULL,
    @ActionID INT = 0,  
    @Doing VARCHAR(300),
    @BrowserName NVARCHAR(255) = NULL,
    @Platform NVARCHAR(255) = NULL,
    @CountryCode VARCHAR(64) = NULL,
    @Duration INT = NULL		 
AS  
/*  
Creator:  

Task: Insert login count statistic  
DB: DB052.bodb_Licensee  
 
  
Revisions:  
 - 20110505@Henry: change the table Userlog_login to Lrf_UserLog_Login AND put the table in bodb_CustomerLog
 
 
Param's Explanation:  
    • @UserID: main account login.  
    • @ServerID: serverID.  
    • @DomainName: Domain user login.  
    • @LoginIP: IP user login.  
    • @BrowserName: Browser user using.  
    • @Platform: Platform user login. 
    • @CountryCode: CountryCode user login.  
    • @Duration: Time process login
*/  
  
  
SET NOCOUNT ON  
	
	INSERT INTO bodb_CustomerLog.dbo.UserLog_Login_Lrf  (UserID,ServerID,IP,LogDate,ActionID,Doing,DomainName,BrowserName,Platform,CountryCode,Duration)
	values
	(
	@UserID,  
    @ServerID,   
    @LoginIP, 
    GETDATE(),
    @ActionID,  
    @Doing,
    @DomainName,
    @BrowserName,
    @Platform,
    @CountryCode,
    @Duration
	)
	


GO
GRANT EXECUTE ON [dbo].[WriteLog_UserLog_Login] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[WriteLog_UserLog_Login] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[WriteLog_UserLog_Login] TO [vnteam]