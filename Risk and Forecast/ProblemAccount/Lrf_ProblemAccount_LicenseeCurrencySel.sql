/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE Lrf_ProblemAccount_LicenseeCurrencySel	
AS
/*
	Created: Johnson
	Date: 20200217
	Task : currency dropdown box
	DB: DBACC/bodb02

	Revisions:
		- 20200217@Johnson: Initial SP [Redmine:#128077]

	Parameter's explaination: 
			
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT exchangeid, currency
	FROM exchange WITH(NOLOCK)
	WHERE currency NOT IN ('C','H')
END
GO
