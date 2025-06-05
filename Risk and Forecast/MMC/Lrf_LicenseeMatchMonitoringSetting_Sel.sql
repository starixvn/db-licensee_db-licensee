/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoringSetting_Sel]
    @MonitoringID INT
AS
/*
    Created: 20250521@Tacy
    Task: LAP - Match Monitoring Center
    DB: DBCUST-bodb_licensee
    
    Revisions:
        - 20250521@Tacy: Create SP [RedmineID: #227673]
*/
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.SettingID,
        s.SettingName,
        s.ConditionType,
        CASE s.ConditionType 
            WHEN 0 THEN 'OR'
            WHEN 1 THEN 'AND'
        END AS ConditionTypeName,
        s.BaseCurrency,
        s.NotificationInterval,
        (SELECT r.RuleName,
				d.Threshold
		 FROM [dbo].[LicenseeMatchMonitoringSetting_Detail] d WITH(NOLOCK)
		 INNER JOIN [dbo].[LicenseeMatchMonitoringRule] r WITH(NOLOCK) ON d.RuleID = r.RuleID
		 WHERE d.SettingID=s.SettingID
		 FOR JSON PATH
		) rules
    FROM [dbo].[LicenseeMatchMonitoringSetting] s WITH(NOLOCK)
	INNER JOIN LicenseeMatchMonitoring m WITH (NOLOCK) ON m.MonitoringID=s.MonitoringID
    WHERE m.MonitoringID = @MonitoringID
		AND m.IsActive=1
    ORDER BY s.SettingID
END
GO
