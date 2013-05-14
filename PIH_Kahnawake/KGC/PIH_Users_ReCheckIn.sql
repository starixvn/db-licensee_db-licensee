ALTER PROCEDURE [dbo].[PIH_Users_ReCheckIn]       
	@On_UserID INT,      
	@IsKickedOut BIT = 0 OUTPUT      
AS      
      
/*  
 * Created by : [20111512@Kos]  
 * Task  : Recheck in user  
 * DB   : WW100_DB.bodb_PIH @ kahnawake 
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @On_UserID : User ID  
 *  - @IsKickedOut : Is kicked out or not (output)  
 */  
  
SET NOCOUNT ON      
      
IF EXISTS (SELECT 1 FROM PIH_OnUser WITH (NOLOCK) WHERE On_UserID = @On_UserID AND isKickedOut = 1)      
BEGIN      
	SELECT @IsKickedOut = 1      
END      
ELSE     
BEGIN      
	 SELECT @IsKickedOut = 0      
   
	 UPDATE PIH_OnUser WITH (ROWLOCK, UPDLOCK)   
	 SET reload_time = GETDATE()       
	 WHERE on_userid = @On_UserID      
	       
	 IF @@ROWCOUNT = 0      
	 SELECT @IsKickedOut = 1      
END  


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_ReCheckIn] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_ReCheckIn] TO [bodbAdminNet] 
