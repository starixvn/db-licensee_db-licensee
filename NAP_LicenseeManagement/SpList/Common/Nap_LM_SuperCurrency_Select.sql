/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_SuperCurrency_Select]
	@SuperWildCard	VARCHAR(50)	= ''
AS
/*
	 Created: Amanda
	 Date: 2018-11-30
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.CustDB
	 
	 Revisions:
	  - 20181130@Amanda: Select super currency by user name [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	;WITH Currency_CTE AS (
		SELECT DISTINCT currency
		FROM dbo.custInfo WITH (NOLOCK)
		WHERE username LIKE @SuperWildCard + '%' AND roleid = 4
	)
	SELECT c.currency AS Id, e.currency AS Name 
	FROM dbo.exchange e WITH (NOLOCK)
	INNER JOIN Currency_CTE c ON e.exchangeid = c.currency
		
END
GO