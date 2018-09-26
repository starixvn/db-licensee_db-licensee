/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_UpdateUser]
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
	DB: DBCUST-bodb_Licensee
	Param's Explanation:
	- @LicenseeName: if not blank then update to new licensee if different from current
	- @Username: if not blank then update to new username if different from current
	- @EncryptedPassword: if not blank then update to current password
	
	
	Revisions:
	- 20130625@Jim: set default currency permission for new licensee's user
	- 20141112@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
	- 20180925@Joseph: Migrate to DBCUST [Feature #99855]
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
			SELECT @Cnt = LicenseeID FROM LicenseeUser WITH (NOLOCK) WHERE UserID = @UserID
		
			--Map User to Licensee if not exist
			IF (ISNULL(@Cnt,0) = 0)
			BEGIN
				INSERT INTO LicenseeUser (LicenseeID, UserID, isActive,ModifyDate)
				VALUES (@LicenseeID, @UserID, 1,GETDATE())
				
				INSERT INTO @Currency 
				SELECT DISTINCT  Currency as CurrencyID
				FROM dbo.f_SelLicenseeCust(@LicenseeID)
				
				-- Currency User
				INSERT INTO dbo.CurrencyUser (usrID,LicenseeID,CurrencyID,SystemID,isActive)
				select @UserID,@LicenseeID,CurrencyID,1,1 -- systemID=1 is default from Lrf
				from @currency
			END
			ELSE IF (ISNULL(@Cnt,0) <>0) --Re-map to new Licensee
			BEGIN
				IF NOT EXISTS(SELECT 1 FROM LicenseeUser WITH (NOLOCK) WHERE UserID = @UserID AND LicenseeID = @LicenseeID AND isActive=1 )
				BEGIN
					UPDATE LicenseeUser WITH (ROWLOCK, UPDLOCK)
					SET LicenseeID = @LicenseeID, isActive = 1, ModifyDate = GETDATE()
					WHERE UserID = @UserID	
					
					UPDATE CurrencyUser WITH (ROWLOCK,UPDLOCK)
					SET LicenseeID=@LicenseeID
					WHERE usrID=@UserID 
						AND LicenseeID=@Cnt	
				END
			END
		END
		
		
	END
END

GO