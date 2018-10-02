/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb_Licensee]
GO

ALTER PROCEDURE LAP_WriteLog_UserLog_LicenseeBAConfig_Wrapper
	@UserID INT,
	@LicenseeID INT,
	@1x2Comm DECIMAL(9,8),
	@OtherComm DECIMAL(9,8),
	@EnableBA BIT,
	@IP VARCHAR(40),
	@ActionID INT,	
	@Groupa DECIMAL(9,8),			
	@Groupb DECIMAL(9,8),
	@Groupc DECIMAL(9,8),
	@Groupd DECIMAL(9,8)
AS
/* 
	Created: 20180924@Elodie
    Task: ViewLog function
    DB: DBCUST/bodb_Licensee

	Revisions:
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

    Param's Explaination:    	
		- @UserID: UserId perform this action
		- @ActionID: Log action Id
*/
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON  

	--write log
	INSERT INTO DBLOG.bodb_CustomerLog.dbo.UserLog_LicenseeBAConfig (LicenseeID, groupa, groupb, groupc, groupd,  [1x2Comm], [OtherComm], EnableBA , IP, ActionID, ModifyBy, ModifyDate)
	VALUES (@LicenseeID, @Groupa, @Groupb, @Groupc, @Groupd,  @1x2Comm, @OtherComm, @EnableBA , @IP, @ActionID, @UserID, getdate())

END
GO
