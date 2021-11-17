ALTER PROCEDURE [dbo].[Acc_UserLogin]  
	@Username varchar(50),
	@UserPwd varchar(50)
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : User Login
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
		Username = @Username AND UserPwd = @UserPwd
		
	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_UserLogin] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_UserLogin] TO [vnteam] 

     