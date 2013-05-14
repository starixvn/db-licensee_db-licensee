set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER PROCEDURE [dbo].[Lrf_UserUpdAccount]
	@LicenseeID INT	,
	@UserID INT,
	@UpdateBy INT,
	@FirstName VARCHAR(50),
	@LastName VARCHAR(50) = '',
	@Status VARCHAR(30) = 'Open', --Open/Closed
	@PageAccess VARCHAR(500)='',
	@Langkey VARCHAR(20) = 'en-US',
	@LoginIP VARCHAR(30)='',
	@ErrCode INT = 0 OUTPUT,  
	@ErrMsg nvarchar(1000) = '' OUTPUT  
AS

/*
	Created by: [20110405@Henry]
	Task: Update FirstName, LastName, Status (Open/Closed)
	DB: DB052.bodb_Licensee
	Revisions:
	- 20111220@Henry: Stop updating PageAccess
	- 20130413@Jim: support multi language
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME  
DECLARE @endRun DATETIME  
DECLARE @duration INT  
SET @startRun = GETDATE()  

DECLARE @LicenseeName VARCHAR(50)
SELECT @LicenseeName = LicenseeName FROM Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID


IF NOT EXISTS (SELECT 1 FROM Users (nolock) WHERE  UserID = @UserID)
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This user does not exist!'
								   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](40002,@Langkey)
        END ,@ErrCode=102 
    RETURN    
END

IF NOT EXISTS (SELECT 1 FROM LicenseeUser (nolock) WHERE LicenseeID = @LicenseeID AND UserID = @UserID)
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This user does not belong to:' 
								   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200026,@Langkey)
        END  + @LicenseeName  ,@ErrCode=103 
    RETURN    
END

/*
UPDATE LicenseeUser with (rowlock,updlock)
SET 
	PageAccess = @PageAccess,
	ModifyBy = @UpdateBy,
	ModifyDate = GETDATE()
WHERE 
	LicenseeID = @LicenseeID
	AND UserID = @UserID 
*/

UPDATE Users WITH(rowlock,updlock)
SET 
	FirstName = @FirstName,
	LastName = @LastName,
	[Status] = @Status
WHERE 
	UserID = @UserID
	AND IsInternal=0
	IF  @@rowcount <=0
BEGIN
SELECT @ErrCode = 104
	 , @ErrMsg = 'updated failed'
end
DECLARE @LogSPData VARCHAR(5000)  

SELECT @LogSPData ='<Lrf_UserUpdAccount custid="'+ COALESCE(CAST(@userid as VARCHAR(50)),SPACE(1)) + '" ' +  
 'fname="'+ dbo.Lrf_f_EncodeXMLValue(COALESCE(CAST(@FirstName as nvarchar(50)),SPACE(1))) + '" ' +  
 'lname="'+ dbo.Lrf_f_EncodeXMLValue(COALESCE(CAST(@LastName as nvarchar(50)),SPACE(1))) + '" ' +  
 'Status="'+ COALESCE(CAST(@Status as VARCHAR(50)),SPACE(1)) + '" ' +  
 --'PageAccess="'+ COALESCE(CAST(@PageAccess as VARCHAR(500)),SPACE(1)) + '" ' +  
 'LicenseeName="'+ COALESCE(CAST(@LicenseeName as VARCHAR(50)),SPACE(1)) + '" ' +  
 'IP="'+ COALESCE(CAST(@LoginIP as VARCHAR(30)),SPACE(1)) + '" ' +  
 'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(20)),SPACE(1)) + '" ' +  
 'UserID="'+ COALESCE(CAST(@UpdateBy as VARCHAR(50)),SPACE(1)) + '" />'  

SET @endRun = GETDATE()  
SET @duration  = datediff (millisecond,@startRun,@endRun)   
---------------------------  
EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
 @UserID = @UpdateBy,   
 @CustID = @UserID,  
 @ActionID = 2400,  
 @TrackingValue = @LogSPData,  
 @duration = @duration  
  
GO
GRANT EXECUTE ON [dbo].[Lrf_UserUpdAccount] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserUpdAccount] TO [vnteam]



