/*<info serverAlias="DBEXT-bodb02,DBLIC-bodb_LicenseeReport,DBBAL-bodb_LicenseeReport,DBWH-bodb_DWRS" selecters="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].Lrf_f_GetCutOffDate()
RETURNS TABLE
AS

/*
	Creator: Evan
	Task: Get Cut Off Date
	DB: DBEXT-bodb02
	Revision:
		- 20221912@Evan: Add cutoff date of Cash Out Win Loss Report [Redmine: #179083]	
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]
		- 20230702@Evan: LAP - Enhance Exchange reports (Support View Resettled Ticket Data + add COD for NewTerm) [Redmine: #193954]

*/

RETURN

	SELECT CutoffDate, TypeName
	FROM (
		VALUES ('2023-01-01', 'CashOut'),
			('2023-07-01', 'SabaTennis'),
			('2023-05-01', 'ExchangeWL_NewTerm'),
			('2023-09-01', 'ExchangeWL_ViewResettled')
	) AS t (CutoffDate, TypeName)
	
GO