/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LrfFunction_GetTopParentFunction]
AS
/*
	 Created: Amanda
	 Date: 2019-01-04
	 Task: Implement "Manage LRF Function" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190104@Amanda: Get Top Parent LRF function [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT f.FunctionId AS Id, f.Name AS Name
	FROM dbo.Functions f WITH (NOLOCK)
	LEFT JOIN dbo.Functions p WITH (NOLOCK) ON f.ParentId = p.FunctionId
	WHERE p.FunctionId IS NULL
	ORDER BY f.DisplayOrder
END
GO