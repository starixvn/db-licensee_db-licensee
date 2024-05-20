/*<info serverAlias="DBPLO-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_AdminPlayerSearch_Site]  	
	@SearchName		VARCHAR(50),
    @SiteName       VARCHAR(15) = 'ivorybet'
AS 
/*  
	Created: 20231025@Bobby
    Description: LAP - Implement new report for auditing
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20231211@Bobby: Ivory Player Report - [redmine: #197945]
		
    Param's Explanation:  
	  
*/
BEGIN  
    
	SET NOCOUNT ON;

    -- Brand mapping
	SELECT @SiteName = dbo.Lrf_f_MappingAuditSite(@SiteName)

	SELECT TOP (1) pp.[CustID]
        ,@SearchName AS [UserName] 
        ,pp.CurrencyCode
        ,c.creatdate AS [RegisteredDate]
        ,pp.IPAddress AS [IP]
        ,'-' AS DOB
        -------------Player infomation
        ,'Male' AS [Gender]
        ,SUBSTRING(c.username2, CHARINDEX('$', c.username2)+1, 50) AS [RegisteredUserName]
        ,pp.EmailAddress AS [Email]
        ,'-' AS [Mobile]
        ,'Yes' AS [Active]
        ,'No' AS [Locked]
        ,'-' AS [Address]
        ,'-' AS Nationality
        ,'-' AS Occupation
        ,lic.LicenseeName
    FROM bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) 
        INNER JOIN bodb_Ploutos.dbo.Brand b WITH(NOLOCK) ON b.BrandCode = pp.BrandCode
        INNER JOIN dbo.vw_Customer c WITH(NOLOCK) ON c.CustID = pp.custid
        --INNER JOIN bodb_licensee.dbo.LicenseeSourcedSetting lcust WITH(NOLOCK) ON lcust.LicenseeID = b.LicenseeID AND lcust.SourcedId = c.recommend AND lcust.RoleID = 2
        INNER JOIN bodb_licensee.dbo.LicenseeCust lcust WITH(NOLOCK) ON lcust.CustID = c.recommend AND lcust.RoleID = 2
        INNER JOIN bodb_licensee.dbo.Licensees lic WITH(NOLOCK) ON lic.LicenseeID = lcust.LicenseeID
	WHERE pp.BrandCode = @SiteName
        AND (
            pp.userName = @SearchName
            OR c.username2 = lic.LicenseeName+'$' + @SearchName
        )
    ;
END
GO