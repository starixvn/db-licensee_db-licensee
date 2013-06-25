set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER PROCEDURE [dbo].[Lrf_SyncInternalUser]
	@LicenseeName VARCHAR (50),
	@Username VARCHAR(50),
	@EncryptedPassword VARCHAR (50),
	@Langkey			VARCHAR(20) = 'en-US',
	@ErrMsg			NVARCHAR(1000)	= '' OUTPUT,
    @ErrCode		INT				= 0 OUTPUT
AS
/*
	Created by: [20110704@Henry]
	Task: Create Licensee User thru Internal site
	DB: DB052.bodb_Licensee
	Param's Explanation:
	@UserRole: value=Licensee/Admin
	
	Revisions:
	- 20111004@Henry: Add IsInternal = 1 when create new user
	- 20111220@Henry: Add default Function to new created user (remove PageAccess)
	- 20120220@Henry: Define New Category "Customer Reports" and Move Customer related reports to it
	- 20120417@Minzy: Define New Category "Admin"
	- 20130625@Jim: set default currency permission for new licensee user
*/

SET NOCOUNT ON
DECLARE @LicenseeID INT
DECLARE @UserID INT
DECLARE @Currency as table (CurrencyID INT)

IF NOT EXISTS (
	SELECT 1 FROM Licensees WITH(NOLOCK) WHERE LicenseeName = @LicenseeName
)
BEGIN
	SET @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'The Licensee: ' + @LicenseeName + ' does not exist!'
								ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200021,@Langkey)
								END	
	SET @ErrCode = 101
	RETURN
END
ELSE
BEGIN
	SELECT @LicenseeID = LicenseeID 
	FROM Licensees WITH (NOLOCK)
	WHERE LicenseeName = @LicenseeName

	INSERT INTO @Currency 
	SELECT DISTINCT  Currency as CurrencyID
	FROM dbo.LicenseeCust with (NOLOCK)
	WHERE LicenseeID=@LicenseeID
		
END


--insert new users if not exist
IF EXISTS(SELECT 1 FROM users WITH(NOLOCK) WHERE Username = @Username AND LicenseeName = @LicenseeName AND IsInternal=1)
BEGIN
	SELECT @UserID = UserID FROM Users (NOLOCK) WHERE Username = @Username AND LicenseeName = @LicenseeName  AND IsInternal=1
	
	--Update the password if exist
	UPDATE Users WITH (ROWLOCK,UPDLOCK) SET UserPwd = @EncryptedPassword
	WHERE UserID = @UserID
END
ELSE
BEGIN
	INSERT INTO Users (Username, UserPwd, UserSalt, UserRole, FirstName,LastName, Status,CreateDate,LicenseeName,IsInternal)
	VALUES (@Username,@EncryptedPassword,'', 'Licensee',@Username, '', 'Open',GETDATE(),@LicenseeName,1)	
	
	SELECT @UserID = @@IDENTITY
END

--insert new licenseeuser
--By default, PageAccess will be granted: TotalBets,Forecast,Reports,ManageMember,DataWarehouse

IF NOT EXISTS(SELECT 1 FROM LicenseeUser (nolock) WHERE LicenseeID = @LicenseeID AND UserID = @UserID)
BEGIN
	/*
	INSERT INTO LicenseeUser (LicenseeID, UserID, isActive,ModifyDate,PageAccess)
	VALUES (@LicenseeID, @UserID, 1,GETDATE(),'TotalBets,Forecast,Reports,ManageMember,DataWarehouse')
	*/
	INSERT INTO LicenseeUser (LicenseeID, UserID, isActive,ModifyDate,PageAccess)
	VALUES (@LicenseeID, @UserID, 1,GETDATE(),'')
	
	-- Currency User
	INSERT INTO dbo.CurrencyUser (usrID,LicenseeID,CurrencyID,SystemID,isActive)
	select @UserID,@LicenseeID,CurrencyID,1,1 -- systemID=1 is default from Lrf
	from @currency
	--Total bets
	INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
	SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND f.FunctionId = 1 OR f.ParentId = 1
		
	--forecast
	INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
	SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
	FROM [Functions] f WITH(NOLOCK)
		INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
	WHERE l.LicenseeId =@LicenseeId			
	AND f.FunctionId = 2 OR f.ParentId = 2	
	
	--Reports
	INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
	SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
	FROM [Functions] f WITH(NOLOCK)
		INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
	WHERE l.LicenseeId =@LicenseeId			
	AND f.FunctionId = 3 OR f.ParentId = 3
	
	--ManageMember
	INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
	SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
	FROM [Functions] f WITH(NOLOCK)
		INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
	WHERE l.LicenseeId =@LicenseeId			
	AND f.FunctionId = 4 OR f.ParentId = 4
	
	--DataWarehouse
	INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
	SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
	FROM [Functions] f WITH(NOLOCK)
		INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
	WHERE l.LicenseeId =@LicenseeId			
	AND f.FunctionId = 5 OR f.ParentId = 5
	
	--Customer Reports
	INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
	SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
	FROM [Functions] f WITH(NOLOCK)
		INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
	WHERE l.LicenseeId =@LicenseeId			
	AND f.FunctionId = 52 OR f.ParentId = 52

	IF (@Username = 'Administrator') OR (@Username = 'Admin') 
	BEGIN	
		-- Manage Account
		INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
		SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId 
		FROM [Functions] f WITH(NOLOCK)
			INNER JOIN [LicenseeFunctions] l WITH(NOLOCK) ON f.FunctionId = l.FunctionId
		WHERE l.LicenseeId =@LicenseeId			
		AND f.FunctionId = 6 OR f.ParentId = 6
	END
	
END
GO
GRANT EXECUTE ON [dbo].[Lrf_SyncInternalUser] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SyncInternalUser] TO [vnteam]  

