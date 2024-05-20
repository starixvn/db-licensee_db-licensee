/*<info serverAlias="DBCUST-SiteConfig" executers="wsv_lap" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SubsidiarySel]
	@LicenseeName NVARCHAR(50)
AS
/*
	 Created: [20171226@Walter]
	 Description: Implement Subsidiary Performance report (phase 2)
	 DB: DBCUST.SiteConfig

	 Revisions:
	  - 20171226@Walter: Select Operator By Licensee Name [Redmine: #88398]
	  - 20180914@Amanda: Remove empty OperatorId from returned data [Redmine: #95177]

	 Example:
	  exec Lrf_SubsidiarySel @LicenseeName='12bet'
*/
BEGIN
	 SELECT AgentID, OperatorID, Currency
	 FROM Operator WITH(NOLOCK)
	 WHERE SiteName = @LicenseeName AND OperatorID <> '' AND OperatorID IS NOT NULL
END
GO