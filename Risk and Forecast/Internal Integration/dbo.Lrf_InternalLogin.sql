/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LRF_InternalLogin]
	@LicenseeName		VARCHAR(50),
	@Username			VARCHAR(50),
	@EncryptedPassword	VARCHAR(50),
	@LoginTime			DATETIME,
	@LoginIP			VARCHAR(50),
	@ServerID			INT				= 0 OUTPUT,	
	@LoginDomain		NVARCHAR(253)	= NULL,
	@BrowserName		NVARCHAR(255)	= NULL,
	@Platform			NVARCHAR(255)	= NULL,  
	@CountryCode		VARCHAR(64)		= NULL,  	
	@Language			VARCHAR(20)		= 'en-us',
	@ErrMsg				NVARCHAR(1000)	= '' OUTPUT,
    @ErrCode			INT				= 0 OUTPUT	
AS

/*
	Created by: [20110704@Henry]
	Task: Login to LRF thru Internal site
	DB: DBCUST-bodb_Licensee
	Param's Explanation:
	
	Revisions:
		- 20111004@Henry: check only Internal user (IsInternal = 1)
		- 20120724@HEnry: return 1 more column: IsAllowedMemberComm
		- 20141217@Jim: correct error code 
		- 20151023@Victor: Support New Simplified Chinese
		- 20171002@Percy: Write more password into log [RedmineID: #83692]
		- 20180925@Joseph: Migrate to DBCUST [Feature #99855]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Begin		DATETIME
	DECLARE @Duration	INT

	SET @Begin = GETDATE()

	DECLARE @UserID		INT
	DECLARE @FirstName	NVARCHAR(50)
	DECLARE @LastName	NVARCHAR(50)
	DECLARE @UserRole	VARCHAR(50)
	DECLARE @Email		VARCHAR(50)
	DECLARE @Status		VARCHAR(30)
	DECLARE @LogData	NVARCHAR(600)

	IF DATEDIFF(SECOND, @LoginTime, GETDATE()) > 30
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'The link has been expired!'
						
		SET @LogData = 'Failed(Link_Expired)'
	END
	ELSE
	BEGIN
		SELECT @UserID = UserID, @UserRole = UserRole, @FirstName = FirstName, @LastName = LastName, @Email = Email, @Status = [Status]
		FROM dbo.Users WITH (NOLOCK)
		WHERE Username = @UserName
			AND LicenseeName = @LicenseeName
			AND UserPwd = @EncryptedPassword
			AND IsInternal = 1

		IF @UserID IS NULL
		BEGIN
			SELECT @ErrCode = 101, @ErrMsg = 'Wrong username or password.'

			SET @LogData = 'Failed(User_Not_Found)'
		END
		ELSE IF @Status <> 'Open'
		BEGIN
			SELECT @ErrCode = 102, @ErrMsg = 'This user is not active.'

			SET @LogData = 'Failed(User_Not_Active)'
		END
		ELSE
		BEGIN
			DECLARE @LicenseeID INT
			DECLARE @RowCnt INT
			DECLARE @EnableBA BIT
			DECLARE @IsAllowedMemberComm BIT
			
			IF @UserRole = 'Licensee'
			BEGIN
				SELECT @RowCnt = COUNT(*) FROM dbo.LicenseeUser WITH (NOLOCK) WHERE UserID = @UserID
				
				IF @RowCnt > 1
				BEGIN
					SELECT @ErrCode = 103, @ErrMsg = 'This user has too many licensees.'  
					
					SET @LogData = 'Failed(User_Too_Many_Licensees)'
				END
				ELSE
				BEGIN
					SELECT @LicenseeID = LicenseeID FROM dbo.LicenseeUser WITH (NOLOCK) WHERE UserID = @UserID
			
					IF @LicenseeID IS NULL
					BEGIN
						SELECT @ErrCode = 104, @ErrMsg = 'This user has no licensee.'  
						
						SET @LogData = 'Failed(User_Not_Found_Licensee)'
					END
					ELSE
					BEGIN
						SELECT @EnableBA = EnableBA FROM dbo.LicenseeBAConfig WITH (NOLOCK) WHERE LicenseeID = @LicenseeID
						SELECT @IsAllowedMemberComm = IsAllowedMemberComm FROM dbo.Licensees WITH (NOLOCK) WHERE LicenseeID = @LicenseeID

						-- Return data
						SELECT
							@UserID							AS UserID,
							@Username						AS Username,
							@UserRole						AS UserRole,
							@FirstName						AS FirstName,
							@LastName						AS LastName,
							@Email							AS Email,
							@Status							AS Status,
							@LicenseeID						AS LicenseeID,
							ISNULL(@EnableBA, 0)			AS EnableBA,
							ISNULL(@IsAllowedMemberComm, 0) AS IsAllowedMemberComm,
							1 AS IsInternal

						SET @LogData = 'Success'
					END
				END
			END
		END
	END
	
	IF ISNULL(@LogData, '') <> ''
	BEGIN
		SELECT @UserID	= ISNULL(@UserID, 0), @ServerID = 200, @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE())
		SELECT @LogData	= 'User: ' + @UserName +  ' - ' + 'Password: ' + @EncryptedPassword + ' - ' + @LogData

		EXEC dbo.LAP_WriteLog_UserLog_Login_Wrapper
			@UserID			= @UserID,
			@ServerID		= @ServerID,
			@LoginIP		= @LoginIP,
			@DomainName		= @LoginDomain,	
			@ActionID		= 2302,
			@Doing			= @LogData,
			@BrowserName	= @BrowserName,
			@Platform		= @Platform,
			@CountryCode	= @CountryCode,
			@Duration		= @Duration
	END
END
GO