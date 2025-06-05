/*<info serverAlias="DBCUST-bodb_CustomerLog,DBLOG-bodb_CustomerLog" executers="wsv_lap" isNested="1"></info>*/

CREATE PROCEDURE [dbo].[Lrf_WriteLog_UserLog_LicenseeSetting]
    @UserId		INT,
	@IP			VARCHAR(15),
    @LicenseeID INT,
    @CurrencyID INT=0,
    @SPName		VARCHAR(50),
    @CustId		INT=0,
    @ActionId	INT,
    @Duration	INT,
    @Data		NVARCHAR(MAX),
    @OldData	NVARCHAR(MAX)=NULL
AS
/*
    Created: 20250521@Tacy
    Task: LAP - Insert log Licensee setting
    DB: DBCUST-bodb_CustomerLog,DBLOG-bodb_CustomerLog
    
    Revisions:
        - 20250521@Tacy: Create SP [RedmineID: #227673]
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.Userlog_LicenseeSetting (UserId,IP,LicenseeID,CurrencyID,SPName,CustId,ActionId,Duration,Data,OldData)
	SELECT @UserId,@IP,@LicenseeID,@CurrencyID,@SPName,@CustId,@ActionId,@Duration,CONVERT(XML, @Data),CONVERT(XML, @OldData)
END
GO