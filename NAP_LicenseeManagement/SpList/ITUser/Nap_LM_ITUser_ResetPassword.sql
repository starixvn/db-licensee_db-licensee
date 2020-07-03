/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_ResetPassword]
	@UserId INT,
	@UserSalt VARCHAR(50),
	@UserPwd VARCHAR(50)
AS
/*
	 Created: Amanda
	 Date: 2019-02-15
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190215@Amanda: Reset IT User password [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	IF NOT EXISTS (SELECT 1 FROM dbo.Users WITH (NOLOCK) WHERE UserID = @UserId AND isInternal = 0)
	BEGIN
		SELECT 'User does not exist!' AS [Message]
		RETURN
	END
	
	IF ISNULL(@UserSalt, '') = '' OR ISNULL(@UserPwd, '') = ''
	BEGIN
		SELECT 'Invalid password!' AS [Message]
		RETURN
	END
	
	UPDATE dbo.Users WITH (ROWLOCK, UPDLOCK)
	SET UserPwd = @UserPwd,
		UserSalt = @UserSalt
	WHERE UserID = @UserId
	
	SELECT TOP(0) '' AS [Message], CAST(1 AS BIT) AS IsOk
END
GO