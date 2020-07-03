/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_GetAgentInfoByAgentId]
	@AgentId	INT
AS
/*
	 Created: Amanda
	 Date: 2018-10-12
	 Task: Implement "Manage operatorID" function
	 DB: DBCUST.CustDB
	 
	 Revisions:
	  - 20181012@Amanda: Get Agent Info By AgentId [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT c.custid AS AgentId, c.currency AS currencyId, c.username, c.[site] AS SiteName, e.currency AS currencyName
	FROM dbo.Customer c WITH (NOLOCK)
	INNER JOIN dbo.Exchange e WITH (NOLOCK) ON c.currency = e.exchangeid
	WHERE c.custid = @AgentId

END
GO