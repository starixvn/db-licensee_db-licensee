ALTER PROCEDURE [dbo].[PIH_Users_ResetPassword]  
	@AdminID INT,   
	@UserID  INT,   
	@Pwd  VARCHAR(50),  
	@UserSalt VARCHAR(50),     
	@Language VARCHAR(20)  = 'en-us',  
	@LoginIP VARCHAR(30)  = '',  
	@ErrCode INT    = 0   OUTPUT,    
	@ErrMsg  NVARCHAR(1000) = ''  OUTPUT    
AS  
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : Reset user password  
 * DB   : WW100_DB.bodb_PIH @ kahnawake 
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @AdminID : Admin ID (for write log)  
 *  - @UserID : User ID  
 *  - @Pwd  : Password  
 *  - @UserSalt : User salt  
 *  - @Language : Language  
 *  - @LoginIP : Login IP address  
 *  - @ErrCode : Error code (output)  
 *  - @ErrMsg : Error message (output)  
 */  
  
SET NOCOUNT ON  
  
  
-- check if user exists  
IF NOT EXISTS (SELECT 1 FROM PIH_Users (NOLOCK) WHERE UserID = @UserID)  
BEGIN  
	 SELECT   
	  @ErrMsg = CASE @Language   
	   WHEN 'en-us' THEN 'This user does not exist!'  
	   WHEN 'zh-cn' THEN 'This user does not exist!'  
	   WHEN 'zh-tw' THEN 'This user does not exist!'  
	   WHEN 'Ja' THEN 'This user does not exist!'  
	   WHEN 'TH' THEN 'This user does not exist!'  
	   WHEN 'KO' THEN 'This user does not exist!'  
	   ELSE 'This user does not exist!'  
	   END,  
	  @ErrCode = 102   
		RETURN      
END  
  
-- update password   
UPDATE dbo.PIH_Users WITH (ROWLOCK,UPDLOCK)  
SET   
 UserPwd = @Pwd,     
 UserSalt = @UserSalt    
WHERE   
 UserID = @UserID  
   
IF @@Error > 0  
BEGIN  
 SELECT   
  @ErrCode = 1,   
  @ErrMsg = 'Fail to reset password'  
 RETURN  
END


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_ResetPassword] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_ResetPassword] TO [bodbAdminNet] 
