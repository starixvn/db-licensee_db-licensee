USE bodb_Licensee
GO

/*
	Creator: 20190103@Amanda
	Task: LM - Implement 'Manage Product' function [Redmine: #83584]
	Database: DBCUST.bodb_Licensee

	Revisions:
	- 20190103@Amanda: Grant select permission on dbo.LicenseeProduct3rd to bodbLicenseeNet [Redmine: #83584]
*/

GRANT SELECT ON [dbo].[LicenseeProduct3rd] TO [bodbLicenseeNet]