USE bodb_licensee
GO

/*
	Created: 20170712@Harper
	Description: #79838

	Haydock (Bodog) - Change licensee type from OW to Zelianta	
*/

DECLARE @ZeResellerID INT, @OWResellerID INT
SELECT @ZeResellerID = ResellerID FROM dbo.Resellers WITH (NOLOCK) WHERE ResellerName = 'Zelianta'
SELECT @OWResellerID = ResellerID FROM dbo.Resellers WITH (NOLOCK) WHERE ResellerName = 'ONEworks'

SELECT @ZeResellerID, @OWResellerID

DECLARE @LicenseeId INT
SELECT @LicenseeId = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = 'Bodog'

-------------------------------------------------------- Update Information

UPDATE dbo.LicenseeReseller
SET ResellerID = @ZeResellerID
WHERE LicenseeID = @LicenseeId
	AND ResellerID = @OWResellerID

--- SET BETSETTING IS ACTIVE AS DEFAULT FOR BOPING/ZELIANTA
UPDATE dbo.Licensees
SET EditBetSetting = 1 
WHERE LicenseeID = @LicenseeId


UPDATE OA_GroupLicensees
SET ResellerID = @ZeResellerID
WHERE LicenseeID = @LicenseeId  
	AND ResellerID =  @OWResellerID

UPDATE OA_UserLicensees
SET ResellerID = @ZeResellerID
WHERE LicenseeID = @LicenseeId
	AND ResellerID =  @OWResellerID

-- UPDATE FUNCTION OF RE-SELLER
	
UPDATE dbo.OA_FunctionLicensees
SET ResellerID = @ZeResellerID
WHERE LicenseeID = @LicenseeId 
	AND ResellerID = @OWResellerID
	
