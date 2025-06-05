/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoringLog_Sel]
    @MonitoringID   INT,
    @LicenseeId     INT,
	@LicenseeName	VARCHAR(50),
    @ActionIDs      VARCHAR(100),
    @FromDate       DATETIME = NULL,
    @ToDate         DATETIME = NULL
AS
/*
    Created: 20250529@Tacy
    Task: LAP - Match Monitoring Center - Log View
    DB: DBCUST-bodb_licensee
    
    Revisions:
        - 20250529@Tacy: Create SP  [RedmineID: #227673]

    Param's Explanation:        
		@UserId: Filter by specific user
        @LicenseeId: Filter by specific licensee
        @ActionIDs: Filter by specific action IDs (comma separated)
        @FromDate: Filter logs from this date (inclusive)
        @ToDate: Filter logs until this date (inclusive)
*/
BEGIN
    SET NOCOUNT ON;
	
	SET @ToDate=GETDATE()

	--TODO: get MBU days
	DECLARE @MoveBetsDay SMALLDATETIME
	EXEC bodb02.dbo.NAP_Admin_GetMovebetDate @MovebetDate = @MoveBetsDay OUTPUT

	SELECT @FromDate = DATEADD(DAY,1,@MoveBetsDay)

	CREATE TABLE #log (	LogId BIGINT, 
						LogDate DATETIME,
						UserId INT, 
						ActionId INT, 
						ActionTypeId INT,
						[Data] XML,
						OldData XML)

    ;WITH ActionIDs AS (
        SELECT CAST(value AS INT) AS ActionId
        FROM STRING_SPLIT(@ActionIDs, ',')
        WHERE @ActionIDs IS NOT NULL
    )
	INSERT INTO #log (LogDate, LogId, ActionTypeId, ActionId, UserId, [Data], OldData)    	
	SELECT l.LogDate, l.LogId
		, lat.ActionTypeId, la.ActionId
		, l.UserId, l.Data, l.OldData
    FROM Userlog_LicenseeSetting l WITH (NOLOCK)
	INNER JOIN dbo.LogAction_lic la WITH (NOLOCK) ON l.ActionId = la.ActionId
    INNER JOIN dbo.LogActionType_lic lat WITH (NOLOCK) ON la.ActionTypeId = lat.ActionTypeId
	WHERE l.LicenseeId = @LicenseeId
        AND l.ActionId IN (SELECT ActionId FROM ActionIDs)
        AND l.LogDate BETWEEN @FromDate AND @ToDate

	-- Filter by MonitoringID
	;WITH tmpLog AS (
		SELECT DISTINCT l.LogId
		FROM #log l
		CROSS APPLY (VALUES(l.Data)) AS v(Casted)
		CROSS APPLY v.Casted.nodes('/Root/r') AS x(Control)
		WHERE x.Control.value('@MonitoringID', 'int')=@MonitoringID
	)
	DELETE l
	FROM #log l
	LEFT JOIN tmpLog T on T.LogId=l.LogId
	WHERE t.LogId IS NULL;

	-- transform XML data for ActionID=4006:
	;WITH FilteredXml AS (
		SELECT 
			l.LogId,
			(
					SELECT 
						x.r.value('@MonitoringID', 'int') AS [@MonitoringID],
						x.r.value('@SettingID', 'int') AS [@SettingID],
						x.r.value('@SettingName', 'nvarchar(100)') AS [@SettingName],
						x.r.value('@NegativeProfit', 'decimal(18,4)') AS [@NegativeProfit],
						x.r.value('@BaseCurrency', 'varchar(10)') AS [@BaseCurrency],
						x.r.value('@ConditionType', 'int') AS [@ConditionType],
						x.r.value('@BetRatio', 'decimal(18,4)') AS [@BetRatio],
						x.r.value('@ForecastLoss', 'decimal(18,4)') AS [@ForecastLoss],
						x.r.value('@HomeStakePercentage', 'decimal(18,2)') AS [@HomeStakePercentage],
						x.r.value('@AwayStakePercentage', 'decimal(18,2)') AS [@AwayStakePercentage]
					FROM l.Data.nodes('/Root/r') AS x(r)
					WHERE x.r.value('@MonitoringID', 'int') = @MonitoringID
					FOR XML PATH('r'), ROOT('Root')
				)
			AS TransformedData
		FROM #log l
		WHERE ActionId=4006
	)
	UPDATE l
	SET l.Data = f.TransformedData
	FROM #log l
	INNER JOIN FilteredXml f ON f.LogId = l.LogId;

	--IF @FromDate >= @LapLaunchDate
	BEGIN
		CREATE TABLE #lapUsers (UserId INT, Editedby NVARCHAR(20))
		INSERT INTO #lapUsers (UserId, Editedby)
		SELECT UserSEQ, UserID
		FROM DBCUST.SiteConfig.dbo.users WITH(NOLOCK)
		WHERE SiteName = @LicenseeName
		
		SELECT	l.LogId,
				DATEADD(HOUR, 12, l.LogDate) AS LogDate,
				u.Editedby AS Operator,
				l.ActionId,
				l.[Data],
				l.OldData
		FROM #log l
			INNER JOIN #lapUsers u ON u.UserId = l.userid
		UNION ALL
		SELECT	l.LogId,
				DATEADD(HOUR, 12, l.LogDate) AS LogDate,
				'System' AS Operator,
				l.ActionId,
				l.[Data],
				l.OldData
		FROM #log l
		WHERE l.UserId=0
		ORDER BY l.logid DESC
		
		DROP TABLE #lapUsers
	END
END
GO
