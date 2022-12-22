/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE Lrf_SystemSettingsUpd
	@Name		VARCHAR(50)
	,@Value		VARCHAR(200)
AS

/*	
	Created by: Kai
	Task : update system settings (#174308)
	DB: DBCUST/SiteConfig
	Revisions:
		- 20221222@Kai: Initial sp [RedmineID: #174308]
*/

BEGIN

	SET NOCOUNT ON
 
	IF EXISTS (
		SELECT 1
		FROM [SystemSettings] WITH(NOLOCK)
		WHERE [VName] = @Name
	)
	BEGIN
		UPDATE [SystemSettings] WITH(ROWLOCK)
		SET [VValue] = @Value
		WHERE [VName] = @Name;
	END
	
END
GO