USE bodb_Licensee
GO

/*
	Created:	20170608@Harper
	Support:	#77867: Bolanation - Get dummy account & create aff dummy account
*/

EXEC [dbo].[DBA_CreateLicenseeAgent]
@LicenseeName = 'Bolanation',
@SuperWildCard = 'BolanationSuper%'

GO