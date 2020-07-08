/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_IPWhiteListUpdate]
	@Id INT = NULL,
	@IPValue VARCHAR(MAX),
	@ModifiedUser VARCHAR(30) = NULL,
	@Remark NVARCHAR(80) = NULL,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20200630@Mark
	Task: Update IPWhiteList
	DB: DBCUST.bodb_Licensee
	 
	Revisions:
		- 20200630@Mark: Create New SP Update IPWhiteList [RedmineID: #137048]

	Param's Explannation:
	@Id: Id of IPWhiteList to update.
	@IPValue: IPWhiteList value to update.
	@ModifiedUser: UserName update IPWhiteList.
	@Remark: Remark of IPWhiteList to update.

	@ErrCode:
		= 0: Transaction recorded successfully.
		> 0: Specific Error.

	@ErrMsg: Error description.
*/
BEGIN
	SET NOCOUNT ON

	SELECT @ErrCode = 0, @ErrMsg =''

	--IP is existed
	IF EXISTS(SELECT 1 FROM IPWhiteList WITH (NOLOCK) WHERE @Id = Id)
	BEGIN
		DECLARE @TempID INT

		SELECT @TempID = Id FROM dbo.IPWhiteList WITH (NOLOCK) WHERE @IPValue = IPValue

		--IP to UPDATE existed and not itself
		IF @Id <> @TempID
		BEGIN
			SELECT @ErrCode = 101, @ErrMsg = 'This IP is existed'

			RETURN
		END
		ELSE
		BEGIN			
			UPDATE dbo.IPWhiteList WITH(ROWLOCK, UPDLOCK)
			SET IPValue = @IPValue,
				ModifiedUser = @ModifiedUser,
				ModifiedDate = GETDATE(),
				Remark = @Remark
			WHERE Id = @Id

			RETURN
		END
	END		
	ELSE
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'This IP is not existed'

		RETURN
	END
END
GO