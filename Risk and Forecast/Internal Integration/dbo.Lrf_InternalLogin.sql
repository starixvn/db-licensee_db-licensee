USE [bodb_licensee]
GO

ALTER  PROCEDURE [dbo].[LRF_InternalLogin]
	@LicenseeName VARCHAR (50),
	@Username VARCHAR(50),
	@EncryptedPassword VARCHAR (50),
	@LoginTime DATETIME,
	@LoginIP VARCHAR(50),
	@ServerID INT = 0 OUTPUT,	
	@LoginDomain NVARCHAR(253) = NULL,
	@BrowserName NVARCHAR(255) = NULL,
	@Platform NVARCHAR(255) = NULL,  
	@CountryCode VARCHAR(64) = NULL,  	
	@Language VARCHAR(20) = 'en-us',
	@ErrMsg			NVARCHAR(1000)	= '' OUTPUT,
    @ErrCode		INT				= 0 OUTPUT	
AS
/*
	Created by: [20110704@Henry]
	Task: Login to LRF thru Internal site
	DB: DB052.bodb_Licensee
	Param's Explanation:
	
	
	Revisions:
	- 20111004@Henry: check only Internal user (IsInternal = 1)
	- 20120724@HEnry: return 1 more column: IsAllowedMemberComm
	- 20141217@Jim: correct error code 
*/

SET NOCOUNT ON



DECLARE @Begin		DATETIME
DECLARE @END		DATETIME
DECLARE @Duration	INT

SET @Begin = GETDATE()

DECLARE @UserID INT
DECLARE @FirstName NVARCHAR(50)
DECLARE @LastName NVARCHAR(50)
DECLARE @UserRole VARCHAR(50)
DECLARE @Email VARCHAR(50)
DECLARE @Status VARCHAR(30)
DECLARE @LogData NVARCHAR(500)

IF (DATEDIFF (second,@LoginTime,getdate()))>30
BEGIN
	SELECT @ErrMsg = CASE @Language WHEN 'en-us' THEN 'The link has been expired!'  
         WHEN 'zh-cn' THEN N'The link has been expired!' 
         WHEN 'zh-tw' THEN N'The link has been expired!' 
         WHEN 'Ja' THEN N'The link has been expired!'  
         WHEN 'TH' THEN N'The link has been expired!' 
         WHEN 'KO' THEN N'The link has been expired!'   
         ELSE N'The link has been expired!'  
        END ,@ErrCode=100     
    SET @LogData = 'User: ' + @UserName +  ' - ' + 'Failed(User_Not_Found)' 
	
	SET @UserID = ISNULL(@UserID,0)
	SET @ServerID = 200
	SET @END = GETDATE()
	SET @Duration = DATEDIFF(millisecond,@Begin,@END)

	EXEC WriteLog_UserLog_Login
			 @UserID = @UserID,
			 @ServerID = @ServerID,
			 @LoginIP = @LoginIP,
			 @DomainName = @LoginDomain,	
			 @ActionID = 2301,
			 @Doing = @LogData,
			 @BrowserName = @BrowserName,
			 @Platform = @Platform,
			 @CountryCode = @CountryCode,
			 @Duration = @Duration
		 
    RETURN;
    
END

SELECT 
	@UserID=UserID,@UserRole=UserRole, @FirstName=FirstName,@LastName= LastName, @Email= Email, @Status=Status
FROM 
	Users WITH (NOLOCK)
WHERE 
	Username = @UserName AND 
	LicenseeName = @LicenseeName AND
	UserPwd = @EncryptedPassword AND
	IsInternal = 1

IF (@UserID IS NULL)
BEGIN
	SELECT @ErrMsg = CASE @Language WHEN 'en-us' THEN 'Wrong username or password.'  
         WHEN 'zh-cn' THEN N'Wrong username or password.'  
         WHEN 'zh-tw' THEN N'Wrong username or password.'  
         WHEN 'Ja' THEN N'Wrong username or password.'  
         WHEN 'TH' THEN N'Wrong username or password.'  
         WHEN 'KO' THEN N'Wrong username or password.'  
         ELSE N'Wrong username or password.'  
        END ,@ErrCode=101     
    SET @LogData = 'User: ' + @UserName +  ' - ' + 'Failed(User_Not_Found)'  
	
	SET @UserID = ISNULL(@UserID,0)
	SET @ServerID = 200
	SET @END = GETDATE()
	SET @Duration = DATEDIFF(millisecond,@Begin,@END)

	EXEC WriteLog_UserLog_Login
			 @UserID = @UserID,
			 @ServerID = @ServerID,
			 @LoginIP = @LoginIP,
			 @DomainName = @LoginDomain,	
			 @ActionID = 2301,
			 @Doing = @LogData,
			 @BrowserName = @BrowserName,
			 @Platform = @Platform,
			 @CountryCode = @CountryCode,
			 @Duration = @Duration
			 
    RETURN;
END
ELSE IF (@Status <> 'Open')
BEGIN
	SELECT @ErrMsg = CASE @Language WHEN 'en-us' THEN 'This user is not active.'  
         WHEN 'zh-cn' THEN N'This user is not active.'  
         WHEN 'zh-tw' THEN N'This user is not active.'  
         WHEN 'Ja' THEN N'This user is not active.'  
         WHEN 'TH' THEN N'This user is not active.'  
         WHEN 'KO' THEN N'This user is not active.'  
         ELSE N'This user is not active.'  
        END ,@ErrCode=102     
    SET @LogData = 'User: ' + @UserName + ' - ' + 'Failed(User_Not_Active)' 
	
	SET @UserID = ISNULL(@UserID,0)
	SET @ServerID = 200
	SET @END = GETDATE()
	SET @Duration = DATEDIFF(millisecond,@Begin,@END)

	EXEC WriteLog_UserLog_Login
			 @UserID = @UserID,
			 @ServerID = @ServerID,
			 @LoginIP = @LoginIP,
			 @DomainName = @LoginDomain,	
			 @ActionID = 2301,
			 @Doing = @LogData,
			 @BrowserName = @BrowserName,
			 @Platform = @Platform,
			 @CountryCode = @CountryCode,
			 @Duration = @Duration
			 
    RETURN; 
END
ELSE
BEGIN
	DECLARE @LicenseeID INT
	DECLARE @RowCnt INT
	DECLARE @EnableBA BIT
	DECLARE @IsAllowedMemberComm BIT
	IF @UserRole = 'Licensee'
	BEGIN
	
		SELECT @RowCnt=COUNT(*) FROM LicenseeUser WITH (NOLOCK)
		WHERE UserID = @UserID
		IF (@RowCnt>1)
		BEGIN
			SELECT @ErrMsg = CASE @Language WHEN 'en-us' THEN 'This user has too many licensees.'  
			 WHEN 'zh-cn' THEN N'This user has too many licensees.'  
			 WHEN 'zh-tw' THEN N'This user has too many licensees.' 
			 WHEN 'Ja' THEN N'This user has too many licensees.' 
			 WHEN 'TH' THEN N'This user has too many licensees.' 
			 WHEN 'KO' THEN N'This user has too many licensees.' 
			 ELSE N'This user has too many licensees.' 
			END ,@ErrCode=103   
			SET @LogData = 'User: ' + @UserName +  ' - ' + 'Failed(User_Too_Many_Licensees)'
			
			SET @UserID = ISNULL(@UserID,0)
			SET @ServerID = 200
			SET @END = GETDATE()
			SET @Duration = DATEDIFF(millisecond,@Begin,@END)

			EXEC WriteLog_UserLog_Login
					 @UserID = @UserID,
					 @ServerID = @ServerID,
					 @LoginIP = @LoginIP,
					 @DomainName = @LoginDomain,	
					 @ActionID = 2301,
					 @Doing = @LogData,
					 @BrowserName = @BrowserName,
					 @Platform = @Platform,
					 @CountryCode = @CountryCode,
					 @Duration = @Duration
					 
			RETURN; 
	
		END	
		ELSE
		BEGIN
			SELECT @LicenseeID = LicenseeID FROM LicenseeUser WITH (NOLOCK)
			WHERE UserID = @UserID
			
			IF (@LicenseeID IS NULL)
			BEGIN
					SELECT @ErrMsg = CASE @Language WHEN 'en-us' THEN 'This user has no licensee.'  
					 WHEN 'zh-cn' THEN N'This user has no licensee.'
					 WHEN 'zh-tw' THEN N'This user has no licensee.'
					 WHEN 'Ja' THEN N'This user has no licensee.'
					 WHEN 'TH' THEN N'This user has no licensee.'
					 WHEN 'KO' THEN N'This user has no licensee.'
					 ELSE N'This user has no licensee.'
					END ,@ErrCode=104   
					SET @LogData = 'User: ' + @UserName + ' - ' + 'Failed(User_Not_Found_Licensee)'
					
					SET @UserID = ISNULL(@UserID,0)
					SET @ServerID = 200
					SET @END = GETDATE()
					SET @Duration = DATEDIFF(millisecond,@Begin,@END)

					EXEC WriteLog_UserLog_Login
							 @UserID = @UserID,
							 @ServerID = @ServerID,
							 @LoginIP = @LoginIP,
							 @DomainName = @LoginDomain,	
							 @ActionID = 2301,
							 @Doing = @LogData,
							 @BrowserName = @BrowserName,
							 @Platform = @Platform,
							 @CountryCode = @CountryCode,
							 @Duration = @Duration
					 
					RETURN; 	     
			END
			ELSE
			BEGIN
				SELECT @EnableBA = EnableBA FROM LicenseeBAConfig (NOLOCK) WHERE LicenseeID = @LicenseeID
				SELECT @IsAllowedMemberComm = IsAllowedMemberComm FROM Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID

				SELECT @UserID AS UserID,@Username AS Username,@UserRole AS UserRole, @FirstName AS FirstName,@LastName LastName, @Email AS Email, @Status AS Status, @LicenseeID AS LicenseeID, ISNULL(@EnableBA,0) EnableBA, isnull(@IsAllowedMemberComm,0) IsAllowedMemberComm, 1 AS IsInternal
				SET @LogData = 'User: ' + @username +  ' - ' + 'Success'
			END	
		END
	END
END

SET @UserID = ISNULL(@UserID,0)
SET @ServerID = 200

SET @END = GETDATE()
SET @Duration = DATEDIFF(millisecond,@Begin,@END)

EXEC WriteLog_UserLog_Login
		 @UserID = @UserID,
		 @ServerID = @ServerID,
		 @LoginIP = @LoginIP,
		 @DomainName = @LoginDomain,	
		 @ActionID = 2301,
		 @Doing = @LogData,
		 @BrowserName = @BrowserName,
		 @Platform = @Platform,
		 @CountryCode = @CountryCode,
		 @Duration = @Duration



GO
GRANT EXECUTE ON [Lrf_InternalLogin] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_InternalLogin] TO [vnteam]  

