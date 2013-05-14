ALTER PROCEDURE [dbo].[Lbs_UserLogin]
	@UserName VARCHAR(50),
	@UserPwd VARCHAR(50),	
	@LoginIP VARCHAR(20), 	
	@Language VARCHAR(20) = 'en-us',
	@ServerID INT = 0 OUTPUT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
	
AS
/*
 *	Created: 20101208@Henry
 *	Task : User Login into LBS system
 *	DB: DB052.bodb_Licensee
 *
 *	Revisions:			
	- 20110505: Shorten the Log content	AND change the action ID
*/
SET NOCOUNT ON

DECLARE @Begin		DATETIME
DECLARE @END		DATETIME
DECLARE @Duration	INT

SET @Begin = GETDATE()

DECLARE @UserID INT
DECLARE @FirstName nvarchar(50)
DECLARE @LastName nvarchar(50)
DECLARE @UserRole VARCHAR(50)
DECLARE @Email VARCHAR(50)
DECLARE @Status VARCHAR(30)
DECLARE @LogData nvarchar(500)

SELECT @UserID=UserID,@UserRole=UserRole, @FirstName=FirstName,@LastName= LastName, @Email= Email, @Status=Status
from Users with (nolock)
WHERE 
	Username = @UserName AND 
	UserPwd = @UserPwd AND
	UserRole = 'Admin'


IF isnull(@UserID,0)=0
BEGIN
	SELECT @ErrMsg = CASE @Language WHEN 'en-us' THEN 'Wrong username or password.'  
         WHEN 'zh-cn' THEN N'Wrong username or password.'  
         WHEN 'zh-tw' THEN N'Wrong username or password.'  
         WHEN 'ja' THEN N'Wrong username or password.'  
         WHEN 'TH' THEN N'Wrong username or password.'  
         WHEN 'KO' THEN N'Wrong username or password.'  
         ELSE N'Wrong username or password.'  
        END ,@ErrCode=101     
         SET @LogData = 'Admin: ' + @UserName + ' - ' + 'Failed(User_Not_Found)'   
END

ELSE IF (@Status <> 'Open')
BEGIN
	SELECT @ErrMsg = CASE @Language WHEN 'en-us' THEN 'This admin is not active.'  
         WHEN 'zh-cn' THEN N'This admin is not active.'  
         WHEN 'zh-tw' THEN N'This admin is not active.'  
         WHEN 'Ja' THEN N'This admin is not active.'  
         WHEN 'TH' THEN N'This admin is not active.'  
         WHEN 'KO' THEN N'This admin is not active.'  
         ELSE N'This admin is not active.'  
        END ,@ErrCode=102     
        SET @LogData = 'Admin: ' + @UserName + ' - ' + 'Failed(User_Not_Active)'
END
ELSE
BEGIN
	SELECT @UserID as UserID,@Username as Username,@UserRole as UserRole, @FirstName as FirstName,@LastName LastName, @Email as Email, @Status as Status
	SET @LogData = 'Admin: ' + @UserName +  ' - ' + 'Success'
END

SET @END = GETDATE()
SET @Duration = DATEDIFF(millisecond,@Begin,@END)

SET @UserID = isnull(@UserID,0)
SET @ServerID = 201

EXEC dbo.WriteLog_UserLog_Login
		 @UserID = @UserID,
		 @ServerID = @ServerID,
		 @LoginIP = @LoginIP,
		 @DomainName = '',	
		 @ActionID = 2300,
		 @Doing = @LogData,
		 @BrowserName = '',
		 @Platform = '',
		 @CountryCode = '',
		 @Duration = @Duration


GO
GRANT EXECUTE ON [dbo].[Lbs_UserLogin] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lbs_UserLogin] TO [vnteam]