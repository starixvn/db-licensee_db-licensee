/*<info serverAlias="DBCUST-SiteConfig" executers="Dot_Admin_Portal" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Portal_GetFuncPermission_byUser]
	@UserSEQ int
AS
/*
    Created: 20170607@Wen
    Task: get permission by user
    DB: DBCUST.SiteConfig
    
    Revisions:
		- 20170607@Wen: Create SP
    
    Parameter's Explaination:
		- @Example: exec Portal_GetFuncPermission_byUser 15
*/ 
BEGIN	
	SET NOCOUNT ON;

	SELECT FunctionKey, SubFunctionKeys, SystemType, IsAllow
	FROM [dbo].[UserFuncPermission] WITH(NOLOCK)
	WHERE UserSEQ = @UserSEQ
END
GO
