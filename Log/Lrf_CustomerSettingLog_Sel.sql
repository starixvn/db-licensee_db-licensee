/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Lrf_CustomerSettingLog_Sel]    
	@LicenseeID			INT,
	@SiteName			VARCHAR(50),
	@UserName			AS VARCHAR(50), 
	@FilterBy			SMALLINT=0,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@LapLaunchDate		SMALLDATETIME = '2018-07-01',
	@AgentList			VARCHAR(MAX)
AS       
/*     
Created:20130206@Scott    
Task: Get log for lrf customer setting    
DB: bodb_CustomerLog      
      
Revisions:      
	20130411Scott : Check Customer belong Licensee
	20131126@Jim: return result-table with NULL value if search condition are not match
    20170321@Harper: Add more Currency permission [#73677]
    20180711@Amanda: get username of LAP if log data is after LAP launch data [#97994]
	20190405@Patrick: Support archive date range [Redmine: #111476]
	   
Param's Explaination:          
 - @UserName: customer name type in textbox to search      
 - @FilterBy : 0 - View All    
      1 - View BA    
      2 - View by Status    
      3 - View by Commission    
      4 - View by Special Level.
           
 - @FromDate: date range to view log      
 - @ToDate: date range to view log 
 
==========Execute sample=================    
exec  Lrf_CustomerSettingLog_Sel    
	@LicenseeID = 1,
	@UserName=N'AlogIN01002',
    @FromDate ='2013-02-05',
    @ToDate = '2013-02-07'
 
*/      
      
BEGIN      
	SET NOCOUNT ON
     
	--### DECLARE VARIABLE ###--
	DECLARE @custid INT ,@status int
	DECLARE @RowFilter table ( Actionid int)
	declare @UserName2 varchar(50)

	IF (@UserName is null or @UserName = '')
		RETURN;

	DECLARE @TempAg		TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	SELECT @UserName2 = licenseeName + '$' + @Username 
	FROM bodb_Licensee.dbo.Licensees WITH(NOLOCK)
	WHERE LicenseeID = @LicenseeID
    
	--### SET VALUE FOR VARIABLE ###--      
	SELECT	@Custid = c.custid
	FROM bodb02.dbo.customer c WITH(NOLOCK)
		INNER JOIN @TempAg ag ON c.recommend = ag.CustId AND c.currency = ag.Currency
	WHERE   ( username = @Username or username2 = @Username2 )
			AND c.roleid = 1
	/*
	IF @Custid IS NULL
		Return;
	*/	
 
	--### set actionid by @rowfilter
    
	IF @filterby=1
	BEGIN
		INSERT INTO @RowFilter VALUES (2401), (2403)
	END  
	ELSE IF @filterby=2
	BEGIN
		INSERT INTO @RowFilter VALUES (2200), (2201)
	END 
	ELSE IF @filterby=3
	BEGIN
		INSERT INTO @RowFilter VALUES (2612)
	END
	ELSE IF @filterby=4
	BEGIN
		INSERT INTO @RowFilter VALUES (2407)
	END
	ELSE
	BEGIN
		--Default view all 
		INSERT INTO @RowFilter VALUES (2401), (2403), (2200), (2201), (2612), (2407)
	END  
	
	DECLARE @logDataToDate DATE
	SELECT @logDataToDate = DATEADD(DAY, 1, @ToDate)

	DECLARE @__archiveDate DATETIME
	SELECT @__archiveDate = DATEADD(DAY, 1, dbo.f_CustomerLog_GetArchiveDate())

	CREATE TABLE #__logData (Logid BIGINT, userId INT, LogDate DATETIME, Actionid INT, actionnameen NVARCHAR(512), trackingvalue NVARCHAR(MAX), trackingvalue2 NVARCHAR(MAX))

	IF @FromDate >= @__archiveDate
	BEGIN
		INSERT INTO #__logData(Logid, userId, LogDate, Actionid, actionnameen, trackingvalue, trackingvalue2)
		SELECT	l.Logid,
				l.userid,
				l.LogDate,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				trackingvalue,
				trackingvalue2 as trackingvalueold
		FROM dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.custid = @custid And l.Logdate >= @FromDate AND l.logdate < @logDataToDate
	END
	ELSE IF @ToDate < @__archiveDate
	BEGIN
		INSERT INTO #__logData(Logid, userId, LogDate, Actionid, actionnameen, trackingvalue, trackingvalue2)
		SELECT	l.Logid,
				l.userid,
				l.LogDate,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				trackingvalue,
				trackingvalue2 as trackingvalueold
		FROM bodb_CustomerLog_Archive.dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.custid = @custid And l.Logdate >= @FromDate AND l.logdate < @logDataToDate
	END
	ELSE
	BEGIN
		INSERT INTO #__logData(Logid, userId, LogDate, Actionid, actionnameen, trackingvalue, trackingvalue2)
		SELECT	l.Logid,
				l.userid,
				l.LogDate,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				trackingvalue,
				trackingvalue2 as trackingvalueold
		FROM dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.custid = @custid And l.Logdate >= @FromDate AND l.logdate < @logDataToDate

		UNION ALL
		SELECT	l.Logid,
				l.userid,
				l.LogDate,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				trackingvalue,
				trackingvalue2 as trackingvalueold
		FROM bodb_CustomerLog_Archive.dbo.UserLog_RunSP l WITH(NOLOCK)
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN dbo.LogAction a WITH(NOLOCK) ON a.actionid = l.actionid
		WHERE l.custid = @custid And l.Logdate >= @FromDate AND l.logdate < @logDataToDate
	END

	CREATE TABLE #__lapUsers (UserId INT, Editedby NVARCHAR(20))
	IF @ToDate >= @LapLaunchDate
	BEGIN
		INSERT INTO #__lapUsers (UserId, Editedby)
		SELECT UserSEQ, UserID
		FROM DBCUST.SiteConfig.dbo.users WITH(NOLOCK)
		WHERE SiteName = @SiteName
	END

	IF @ToDate < @LapLaunchDate
	BEGIN
		SELECT Logid, LogDate, u.username AS Editedby, Actionid, actionnameen AS ActionName, trackingvalue, trackingvalue2 AS trackingvalueold
		FROM #__logData l
			INNER JOIN bodb_licensee.dbo.users u WITH(NOLOCK) ON u.userid = l.userid
		ORDER BY l.logid DESC
	END
	ELSE IF @FromDate >= @LapLaunchDate
	BEGIN
		SELECT Logid, LogDate, u.UserID AS Editedby, Actionid, actionnameen AS ActionName, trackingvalue, trackingvalue2 AS trackingvalueold
		FROM #__logData l
			INNER JOIN #__lapUsers u ON u.UserId = l.userid
		ORDER BY l.logid DESC
	END
	ELSE
	BEGIN
		SELECT Logid, LogDate, u.UserID AS Editedby, Actionid, actionnameen AS ActionName, trackingvalue, trackingvalue2 AS trackingvalueold
		FROM #__logData l
			INNER JOIN #__lapUsers u ON u.UserId = l.userid
		WHERE l.LogDate < @LapLaunchDate

		UNION ALL
		SELECT Logid, LogDate, u.UserID AS Editedby, Actionid, actionnameen AS ActionName, trackingvalue, trackingvalue2 AS trackingvalueold
		FROM #__logData l
			INNER JOIN #__lapUsers u ON u.UserId = l.userid
		WHERE l.LogDate >= @LapLaunchDate
		ORDER BY l.logid DESC
	END

	DROP TABLE #__logData
	DROP TABLE #__lapUsers
END
GO
