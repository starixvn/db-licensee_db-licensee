ALTER PROCEDURE [dbo].[Lrf_UserLogout]
	@On_UserID INT
AS
SET NOCOUNT ON

/*
	Task: User Logout
	DB: DB052.bodb_Licensee
	Original 
	
	Revisions:
		- 20101208@Johnny

*/

Delete from On_User WHERE on_userid = @On_UserID

GO
GRANT EXECUTE ON [dbo].[Lrf_UserLogout] TO [bodbLicenseeNet] 
GO
GRANT EXECUTE ON [dbo].[Lrf_UserLogout] TO [bodbAdminNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserLogout] TO [vnteam] 