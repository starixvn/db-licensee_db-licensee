USE bodb_licensee
GO

DECLARE @LicenseeName VARCHAR (100)
		,@LicenseeID INT
		
SET @LicenseeName = 'Lambo777'
SELECT @LicenseeId = LicenseeId
FROM dbo.Licensees WITH (NOLOCK)
WHERE LicenseeName = @LicenseeName

UPDATE dbo.SystemLicensee WITH (ROWLOCK,UPDLOCK)
SET IsActive = 0
WHERE LicenseeId = @LicenseeId
