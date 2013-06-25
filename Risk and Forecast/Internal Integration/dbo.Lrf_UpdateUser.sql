CREATE  PROCEDURE [dbo].[Lrf_UpdateUser]
	@UserID INT,
	@LicenseeName VARCHAR (50) = '',
	@Username VARCHAR(50)='',
	@EncryptedPassword  VARCHAR (50) = '',
	@ErrMsg			NVARCHAR(1000)	= '' OUTPUT,
    @ErrCode		INT				= 0 OUTPUT
AS
/*
	Created by: [20110704@Henry]
	Task: Update Licensee User thru Internal site
	DB: DB052.bodb_Licensee
	Param's Explanation:
	- @LicenseeName: if not blank then update to new licensee if different from current
	- @Username: if not blank then update to new username if different from current
	- @EncryptedPassword: if not blank then update to current password
	
	
	Revisions:
	- 20130625@Jim: set default currency permission for new licensee's user
*/

SET NOCOUNT ON
DECLARE @LicenseeID INT
DECLARE @Old_Username VARCHAR (50)
DECLARE @UserRole VARCHAR (50)
DECLARE @Cnt INT
DECLARE @Currency as table (CurrencyID INT)

SET @Username = RTRIM(LTRIM(@Username))
SET @LicenseeName = RTRIM(LTRIM(@LicenseeName))

--check UserID
IF NOT EXISTS (SELECT 1 FROM users WITH(NOLOCK) WHERE UserID = @UserID)
BEGIN
	SET @ErrMsg = 'The UserID ' + @UserID  + ' does not exist ! '
	SET @ErrCode = 101
	RETURN
END

--Update Username if is not blank
IF (@Username <> '') 
BEGIN 
	SELECT @Old_Username = Username 
	FROM Users WITH (NOLOCK)
	WHERE UserID = @UserID

	IF @Old_Username <> @Username
	BEGIN
		--Check exist username
		IF NOT EXISTS (SELECT TOP 1 1 FROM users WITH(NOLOCK) WHERE Username = @Username)
		BEGIN
			UPDATE Users WITH (ROWLOCK,UPDLOCK)
			SET Username = @Username
			WHERE UserID = @UserID	
		END
		
	END
END

--Update Password if not blank
IF (@EncryptedPassword <> '')
BEGIN
	UPDATE Users WITH (ROWLOCK,UPDLOCK)
	SET UserPwd = @EncryptedPassword
	WHERE UserID = @UserID	
END


-- Map User to Licensee if not blank
IF (@LicenseeName <> '')
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM Licensees WITH(NOLOCK) WHERE LicenseeName = @LicenseeName
	)
	BEGIN
		SET @ErrMsg = 'The Licensee: ' + @LicenseeName + ' does not exist!'
		SET @ErrCode = 102
		RETURN
	END
	ELSE
	BEGIN
		SELECT @UserRole = UserRole FROM Users WITH(NOLOCK)
		WHERE UserID = @UserID
	
		SELECT @LicenseeID = LicenseeID 
		FROM Licensees WITH (NOLOCK)
		WHERE LicenseeName = @LicenseeName
		
		IF @UserRole = 'Licensee'
		BEGIN
			SELECT @Cnt = COUNT(LicenseeID) FROM LicenseeUser WITH (NOLOCK) WHERE UserID = @UserID
			--Map User to Licensee if not exist
			IF (@Cnt = 0)
			BEGIN
				INSERT INTO LicenseeUser (LicenseeID, UserID, isActive,ModifyDate)
				VALUES (@LicenseeID, @UserID, 1,GETDATE())
				
				INSERT INTO @Currency 
				SELECT DISTINCT  Currency as CurrencyID
				FROM dbo.LicenseeCust with (NOLOCK)
				WHERE LicenseeID=@LicenseeID
				
				-- Currency User
				INSERT INTO dbo.CurrencyUser (usrID,LicenseeID,CurrencyID,SystemID,isActive)
				select @UserID,@LicenseeID,CurrencyID,1,1 -- systemID=1 is default from Lrf
				from @currency
			END
			ELSE IF (@Cnt = 1) --Re-map to new Licensee
			BEGIN
				IF NOT EXISTS(SELECT 1 FROM LicenseeUser WITH (NOLOCK) WHERE UserID = @UserID AND LicenseeID = @LicenseeID AND isActive=1 )
				BEGIN
					UPDATE LicenseeUser WITH (ROWLOCK, UPDLOCK)
					SET LicenseeID = @LicenseeID, isActive = 1, ModifyDate = GETDATE()
					WHERE UserID = @UserID	
				END
			END
		END
		
		
	END
END





GO
--wait for confirming with TW team
--GRANT EXECUTE ON [dbo].[Lrf_CreateUser] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UpdateUser] TO [vnteam]  