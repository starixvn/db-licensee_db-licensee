/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb_licensee]
GO

ALTER PROCEDURE [dbo].[Lrf_SyncInternalUser]
	@LicenseeName		VARCHAR(50),
	@Username			VARCHAR(50),
	@EncryptedPassword	VARCHAR(50),
	@Langkey			VARCHAR(20)		= 'en-US',
	@ErrMsg				NVARCHAR(1000)	= '' OUTPUT,
    @ErrCode			INT				= 0 OUTPUT
AS

/*
	Created by: [20110704@Henry]
	Task: Create Licensee User thru Internal site
	DB: DBCUST-bodb_Licensee
	Param's Explanation:
	@UserRole: value=Licensee/Admin
	
	Revisions:
		- 20111004@Henry: Add IsInternal = 1 when create new user
		- 20111220@Henry: Add default Function to new created user (remove PageAccess)
		- 20120220@Henry: Define New Category "Customer Reports" and Move Customer related reports to it
		- 20120417@Minzy: Define New Category "Admin"
		- 20130625@Jim: set default currency permission for new licensee user
		- 20130725@Jim: restrict permission for DW function 
		- 20141112@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
		- 20160523@Jim: Currency permision restrict (#53882)
		- 20160818@Jim: LRF - Set "Adjust bet settings" with separate authorization [RedmineID : #61999]
		- 20171002@Percy: Write more password into log [RedmineID: #83692]
		- 20180925@Joseph: Migrate to DBCUST [Feature #99855]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Begin		DATETIME
	DECLARE @Duration	INT
	DECLARE @LogData	NVARCHAR(600)

	SET @Begin = GETDATE()
	
	DECLARE @LicenseeID			INT
	DECLARE @UserID				INT
	DECLARE @UserOldPassWord	VARCHAR(50)
	DECLARE @Currency			TABLE (CurrencyID INT)

	SELECT @LicenseeID = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = @LicenseeName

	IF @LicenseeID IS NULL
	BEGIN
		SET @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'The Licensee: ' + @LicenseeName + ' does not exist!'
									ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200021, @Langkey)
									END	
		SET @ErrCode = 101
		
		SELECT @LogData = 'Failed(Licensee_Not_Exist) - LicenseeName: ' + @LicenseeName
	END
	ELSE
	BEGIN
		INSERT INTO @Currency (CurrencyID)
		SELECT DISTINCT Currency AS CurrencyID
		FROM dbo.Lrf_f_SelLicenseeCust (@LicenseeID)	
		WHERE Currency NOT IN (SELECT CurrencyID FROM dbo.Lrf_f_LicenseeCurrencyLimit_Main() WHERE LicenseeID = @LicenseeID)

		-- if user exists --> update new password, if not --> insert new
		SELECT @UserID = UserID, @UserOldPassWord = UserPwd
		FROM dbo.Users WITH (NOLOCK)
		WHERE Username = @Username AND LicenseeName = @LicenseeName AND IsInternal = 1

		IF @UserID IS NOT NULL
		BEGIN
			UPDATE dbo.Users WITH (ROWLOCK, UPDLOCK)
			SET UserPwd = @EncryptedPassword
			WHERE UserID = @UserID

			SELECT @LogData = 'Success(Update_Password) - Old Password: ' + @UserOldPassWord
		END
		ELSE
		BEGIN
			INSERT INTO dbo.Users (Username, UserPwd, UserSalt, UserRole, FirstName, LastName, Status, CreateDate, LicenseeName, IsInternal)
			VALUES (@Username, @EncryptedPassword, '', 'Licensee', @Username, '', 'Open', GETDATE(), @LicenseeName, 1)

			SELECT @UserID = @@IDENTITY

			SELECT @LogData = 'Success(Insert_New_User)'
		END

		-- By default, PageAccess will be granted: TotalBets, Forecast, Reports, ManageMember, DataWarehouse
		IF NOT EXISTS (SELECT 1 FROM LicenseeUser WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND UserID = @UserID)
		BEGIN
			INSERT INTO dbo.LicenseeUser (LicenseeID, UserID, isActive, ModifyDate, PageAccess)
			VALUES (@LicenseeID, @UserID, 1, GETDATE(), '')
	
			-- Currency User
			INSERT INTO dbo.CurrencyUser (usrID, LicenseeID, CurrencyID, SystemID, isActive)
			SELECT @UserID, @LicenseeID, CurrencyID, 1, 1 -- SystemID = 1 is default from LRF
			FROM @Currency

			-- Total bets
			INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
			SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
			FROM dbo.Functions f WITH (NOLOCK)
				INNER JOIN dbo.LicenseeFunctions lf WITH(NOLOCK) ON f.FunctionId = lf.FunctionId
			WHERE lf.LicenseeId = @LicenseeId AND (f.FunctionId = 1 OR f.ParentId = 1)
		
			-- forecast
			INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
			SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
			FROM dbo.Functions f WITH(NOLOCK)
				INNER JOIN dbo.LicenseeFunctions lf WITH(NOLOCK) ON f.FunctionId = lf.FunctionId
			WHERE lf.LicenseeId = @LicenseeId AND (f.FunctionId = 2 OR f.ParentId = 2)
	
			-- Reports
			INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
			SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
			FROM dbo.Functions f WITH(NOLOCK)
				INNER JOIN dbo.LicenseeFunctions lf WITH(NOLOCK) ON f.FunctionId = lf.FunctionId
			WHERE lf.LicenseeId = @LicenseeId AND (f.FunctionId = 3 OR f.ParentId = 3)
	
			-- ManageMember
			INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
			SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
			FROM dbo.Functions f WITH(NOLOCK)
				INNER JOIN dbo.LicenseeFunctions lf WITH(NOLOCK) ON f.FunctionId = lf.FunctionId
			WHERE lf.LicenseeId = @LicenseeId AND (f.FunctionId = 4 OR f.ParentId = 4)
				AND f.functionID NOT IN (SELECT FunctionID FROM dbo.Functions WITH (NOLOCK) WHERE Name = 'Edit Bet Setting')

			-- DataWarehouse
			INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
			SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
			FROM dbo.Functions f WITH(NOLOCK)
				INNER JOIN dbo.LicenseeFunctions lf WITH(NOLOCK) ON f.FunctionId = lf.FunctionId
			WHERE lf.LicenseeId = @LicenseeId AND (f.FunctionId = 5 OR f.ParentId = 5)
	
			-- Customer Reports
			INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
			SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
			FROM dbo.Functions f WITH(NOLOCK)
				INNER JOIN dbo.LicenseeFunctions lf WITH(NOLOCK) ON f.FunctionId = lf.FunctionId
			WHERE lf.LicenseeId = @LicenseeId AND (f.FunctionId = 52 OR f.ParentId = 52)

			SELECT @LogData = @LogData + ' - ' + 'Grant default permission'
	
			IF (@Username = 'Administrator') OR (@Username = 'Admin')
			BEGIN	
				-- Manage Account
				INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
				SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
				FROM dbo.Functions f WITH(NOLOCK)
					INNER JOIN dbo.LicenseeFunctions lf WITH(NOLOCK) ON f.FunctionId = lf.FunctionId
				WHERE lf.LicenseeId = @LicenseeId
					AND (f.FunctionId = 6
						OR f.ParentId = 6
						OR f.functionID IN (SELECT FunctionID FROM dbo.Functions WITH (NOLOCK) WHERE Name = 'Edit Bet Setting')
					)

				SELECT @LogData = @LogData + ' - ' + 'Grant permission on Manage Account Function because the username =''Admin/Administrator'''
			END
		END
	END

	SELECT @UserID = ISNULL(@UserID, 0), @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE())
	SELECT @LogData	= 'User: ' + @UserName +  ' - ' + 'Password: ' + @EncryptedPassword + ' - ' + @LogData

	EXEC dbo.Lrf_WriteLog_UserLog_Login_Wrapper
		@UserID		= @UserID,
		@ServerID	= 200,
		@ActionID	= 2303,
		@Doing		= @LogData,
		@Duration	= @Duration
END
GO