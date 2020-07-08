/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_SingleIPWhiteListSel]
	@Id INT
AS
/*
	Created: 20200630@Mark
	Task: Select single IPWhiteList by Id
	DB: DBCUST.bodb_Licensee
	 
	Revisions:
		- 20200630@Mark: Create New SP Single Select IPWhiteList [RedmineID: #137048]

	Param's Explannation:
	@Id: Id of IPWhiteList to select.
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT 
		Id,
		IPValue,
		Remark
	FROM dbo.IPWhiteList WITH (NOLOCK) WHERE Id = @Id
END
GO