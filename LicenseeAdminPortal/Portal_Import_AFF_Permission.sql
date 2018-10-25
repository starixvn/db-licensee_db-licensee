/*<info serverAlias="DBCUST-SiteConfig" executers="Dot_Admin_Portal" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Portal_Import_AFF_Permission]
	@UserSEQ INT,
	@UserID NVARCHAR(20),
	@SiteName NVARCHAR (50)
AS
/*
	 Creator: 20170112@Walter
	 Task:  Description - [Redmine: #87709]
	 Database: DBCUST.SITECONFIG
	 
	 Revisions:
		- 20171206@Walter : Import AFF permission
		- 20180131@Walter : Fix issue import both individual permissions and group permissions
		- 20180928@Amanda: Migrate table from DBLIC.bodb_Licensee to DBCust.bodb_Licensee - [Redmine: #99855]
	  
	 Parameter's Explaination:
	  - @Example:   exec Portal_Import_AFF_Permission @UserSEQ=3443, @UserID='walter', @SiteName='Athena000'
*/
BEGIN	
	DECLARE @systemType INT = 2; -- Affiliate
	DECLARE @licenseeID INT, @affUserID INT, @groupID INT;
	
	DECLARE @affActiveFunction TABLE(FunctionName NVARCHAR(50) NOT NULL);
	INSERT INTO @affActiveFunction
	VALUES('[Affiliate]'), ('[Payment]'), ('[CommissionGroup]'), ('[AffReport]'), ('[Media]'), ('[HotNews]'),('[AffEx.Rate]')
	
	SELECT @licenseeID = LicenseeID
	FROM bodb_licensee.dbo.Licensees WITH (nolock)
	WHERE LicenseeName = @SiteName;
	
	SELECT @affUserID = u.UserId, @groupID = l.GroupID
	FROM bodb_licensee.dbo.Users AS u WITH (nolock)
		 INNER JOIN DBLIC.bodb_licensee.dbo.Aff_LicenseeUser AS l WITH (nolock)
		 ON u.UserID = l.UserID AND 
			u.isInternal = 1 AND
			u.Username = @UserID AND 
			l.LicenseeID = @licenseeID AND
			l.IsActive = 1;

	IF @affUserID > 0
		BEGIN
			CREATE TABLE #allowedFunctions (FunctionId INT NOT NULL, FunctionName NVARCHAR(50) NOT NULL, ActualPolicy TINYINT NOT NULL);

			-- Clear current aff permission
			BEGIN
			DELETE FROM dbo.UserFuncPermission
			WHERE UserSEQ = @UserSEQ AND 
				  SiteName = @siteName AND 
				  SystemType = @systemType
		     END
			
			BEGIN
			-- fetch function keys
			INSERT INTO #allowedFunctions(FunctionId, FunctionName,ActualPolicy)
			
		   SELECT f.functionId,f.functionName, ISNULL(uf.Policy,0)|ISNULL(gf.Policy,0) 
		   FROM DBLIC.bodb_licensee.dbo.Aff_FunctionInfo f WITH(NOLOCK)  
		   LEFT JOIN DBLIC.bodb_licensee.dbo.Aff_UserPolicy uf WITH(NOLOCK) on uf.UserID=@affUserID and uf.LicenseeID=@licenseeID
			AND f.FunctionId = uf.FunctionId
		   LEFT JOIN  DBLIC.bodb_licensee.dbo.Aff_GroupPolicy gf WITH(NOLOCK) on gf.GroupID=@groupID and f.FunctionId = gf.FunctionId
		   WHERE f.FunctionName in (select FunctionName from @affActiveFunction)
			
			-- DELETE FUNCTION WITHOUT POLICY
			DELETE FROM #allowedFunctions
			WHERE ActualPolicy=0
			END
			
			--insert new function Aff statistic for LAP only
			IF (EXISTS(SELECT TOP 1 FunctionId FROM #allowedFunctions WHERE FunctionName='[AffReport]'))
			 BEGIN
			    INSERT INTO #allowedFunctions(FunctionId, FunctionName, ActualPolicy)
			    VALUES(100000,'lblAffiliateStatistics', 1)

			 END
			---- insert allowed function
			BEGIN
				INSERT INTO dbo.UserFuncPermission( UserSEQ, FunctionKey, SiteName, SystemType, IsAllow )
				SELECT DISTINCT @UserSEQ, FunctionName, @SiteName, @systemType, 1
				FROM #allowedFunctions			
			END
			---- insert denied function
			BEGIN			
				INSERT INTO dbo.UserFuncPermission( UserSEQ, FunctionKey, SiteName, SystemType, IsAllow )
				SELECT @UserSEQ, FunctionName, @SiteName, @systemType, 0
				FROM @affActiveFunction WHERE FunctionName NOT IN (select FunctionName from #allowedFunctions);			
			END
			
			SELECT FunctionId FROM #allowedFunctions

			SELECT u.FunctionId FROM DBLIC.bodb_licensee.dbo.Aff_FunctionInfo u WITH(NOLOCK)  
			WHERE u.FunctionId NOT IN (select FunctionId from #allowedFunctions)
			
			DROP TABLE #allowedFunctions
			
		END;
END
GO