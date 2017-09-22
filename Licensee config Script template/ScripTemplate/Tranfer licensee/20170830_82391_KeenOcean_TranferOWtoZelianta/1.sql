USE bodb_licensee
GO

/*
	Created: 20170830@Harper
	Description: #82391

	KeenOcean(Livv88) - Change licensee type from OW to Zelianta	
*/

DECLARE @LicenseeId INT
SELECT @LicenseeId = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = 'KeenOcean'
-------------------------------------------------------- Update Information

--- SET BETSETTING IS ACTIVE AS DEFAULT FOR BOPING/ZELIANTA
UPDATE dbo.Licensees
SET EditBetSetting = 1 
WHERE LicenseeID = @LicenseeId

	
