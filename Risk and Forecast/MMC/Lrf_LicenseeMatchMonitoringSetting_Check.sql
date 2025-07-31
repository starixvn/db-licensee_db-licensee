/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoringSetting_Check]
    @MonitoringID	INT,
	@SettingID		INT = NULL,
    @SettingName	NVARCHAR(100),
    @ConditionType	TINYINT, 
    @BaseCurrency	VARCHAR(10),
    @NotificationInterval SMALLINT,
    @RulesJson		NVARCHAR(MAX) = NULL,
	@Langkey		VARCHAR(20)	= 'en-US',
    @ErrCode		INT = 0 OUTPUT,
    @ErrMsg			NVARCHAR(500) = NULL OUTPUT
AS
/*
    Created: 20250521@Tacy
    Task: LAP - Match Monitoring Center
    DB: DBCUST-bodb_licensee
    
    Revisions:
        - 20250521@Tacy: Create SP [RedmineID: #227673]
        - 20250728@Tacy: Add "Only Once" Option for Alert Notification [RedmineID: #233693]

    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
    
    -- Initialize
    SET @ErrCode = 0
    SET @ErrMsg = NULL

	-- Check SettingID exists
	IF @MonitoringID IS NULL
	BEGIN
		SET @ErrCode = 20
		SET @ErrMsg = 'Setting not found.'
		RETURN
	END
	
	-- Check MonitoringID exists
    IF NOT EXISTS (
        SELECT 1 
        FROM [dbo].[LicenseeMatchMonitoring] WITH(NOLOCK)
        WHERE MonitoringID = @MonitoringID
        AND IsActive = 1
    )
    BEGIN
        SET @ErrCode = 10
        SET @ErrMsg = 'Invalid MonitoringID.'
        RETURN
    END

    -- Validate ConditionType
    IF @ConditionType NOT IN (0, 1)
    BEGIN
        SET @ErrCode = 12
        SET @ErrMsg = 'Invalid ConditionType. Must be 0 (OR) or 1 (AND).'
        RETURN
    END

    -- Validate NotificationInterval    
	IF @NotificationInterval <= -2
    BEGIN
        SET @ErrCode = 13
        SET @ErrMsg = 'Invalid NotificationInterval.'
        RETURN
    END

    -- Check SettingName duplicate
    IF EXISTS (
        SELECT 1 
        FROM [dbo].[LicenseeMatchMonitoringSetting] WITH(NOLOCK)
        WHERE MonitoringID=@MonitoringID 
			AND SettingName = @SettingName
			AND ((@SettingID IS NOT NULL AND SettingID<>@SettingID)
				OR @SettingID IS NULL)
    )
    BEGIN
        SET @ErrCode = 14        
		SET @ErrMsg = CASE WHEN @Langkey='en-US'
							THEN 'Setting name already exists for this monitoring.'
							ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200054, @Langkey)
						END
        RETURN
    END

	--
	IF TRIM(ISNULL(@BaseCurrency,''))=''
	BEGIN
		SET @ErrCode = 18
        SET @ErrMsg = 'Invalid BaseCurrency.'
        RETURN 
	END

    -- Validate JSON rules if provided
    IF @RulesJson IS NOT NULL
    BEGIN
        IF ISJSON(@RulesJson) = 0
        BEGIN
            SET @ErrCode = 15
            SET @ErrMsg = 'Invalid JSON format for Rules.'
            RETURN
        END

		 IF EXISTS (
            SELECT 1
            FROM OPENJSON(@RulesJson)
            WITH (
                RuleId SMALLINT '$.RuleId'
            ) r
            GROUP BY RuleId
			HAVING COUNT(1)>1
        )
		BEGIN
            SET @ErrCode = 15
            SET @ErrMsg = 'Invalid JSON format for Rules.'
            RETURN
        END

        -- Check if all rules exist
        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@RulesJson)
            WITH (
                RuleId SMALLINT '$.RuleId'
            ) r
            LEFT JOIN [dbo].[LicenseeMatchMonitoringRule] m ON r.RuleId = m.RuleID
            WHERE m.RuleID IS NULL
        )
        BEGIN
            SET @ErrCode = 16
            SET @ErrMsg = 'One or more RuleIds do not exist.'
            RETURN
        END       
		
		-- Check if all thresholds and ratios are valid
        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@RulesJson)
            WITH (
                RuleId SMALLINT '$.RuleId',
                Threshold MONEY '$.Threshold'
            ) r
			INNER JOIN [dbo].[LicenseeMatchMonitoringRule] m ON r.RuleId = m.RuleID
            WHERE m.RuleName='BetRatio'
				AND (r.Threshold < 0 OR r.Threshold > 100)  -- Validate Ratio for BetRatio rule
        )
        BEGIN
            SET @ErrCode = 17           			
			SET @ErrMsg = CASE WHEN @Langkey='en-US'
								THEN 'Invalid values in BetRatio rule: Ratio must be between 0 and 100.'
								ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200053, @Langkey)
							END
            RETURN
        END
    END

	--no change setting:
	SELECT TOP 1 @ErrCode=22
	FROM LicenseeMatchMonitoringSetting ls WITH (NOLOCK)
		INNER JOIN LicenseeMatchMonitoringSetting_Detail lsd WITH (NOLOCK)
			ON lsd.settingid=ls.settingid
		INNER JOIN OPENJSON(@RulesJson) WITH (
					RuleId SMALLINT  '$.RuleId',
					Threshold MONEY  '$.Threshold'
				) r
			ON r.RuleId=lsd.RuleID
	WHERE ls.MonitoringID=@MonitoringID
		AND ls.SettingID=@SettingID 
		AND SettingName=@SettingName
		AND ConditionType=@ConditionType
		AND BaseCurrency=@BaseCurrency
		AND NotificationInterval=@NotificationInterval
		AND lsd.Threshold=r.Threshold
	HAVING COUNT(1)>1

	IF @ErrCode = 22
	BEGIN
        SET @ErrMsg='Nothing change.'
		RETURN
	END
	
	-- Existing setting:
	SELECT TOP 1 @ErrCode=21
	FROM LicenseeMatchMonitoringSetting ls WITH (NOLOCK)
		INNER JOIN LicenseeMatchMonitoringSetting_Detail lsd WITH (NOLOCK)
			ON lsd.settingid=ls.settingid
		INNER JOIN OPENJSON(@RulesJson) WITH (
					RuleId SMALLINT  '$.RuleId',
					Threshold MONEY  '$.Threshold'
				) r
			ON r.RuleId=lsd.RuleID
	WHERE ls.MonitoringID=@MonitoringID
		AND ls.ConditionType=@ConditionType
		AND ls.BaseCurrency=@BaseCurrency
		AND lsd.Threshold=r.Threshold
		AND ((@SettingID IS NOT NULL AND ls.SettingID<>@SettingID)
			OR @SettingID IS NULL)
	GROUP BY ls.SettingID
	HAVING COUNT(1)>1

	IF @ErrCode = 21
	BEGIN        
		SET @ErrMsg= CASE WHEN @Langkey='en-US'
							THEN 'This setting is already existed.'
							ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200056, @Langkey)
						END
		RETURN
	END
END
GO