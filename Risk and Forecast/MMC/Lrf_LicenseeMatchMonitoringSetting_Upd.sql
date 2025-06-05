/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoringSetting_Upd]
    @SettingID		INT,
    @SettingName	NVARCHAR(100),
    @ConditionType	TINYINT,
    @BaseCurrency	VARCHAR(10),
    @NotificationInterval SMALLINT,
    @RulesJson		NVARCHAR(MAX), 
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
        @SettingID: ID of the monitoring setting to update
        @SettingName: Name of the monitoring setting
        @ConditionType: 0 = OR, 1 = AND
        @BaseCurrency: Base currency for threshold comparison
        @NotificationInterval: Interval in seconds between notifications
        @RulesJson: JSON array of rules [{"RuleId":1,"Threshold":50000.00},...]
        @ErrCode: Output parameter for error code
        @ErrMsg: Output parameter for error message
*/
BEGIN
    SET NOCOUNT ON;
    
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
    DECLARE @ActionID INT = 4004, @LicenseeID INT
    DECLARE @logSpData NVARCHAR(MAX), @logSpDataOld NVARCHAR(MAX)
    
	SET @startRun = GETDATE()
    
    BEGIN TRY
        -- Check SettingID exists
        DECLARE @MonitoringID INT
        SELECT @MonitoringID = MonitoringID
        FROM [dbo].[LicenseeMatchMonitoringSetting] WITH(NOLOCK)
        WHERE SettingID = @SettingID

        -- Validate inputs (except duplicate name check)
        EXEC [dbo].[Lrf_LicenseeMatchMonitoringSetting_Check]
            @MonitoringID = @MonitoringID,
			@SettingID = @SettingID,
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
		
		SET @logSpDataOld = (SELECT s.MonitoringID
									, s.SettingID, s.SettingName, s.ConditionType
									, s.BaseCurrency, s.NotificationInterval,
									(SELECT d.RuleID, d.Threshold 
									 FROM [dbo].[LicenseeMatchMonitoringSetting_Detail] d WITH (NOLOCK)
									 WHERE d.SettingID = s.SettingID 
									 FOR XML RAW('Rules'), TYPE
									)
							FROM [dbo].[LicenseeMatchMonitoringSetting] s WITH (NOLOCK)
							WHERE s.SettingID = @SettingID
							FOR XML RAW('r'), ROOT('Root'))

        UPDATE [dbo].[LicenseeMatchMonitoringSetting] WITH (ROWLOCK, UPDLOCK)
        SET SettingName = @SettingName,
            ConditionType = @ConditionType,
            BaseCurrency = @BaseCurrency,
            NotificationInterval = @NotificationInterval,
            ModifiedDate = GETDATE(),
			LastSendNotification = NULL
        WHERE SettingID = @SettingID

		UPDATE lsd
		SET lsd.Threshold=r.Threshold
		FROM LicenseeMatchMonitoringSetting_Detail lsd WITH (ROWLOCK, UPDLOCK)
		INNER JOIN OPENJSON(@RulesJson) WITH (
					RuleId SMALLINT  '$.RuleId',
					Threshold MONEY  '$.Threshold'
				) r
				ON r.RuleId=lsd.RuleID
		WHERE lsd.SettingID=@SettingID
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE()
        SET @ErrCode = ERROR_NUMBER()
		RETURN
    END CATCH

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)

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

	SELECT @LicenseeID=LicenseeId
	FROM LicenseeMatchMonitoring WITH (NOLOCK)
	WHERE MonitoringID=@MonitoringID	

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting 
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoringSetting_Upd',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData,
			@OldData = @logSpDataOld
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoringSetting_Upd',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData,
			@OldData = @logSpDataOld
	END CATCH
END
GO
