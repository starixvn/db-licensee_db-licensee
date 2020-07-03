/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LrfFunction_Select]
	@ParentFunctionId	INT = 0
AS
/*
	 Created: Amanda
	 Date: 2019-01-04
	 Task: Implement "Manage LRF Function" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190104@Amanda: Get LRF function [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @parent AS TABLE (
		FunctionId		INT,
		Name			NVARCHAR(100),
		ParentId		INT,
		Url				VARCHAR(200),
		IsMenu			BIT,
		IsActive		BIT,
		DisplayOrder	INT,
		IsNew			BIT,
		FunctionKey		NVARCHAR(100),
		Environment		VARCHAR(10),
		IsFunction		BIT,
		[Root]			BIT
	)
	
	IF (@ParentFunctionId = 0)
	BEGIN
		INSERT INTO @parent (
			FunctionId,
			Name,
			ParentId,
			Url,
			IsMenu,
			IsActive,
			DisplayOrder,
			IsNew,
			FunctionKey,
			Environment,
			IsFunction,
			[Root]
		)
		SELECT	f.FunctionId,
				f.Name,
				f.ParentId,
				f.Url,
				f.IsMenu,
				f.IsActive,
				f.DisplayOrder,
				f.IsNew,
				f.FunctionKey,
				f.Environment,
				f.IsFunction,
				1 AS [Root]
		FROM dbo.Functions f WITH (NOLOCK)
		LEFT JOIN dbo.Functions p WITH (NOLOCK) ON f.ParentId = p.FunctionId
		WHERE p.FunctionId IS NULL
	END
	ELSE
	BEGIN
		INSERT INTO @parent (
			FunctionId,
			Name,
			ParentId,
			Url,
			IsMenu,
			IsActive,
			DisplayOrder,
			IsNew,
			FunctionKey,
			Environment,
			IsFunction,
			[Root]
		)
		SELECT	f.FunctionId,
				f.Name,
				f.ParentId,
				f.Url,
				f.IsMenu,
				f.IsActive,
				f.DisplayOrder,
				f.IsNew,
				f.FunctionKey,
				f.Environment,
				f.IsFunction,
				1 AS [Root]
		FROM dbo.Functions f WITH (NOLOCK)
		WHERE f.FunctionId = @ParentFunctionId
	END

	;WITH Parent_CTE as (
		SELECT	FunctionId,
				Name,
				ParentId,
				Url,
				IsMenu,
				IsActive,
				DisplayOrder,
				IsNew,
				FunctionKey,
				Environment,
				IsFunction,
				1 AS [Root]
		FROM @parent
		UNION ALL 
		SELECT	f.FunctionId,
				f.Name,
				f.ParentId,
				f.Url,
				f.IsMenu,
				f.IsActive,
				f.DisplayOrder,
				f.IsNew,
				f.FunctionKey,
				f.Environment,
				f.IsFunction,
				0 AS [Root]
		FROM Functions f WITH (NOLOCK)
		INNER JOIN Parent_CTE p on f.ParentId = p.FunctionId
	)
	SELECT FunctionId,
			Name,
			ParentId,
			Url,
			IsMenu,
			IsActive,
			DisplayOrder,
			IsNew,
			FunctionKey,
			Environment,
			IsFunction,
			[Root]
	FROM Parent_CTE
	ORDER BY ParentId, DisplayOrder
	OPTION (maxrecursion 20)
END
GO