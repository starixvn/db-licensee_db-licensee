/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Operator_Delete]
	@AgentId			INT
AS
/*
	 Created: Amanda
	 Date: 2018-11-19
	 Task: Implement "Manage operatorID" function
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20181119@Amanda: Delete operator [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	IF EXISTS (SELECT 1 FROM dbo.Operator WITH(NOLOCK) WHERE AgentID = @AgentId AND ISNULL(OperatorID, '') = '')
	BEGIN
		DELETE dbo.Operator WITH (ROWLOCK)
		WHERE AgentID = @AgentId AND ISNULL(OperatorID, '') = ''

		SELECT 1
	END

	SELECT 0
END
GO