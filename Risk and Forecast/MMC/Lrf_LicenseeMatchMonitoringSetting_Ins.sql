/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoringSetting_Ins]
    @MonitoringID	INT,
    @SettingName	NVARCHAR(100),
    @ConditionType	TINYINT,
    @BaseCurrency	VARCHAR(10),
    @NotificationInterval SMALLINT,
    @RulesJson		NVARCHAR(MAX)='',  
	@Langkey		VARCHAR(20)	= 'en-US',
    @UserId			INT = 0,
    @IP				VARCHAR(20) = '',
    @ErrCode		INT = 0 OUTPUT,
    @ErrMsg			NVARCHAR(500) = NULL OUTPUT
AS
/*
    Created: 20250521@Tacy
    Task: LAP - Match Monitoring Center
    DB: DBCUST-bodb_licensee
    
    Revisions:
        - 20250521@Tacy: Create SP [RedmineID: #227673]

    Param's Explanation:
        @ConditionType: 0 = OR, 1 = AND
        @BaseCurrency: Base currency for threshold comparison
        @NotificationInterval: Interval in seconds between notifications
        @RulesJson: JSON array of rules [{"RuleId":1,"Threshold":50000.00},{"RuleId":2,"Threshold":80.00}]
*/
BEGIN
    SET NOCOUNT ON;    
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
    DECLARE @ActionID INT = 4003, @LicenseeID INT
    DECLARE @logSpData NVARCHAR(MAX)
    
	SET @startRun = GETDATE()
    
    BEGIN TRY
        -- Validate inputs
        EXEC [dbo].[Lrf_LicenseeMatchMonitoringSetting_Check]
            @MonitoringID = @MonitoringID,
            @SettingName = @SettingName,
            @ConditionType = @ConditionType,
            @BaseCurrency = @BaseCurrency,
            @NotificationInterval = @NotificationInterval,
			@RulesJson = @RulesJson,
			@Langkey = @Langkey,
            @ErrCode = @ErrCode OUTPUT,
            @ErrMsg = @ErrMsg OUTPUT

        IF @ErrCode <> 0
            RETURN

        DECLARE @SettingID INT

        INSERT INTO [dbo].[LicenseeMatchMonitoringSetting]
        (
            SettingName,
            MonitoringID,
            ConditionType,
            BaseCurrency,
            NotificationInterval
        )
        VALUES
        (
            @SettingName,
            @MonitoringID,
            @ConditionType,
            @BaseCurrency,
            @NotificationInterval
        )

        SET @SettingID = SCOPE_IDENTITY()        -- Insert rules from JSON

        INSERT INTO [dbo].[LicenseeMatchMonitoringSetting_Detail]
        (
            SettingID,
            RuleID,
            Threshold
        )
        SELECT 
            @SettingID,
            JSON_VALUE(r.value, '$.RuleId'),
            JSON_VALUE(r.value, '$.Threshold')        
		FROM OPENJSON(@RulesJson) r

    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE()
        SET @ErrCode = ERROR_NUMBER()
        RETURN
    END CATCH

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)

	SET @logSpData = (
						SELECT 
							@MonitoringID AS MonitoringID,
							@SettingID AS SettingID,
							@SettingName AS SettingName,
							@ConditionType AS ConditionType,
							@BaseCurrency AS BaseCurrency,
							@NotificationInterval AS NotificationInterval,
							(SELECT 
									JSON_VALUE(r.value, '$.RuleId') AS RuleId,
									JSON_VALUE(r.value, '$.Threshold') AS Threshold        
							FROM OPENJSON(@RulesJson) r
							FOR XML RAW('Rules'), TYPE)
						FOR XML RAW('r'), ROOT('Root')
					)

	SELECT @LicenseeID=LicenseeId
	FROM LicenseeMatchMonitoring WITH (NOLOCK)
	WHERE MonitoringID=@MonitoringID

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting 
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoringSetting_Ins',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoringSetting_Ins',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData
	END CATCH
END
GO