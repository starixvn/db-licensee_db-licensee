/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoringSetting_Del]
    @SettingID INT,
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
        @SettingID: ID of the monitoring setting to delete
        @ErrCode: Output parameter for error code
        @ErrMsg: Output parameter for error message
*/
BEGIN
    SET NOCOUNT ON;
    DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
    DECLARE @ActionID INT = 4005, @LicenseeID INT
    DECLARE @logSpData NVARCHAR(MAX)

    SET @startRun = GETDATE()
    
    BEGIN TRY
        -- Check SettingID exists
        DECLARE @MonitoringID INT
        SELECT @MonitoringID = MonitoringID
        FROM [dbo].[LicenseeMatchMonitoringSetting] WITH(NOLOCK)
        WHERE SettingID = @SettingID

        IF @MonitoringID IS NULL
        BEGIN
            SET @ErrCode = 20
            SET @ErrMsg = 'Setting not found'
            RETURN
        END

		SET @logSpData = (SELECT s.MonitoringID
								, s.SettingID, s.SettingName, s.ConditionType
								, s.BaseCurrency, s.NotificationInterval,
								(SELECT d.RuleID, d.Threshold 
								 FROM [dbo].[LicenseeMatchMonitoringSetting_Detail] d WITH (NOLOCK)
								 WHERE d.SettingID = s.SettingID 
								 FOR XML RAW('Rules'), TYPE
								)
							FROM [dbo].[LicenseeMatchMonitoringSetting] s WITH (NOLOCK)
							WHERE s.SettingID = @SettingID
							FOR XML RAW('r'), ROOT('Root')
						)

        -- Delete rules first
        DELETE FROM [dbo].[LicenseeMatchMonitoringSetting_Detail] WITH(ROWLOCK)
        WHERE SettingID = @SettingID       

        DELETE FROM [dbo].[LicenseeMatchMonitoringSetting] WITH(ROWLOCK)
        WHERE SettingID = @SettingID

    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE()
        SET @ErrCode = ERROR_NUMBER()
        RETURN
    END CATCH

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)
	
	SELECT @LicenseeID=LicenseeId
	FROM LicenseeMatchMonitoring WITH (NOLOCK)
	WHERE MonitoringID=@MonitoringID
		
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting 
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoringSetting_Del',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoringSetting_Del',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData
	END CATCH
END
GO
