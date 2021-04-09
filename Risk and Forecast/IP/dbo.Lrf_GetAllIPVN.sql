
/*<info serverAlias="DBCUST-IPDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_GetAllIPVN]
AS
/*
	Created: 20210322@Mark
	Task: Get All IPVN
	DB: DBCUST-IPDB
	
	Revisions:
		- 20210322@Mark: Get all IPVN [RedmineID: #151085]
*/
BEGIN
	SET NOCOUNT ON

	SELECT IPFrom, IPTo
	FROM dbo.IPVN WITH (NOLOCK)
END
GO
