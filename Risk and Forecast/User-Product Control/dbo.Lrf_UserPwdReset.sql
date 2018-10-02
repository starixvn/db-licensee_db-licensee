/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_UserPwdReset]
	@LicenseeID INT	,
	@UserID INT,
	@UpdateBy INT,
	@Pwd VARCHAR(50),
	@UserSalt VARCHAR(50),   
	@Langkey VARCHAR(20) = 'en-US',
	@LoginIP VARCHAR(30)='',
	@ErrCode INT = 0 OUTPUT,  
	@ErrMsg nvarchar(1000) = '' OUTPUT  
AS

/*
	Created by: [20110405@Henry]
	Task: Reset Pwd of a Licensee user
	DB: DBCUST-bodb_Licensee
	Revisions:
	- 20111004@Henry: check only LRF pure users (isInternal=0)
	- 20130413@Jim: support multi language
	- 20180925@Joseph: Migrate to DBCUST [Feature #99855]
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME  
DECLARE @endRun DATETIME  
DECLARE @duration INT  
SET @startRun = GETDATE()  

DECLARE @LicenseeName VARCHAR(50)
SELECT @LicenseeName = LicenseeName FROM Licensees (NOLOCK) WHERE LicenseeID = @LicenseeID



IF NOT EXISTS (SELECT 1 FROM Users (nolock) WHERE  UserID = @UserID AND IsInternal=0)
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This user does not exist!'
								   ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](40002,@Langkey)
        END ,@ErrCode=102 
    RETURN    
END

IF NOT EXISTS (SELECT 1 FROM LicenseeUser (nolock) WHERE LicenseeID = @LicenseeID AND UserID = @UserID)
BEGIN
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This user does not belong to:'  
         ELSE [CustDB].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200026,@Langkey)
        END  + @LicenseeName  ,@ErrCode=103 
    RETURN    
END

UPDATE dbo.Users   with (ROWLOCK,UPDLOCK)
SET 
	UserPwd = @Pwd,   
	UserSalt = @UserSalt  
WHERE 
	UserID = @UserID
	AND IsInternal=0
	IF  @@rowcount <=0
BEGIN
SELECT @ErrCode = 104
	 , @ErrMsg = 'updated failed'
end


DECLARE @LogSPData VARCHAR(5000)  

SELECT @LogSPData ='<Lrf_UserPwdReset custid="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +  
 'LicenseeName="'+ COALESCE(CAST(@LicenseeName as VARCHAR(50)),SPACE(1)) + '" ' +  
 'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(20)),SPACE(1)) + '" ' +  
 'IP="'+ COALESCE(CAST(@LoginIP as VARCHAR(30)),SPACE(1)) + '" ' +  
 'UserID="'+ COALESCE(CAST(@UpdateBy as VARCHAR(50)),SPACE(1)) + '" />'  

SET @endRun = GETDATE()  
SET @duration  = datediff (millisecond,@startRun,@endRun)   
---------------------------  
EXEC dbo.LAP_WriteLog_UserLog_RunSP_Wrapper
 @UserID = @UpdateBy,   
 @CustID = @UserID,  
 @ActionID = 2500,  
 @TrackingValue = @LogSPData,  
 @duration = @duration  

GO





