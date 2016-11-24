USE [bodb_licensee]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Lrf_LicenseeSelBySiteName]
	@siteName nvarchar(25)
AS
/*
	Created by: [20161114@Alex]
	Task: Get detailed of licensee by SiteName
	DB: DBLIC/bodb_Licensee
	Revisions:
		
*/
--  EXEC Lrf_LicenseeSelBysiteName @siteName=12bet
SET NOCOUNT ON
BEGIN
	SELECT l.LicenseeID
		, l.LicenseeName
		, ISNULL(lb.EnableBA,0) EnableBA
		, l.IsAllowedMemberComm
		, r.ResellerID
		, r.ResellerName
	FROM dbo.Licensees l WITH (NOLOCK)
	INNER JOIN dbo.SystemLicensee sl WITH (NOLOCK)
		ON l.LicenseeID = sl.LicenseeID
	INNER JOIN dbo.Systems s WITH (NOLOCK)
		ON sl.SystemID = s.ID
	INNER JOIN dbo.LicenseeReseller lr WITH (NOLOCK)
		ON l.LicenseeID = lr.LicenseeID AND lr.ResellerID <> 3
	INNER JOIN Resellers r WITH (NOLOCK)
		ON r.ResellerID = lr.ResellerID
	LEFT JOIN dbo.LicenseeBAConfig lb WITH (NOLOCK)
		ON lb.licenseeID = l.licenseeID
	WHERE LOWER(l.LicenseeName) = LOWER(@siteName)
		AND l.IsActive = 1
		AND sl.IsActive = 1
		AND s.ID = 1 --- 'LRF'
 
END

GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeSelBySiteName] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeSelBySiteName] TO vnteam