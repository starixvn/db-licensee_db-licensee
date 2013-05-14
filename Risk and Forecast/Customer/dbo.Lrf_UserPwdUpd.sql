CREATE  PROCEDURE [dbo].[Lrf_UserPwdUpd]
	@UserID int	,
	@UserPwd VARCHAR(50), 
	@UserSalt VARCHAR(50),
	@LoginIP varchar(20)
AS

/*
	Created by: [20101207@Henry]
	Task: Update Pwd
	DB: DB052.bodb_Licensee
	Revisions:
*/

SET NOCOUNT ON
	
	UPDATE Users with (updlock,rowlock)
	SET UserPwd = @UserPwd,
		UserSalt = @UserSalt
	WHERE UserID = @UserID



GO
GRANT EXECUTE ON [dbo].[Lrf_UserPwdUpd] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserPwdUpd] TO [vnteam]

