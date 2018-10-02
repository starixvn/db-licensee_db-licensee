/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet,bodbExtAccNet" viewers="vnteam" isFunction="0"></info>*/
USE bodb_Licensee
GO

ALTER PROCEDURE [dbo].[LAP_WriteLog_UserLog_Login_Wrapper]
    @UserID int,  
    @ServerID int,   
    @LoginIP VARCHAR(20)='', 
    @DomainName NVARCHAR(253) = NULL,
    @ActionID int = 0,  
    @Doing VARCHAR(300),
    @BrowserName NVARCHAR(255) = NULL,
    @Platform NVARCHAR(255) = NULL,
    @CountryCode VARCHAR(64) = NULL,
    @Duration INT = NULL		 
AS  
/*  
	Creator: 20180924@Elodie 
	Task: Insert log when user login
	DB: DBCUST/bodb_Licensee
  
	Revisions:  
		- 20180924@Elodie: Insert log when user login
 
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
BEGIN
	SET NOCOUNT ON 

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Login_Lrf
				@UserID = @UserID,
				@ServerID = @ServerID,
				@LoginIP = @LoginIP,
				@DomainName = @DomainName,	
				@ActionID = @ActionID,
				@Doing = @Doing,
				@BrowserName = @BrowserName,
				@Platform = @Platform,
				@CountryCode = @CountryCode,
				@Duration = @Duration
END  	
