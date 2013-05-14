ALTER PROCEDURE [dbo].[PIH_Users_Logout]
	@On_UserID INT
AS

/*
 *	Created by	: [20111512@Kos]
 *	Task		: PIH user logout
 *	DB			: WW100_DB.bodb_PIH @ kahnawake
 *	Revisions	:
 *
 *	Param's Explanation:  
 *		- @On_UserID		: User ID
 */

SET NOCOUNT ON

DELETE 
FROM PIH_OnUser 
WHERE on_userid = @On_UserID


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_Logout] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_Logout] TO [bodbAdminNet] 
