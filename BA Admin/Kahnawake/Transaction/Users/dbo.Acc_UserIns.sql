ALTER PROCEDURE [dbo].[Acc_UserIns]  
	@username varchar(50),
	@userpwd varchar(50),
	@errcode int = 0 OUTPUT,
	@errmsg NVARCHAR(4000) = '' OUTPUT
AS  
/*  Created: Kevin  
	Date: 2012-06-13
    TASk : User Insert
    DB: bodb_MoveBet
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN 

SET NOCOUNT ON  
	
IF EXISTS (SELECT 1
       FROM   Users WITH (NOLOCK)
       WHERE  Username = @username)
BEGIN
    SELECT @errmsg = 'This username is not available. ',
           @errcode = 1;
    RETURN;
END

Insert into Users (Username, UserPwd)
values (@username, @userpwd)

IF @@ERROR <> 0
    BEGIN
        SELECT @errmsg = 'Add customer failed.',
               @errcode = 103;      
    END
END   



GO
GRANT EXECUTE ON [dbo].[Acc_UserIns] TO [bodbAdminNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_UserIns] TO [vnteam] 
