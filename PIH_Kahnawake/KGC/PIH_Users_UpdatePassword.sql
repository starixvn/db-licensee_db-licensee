ALTER PROCEDURE [dbo].[PIH_Users_UpdatePassword]    
	@AdminID INT,  
	@UserID  INT,   
	@OldPwd  VARCHAR(50),     
	@NewPwd  VARCHAR(50),     
	@UserSalt VARCHAR(50),     
	@Language VARCHAR(20)  = 'en-US',    
	@LoginIP VARCHAR(20),    
	@ErrCode INT    = 0   OUTPUT,    
	@ErrMsg  NVARCHAR(4000) = ''  OUTPUT      
AS    
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : update user password  
 * DB   : WW100_DB.bodb_PIH @ kahnawake
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @AdminID : Admin ID (for write log)  
 *  - @UserID : User ID  
 *  - @OldPwd : Old password  
 *  - @NewPwd : New password  
 *  - @UserSalt : User salt  
 *  - @Language : Language  
 *  - @LoginIP : Login IP address  
 *  - @ErrCode : Error code (output)  
 *  - @ErrMsg : Error message (output)  
 */  
  
BEGIN    
  
 SET NOCOUNT ON;    
  
 /* check if old password is valid */  
 IF EXISTS(SELECT 1 FROM dbo.PIH_Users WITH (NOLOCK) WHERE UserID = @UserID AND UserPwd <> @OldPwd)  
 BEGIN  
	  SELECT   
	   @ErrMsg =   
		CASE @Language   
		 WHEN 'en-us' THEN 'Wrong password.'    
		 WHEN 'zh-cn' THEN N'Wrong password.'    
		 WHEN 'zh-tw' THEN N'Wrong password.'    
		 WHEN 'ja' THEN N'Wrong password.'    
		 WHEN 'TH' THEN N'Wrong password.'    
		 WHEN 'KO' THEN N'Wrong password.'    
		 ELSE N'Wrong password.'    
		END,   
	   @ErrCode = 101      
	  RETURN   
 END  
  
 /* check if user is active */  
 IF EXISTS(SELECT 1 FROM dbo.PIH_Users WITH (NOLOCK) WHERE UserID = @UserID and IsActive = 0)  
 BEGIN  
	  SELECT   
	   @ErrMsg =   
		CASE @Language   
		 WHEN 'en-us' THEN 'This user is not active.'    
		 WHEN 'zh-cn' THEN N'This user is not active.'    
		 WHEN 'zh-tw' THEN N'This user is not active.'    
		 WHEN 'ja' THEN N'This user is not active.'    
		 WHEN 'TH' THEN N'This user is not active.'    
		 WHEN 'KO' THEN N'This user is not active.'    
		 ELSE N'This user is not active.'    
		END,  
	   @ErrCode = 102  
	  RETURN   
 END  
   
 /* update password */     
 UPDATE dbo.PIH_Users WITH(UPDLOCK,ROWLOCK)  
 SET   
  UserPwd = @NewPwd,     
  UserSalt = @UserSalt    
 WHERE UserID = @UserID  
     
 IF (@@ERROR > 0)    
 BEGIN  
	  SELECT   
	   @ErrCode = 100,   
	   @ErrMsg = 'Cannot change password'    
	  RETURN  
 END  
 
 SET NOCOUNT OFF  
  
END


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_UpdatePassword] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_UpdatePassword] TO [bodbAdminNet] 
