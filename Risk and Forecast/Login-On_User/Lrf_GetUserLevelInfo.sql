/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_GetUserLevelInfo]  	
	@UserSEQ		INT,
	@UserLevel		INT OUTPUT,
	@HasSubsidiary	BIT OUTPUT,
	@OperatorID VARCHAR(50) OUTPUT
AS 
/*  Created: 20180905@Amanda
    Description: LAP - Get user level info
    DB: DBCUST.SiteConfig
   
    Revisions:  
		- 20180905@Amanda: Created SP [RedmineID: #95177]

	Developer's Notes:
		- Notes: User level = 0 --- Oneworks
							= 1 --- Licensee
							= 2 --- Subsidiary
		    
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SiteName VARCHAR(50)
	
	SELECT @UserLevel = UserLevel, @OperatorID = OperatorID, @SiteName = SiteName
	FROM dbo.Users WITH (NOLOCK)
	WHERE UserSEQ = @UserSEQ
	
	SELECT @HasSubsidiary = SubsidiaryEnabled
	FROM dbo.LicVendorProfile WITH (NOLOCK)
	WHERE SiteName = @SiteName
	
	IF @UserLevel = 2
	BEGIN
		SELECT AgentID, Currency
		FROM dbo.Operator WITH (NOLOCK)
		WHERE OperatorID = @OperatorID AND SiteName = @SiteName AND OperatorID <> '' AND OperatorID IS NOT NULL
	END
END
GO