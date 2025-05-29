/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_MatchMonitoring_SelTriggeredAlert]
	@MonitoringID		INT
AS

/*
	Created: 20250522@Kelvin
	Task: Get Triggered Alert for Match Monitoring
	DB: DBBOF-bodb02

	Revisions:
		- 20250522@Kelvin: Match Monitoring Center [Redmine #227673]
*/

BEGIN
	SET NOCOUNT ON
	
	;WITH CTE_Alert AS
	(
		SELECT 
			h.LogDate

			-- Detected Info
			,'Negative Profit Forecast ' + 
			FORMAT(e.NegativeProfit, 'N2') + 
			' | ' + e.BaseCurrency + 
			' | ' + FORMAT(e.HomeStakePercentage, 'N2') + '%:' + FORMAT(e.AwayStakePercentage, 'N2') + '%' AS [DetectedInfo]

			-- Alert Rule
			,'Name:[' + s.SettingName + '] | ' + 
			FORMAT(s.NegativeProfit, 'N2') + 
			' | ' + s.BaseCurrency + 
			' | ' + 
			CASE s.ConditionType 
				WHEN 0 THEN 'Or' 
				WHEN 1 THEN 'And' 
				ELSE '' 
			END + ' | ' + FORMAT(s.BetRatio, 'N2') + '%' AS [AlertRule]
		FROM 
			bodb_LicenseeReport.dbo.LicenseeMatchMonitoring_History (NOLOCK) h
			-- Parse ExtraInfo
			CROSS APPLY OPENJSON(h.ExtraInfo)
			WITH (
				SettingID INT,
				NegativeProfit MONEY,
				BaseCurrency VARCHAR(10),
				HomeStakePercentage DECIMAL(5,2),
				AwayStakePercentage DECIMAL(5,2)
			) AS e

			-- Parse SettingInfo
			CROSS APPLY OPENJSON(h.SettingInfo)
			WITH (
				SettingID INT,
				SettingName NVARCHAR(100),
				NegativeProfit MONEY,
				BaseCurrency VARCHAR(10),
				ConditionType TINYINT,
				BetRatio DECIMAL(5,2)
			) AS s
		WHERE 
			h.MonitoringID = @MonitoringID
			AND e.SettingID = s.SettingID -- Join by SettingID (ensure both match)
	)
	SELECT 
		FORMAT(DATEADD(HOUR, 12, LogDate), 'yyyy-MM-dd HH:mm:ss') AS [LogDate] -- (GMT-4) -> (GMT+8)
		,'[' + STRING_AGG('"' + DetectedInfo + '"',',') + ']' AS [DetectedInfo]
		,'[' + STRING_AGG('"' + AlertRule + '"',',') + ']' AS [AlertRule]
	FROM CTE_Alert
	GROUP BY FORMAT(DATEADD(HOUR, 12, LogDate), 'yyyy-MM-dd HH:mm:ss')
	ORDER BY LogDate
END
GO
