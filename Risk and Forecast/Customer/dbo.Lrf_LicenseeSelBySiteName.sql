/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_LicenseeSelBySiteName]
	@siteName nvarchar(25)
AS
/*
	Created by: 20161114@Alex
	Task: Get detailed of licensee by SiteName
	DB: DBLIC/bodb_Licensee
	Revisions:
		- 20220803@Elodie: add column SiteDBGroupID
*/
--  EXEC Lrf_LicenseeSelBysiteName @siteName=12bet
BEGIN
	SET NOCOUNT ON

	SELECT l.LicenseeID
		, l.LicenseeName
		, ISNULL(lb.EnableBA,0) EnableBA
		, l.IsAllowedMemberComm
		, r.ResellerID
		, r.ResellerName
		, si.SiteDBGroupID
	FROM dbo.Licensees l WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Site si WITH (NOLOCK) ON l.LicenseeID = si.siteid
		INNER JOIN dbo.SystemLicensee sl WITH (NOLOCK) ON l.LicenseeID = sl.LicenseeID
		INNER JOIN dbo.Systems s WITH (NOLOCK) ON sl.SystemID = s.ID
		INNER JOIN dbo.LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeID = lr.LicenseeID AND lr.ResellerID <> 3
		INNER JOIN Resellers r WITH (NOLOCK) ON r.ResellerID = lr.ResellerID
		LEFT JOIN dbo.LicenseeBAConfig lb WITH (NOLOCK) ON lb.licenseeID = l.licenseeID
	WHERE LOWER(l.LicenseeName) = LOWER(@siteName)
		AND l.IsActive = 1
		AND sl.IsActive = 1
		AND s.ID = 1 --- 'LRF'
 
END
GO
