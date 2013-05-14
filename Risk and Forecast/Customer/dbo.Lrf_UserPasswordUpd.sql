set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_UserPasswordUpd]  
 @UserName VARCHAR(50),    
 @OldPwd VARCHAR(50),   
 @NewPwd VARCHAR(50),   
 @UserSalt VARCHAR(50),   
 @Langkey VARCHAR(20) = 'en-US',  
 @LoginIP VARCHAR(20),  
 @ErrCode INT = 0 OUTPUT,  
 @ErrMsg nvarchar(4000) = '' OUTPUT  
   
  
AS  
/*  
 * Created: 20101201@ Johnny
 * Task : User change password
 * DB: DB052.bodb_Licensee  
 *  
 * Revisions:     
 - 20111004@Henry: check only LRF pure users (isInternal=0)
 - 20130413@jim: support multi language 
*/  
BEGIN  
SET NOCOUNT ON;  

DECLARE @UserId INT

SELECT @UserId = UserId from Users with (nolock) WHERE Username = @UserName AND UserPwd = @OldPwd AND IsInternal = 0

If isnull(@UserId, 0) = 0
Begin
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Wrong password.'  
								   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](80001,@Langkey)  
								   	
        END ,@ErrCode=101    
    RETURN 
END

if exists (SELECT 1 from Users with (nolock) WHERE @UserId = UserId AND Status <> 'Open')
Begin
	SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This user is not active.'  
								   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200022,@Langkey)
        END ,@ErrCode=102
    RETURN 
END
   
UPDATE dbo.Users   with (ROWLOCK)
SET UserPwd = @NewPwd,   
  UserSalt = @UserSalt  
WHERE 
UserId =  @UserId 
AND IsInternal = 0
  
 IF (@@ERROR > 0)  
  SELECT @ErrCode = 100, @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Cannot change password'  
												 ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200025,@Langkey)
												 END
END  

GO
GRANT EXECUTE ON [dbo].[Lrf_UserPasswordUpd] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserPasswordUpd] TO [vnteam] 

