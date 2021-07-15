/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_GetConfigDetailByKeyName] 
	@SiteName varchar(50),
	@Environment varchar(20),
	@KeyName varchar(50),
	@KeyValue varchar(600) OUTPUT
AS
/*  Created: 20210618@Howard
    Description: LAP - Get config detail by key name
    DB: DBCUST.SiteConfig
   
    Revisions:  
		- 20210618@Howard: Created SP [RedmineID: #154826]
    Param's Explanation:
      @SiteName: 12Bet, ALog ...
      @Environment: UAT, Production
      @KeyName: EnableSingleWallet, ...
*/
BEGIN
	SET NOCOUNT ON

	SELECT @KeyValue = cd.KeyValue
	FROM dbo.LicVendorProfile lvp WITH (NOLOCK)
	INNER JOIN dbo.ConfigMaster cm WITH (NOLOCK) ON lvp.SiteId = cm.SiteID
	INNER JOIN dbo.ConfigDetail cd WITH (NOLOCK) ON cd.ConfigID = cm.ConfigID
	WHERE cm.Application = 'member' AND cm.Platform = 'Desktop'
		AND cm.Environment = @Environment
		AND lvp.SiteName = @SiteName
		AND cd.KeyName = @KeyName
END