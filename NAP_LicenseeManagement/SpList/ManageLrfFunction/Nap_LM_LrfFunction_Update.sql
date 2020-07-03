/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LrfFunction_Update]
	@FunctionId		INT,
	@Name			NVARCHAR(100),
	@Description	NVARCHAR(4000),
	@ParentId		INT = 0,
	@Url			VARCHAR(200) = '',
	@IsMenu			BIT = 0,
	@IsActive		BIT = 0,
	@DisplayOrder	INT = 0,
	@IsNew			BIT = 0,
	@FunctionKey	NVARCHAR(100),
	@Environment	VARCHAR(10) = 'UAT',
	@IsFunction		BIT = 0
AS
/*
	 Created: Amanda
	 Date: 2019-01-09
	 Task: Implement "Manage LRF Function" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190109@Amanda: Update LRF functions [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	IF NOT EXISTS ( SELECT 1 FROM dbo.Functions WITH (NOLOCK) WHERE FunctionKey = @FunctionKey AND FunctionId <> @FunctionId )
	BEGIN
		UPDATE dbo.Functions WITH (ROWLOCK, UPDLOCK)
		SET Name			= @Name,
			[Description]	= @Description,
			ParentId		= @ParentId,
			Url				= @Url,
			IsMenu			= @IsMenu,
			IsActive		= @IsActive,
			DisplayOrder	= @DisplayOrder,
			IsNew			= @IsNew,
			FunctionKey		= @FunctionKey,
			Environment		= @Environment,
			IsFunction		= @IsFunction
		WHERE FunctionId = @FunctionId
		
		SELECT NULL AS Error
	END
	ELSE
	BEGIN
		SELECT 'Function Key already exists!'
	END

END
GO