/*<info serverAlias="DBCUST-SiteConfig" executers="Dot_Admin_Portal" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Portal_Get_LRF_CurrencyPermission]
	@SiteName VARCHAR(50),
	@UserSEQ INT
AS
/*
    Created: 20180206@Amanda
    Task: Get list of active CurrencyID by UserSEQ and SiteName - [Redmine: #87709]
    DB: DBCUST.SiteConfig
    
    Revisions:
		- 20180928@Amanda: Migrate table from DBLIC.bodb_Licensee to DBCust.bodb_Licensee - [Redmine: #99855]
    
    Parameter's Explaination:
		- @Example: exec Portal_Get_LRF_CurrencyPermission 'Athena000',608
*/ 
BEGIN 
	SET NOCOUNT ON	
	
	DECLARE @LicenseeId INT
	DECLARE @UserId INT
	
	DECLARE @UserName VARCHAR(50)
	
	SELECT @UserName = UserID
	FROM dbo.Users WITH (NOLOCK)
	WHERE UserSEQ = @UserSEQ
	
	SELECT @LicenseeId = lic.LicenseeID, @UserId = usr.UserID
	FROM bodb_licensee.dbo.Licensees lic  WITH (NOLOCK)
	INNER JOIN bodb_licensee.dbo.LicenseeUser leu WITH (NOLOCK) ON lic.LicenseeID = leu.LicenseeID
	INNER JOIN bodb_licensee.dbo.Users usr WITH (NOLOCK) ON usr.UserID = leu.UserID
	WHERE lic.LicenseeName = @SiteName AND usr.Username = @UserName	
	
	SELECT  cru.CurrencyID
	FROM bodb_licensee.dbo.CurrencyUser cru WITH (NOLOCK)
	WHERE cru.usrID = @UserId
			AND cru.LicenseeID = @LicenseeId 
			AND cru.SystemID = 1 -- System is default=1 (LRF) 
			AND cru.isActive = 1
END
GO