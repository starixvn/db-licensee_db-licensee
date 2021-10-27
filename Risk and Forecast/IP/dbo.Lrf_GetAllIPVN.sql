/*<info serverAlias="DBCUST-IPDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_GetAllIPVN]
AS
/*
	Created: 20210322@Mark
	Task: Get All IPVN
	DB: DBCUST-IPDB
	
	Revisions:
		- 20210322@Mark: Get all IPVN [RedmineID: #151085]
		- 20211018@Elodie: Support IPv6 Phase 1 - Support for 3rd party product bet tickets  [Redmine:#90903]
*/
BEGIN
	SET NOCOUNT ON

	SELECT ipFROM,ipTO FROM IPv4Restriction WITH (NOLOCK)  
	WHERE countrySHORT = 'vn'  

	SELECT ipFROM,ipTO FROM IPv6Restriction WITH (NOLOCK)  
	WHERE countrySHORT = 'vn'  

END
GO
