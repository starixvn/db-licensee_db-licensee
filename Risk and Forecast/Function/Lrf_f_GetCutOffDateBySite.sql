/*<info serverAlias="DBPLO-bodb02" selectors="bodbLicenseeNet" viewers="" isFunction="1" isNested="0"></info>*/
CREATE FUNCTION [dbo].[Lrf_f_GetCutOffDateBySite]()
RETURNS TABLE
AS
/*
	Created:20200916@Sol
	Task: Cut Off Date By Site name
	DB: DBPLO-bodb02
	Revisions:
		- 20200916@Sol: Initialize [redmine: #125252]
		- 20200916@Sol: update cut off time for 12bet [redmine: #139910]

	Data description:
		Reporttype = 1: for reports related to audit (bodb_licenseeReportArchive.dbo.rptDep_AuditTickets)
 */
RETURN (
	
	SELECT 	ReportType, SiteName, CutOffDate
	FROM
		(
			VALUES 
				(1, '12Bet', '2019-12-01'),
				(1, 'Ivorysport', '2020-09-01'),
				(1, 'Nova88', '2020-09-01'),
				(1, 'Opal88', '2020-09-01')
		) AS tbl (ReportType, SiteName, CutOffDate)
	
)
GO