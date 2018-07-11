/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE  [Lrf_GroupCommLog_Sel]
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
       
Param's Explaination:          
 - @FromDate: date range to view log      
 - @ToDate: date range to view log      
*/      
      
BEGIN

	SET NOCOUNT ON

	CREATE TABLE #log (	LogId BIGINT, LogDate DATETIME,
						UserId INT, ActionId INT, 
						ActionName NVARCHAR(256), TrackingValue NVARCHAR(MAX),
						TrackingValueOld NVARCHAR(MAX))

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
		INNER JOIN LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		INNER JOIN bodb_licensee.dbo.LicenseeGroupComm c WITH(NOLOCK) ON l.custid = c.id
	WHERE Logdate BETWEEN @FromDate AND @ToDate AND (l.ActionID = 2609 OR l.ActionID = 2610) AND c.LicenseeID = @Licenseeid
	UNION ALL
	SELECT	l.Logid,
			l.LogDate,
			l.userid,
			l.Actionid,
			a.actionnameen ActionName,
			l.trackingvalue,
			l.trackingvalue2 AS trackingvalueold
	FROM dbo.UserLog_RunSP l WITH(NOLOCK)
		INNER JOIN LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
	WHERE l.Logdate BETWEEN @FromDate AND @ToDate AND l.actionid = 2611 AND l.custid = @Licenseeid


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
				INNER JOIN bodb_licensee.dbo.users u ON u.userid = l.userid
			ORDER BY l.logid
		END
		ELSE IF @FromDate >= @LapLaunchDate
		BEGIN
			SELECT	l.LogId,
					l.LogDate,
					u.Username AS Editedby,
					l.ActionId,
					l.ActionName,
					l.TrackingValue,
					l.TrackingValueOld    
			FROM #log l
				INNER JOIN DBCUST.SiteConfig.dbo.users u ON u.userSEQ = l.userid
			WHERE u.SiteName = @SiteName
			ORDER BY l.logid
		END
		ELSE
		BEGIN
			DECLARE @tempToDate DATETIME
			SET @tempToDate = DATEADD(DAY, 1, @LapLaunchDate)

			SELECT	l.LogId,
					l.LogDate,
					u.Username AS Editedby,
					l.ActionId,
					l.ActionName,
					l.TrackingValue,
					l.TrackingValueOld
			FROM #log l
				INNER JOIN bodb_licensee.dbo.users u ON u.userid = l.userid
			WHERE l.Logdate BETWEEN @FromDate AND @tempToDate
			ORDER BY l.logid
			UNION ALL
			SELECT	l.LogId,
					l.LogDate,
					u.Username AS Editedby,
					l.ActionId,
					l.ActionName,
					l.TrackingValue,
					l.TrackingValueOld
			FROM #log l
				INNER JOIN DBCUST.SiteConfig.dbo.users u ON u.userSEQ = l.userid
			WHERE l.Logdate BETWEEN @LapLaunchDate AND @ToDate AND u.SiteName = @SiteName
			ORDER BY l.logid

		END

	DROP TABLE #log
/*    
==========Execute sample=================    
exec  [Lrf_GroupCommLog_Sel]    
    @FromDate ='2013-01-05',      
    @ToDate = '2013-02-07'        
*/    
END

GO
GRANT EXECUTE ON [dbo].[Lrf_GroupCommLog_Sel] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_GroupCommLog_Sel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GroupCommLog_Sel] TO [vnteam] 
