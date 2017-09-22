USE bodb_licensee
GO

/*
	Created: 20170712@Harper
	Description: #79838

	Keep Bodog under BCH
*/

DECLARE @ZeResellerID INT
SELECT @ZeResellerID = ResellerID FROM dbo.Resellers WITH (NOLOCK) WHERE ResellerName = 'Zelianta'

DECLARE @LicenseeId INT
SELECT @LicenseeId = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = 'Bodog'

SELECT @ZeResellerID, @LicenseeId

DELETE dbo.LicenseeReseller
WHERE LicenseeID = @LicenseeId AND ResellerID = @ZeResellerID

DELETE OA_GroupLicensees
WHERE LicenseeID = @LicenseeId AND ResellerID = @ZeResellerID

DELETE OA_UserLicensees
WHERE LicenseeID = @LicenseeId AND ResellerID = @ZeResellerID

DELETE dbo.OA_FunctionLicensees
WHERE LicenseeID = @LicenseeId AND ResellerID = @ZeResellerID		
