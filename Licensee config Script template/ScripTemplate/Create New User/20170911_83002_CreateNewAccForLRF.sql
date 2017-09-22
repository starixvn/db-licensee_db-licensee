USE bodb_licensee
GO

/*
	Created: 20170911@Harper
	Description: Create account for internal LRF [RedmineID: #83002]
		1) Turky
		2) LSoon
		3) Brian
		4) Yakushi
		5) Flin

	DB: DBLIC/bodb_licensee
*/

UPDATE dbo.Users
SET Status = 'Closed'
WHERE UserID IN (207, 1352) -- Brian

GO

-- Add New User With Admin Role

EXEC [DBA_CreateLicenseeUser] @LicenseeName = 'All', @Username= 'Turky',@UserRole='Admin',@FirstName='Turky'

EXEC [DBA_CreateLicenseeUser] @LicenseeName = 'All', @Username= 'LSoon',@UserRole='Admin',@FirstName='LSoon'

EXEC [DBA_CreateLicenseeUser] @LicenseeName = 'All', @Username= 'Yakushi',@UserRole='Admin',@FirstName='Yakushi'

EXEC [DBA_CreateLicenseeUser] @LicenseeName = 'All', @Username= 'Flin',@UserRole='Admin',@FirstName='Flin'

-- Add more Licensee for existing User
EXEC [DBA_CreateLicenseeUser] @LicenseeName = 'All', @Username= 'Brian',@UserRole='Admin',@FirstName='Brian'

GO
