ALTER PROCEDURE [dbo].[PIH_Users_GetSalt]    
	@Username VARCHAR(50)  
AS    
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : Get user salt  
 * DB   : WW100_DB.bodb_PIH @ kahnawake
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @Username  : Username  
 */  
  
SET NOCOUNT ON  
  
SELECT UserSalt    
FROM dbo.PIH_Users WITH (NOLOCK)    
WHERE Username = @Username


GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_GetSalt] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_GetSalt] TO [bodbAdminNet] 
