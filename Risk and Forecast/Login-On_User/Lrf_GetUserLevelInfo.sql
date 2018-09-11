/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_GetUserLevelInfo]  	
	@UserSEQ		INT,
	@UserLevel		INT OUTPUT,
	@HasSubsidiary	BIT OUTPUT
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
	
	DECLARE @OperatorID VARCHAR(50), @SiteName VARCHAR(50)
	SET @HasSubsidiary = 0
	
	SELECT @UserLevel = UserLevel, @OperatorID = OperatorID, @SiteName = SiteName
	FROM dbo.Users WITH (NOLOCK)
	WHERE UserSEQ = @UserSEQ
	
	IF @UserLevel = 2
	BEGIN
		SELECT AgentID, Currency
		FROM dbo.Operator WITH (NOLOCK)
		WHERE OperatorID = @OperatorID AND SiteName = @SiteName
	END
	ELSE
	BEGIN
		SELECT TOP 1 @HasSubsidiary = 1
		FROM dbo.Operator WITH (NOLOCK)
		WHERE SiteName = @SiteName
	END
END
GO