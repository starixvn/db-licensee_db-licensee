ALTER PROCEDURE [dbo].[Acc_UserResetPwd]  
	@UserID INT,
	@UserPwd varchar(50)
	
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Reset pwd
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	UPDATE users WITH (ROWLOCK,UPDLOCK)
	SET Userpwd = @UserPwd
	WHERE UserID = @UserID

END   

GO
GRANT EXECUTE ON [dbo].[Acc_UserResetPwd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_UserResetPwd] TO [vnteam] 

      