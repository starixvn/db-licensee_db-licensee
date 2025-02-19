/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

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
	  - 20250219@Eden:Scale Out DBCUST - bodb_Licensee [Redmine:#216866]
*/
BEGIN
	SET NOCOUNT ON;

	;WITH Currency_CTE AS (
		SELECT DISTINCT l.Currency
		FROM dbo.LicenseeCust l WITH (NOLOCK)
		WHERE l.LicenseeID = @LicenseeId AND RoleID = 2
	)
	SELECT e.exchangeid AS Id, e.currency AS Name
	FROM GlobCustDB.dbo.exchange e WITH (NOLOCK)
	INNER JOIN Currency_CTE c ON e.exchangeid = c.Currency
END
