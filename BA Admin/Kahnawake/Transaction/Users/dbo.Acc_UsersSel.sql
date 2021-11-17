ALTER PROCEDURE [dbo].[Acc_UsersSel]  
	@UserID int = 0	
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Get Users information
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	SELECT
		UserID, Username
	FROM users  WITH (NOLOCK)
	WHERE
		@UserID=0 OR (@UserID<>0 AND UserID = @UserID)

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_UsersSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_UsersSel] TO [vnteam] 

    