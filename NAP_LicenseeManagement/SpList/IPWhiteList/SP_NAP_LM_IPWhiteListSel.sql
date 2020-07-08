/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_IPWhiteListSel]
	@Ip VARCHAR(20) = NULL,
	@Remark NVARCHAR(80) = NULL
AS
/*
	Created: 20200630@Mark
	Task: Select All IPWhiteList
	DB: DBCUST.bodb_Licensee
	 
	Revisions:
		- 20200630@Mark: Create New SP Select All IPWhiteList [RedmineID: #137048]

	Param's Explannation:
	@Ip: Ip Value to search and select IPWhiteList.
	@Remark: Remark value to search and select IPWhiteList.
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		Id,
		IPValue,
		ModifiedUser,
		ModifiedDate,
		Remark
	FROM dbo.IPWhiteList ipwl WITH (NOLOCK)
	WHERE
		(@Ip IS NULL OR ipwl.IPValue LIKE '%' + @Ip + '%') AND
		(@Remark IS NULL OR ipwl.Remark LIKE '%' + @Remark + '%')
END
GO