/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE dbo.Lrf_WriteLog_UserLog_Session
    @SessionID    VARCHAR(50),
    @UserId       INT,
    @LicenseeID   INT,
    @IP           VARCHAR(15),
    @DomainName   VARCHAR(200) = NULL,
    @BrowserName  VARCHAR(100) = NULL,
    @Platform     VARCHAR(100) = NULL,
    @ErrCode    INT = 0 OUTPUT,
    @ErrMsg     VARCHAR(200) = '' OUTPUT
AS
/*
    Created:      20240702@Tacy
    Task:         Insert user log session into Lrf_UserLog_Session [#227673]
    DB:           DBLOG-bodb_CustomerLog
    Revisions:
        - 20240702@Tacy: Initial creation [redmine: #227673]
*/
BEGIN
    SET NOCOUNT ON;

    SET @ErrCode = 0;
    SET @ErrMsg  = '';

    -- Input validation
    IF (TRIM(ISNULL(@SessionID, '')) = '')
    BEGIN
        SET @ErrCode = 1001;
        SET @ErrMsg  = 'SessionID is required.';
        RETURN;
    END

    IF @UserId IS NULL
    BEGIN
        SET @ErrCode = 1002;
        SET @ErrMsg  = 'UserId is required.';
        RETURN;
    END

    IF @LicenseeID IS NULL OR
	NOT EXISTS (SELECT 1 FROM bodb_Licensee.dbo.Licensees l WITH (NOLOCK) WHERE LicenseeID=@LicenseeID)
    BEGIN
        SET @ErrCode = 1003;
        SET @ErrMsg  = 'This Licensee does not exists.';
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Lrf_UserLog_Session
        (
            SessionID,
            UserID,
            LicenseeID,
            IP,
            DomainName,
            BrowserName,
            Platform
        )
        VALUES
        (
            @SessionID,
            @UserId,
            @LicenseeID,
            @IP,
            @DomainName,
            @BrowserName,
            @Platform
        );
    END TRY
    BEGIN CATCH
        SET @ErrCode = ERROR_NUMBER();
        SET @ErrMsg  = ERROR_MESSAGE();

        RETURN;
    END CATCH
END;
GO 