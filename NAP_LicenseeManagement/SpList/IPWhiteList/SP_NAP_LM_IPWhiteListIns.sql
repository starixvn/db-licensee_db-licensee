/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_IPWhiteListIns]
	@IPValue VARCHAR(MAX),
	@ModifiedUser VARCHAR(30) = NULL,
	@Remark NVARCHAR(80) = NULL,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200630@Mark
	Task: Insert IPWhiteList
	DB: DBCUST.bodb_Licensee
	 
	Revisions:
		- 20200630@Mark: Create New SP Insert IPWhiteList [RedmineID: #137048]

	Param's Explannation:
	@IPValue: IPWhiteList value to insert.
	@ModifiedUser: UserName insert IPWhiteList.
	@Remark: Remark of IPWhiteList

	@ErrCode:
		= 0: Transaction recorded successfully.
		> 0: Specific Error.

	@ErrMsg: Error description.
*/
BEGIN
	SET NOCOUNT ON

	SELECT @ErrCode = 0, @ErrMsg = ''

	IF EXISTS(SELECT 1 FROM IPWhiteList WITH (NOLOCK) WHERE IPValue  IN (SELECT val FROM dbo.strSplit(@IPValue, ';')))
	BEGIN
		DECLARE @Ip VARCHAR(20) = NULL

		SELECT @Ip = IPValue FROM IPWhiteList WITH (NOLOCK) WHERE IPValue  IN (SELECT val FROM dbo.strSplit(@IPValue, ';'))

		SELECT @ErrCode = 101, @ErrMsg = 'This IP ' + @Ip + ' is existed'

		RETURN
	END
	ELSE
	BEGIN
		INSERT INTO dbo.IPWhiteList(IPValue, ModifiedUser, ModifiedDate, Remark)
		SELECT val, @ModifiedUser, GETDATE(), @Remark FROM dbo.strSplit(@IPValue, ';')

		RETURN
	END
END
GO