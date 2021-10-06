/*<info serverAlias="DBLIC-bodb_licensee,DBBAL-bodb_licensee" selecters="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
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
		+ 20210816@Sophia: add DBBAL [Redmine: #154300]
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
 
