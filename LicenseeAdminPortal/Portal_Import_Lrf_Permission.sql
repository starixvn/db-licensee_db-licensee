/*<info serverAlias="DBCUST-SiteConfig" executers="Dot_Admin_Portal" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Portal_Import_Lrf_Permission] 
				 @userSEQ int, @siteName varchar(50), @userID varchar(20)
AS
/*
	 Creator: 20170112@Aex
	 Task:  Description - [Redmine: #87709]
	 Database: DBCUST.SITECONFIG
	 
	 Revisions:
		- 20171206@Alex : Import LRF permission
		- 20180928@Amanda: Migrate table from DBLIC.bodb_Licensee to DBCust.bodb_Licensee - [Redmine: #99855]
	  
	 Parameter's Explaination:
	  - @Example:   exec Portal_Import_LRF_Permission 2,'Athena000','william'
*/
BEGIN

	DECLARE @systemType int= 1; -- lrf 
	DECLARE @licenseeID int, @lrfUserID int;

	SELECT @licenseeID = LicenseeID
	FROM bodb_licensee.dbo.Licensees WITH (nolock)
	WHERE LicenseeName = @siteName;

	SELECT @lrfUserID = u.UserId
	FROM bodb_licensee.dbo.Users AS u WITH (nolock)
		 INNER JOIN
		 bodb_licensee.dbo.LicenseeUser AS l WITH (nolock)
		 ON u.UserId = l.UserId AND 
			u.isInternal = 1 AND 
			u.Username = @userID AND 
			l.LicenseeId = @licenseeID;

	IF ISNULL(@licenseeID,0) >0 AND ISNULL(@lrfUserID,0) > 0
	BEGIN

	CREATE TABLE #lrfFunctions
	( 		
		FunctionId int,
		FunctionKey nvarchar(100), 
	);

 -- Clear current lrf permission


BEGIN
	DELETE FROM dbo.UserFuncPermission
	WHERE UserSEQ = @userSEQ AND 
		  SiteName = @siteName AND 
		  SystemType = @systemType;

END;
 -- fetch all LRF permission

BEGIN
	INSERT INTO #lrfFunctions( FunctionId, FunctionKey )
		   SELECT FunctionId, FunctionKey
		   FROM bodb_licensee.dbo.Functions WITH (nolock)
		   WHERE isActive = 1 AND 
				 Environment = 'LIVE' AND 
				 ParentId <> 6 AND 
				 ParentId > 0 AND 
				 FunctionKey IS NOT NULL;
END;

-- fetch allowed  function key

BEGIN
	SELECT distinct f.FunctionId, f.FunctionKey
	INTO #allowedFunctions
	FROM #lrfFunctions AS f WITH (nolock)
		 INNER JOIN
		 bodb_licensee.dbo.LicenseeUserFunctions AS u WITH (nolock)
		 ON u.FunctionId = f.FunctionId AND 
			u.UserId = @lrfUserID AND 
			u.LicenseeId = @licenseeID;
END;

-- insert allowed function
BEGIN
	INSERT INTO dbo.UserFuncPermission( UserSEQ, FunctionKey, SiteName, SystemType, IsAllow )
		   SELECT @userSEQ, FunctionKey, @siteName, @systemType, 1
		   FROM #allowedFunctions;

END;
-- insert denied function
BEGIN
		INSERT INTO dbo.UserFuncPermission( UserSEQ, FunctionKey, SiteName, SystemType, IsAllow )
			   SELECT @userSEQ, f.FunctionKey, @siteName, @systemType, 0
			   FROM #lrfFunctions AS f
			   WHERE f.FunctionKey NOT IN(SELECT FunctionKey FROM #allowedFunctions);
			   END
-- return result.		
		SELECT FunctionId FROM #allowedFunctions
		SELECT FunctionId FROM #lrfFunctions  where FunctionKey NOT IN (SELECT FunctionKey FROM #allowedFunctions)
		
		DROP TABLE #allowedFunctions;
		DROP TABLE #lrfFunctions;
	END;
END;
GO