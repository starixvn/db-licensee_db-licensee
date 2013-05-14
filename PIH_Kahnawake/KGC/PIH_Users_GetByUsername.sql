ALTER PROCEDURE [dbo].[PIH_Users_GetByUsername]   
	@Username VARCHAR(50)  
AS  
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : Get user information by username  
 * DB   : WW100_DB.bodb_PIH @ kahnawake
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @Username  : Username  
 */  
  
SET NOCOUNT ON  
  
SELECT   
	 UserID,  
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
FROM dbo.PIH_Users WITH (NOLOCK)  
WHERE Username = @Username

GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_GetByUsername] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_GetByUsername] TO [bodbAdminNet] 