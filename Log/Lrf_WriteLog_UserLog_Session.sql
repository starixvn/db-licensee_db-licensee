/*<info serverAlias="DBCUST-bodb_CustomerLog" executers="wsv_lap" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_WriteLog_UserLog_Session_Wrapper]
    @SessionID VARCHAR(100),
    @UserID INT,
    @LicenseeID INT,
    @ServerID INT,
    @IP VARCHAR(15)='',
    @DomainName VARCHAR(253) = NULL,
    @BrowserName VARCHAR(255) = NULL,
    @Platform VARCHAR(255) = NULL
AS
/*
    Creator: Tacy
    Task: Insert log when user session
    DB: DBCUST/bodb_Licensee

    Revision:
		- 20250627@Tacy: Create SP [Redmine: #226373]
*/
BEGIN
    SET NOCOUNT ON;

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Session_Lrf
			@SessionID = @SessionID,
			@UserID = @UserID,
			@LicenseeID = @LicenseeID,
			@ServerID = @ServerID,
			@IP = @IP,
			@DomainName = @DomainName,
			@BrowserName = @BrowserName,
			@Platform = @Platform
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Session_Lrf
			@SessionID = @SessionID,
			@UserID = @UserID,
			@LicenseeID = @LicenseeID,
			@ServerID = @ServerID,
			@IP = @IP,
			@DomainName = @DomainName,
			@BrowserName = @BrowserName,
			@Platform = @Platform
	END CATCH
END 