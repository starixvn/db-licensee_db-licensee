/*<info serverAlias="DBLIC-bodb_licensee" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="1"></info>*/
USE [bodb_licensee]
GO

ALTER PROCEDURE [dbo].[WriteLog_UserLog_Login]
    @UserID			INT,  
    @ServerID		INT,   
    @LoginIP		VARCHAR(20)		= '', 
    @DomainName		NVARCHAR(253)	= NULL,
    @ActionID		INT				= 0,  
    @Doing			VARCHAR(4000),
    @BrowserName	NVARCHAR(255)	= NULL,
    @Platform		NVARCHAR(255)	= NULL,
    @CountryCode	VARCHAR(64)		= NULL,
    @Duration		INT				= NULL		 
AS

/*  
	Creator:
	Task: Insert login count statistic  
	DB: DBLIC.bodb_Licensee  
  
	Revisions:  
		- 20110505@Henry: change the table Userlog_login to Lrf_UserLog_Login AND put the table in bodb_CustomerLog
		- 20171002@Percy: Extend length of @Doing [RedmineID: #83692]
 
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
	
	INSERT INTO bodb_CustomerLog.dbo.UserLog_Login_Lrf (UserID, ServerID, IP, LogDate, ActionID, Doing, DomainName, BrowserName, Platform, CountryCode, Duration)
	VALUES (@UserID, @ServerID, @LoginIP, GETDATE(), @ActionID, @Doing, @DomainName, @BrowserName, @Platform, @CountryCode, @Duration)
END
GO