ALTER PROCEDURE [dbo].[PIH_Users_Login]	
	@Username VARCHAR(50)
AS

/*
 *	Created by	: [20111512@Kos]
 *	Task		: Get user and password for the login user
 *	DB			: WW100_DB.bodb_PIH @ kahnawake
 *	Revisions	:
 *
 *	Param's Explanation:  
 *		- @Username		: Username
 */

SET NOCOUNT ON

SELECT UserID,
	Username,
	UserPwd,
	UserSalt,
	DisplayName,
	Role,
	IsActive,
	IsTest
FROM dbo.PIH_Users WITH (NOLOCK)
WHERE Username = @Username


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_Login] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_Login] TO [bodbAdminNet] 
