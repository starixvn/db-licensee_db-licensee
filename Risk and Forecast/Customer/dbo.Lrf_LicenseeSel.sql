ALTER  PROCEDURE [dbo].[Lrf_LicenseeSel]
	@UserID INT	
AS

/*
	Created by: [20101207@Henry]
	Task: Get List of licensee by passing UserID
	DB: DB052.bodb_Licensee
	Revisions:
		- 20110610@Henry: add column EnableBA
		- 20120510@Henry: show only active Licensee
		- 20120621@Jim: optimize code 
		- 20120723@Henry: add column IsAllowedMemberComm
		- 20121024@Henry: add column ResellerID + ResellerName
*/

SET NOCOUNT ON
	SELECT 
		l.LicenseeID, l.LicenseeName, isnull(lb.EnableBA,0) EnableBA, l.IsAllowedMemberComm , r.ResellerID, r.ResellerName
	FROM 
		Licensees l with (NOLOCK)
		INNER JOIN SystemLicensee sl (NOLOCK) ON l.LicenseeID=sl.LicenseeID 
		INNER JOIN Systems s (NOLOCK) ON sl.SystemID=s.ID 
		INNER JOIN LicenseeUser lu with (NOLOCK) ON l.LicenseeID = lu.LicenseeID
		INNER JOIN (SELECT * FROM LicenseeReseller WITH (NOLOCK) WHERE ResellerID <> 3) lr  ON l.LicenseeID = lr.LicenseeID
		INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
		LEFT JOIN LicenseeBAConfig lb with (nolock) ON lb.licenseeID = l.licenseeID
	WHERE 
		lu.UserID = @UserID
		AND lu.isActive = 1
		AND sl.IsActive=1
		AND s.SystemName='LRF'
	ORDER BY l.LicenseeID
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeSel] TO [vnteam]

