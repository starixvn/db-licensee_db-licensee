ALTER PROCEDURE [dbo].[PIH_Users_GetAll]   
AS  
  
/*  
 * Created by : [20111512@Kos]  
 * Task  : Get all users  
 * DB   : WW100_DB.bodb_PIH @ kahnawake
 * Revisions :  
 */  
  
SET NOCOUNT ON  
  
SELECT  
	 u.UserID,
	 u.Username,
	 u.DisplayName,
	 u.Role,
	 u.IsActive,
	 u.IsTest,
	 u.CreatedDate,
	 u.ModifiedDate,
	 u.Creator,
	 ISNULL(p.Username, '') AS CreatorName  
FROM dbo.PIH_Users AS u WITH(NOLOCK)  
	 LEFT JOIN dbo.PIH_Users AS p WITH(NOLOCK) ON u.Creator = p.UserID
	 
GO
GRANT VIEW DEFINITION ON [dbo].[PIH_Users_GetAll] TO [VNTeam] 
GO
GRANT EXECUTE ON [dbo].[PIH_Users_GetAll] TO [bodbAdminNet] 	 
