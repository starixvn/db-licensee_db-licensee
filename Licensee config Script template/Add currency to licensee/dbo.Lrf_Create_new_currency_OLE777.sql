use bodb_Licensee
go
exec [dbo].[DBA_CreateLicenseeAgent]
@LicenseeName = 'OLE777',
@SuperWildCard = 'OLE777Super%'
