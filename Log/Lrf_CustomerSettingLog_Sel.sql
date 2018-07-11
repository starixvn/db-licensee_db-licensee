/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE  [Lrf_CustomerSettingLog_Sel]    
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
	   
Param's Explaination:          
 - @UserName: customer name type in textbox to search      
 - @FilterBy : 0 - View All    
      1 - View BA    
      2 - View by Status    
      3 - View by Commission    
      4 - View by Special Level.
	  5	- View by Currency
           
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
	
	IF @ToDate < @LapLaunchDate
	BEGIN
		SELECT	l.Logid,
				l.LogDate,
				u.username AS Editedby,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				trackingvalue,
				trackingvalue2 as trackingvalueold
		FROM dbo.UserLog_RunSP l
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN bodb_licensee.dbo.users u ON u.userid = l.userid
			INNER JOIN LogAction a ON a.actionid = l.actionid
		WHERE l.custid = @custid And l.Logdate BETWEEN @FromDate AND @ToDate   
		ORDER BY l.logid
	END
	ELSE IF @FromDate >= @LapLaunchDate
	BEGIN
		SELECT	l.Logid,
				l.LogDate,
				u.username AS Editedby,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				trackingvalue,
				trackingvalue2 as trackingvalueold
		FROM dbo.UserLog_RunSP l
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN DBCUST.SiteConfig.dbo.users u ON u.userSEQ = l.userid
			INNER JOIN LogAction a ON a.actionid = l.actionid
		WHERE l.custid = @custid AND l.Logdate BETWEEN @FromDate AND @ToDate AND u.SiteName = @SiteName
		ORDER BY l.logid
	END
	ELSE
	BEGIN
		DECLARE @tempToDate DATETIME
		SET @tempToDate = DATEADD(DAY, 1, @LapLaunchDate)
	
		SELECT	l.Logid,
				l.LogDate,
				u.username AS Editedby,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				l.trackingvalue,
				l.trackingvalue2 as trackingvalueold
		FROM dbo.UserLog_RunSP l
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN  bodb_licensee.dbo.users u ON u.userid = l.userid
			INNER JOIN LogAction a ON a.actionid = l.actionid
		WHERE l.custid = @custid And l.Logdate BETWEEN @FromDate AND @tempToDate
		ORDER BY l.logid
		UNION ALL
		SELECT	l.Logid,
				l.LogDate,
				u.username AS Editedby,
				l.Actionid,
				CASE	WHEN l.Actionid = 2401 then 'Turn On BA'
						WHEN l.Actionid = 2403 then 'Turn Off BA'
				ELSE a.actionnameen END ActionName,
				trackingvalue,
				trackingvalue2 as trackingvalueold
		FROM dbo.UserLog_RunSP l
			INNER JOIN @RowFilter r ON r.actionid = l.actionid
			INNER JOIN DBCUST.SiteConfig.dbo.users u ON u.userSEQ = l.userid
			INNER JOIN LogAction a ON a.actionid = l.actionid
		WHERE l.custid = @custid AND l.Logdate BETWEEN @LapLaunchDate AND @ToDate AND u.SiteName = @SiteName
		ORDER BY l.logid

	END
END    

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSettingLog_Sel] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSettingLog_Sel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSettingLog_Sel] TO [vnteam] 
