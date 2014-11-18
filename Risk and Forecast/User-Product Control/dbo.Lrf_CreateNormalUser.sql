CREATE  PROCEDURE [dbo].[Lrf_CreateNormalUser]
	@LicenseeID INT,
	@Username VARCHAR(50),
	@UserPwd VARCHAR (50),
	@UserSalt VARCHAR(50),
	@FirstName nvarchar(50),
	@LastName nvarchar(50) = '',
	@Email VARCHAR(50) = null,
	@Status VARCHAR(30) = 'Open',
	@UserID INT=0 OUTPUT, 
	@Creator INT,
	@IP VARCHAR(50) = '',
	@Langkey VARCHAR(10)='en-US',
	@ErrMsg			NVARCHAR(200)	= '' OUTPUT,
    @ErrCode		INT				= 0 OUTPUT
AS
/*
	Created by: [20110127@Henry]
	Task: Create Licensee User
	DB: DBLIC/bodb_Licensee
	Param's Explanation:
	
	
	Revisions:
	- 20111004@Henry: check only LRF pure users (isInternal=0)
	- 20130405@Jim: support multiple language
	- 20130625@Jim: set default currency permission for new licensee's user
	- 20141118@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME  
DECLARE @endRun DATETIME  
DECLARE @duration INT  
DECLARE @Currency as table (CurrencyID INT)

SET @startRun = GETDATE()  

DECLARE @LicenseeName VARCHAR(50)

SELECT @LicenseeName = LicenseeName from licensees (nolock) WHERE LicenseeID = @LicenseeID


--insert new users
if exists(SELECT 1 from users (nolock) WHERE Username = @Username AND IsInternal = 0)
begin
	SELECT @UserID = UserID from users (nolock) WHERE Username = @Username AND IsInternal = 0
	
	SELECT @ErrMsg = CASE @Langkey 
				       WHEN 'en-US' THEN 'The username ' + @Username  + ' has already created. Please choose another username !'
					   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](40001,@Langkey)
					   END, @ErrCode = 101
	RETURN
END
ELSE
begin
	insert into Users (Username, UserPwd, UserSalt, UserRole, FirstName,LastName, Email, Status,Creator,CreateDate,IsInternal)
	values (@Username,@UserPwd,@UserSalt, 'Licensee', @FirstName, @LastName, @Email, @Status,@Creator,GETDATE(),0)
	
	SET @UserID = @@identity
END

--insert new licenseeuser
if not exists(SELECT 1 from LicenseeUser (nolock) WHERE LicenseeID = @LicenseeID AND UserID = @UserID)
begin
	
	insert into LicenseeUser (LicenseeID, UserID, isActive,ModifyBy,ModifyDate)
	values (@LicenseeID, @UserID, 1,@Creator,GETDATE())
	
	INSERT INTO @Currency 
	SELECT DISTINCT  Currency as CurrencyID
	FROM dbo.f_SelLicenseeCust(@LicenseeID)
	
	INSERT INTO dbo.CurrencyUser (usrID,LicenseeID,CurrencyID,SystemID,isActive)
	select @UserID,@LicenseeID,CurrencyID,1,1 -- systemID=1 is default from Lrf
	from @currency
END


DECLARE @LogSPData VARCHAR(5000)  

SELECT @LogSPData ='<Lrf_CreateNormalUser custid="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +  
 'LicenseeName="'+ COALESCE(CAST(@LicenseeName as VARCHAR(50)),SPACE(1)) + '" ' +  
 'Username="'+ COALESCE(CAST(@Username as VARCHAR(50)),SPACE(1)) + '" ' +  
 'FirstName="'+ COALESCE(CAST(@FirstName as NVARCHAR(50)),SPACE(1)) + '" ' +  
 'LastName="'+ COALESCE(CAST(@LastName as NVARCHAR(50)),SPACE(1)) + '" ' +  
 'Email="'+ COALESCE(CAST(@Email as VARCHAR(50)),SPACE(1)) + '" ' +  
 'Status="'+ COALESCE(CAST(@Status as VARCHAR(50)),SPACE(1)) + '" ' +  
 'IP="'+ COALESCE(CAST(@IP as VARCHAR(50)),SPACE(1)) + '" ' +  
 'UserID="'+ COALESCE(CAST(@Creator as VARCHAR(50)),SPACE(1)) + '" />'  

SET @endRun = GETDATE()  
SET @duration  = datediff (millisecond,@startRun,@endRun)   
---------------------------  
EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
 @UserID = @Creator,   
 @CustID = @UserID,  
 @ActionID = 2406,  
 @TrackingValue = @LogSPData,  
 @duration = @duration  


GO
GRANT EXECUTE ON [dbo].[Lrf_CreateNormalUser] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CreateNormalUser] TO [vnteam] 