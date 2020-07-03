/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Operator_Get]
	@AgentId INT
AS
/*
	 Created: Amanda
	 Date: 2018-09-25
	 Task: Implement "Manage operatorID" function
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20180925@Amanda: Get operator by @AgentId [Redmine: #83584] 
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT o.AgentID, o.SiteName, o.Currency AS CurrencyId, e.currency AS CurrencyName, o.OperatorID, c.UserName
	FROM dbo.Operator o WITH(NOLOCK)
	INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK) ON o.Currency = e.exchangeid
	INNER JOIN CUSTDB.dbo.Customer c WITH(NOLOCK) ON c.CustId = o.AgentId
	WHERE o.AgentID = @AgentId
END
GO