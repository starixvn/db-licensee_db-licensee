/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LrfFunction_SelectAll]
AS
/*
	 Created: Amanda
	 Date: 2019-01-25
	 Task: Implement "Manage LRF Function" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190125@Amanda: Get All LRF function [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT FunctionId AS Id, Name
	FROM dbo.Functions WITH (NOLOCK)
	WHERE IsActive = 1
END
GO