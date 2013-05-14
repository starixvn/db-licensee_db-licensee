ALTER PROCEDURE [dbo].[PIH_Users_GetByUserID]   
 @UserID INT  
AS  
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : Get user information by user ID  
 * DB   : WW100_DB.bodb_PIH @ kahnawake
 * Revisions :  
 *  
 * Param's Explanation:    
 *  - @UserID : User ID  
 */  
  
SET NOCOUNT ON  
  
SELECT   
	 u.UserID,  
	 u.Username,  
	 u.DisplayName,  
	 u.Role,  
	 u.IsActive,
	 u.IsTest,
	 u.Creator,  
	 u.CreatedDate,  
	 u.ModifiedDate,  
	 pu.Username AS CreatorName  
FROM   
	 dbo.PIH_Users u WITH (NOLOCK)  
	 INNER JOIN   
	 dbo.PIH_Users pu WITH (NOLOCK)   
	 ON u.Creator = pu.UserID  
WHERE u.UserID = @UserID

GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_GetByUserID] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_GetByUserID] TO [bodbAdminNet] 