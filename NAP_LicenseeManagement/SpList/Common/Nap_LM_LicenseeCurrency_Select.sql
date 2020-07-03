/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LicenseeCurrency_Select]
	@LicenseeId INT = 0
AS
/*
	 Created: Amanda
	 Date: 2018-12-11
	 Task: Implement "Source Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181211@Amanda: Select currency of licensee [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	;WITH Currency_CTE AS (
		SELECT DISTINCT l.Currency
		FROM dbo.LicenseeCust l WITH (NOLOCK)
		WHERE l.LicenseeID = @LicenseeId AND RoleID = 2
	)
	SELECT e.exchangeid AS Id, e.currency AS Name
	FROM CustDB.dbo.exchange e WITH (NOLOCK)
	INNER JOIN Currency_CTE c ON e.exchangeid = c.Currency
END
