/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Lrf_GroupCommLog_Sel]
	@LicenseeID			INT,
	@SiteName			VARCHAR(50),
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@LapLaunchDate		SMALLDATETIME = '2018-07-01'
AS       
/*     
Created:20130218@Scott    
Task: Get log for lrf Group commission
DB: bodb_CustomerLog      
      
Revisions:   
	20130411@Scott : Check Customer belong Licensee 
	20180711@Amanda: get username of LAP if log data is after LAP launch data [#97994]
	20190405@Patrick: Support archive date range [Redmine: #111476]
       
Param's Explaination:          
 - @FromDate: date range to view log
 - @ToDate: date range to view log      
*/      
      
BEGIN

	SET NOCOUNT ON
	
	DECLARE @logDataToDate DATE
	SELECT @logDataToDate = DATEADD(DAY, 1, @ToDate)
	
	CREATE TABLE #log (	LogId BIGINT, LogDate DATETIME,
						UserId INT, ActionId INT, 
						ActionName NVARCHAR(256), TrackingValue NVARCHAR(MAX),
						TrackingValueOld NVARCHAR(MAX))

	DECLARE @__archiveDate DATETIME
	SELECT @__archiveDate = DATEADD(DAY, 1, dbo.f_CustomerLog_GetArchiveDate())

	IF @FromDate >= @__archiveDate
	BEGIN
		--### GET DATA
		INSERT INTO #log (LogId, LogDate, UserId, ActionId, ActionName, TrackingValue, TrackingValueOld)
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
			INNER JOIN bodb_licensee.dbo.LicenseeGroupComm c WITH(NOLOCK) ON l.custid = c.id
		WHERE Logdate >= @FromDate AND l.logdate < @logDataToDate AND (l.ActionID = 2609 OR l.ActionID = 2610) AND c.LicenseeID = @Licenseeid

		UNION ALL
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.Logdate >= @FromDate AND l.logdate < @logDataToDate AND l.actionid = 2611 AND l.custid = @Licenseeid
	END
	IF @ToDate < @__archiveDate
	BEGIN
		INSERT INTO #log (LogId, LogDate, UserId, ActionId, ActionName, TrackingValue, TrackingValueOld)
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM bodb_CustomerLog_Archive.dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
			INNER JOIN bodb_licensee.dbo.LicenseeGroupComm c WITH(NOLOCK) ON l.custid = c.id
		WHERE Logdate >= @FromDate AND l.logdate < @logDataToDate AND (l.ActionID = 2609 OR l.ActionID = 2610) AND c.LicenseeID = @Licenseeid

		UNION ALL
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM bodb_CustomerLog_Archive.dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.Logdate >= @FromDate AND l.logdate < @logDataToDate AND l.actionid = 2611 AND l.custid = @Licenseeid
	END
	ELSE
	BEGIN
		INSERT INTO #log (LogId, LogDate, UserId, ActionId, ActionName, TrackingValue, TrackingValueOld)
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
			INNER JOIN bodb_licensee.dbo.LicenseeGroupComm c WITH(NOLOCK) ON l.custid = c.id
		WHERE Logdate >= @__archiveDate AND l.logdate < @logDataToDate AND (l.ActionID = 2609 OR l.ActionID = 2610) AND c.LicenseeID = @Licenseeid

		UNION ALL
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.Logdate >= @__archiveDate AND l.logdate < @logDataToDate AND l.actionid = 2611 AND l.custid = @Licenseeid

		--archive
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM bodb_CustomerLog_Archive.dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
			INNER JOIN bodb_licensee.dbo.LicenseeGroupComm c WITH(NOLOCK) ON l.custid = c.id
		WHERE Logdate >= @FromDate AND l.logdate < @__archiveDate AND (l.ActionID = 2609 OR l.ActionID = 2610) AND c.LicenseeID = @Licenseeid

		UNION ALL
		SELECT	l.Logid,
				l.LogDate,
				l.userid,
				l.Actionid,
				a.actionnameen ActionName,
				l.trackingvalue,
				l.trackingvalue2 AS trackingvalueold
		FROM bodb_CustomerLog_Archive.dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.Logdate >= @FromDate AND l.logdate < @__archiveDate AND l.actionid = 2611 AND l.custid = @Licenseeid
	END

	IF @ToDate < @LapLaunchDate
	BEGIN				
		SELECT	l.LogId,
				l.LogDate,
				u.Username AS Editedby,
				l.ActionId,
				l.ActionName,
				l.TrackingValue,
				l.TrackingValueOld
		FROM #log l
			INNER JOIN bodb_licensee.dbo.users u WITH(NOLOCK) ON u.userid = l.userid
		ORDER BY l.logid DESC
	END
	ELSE IF @FromDate >= @LapLaunchDate
	BEGIN
		CREATE TABLE #lapUsers1 (UserId INT, Editedby NVARCHAR(20))
		INSERT INTO #lapUsers1 (UserId, Editedby)
		SELECT UserSEQ, UserID
		FROM DBCUST.SiteConfig.dbo.users WITH(NOLOCK)
		WHERE SiteName = @SiteName
		
		SELECT	l.LogId,
				l.LogDate,
				u.Editedby,
				l.ActionId,
				l.ActionName,
				l.TrackingValue,
				l.TrackingValueOld
		FROM #log l
			INNER JOIN #lapUsers1 u ON u.UserId = l.userid
		ORDER BY l.logid DESC
		
		DROP TABLE #lapUsers1
	END
	ELSE
	BEGIN
		CREATE TABLE #lapUsers2 (UserId INT, Editedby NVARCHAR(20))
		INSERT INTO #lapUsers2 (UserId, Editedby)
		SELECT UserSEQ, UserID
		FROM DBCUST.SiteConfig.dbo.users WITH(NOLOCK)
		WHERE SiteName = @SiteName
		
		SELECT	l.LogId,
				l.LogDate,
				u.Username AS Editedby,
				l.ActionId,
				l.ActionName,
				l.TrackingValue,
				l.TrackingValueOld
		FROM #log l
			INNER JOIN bodb_licensee.dbo.users u WITH(NOLOCK) ON u.userid = l.userid
		WHERE l.Logdate >= @FromDate AND l.LogDate < @LapLaunchDate
		UNION ALL
		SELECT	l.LogId,
				l.LogDate,
				u.Editedby,
				l.ActionId,
				l.ActionName,
				l.TrackingValue,
				l.TrackingValueOld
		FROM #log l
			INNER JOIN #lapUsers2 u ON u.UserId = l.userid
		WHERE l.Logdate >= @LapLaunchDate AND l.LogDate < @logDataToDate
		ORDER BY l.logid DESC

		DROP TABLE #lapUsers2
	END

	DROP TABLE #log  
END
GO
