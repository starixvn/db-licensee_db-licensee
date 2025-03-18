/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerLoginInfo]
	@LicenseeID		INT = 0,
	@CustID			INT,
	@SiteName		VARCHAR(50),
	@LapLaunchDate	SMALLDATETIME = '2018-07-01'
AS

/*
	Created by: [20110624@Henry]
	Task: Get Login Info
	DB: DB052.BODB02 
	Original: 
	Revisions:
		- 20120203@Henry: get SpecialLevelUpdateBy and SpecialLevelUpdateDate
		- 20120718@Henry: fix bug display wrong TnxDate
		- 20131218@winnie: change from db06 to DBARC Alias
		- 20180711@Amanda: get username of LAP if log data is after LAP launch data [#97994]
		- 20181010@Sophia: add DBLOG for table UserLog_RunSP [redmine: 99855]
		- 20190411@Lukas: archive a part of old log records to new database
		- 20190830@Johnson: Get licenseeID from sitename for LAP [redmine:#112658]
		- 20220818@Hogan: Update bettype range to get Last Transaction [redmine:#176515]
		- 20190830@Johnson: Get licenseeID from sitename for LAP [redmine:#112658]
		- 20250227@Virgil: Drop BA functions [RedmineID: #216882]

	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

----------- get last updated special level ---------------
	DECLARE @SpecialLevelUpdateByName VARCHAR(50), @SpecialLevelUpdateDate DATETIME,@SpecialLevelUpdateByID INT
	
	IF ISNULL(@LicenseeID,0) = 0
	BEGIN
		SELECT @LicenseeID	= LicenseeID
		FROM bodb_Licensee.dbo.Licensees WITH(NOLOCK)
		WHERE LicenseeName = @SiteName
	END
	
	SELECT TOP 1 @SpecialLevelUpdateByID = UserID, @SpecialLevelUpdateDate = LogDate
	FROM DBLOG.bodb_CustomerLog.dbo.UserLog_RunSP WITH (NOLOCK)
	WHERE	CustID = @CustID
			AND ActionID = 2407
	ORDER BY LogDate DESC

	IF @SpecialLevelUpdateByID IS NULL --- read further from log archive
	BEGIN
		SELECT TOP 1 @SpecialLevelUpdateByID = UserID, @SpecialLevelUpdateDate = LogDate
		FROM DBLOG.bodb_CustomerLog_Archive.dbo.UserLog_RunSP WITH (NOLOCK)
		WHERE	CustID = @CustID
				AND ActionID = 2407
		ORDER BY LogDate DESC
	END
	
	IF ISNULL(@SpecialLevelUpdateByID,0) <> 0
	BEGIN
		IF @SpecialLevelUpdateDate >= @LapLaunchDate -- LAP USER
		BEGIN
			SELECT @SpecialLevelUpdateByName = UserID FROM DBCUST.SiteConfig.dbo.Users WITH (NOLOCK)
			WHERE UserSEQ = @SpecialLevelUpdateByID AND SiteName = @SiteName
		END
		ELSE -- LRF USER
		BEGIN
			SELECT @SpecialLevelUpdateByName = Username FROM bodb_Licensee.dbo.Users WITH (NOLOCK)
			WHERE UserID = @SpecialLevelUpdateByID
		END
	END

----------- get last transfer date ---------------
	DECLARE @LastTransferDate DATETIME

	SELECT @LastTransferDate = MAX(transdate)
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE custid = @CustID AND bettype < 19999
		
	IF 	ISNULL(@LastTransferDate,'') = ''
	BEGIN
		SELECT @LastTransferDate = MAX(transdate)
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE custid = @CustID
	END

	IF 	ISNULL(@LastTransferDate,'') = ''
	BEGIN
		SELECT @LastTransferDate = MAX(transdate)
		FROM DBARC.bodb_archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE custid = @CustID
	END

	IF ISNULL(@LastTransferDate,'') = ''
	BEGIN
		SELECT @LastTransferDate = MAX(transdate)
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE custid = @CustID
	END

----------- return ---------------
	SELECT
		custid,
		username,
		SUBSTRING(username2, CHARINDEX('$',username2) + 1, LEN(username2) - CHARINDEX('$',username2)) AS nickname,
		lastlogged,
		creatdate AS createdate,
		@LastTransferDate AS LastTransferDate,
		@SpecialLevelUpdateByName AS SpecialLevelUpdateBy,
		@SpecialLevelUpdateDate AS SpecialLevelUpdateDate
	FROM dbo.Customer WITH(NOLOCK)
	WHERE CustID = @CustID
END