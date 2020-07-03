/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LrfFunction_Get]
	@FunctionId	INT
AS
/*
	 Created: Amanda
	 Date: 2019-01-09
	 Task: Implement "Manage LRF Function" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190109@Amanda: Get LRF functions by @FunctionId [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT	FunctionId,
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
	FROM dbo.Functions WITH (NOLOCK)
	WHERE FunctionId = @FunctionId
	
END
GO