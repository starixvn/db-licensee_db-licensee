/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoring_Upd]
    @MonitoringID INT,
    @UserId INT = 0,
    @IP VARCHAR(20) = '',
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(500) = NULL OUTPUT
AS
/*
    Created: 20250521@Tacy
    Task: LAP - Match Monitoring Center
    DB: DBCUST-bodb_licensee
    
    Revisions:
        - 20250521@Tacy: Create SP [RedmineID: #227673]

    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;    
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
    DECLARE @ActionID INT = 4002, @LicenseeID INT
    DECLARE @logSpData NVARCHAR(MAX)

    SET @startRun = GETDATE()
    
    BEGIN TRY
        -- Check if monitoring exists
        IF NOT EXISTS (
            SELECT 1 
            FROM [dbo].[LicenseeMatchMonitoring] WITH(NOLOCK)
            WHERE MonitoringID = @MonitoringID
        )
        BEGIN
            SET @ErrCode = 98
            SET @ErrMsg = 'Monitoring record not found'
            RETURN 
        END

		-- Check if monitoring exists
        IF EXISTS (
            SELECT 1 
            FROM [dbo].[LicenseeMatchMonitoring] WITH(NOLOCK)
            WHERE MonitoringID = @MonitoringID AND IsActive=0
        )
        BEGIN
            SET @ErrCode = 99
            SET @ErrMsg = 'Monitoring record not found'
            RETURN 
        END        

		-- Update monitoring status
        UPDATE [dbo].[LicenseeMatchMonitoring] WITH (ROWLOCK, UPDLOCK)
        SET IsActive = 0
        WHERE MonitoringID = @MonitoringID

	END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE()
        SET @ErrCode = ERROR_NUMBER()
        RETURN
    END CATCH

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)

	SET @logSpData = (SELECT MonitoringID, LicenseeId, MatchID, BetType
						,LiveIndicator, LiveHomeScore, LiveAwayScore
						FROM [dbo].[LicenseeMatchMonitoring] 
						WHERE MonitoringID = @MonitoringID 
						FOR XML RAW ('r'), ROOT('Root'))

	SELECT @LicenseeID=LicenseeId
	FROM LicenseeMatchMonitoring WITH (NOLOCK)
	WHERE MonitoringID=@MonitoringID
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting 
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoring_Upd',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData,
			@OldData = NULL
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoring_Upd',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData,
			@OldData = NULL
	END CATCH
END
GO
