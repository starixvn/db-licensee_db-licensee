DECLARE @LicenseeID INT
SELECT @LicenseeID = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = 'Mansion88'

-- Licensee
SELECT r.ResellerName, lr.*
FROM dbo.LicenseeReseller lr WITH (NOLOCK)
	INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
WHERE lr.LicenseeID = @LicenseeID

SELECT r.ResellerName, lr.*
FROM dbo.OA_GroupLicensees lr WITH (NOLOCK)
	INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
WHERE lr.LicenseeID = @LicenseeID

SELECT r.ResellerName, lr.*
FROM dbo.OA_UserLicensees lr WITH (NOLOCK)
	INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
WHERE lr.LicenseeID = @LicenseeID

SELECT r.ResellerName, lr.*
FROM dbo.OA_FunctionLicensees lr WITH (NOLOCK)
	INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
WHERE lr.LicenseeID = @LicenseeID