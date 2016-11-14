CREATE  PROCEDURE [dbo].[Lrf_LicenseeSelByLicenseeId]
	@LicenseeID INT	
AS

/*
	Created by: [20161114@Alex]
	Task: Get List of licensee by LicenseeID
	DB: DB052.bodb_Licensee
	Revisions:
		
*/

SET NOCOUNT ON
	SELECT 
		l.LicenseeID, l.LicenseeName, isnull(lb.EnableBA,0) EnableBA, l.IsAllowedMemberComm , r.ResellerID, r.ResellerName
	FROM 
		Licensees l with (NOLOCK)
		INNER JOIN SystemLicensee sl (NOLOCK) ON l.LicenseeID=sl.LicenseeID 
		INNER JOIN Systems s (NOLOCK) ON sl.SystemID=s.ID 
		INNER JOIN (SELECT * FROM LicenseeReseller WITH (NOLOCK) WHERE ResellerID <> 3) lr  ON l.LicenseeID = lr.LicenseeID
		INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
		LEFT JOIN LicenseeBAConfig lb with (nolock) ON lb.licenseeID = l.licenseeID
	WHERE 
		l.LicenseeID = @LicenseeID
		AND l.IsActive=1
		AND sl.IsActive=1
		AND s.SystemName='LRF'
	ORDER BY l.LicenseeID
GO
GRANT EXECUTE ON [dbo].Lrf_LicenseeSelByLicenseeId TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].Lrf_LicenseeSelByLicenseeId TO [vnteam]

