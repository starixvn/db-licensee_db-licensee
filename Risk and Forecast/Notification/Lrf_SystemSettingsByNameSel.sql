/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE Lrf_SystemSettingsByNameSel
	@Name		VARCHAR(50)
AS

/*	
	Created by: Kai
	Task : get system settings by name (#174308)
	DB: DBCUST/SiteConfig
	Revisions:
		- 20221222@Kai: Initial sp [RedmineID: #174308]
*/

BEGIN

	SET NOCOUNT ON

	SELECT [VName] as [Name], [VValue] as [Value]
	FROM [SystemSettings] WITH(NOLOCK)
	WHERE [VName] = @Name
END
GO