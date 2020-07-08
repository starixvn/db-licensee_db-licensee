/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_IPWhiteListDel]
	@Id INT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200630@Mark
	Task: Delete IPWhiteList By Id
	DB: DBCUST.bodb_Licensee
	 
	Revisions:
		- 20200630@Mark: Create New SP Delete IPWhiteList [RedmineID: #137048]

	Param's Explannation:
	@Id: Id of IPWhiteList to delete.

	@ErrCode:
		= 0: Transaction recorded successfully.
		> 0: Specific Error.

	@ErrMsg: Error description.
*/
BEGIN
	SET NOCOUNT ON

	SELECT @ErrCode = 0, @ErrMsg = ''
	
	IF EXISTS (SELECT 1 FROM dbo.IPWhiteList WITH(NOLOCK) WHERE Id = @Id)
	
	BEGIN
	DELETE
	FROM dbo.IPWhiteList WITH (ROWLOCK)
		WHERE Id = @Id

		RETURN
	END

	SELECT @ErrCode = 102, @ErrMsg = 'This IP is not existed'
END
GO