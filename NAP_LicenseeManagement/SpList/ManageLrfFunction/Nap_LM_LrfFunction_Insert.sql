/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LrfFunction_Insert]
	@FunctionId		INT OUTPUT,
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
	  - 20190109@Amanda: Insert new LRF functions [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	IF NOT EXISTS ( SELECT 1 FROM dbo.Functions WITH (NOLOCK) WHERE FunctionKey = @FunctionKey )
	BEGIN
		DECLARE @insertedId AS TABLE (ID INT)
	
		INSERT INTO dbo.Functions 
		(
			Name,
			[Description],
			ParentId,
			Url,
			IsMenu,
			IsActive,
			DisplayOrder,
			IsNew,
			FunctionKey,
			Environment,
			IsFunction
		)
		OUTPUT inserted.FunctionId INTO @insertedId
		VALUES (@Name, @Description, @ParentId, @Url, @IsMenu, @IsActive, @DisplayOrder, @IsNew, @FunctionKey, @Environment, @IsFunction)
		
		SELECT NULL AS Error
		SELECT @FunctionId = ID FROM @insertedId
	END
	ELSE
	BEGIN
		SET @FunctionId = 0
		SELECT 'Function Key already exists!'
	END
END
GO