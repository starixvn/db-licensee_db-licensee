/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_GetUserLevelInfo]
	@UserSEQ			INT,
	@VendorID			VARCHAR(50),
	@UserLevel			INT			OUTPUT,
	@SubsidiaryEnabled	BIT			OUTPUT,
	@OperatorID			VARCHAR(50)	OUTPUT,
	@BaseCurrency		VARCHAR(12)	OUTPUT
AS

/*
	Created: 20180905@Amanda
	Description: LAP - Get user level info
	DB: DBCUST.SiteConfig

	Revisions:
		- 20180905@Amanda: Created SP [RedmineID: #95177]
		- 20190606@Alex: Return base currency setting of user [RedmineID: #114797]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]

	Developer's Notes:
		- Notes: User level = 0 --- Oneworks
							= 1 --- Licensee
							= 2 --- Subsidiary
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteName VARCHAR(50)

	SET @SubsidiaryEnabled = 0

	SELECT
		@UserLevel = UserLevel,
		@OperatorID = OperatorID,
		@SiteName = SiteName
	FROM dbo.Users WITH (NOLOCK)
	WHERE UserSEQ = @UserSEQ

	SELECT TOP(1) @BaseCurrency= BasedCurrencyCode
	FROM dbo.UserDefaultSettings WITH (NOLOCK)
	WHERE UserSEQ = @UserSEQ

	SELECT TOP(1) @SubsidiaryEnabled = 1
	FROM dbo.Operator WITH (NOLOCK)
	WHERE SiteName = @SiteName AND ISNULL(OperatorID,'') <> ''
END
GO
