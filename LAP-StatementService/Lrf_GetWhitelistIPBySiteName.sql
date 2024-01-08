/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_GetWhitelistIPBySiteName] 
	@SiteName varchar(50)
AS
/*  Created: 20240108@Kai
    Description: LAP - Get Whitelist IP by SiteName
    DB: DBCUST.SiteConfig
   
    Revisions:  
		- 20240108@Kai: Created SP [RedmineID: #197094]
    Param's Explanation:
      @SiteName: 12Bet, ALog ...

*/
BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT lcwlip.IP
	FROM [dbo].[LicWhitelistIP] lcwlip WITH (NOLOCK)
	WHERE lcwlip.SiteName = @SiteName
END