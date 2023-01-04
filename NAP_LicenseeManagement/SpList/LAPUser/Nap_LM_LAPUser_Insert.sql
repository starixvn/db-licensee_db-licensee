/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_LAPUser_Insert]
	@VendorID			VARCHAR(50),
	@UserID				VARCHAR(20),
	@UserPWD			VARCHAR(50),
	@UserName			NVARCHAR(20),
	@FuncPermissions	VARCHAR(MAX),
	@Currency			VARCHAR(1024)
AS

/*
	Created: Vickie
	Date: 2019-10-22
	Task: Manage password for LAP's IT accounts
	DB: DBCUST.SiteConfig

	Revisions:
		- 20191021@Vickie: Insert User Info [Redmine: #122008]
		- 20191206@Vickie: Replace @SiteName parameter by @VendorID parameter [Redmine: #119443]
		- 20220921@Kos: Extend Currency param data length [Redmine: #178052]
		- 20230104@Kos: Extend Currency param data length [Redmine: #181486]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @SiteName VARCHAR(50);

	SELECT @SiteName = SiteName
	FROM dbo.LicVendorProfile WITH (NOLOCK)
	WHERE VendorID = @VendorID

	IF NOT EXISTS (SELECT 1 FROM dbo.Users WITH (NOLOCK) WHERE UserID = @UserID AND SiteName = @SiteName)
	BEGIN
		DECLARE @UserSEQ INT;
		DECLARE @DocHandler INT;

		INSERT INTO dbo.Users(SiteName, UserID, UserPWD, UserName, isEnabled, isAdmin, UserLevel)
		VALUES (@SiteName, @UserID, @UserPWD, @UserName, 1, 0, 0)

		SET @UserSEQ = SCOPE_IDENTITY()

		INSERT INTO dbo.AuthorCurrency(UserSEQ, Currency)
		VALUES (@UserSEQ, @Currency)

		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @FuncPermissions
		
		INSERT INTO dbo.UserFuncPermission( UserSEQ, FunctionKey, SiteName, SystemType, SubFunctionKeys, IsAllow )
		SELECT @UserSEQ, XMLTable.FunctionKey, @SiteName, XMLTable.SystemType, XMLTable.SubFunctionKeys, 1
		FROM OPENXML(@DocHandler, '/ROOT/UserFuncPermission', 1)
		WITH(	FunctionKey VARCHAR(50),
				SystemType TINYINT,
				SubFunctionKeys VARCHAR(1000) ) AS XMLTable

		EXEC sp_xml_removedocument @DocHandler

		SELECT 1
	END
	ELSE
		SELECT 0
END
