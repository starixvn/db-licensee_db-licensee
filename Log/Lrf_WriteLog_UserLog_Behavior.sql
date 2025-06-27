/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE dbo.Lrf_WriteLog_UserLog_Behavior
    @SessionID     VARCHAR(50),
    @UserId        INT,
    @LicenseeID    INT,
    @ActionTypeID  INT,
    @SubTypeID     INT,
    @Target        VARCHAR(100),
    @FunctionKey   VARCHAR(50),
    @ExtraContext  NVARCHAR(4000) = NULL,
    @ErrCode	   INT=0 OUTPUT,
    @ErrMsg        NVARCHAR(200)='' OUTPUT
AS
/*
    Created:      20240702@Tacy
    Task:         Insert user log behavior into Lrf_UserLog_LicenseeBehavior [#227673]
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

    IF @ActionTypeID IS NULL OR 
	NOT EXISTS (SELECT 1 FROM Lrf_ActionType WITH (NOLOCK) WHERE ActionTypeID=@ActionTypeID)
    BEGIN
        SET @ErrCode = 2004;
        SET @ErrMsg  = 'ActionTypeID does not exists.';
        RETURN;
    END

    IF @SubTypeID IS NULL OR 
	NOT EXISTS (SELECT 1 FROM Lrf_SubType WITH (NOLOCK) WHERE SubTypeID=@SubTypeID)
    BEGIN
        SET @ErrCode = 2005;
        SET @ErrMsg  = 'SubTypeID does not exists.';
        RETURN;
    END

    IF (TRIM(ISNULL(@Target, '')) = '')
    BEGIN
        SET @ErrCode = 2006;
        SET @ErrMsg  = 'Target is required.';
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Lrf_UserLog_LicenseeBehavior
        (
            SessionID,
            UserID,
            LicenseeID,
            ActionTypeID,
            SubTypeID,
            Target,
            FunctionKey,
            ExtraContext
        )
        VALUES
        (
            @SessionID,
            @UserId,
            @LicenseeID,
            @ActionTypeID,
            @SubTypeID,
            @Target,
            @FunctionKey,
            @ExtraContext
        );
    END TRY
    BEGIN CATCH
        SET @ErrCode = ERROR_NUMBER();
        SET @ErrMsg  = ERROR_MESSAGE();
		
        RETURN;
    END CATCH
END;
GO 