USE [bodb_Licensee]
GO

CREATE VIEW [dbo].[view_site_list]
AS

/*
    Created: 20110621@Don
    Task: Get list of site
    DB: DBLIC.bodb_Licensee, DBACC.bodb_Licensee

    Revisions:
        + 20120314@Don: Fix bug about licensee and label/site have same name
		+ 20181031@Percy: Add new server: DBACC.bodb_Licensee [RedmineID: #103660]
*/

SELECT
    CASE
        WHEN lic.LicenseeName IS NOT NULL THEN lic.LicenseeID
        ELSE (1000 + s.siteID)
    END AS SiteID
    ,s.site AS SiteName
    ,s.siteID AS IbcSiteID
FROM bodb02.dbo.Site s (NOLOCK)
    LEFT JOIN dbo.Licensees lic WITH(NOLOCK) ON s.site = lic.LicenseeName and lic.IsDeposit=1
GO

GRANT SELECT ON [dbo].[view_site_list] TO [bodbAdminNet] AS [dbo]
GO

GRANT SELECT ON [dbo].[view_site_list] TO [vnteam] AS [dbo]
GO


