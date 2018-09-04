USE bodb_licensee
GO

/*
	Created by: 20180807@Harper
	RedmineID: #99550: Taipanbet - Transferred to Zelianta
	Description:  Terminated with OW on June 30, 2018
				Launch date : Jul 1, 2018
				Settings are unchanged 
				Products: SB, NG, BA, VS, AG, GD, Cash Out, VS2, Lottery
*/

DECLARE @LicenseeId INT
SELECT @LicenseeId = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = 'Taipanbet'

-------------------------------------------------------- Update Information

--- SET BETSETTING IS ACTIVE AS DEFAULT FOR BOPING/ZELIANTA
UPDATE dbo.Licensees
SET EditBetSetting = 1 
WHERE LicenseeID = @LicenseeId
