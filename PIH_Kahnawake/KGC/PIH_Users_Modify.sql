ALTER PROCEDURE [dbo].[PIH_Users_Modify]  
	@UserID INT OUTPUT,  
	@Username NVARCHAR(50),  
	@DisplayName NVARCHAR(50),  
	@Role TINYINT,  
	@UserPwd VARCHAR(50) = '',  
	@UserSalt VARCHAR(50) = '',  
	@IsActive BIT,  
	@IsTest BIT,  
	@CreatedDate DATETIME,  
	@ModifiedDate DATETIME,  
	@Creator INT,  
	@Language VARCHAR(20) = 'en-us',  
	@LoginIP VARCHAR(30) = '',  
	@ErrCode INT    = 0 OUTPUT,  
	@ErrMsg NVARCHAR(1000) = '' OUTPUT   
AS  
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : Create or modify a user  
 * DB   : WW100_DB.bodb_PIH @ kahnawake
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @UserID  : User ID (output)  
 *  - @Username  : Username  
 *  - @DisplayName : Display name  
 *  - @Role   : Role (1 : Admin, 2 : User)  
 *  - @UserPwd  : Password  
 *  - @UserSalt  : User salt  
 *  - @IsActive  : Is active or not  
 *  - @IsTest  : Is user a test user 
 *  - @CreatedDate : Created date  
 *  - @ModifiedDate : Modified date  
 *  - @Creator  : Creator user ID  
 *  - @Language  : Language  
 *  - @LoginIP  : Login IP address  
 *  - @ErrCode  : Error code (output)  
 *  - @ErrMsg  : Error message (output)  
 */  
  
SET NOCOUNT ON  
  
-- check if user exists   
IF EXISTS(SELECT 1 FROM dbo.PIH_Users WITH (NOLOCK) WHERE UserID = @UserID)  
	BEGIN  
		 -- check if update password   
		 IF @UserPwd <> '' AND @UserSalt <> ''  
		 BEGIN  
			  UPDATE dbo.PIH_Users WITH (UPDLOCK, ROWLOCK)  
			  SET  
			   Username = @Username,  
			   DisplayName = @DisplayName,  
			   Role = @Role,  
			   IsActive = @IsActive,    
			   IsTest = @IsTest,
			   ModifiedDate = @ModifiedDate,  
			   UserPwd = @UserPwd,  
			   UserSalt = @UserSalt  
			  WHERE  
			   UserID = @UserID  
		 END  
		 ELSE  
		 BEGIN  
			  UPDATE dbo.PIH_Users WITH (UPDLOCK, ROWLOCK)  
			  SET  
			   UserName = @UserName,  
			   DisplayName = @DisplayName,  
			   Role = @Role,  
			   IsActive = @IsActive,
			   IsTest = @IsTest,
			   ModifiedDate = @ModifiedDate   
			  WHERE  
			   UserID = @UserID  
		 END   
		    
		 IF @@Error > 0  
		 BEGIN  
			  SELECT   
			   @ErrCode = 100,   
			   @ErrMsg = 'Fail to update information of the UserID ' + CONVERT(VARCHAR(10), @UserID)  
			  RETURN  
		 END  
	END  
ELSE  
	BEGIN  
		 -- check if password and salt are valid  
		 IF @UserPwd = '' OR @UserSalt = ''  
		 BEGIN  
			  SELECT   
			   @ErrCode = 101,   
			   @ErrMsg = 'Password or Password Salt could not be left blank!'  
			  RETURN  
		 END  
		 ELSE  
		 BEGIN  
			  INSERT INTO dbo.PIH_Users   
			  (    
			   Username,  
			   UserPwd,  
			   DisplayName,  
			   Role,  
			   UserSalt,  
			   IsActive,  
			   IsTest,  
			   Creator,  
			   CreatedDate,  
			   ModifiedDate    
			  )   
			  VALUES   
			  (    
			   @Username,  
			   @UserPwd,  
			   @DisplayName,  
			   @Role,  
			   @UserSalt,  
			   @IsActive,  
			   @IsTest,  
			   @Creator,  
			   @CreatedDate,  
			   @ModifiedDate  
				)  
		 END  
		   
		 SET @UserID = SCOPE_IDENTITY()  
		   
		 IF @@Error > 0  
		 BEGIN  
			  SELECT   
			   @ErrCode = 102,   
			   @ErrMsg = 'Fail to insert information of the UserID ' + CONVERT(VARCHAR(10), @UserID)  
			  RETURN  
		 END  
	END    


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_Modify] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_Modify] TO [bodbAdminNet] 
