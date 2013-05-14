USE [bodb_PIH]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[View_SiteList]') AND type in (N'V'))
DROP VIEW [dbo].[View_SiteList]
GO

CREATE VIEW [dbo].[View_SiteList]
AS
/*
    Created: 20120717@Don
    Task: 
    DB: DB054.bodb_PIH

    Revisions:
    
*/

SELECT
    CASE
        WHEN lic.LicenseeName IS NOT NULL THEN lic.LicenseeID
        ELSE (1000 + s.siteID)
    END AS SiteID
    ,s.site AS SiteName
    ,s.siteID AS IbcSiteID
FROM bodb02.dbo.Site s (NOLOCK)
    LEFT JOIN bodb_Licensee.dbo.Licensees lic WITH(NOLOCK) ON s.site = lic.LicenseeName AND lic.IsDeposit=1



GO
GRANT VIEW DEFINITION ON [dbo].[View_SiteList] TO [VNTeam]