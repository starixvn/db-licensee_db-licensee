/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_LAPUser_Update]
	@UserSEQ			INT,
	@VendorID			VARCHAR(50),
	@UserPWD			VARCHAR(50),
	@FuncPermissions	VARCHAR(MAX),
	@IsRemoveGroup		BIT,
	@Currency			VARCHAR(1024)
AS

/*
	Created: Vickie
	Date: 2019-10-21
	Task: Manage password for LAP's IT accounts
	DB: DBCUST.SiteConfig

	Revisions:
		- 20191021@Vickie: Update User Info [Redmine: #122008]
		- 20191206@Vickie: Replace @SiteName parameter by @VendorID parameter [Redmine: #119443]
		- 20220921@Kos: Extend Currency param data length [Redmine: #178052]
		- 20230104@Kos: Extend Currency param data length [Redmine: #181486]
*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #FuncsTable (
		FunctionKey VARCHAR(50),
		SystemType TINYINT,
		SubFunctionKeys VARCHAR(1000));

	IF EXISTS (SELECT 1 FROM dbo.Users WITH (NOLOCK) WHERE UserSEQ = @UserSEQ)
	BEGIN
		DECLARE @DocHandler INT;
		DECLARE @SiteName VARCHAR(50);
		
		SELECT @SiteName = SiteName
		FROM [dbo].[LicVendorProfile] WITH (NOLOCK)
		WHERE VendorID = @VendorID
	
		UPDATE Users WITH (ROWLOCK, UPDLOCK)
		SET UserPWD = @UserPWD,
			isEnabled = 1
		WHERE UserSEQ = @UserSEQ
		
		--- Currency permission
		IF EXISTS (SELECT 1 FROM dbo.AuthorCurrency WITH (NOLOCK) WHERE UserSEQ = @UserSEQ)
		BEGIN
			UPDATE AuthorCurrency WITH (ROWLOCK, UPDLOCK)
			SET Currency = @Currency
			WHERE UserSEQ = @UserSEQ 
		END
		ELSE
		BEGIN
			INSERT INTO dbo.AuthorCurrency(UserSEQ, Currency)
			VALUES (@UserSEQ, @Currency)
		END

		-- user permission
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @FuncPermissions
	
		INSERT INTO #FuncsTable(FunctionKey, SystemType, SubFunctionKeys)
		SELECT Data.FunctionKey, Data.SystemType, Data.SubFunctionKeys
		FROM OPENXML(@DocHandler, '/ROOT/UserFuncPermission', 1)
		WITH(	FunctionKey VARCHAR(50),
				SystemType TINYINT,
				SubFunctionKeys VARCHAR(1000) ) AS Data 
		
		EXEC sp_xml_removedocument @DocHandler

		-- group permission
		IF @IsRemoveGroup = 1
		BEGIN
			DELETE FROM AuthorGroup WITH (ROWLOCK)
			WHERE UserSEQ = @UserSEQ
		END
		ELSE
		BEGIN
			DELETE f
			FROM #FuncsTable f
				INNER JOIN GroupFuncPermission AS g WITH (NOLOCK) ON f.FunctionKey = g.FunctionKey
				INNER JOIN AuthorGroup AS a WITH (NOLOCK) ON a.UserSEQ = @UserSEQ AND a.UserGroupSEQ = g.UserGroupSEQ
		END

		-- remove old permisison
		DELETE FROM dbo.UserFuncPermission WITH (ROWLOCK)
		WHERE UserSEQ = @UserSEQ
		
		-- insert new permisison
		INSERT INTO dbo.UserFuncPermission(UserSEQ, FunctionKey, SiteName, SystemType, SubFunctionKeys, IsAllow)
		SELECT @UserSEQ ,FunctionKey,@SiteName,SystemType,SubFunctionKeys,1
		FROM #FuncsTable

		SELECT 1
	END
	ELSE
		SELECT 0

	DROP TABLE #FuncsTable
END
