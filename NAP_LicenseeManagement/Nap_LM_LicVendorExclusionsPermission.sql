/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LicVendorExclusionsPermission]
	@SiteName VARCHAR(50)
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	 Created: 20230605@Winfred
	 Date: 2023-06-05
	 Task: Update permission site config LicVendorProfile
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
		- 20230605@Winfred: NAP LM - New function to create agent subsidiary for TM team [redmine:#185123]
*/
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		UPDATE LicVendorProfile WITH (ROWLOCK, UPDLOCK)
		SET Exclusions = REPLACE(REPLACE(REPLACE(REPLACE(Exclusions, ',"SubsidiaryPerformance73"', ''),',"SubsidiaryManage"',''),'"SubsidiaryPerformance73"',''),'"SubsidiaryManage"','')
		WHERE SiteName = @SiteName
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO