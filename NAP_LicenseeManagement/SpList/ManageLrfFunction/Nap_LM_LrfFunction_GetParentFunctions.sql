/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LrfFunction_GetParentFunctions]
	@FunctionId	INT
AS
/*
	 Created: Amanda
	 Date: 2019-01-04
	 Task: Implement "Manage LRF Function" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190104@Amanda: Get Parent LRF functions of @FunctionId [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	IF @FunctionId = 0
	BEGIN
		SELECT FunctionId AS Id, Name
		FROM dbo.Functions WITH (NOLOCK)
		WHERE IsActive = 1	
	END
	ELSE
	BEGIN
		DECLARE @children AS TABLE (Id INT)
	
		;WITH Parent_CTE as (
			SELECT	FunctionId
			FROM dbo.Functions WITH (NOLOCK)
			WHERE FunctionId = @FunctionId
			UNION ALL 
			SELECT	f.FunctionId
			FROM Functions f WITH (NOLOCK)
			INNER JOIN Parent_CTE p on f.ParentId = p.FunctionId
		)
		INSERT INTO @children(Id)
		SELECT FunctionId
		FROM Parent_CTE
		OPTION (maxrecursion 20)
		
		SELECT FunctionId AS Id, Name
		FROM dbo.Functions f WITH (NOLOCK)
		LEFT JOIN @children c ON f.FunctionId = c.Id
		WHERE f.IsActive = 1 AND c.Id IS NULL
	END
END
GO