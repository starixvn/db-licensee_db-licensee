/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_Insert]
	@UserName VARCHAR(50),
	@FirstName NVARCHAR(50) = '',
	@LastName NVARCHAR(50) = '',
	@Email VARCHAR(50) = '',
	@IsAdmin BIT = 0,
	@LicenseeName VARCHAR(50) = '',
	@UserSalt VARCHAR(50),
	@UserPwd VARCHAR(50),
	@SystemId INT = 1, -- LRF
	@Option INT = 0,
	@UserId INT = 0 OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2019-01-31
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee

	 Revisions:
	  - 20190131@Amanda: Add New User [Redmine: #83584]
	  - 20190315@Amanda: Remove unnecessary code [Redmine: #83584]
	  
	 Developer's Note:
	  - @LicenseeName: a Licensee Name or 'All'
	  - @Option:
		+ 0: Only add licensee
		+ 1: Assign all currencies and functions, excluding "Account Management" and "Notification"
		+ 2: Assign all currencies and functions, including "Account Management" and "Notification"

*/
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (SELECT  1 FROM dbo.Users WITH (NOLOCK) WHERE Username = @UserName AND isInternal = 0)
	BEGIN
		SELECT 'This user name already exists!' AS [Message]
		RETURN
	END	
	
	IF ISNULL(@UserSalt, '') = '' OR ISNULL(@UserPwd, '') = ''
	BEGIN
		SELECT 'Invalid password!' AS [Message]
		RETURN
	END
	
	DECLARE @UserRole VARCHAR(50)
	DECLARE @LicenseeId INT, @tmpLicenseeName VARCHAR(50)
	
	IF @IsAdmin = 1
	BEGIN
		SET @UserRole = 'Admin'
	END
	ELSE
	BEGIN
		SET @UserRole = 'Licensee'
	END
	
	IF ISNULL(@LicenseeName, '') <> '' AND @LicenseeName <> 'All'
	BEGIN
		SELECT @LicenseeId = l.LicenseeId
		FROM dbo.Licensees l WITH (NOLOCK)
		INNER JOIN dbo.SystemLicensee sl WITH (NOLOCK) ON l.LicenseeID = sl.LicenseeID
		INNER JOIN dbo.LicenseeReseller lr WITH (NOLOCK) ON l.LicenseeId = lr.LicenseeId
		INNER JOIN dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
		WHERE l.LicenseeName = @LicenseeName 
			AND l.IsActive = 1
			AND sl.IsActive = 1
			AND sl.SystemID = @SystemId
			AND lr.ResellerID <> 3
			
		IF @LicenseeId IS NULL
		BEGIN
			SELECT 'Licensee does not exist or is not active or is not active for LRF system!' AS [Message], 0 AS IsOk		
			RETURN
		END
		
		SET @tmpLicenseeName = @LicenseeName
	END
	
	IF  @UserRole = 'Licensee' AND @LicenseeName = 'All'
	BEGIN
		SELECT 'Can not add multiple Licensees for a Licensee user!' AS [Message], 0 AS IsOk		
		RETURN
	END
	
	INSERT INTO dbo.Users (Username, UserPwd, UserSalt, UserRole, FirstName, LastName, Email, [Status], LicenseeName, isInternal, CreateDate)
	VALUES (@Username, @UserPwd, @UserSalt, @UserRole, @FirstName, @LastName, @Email, 'Open', @tmpLicenseeName, 0, GETDATE())
	SET @UserID = @@identity

	EXEC dbo.Nap_LM_ITUser_AssignToLicensee
		@UserId = @UserID,
		@AssignedLicensees = @LicenseeName,
		@AssignOption = @Option	
END
GO