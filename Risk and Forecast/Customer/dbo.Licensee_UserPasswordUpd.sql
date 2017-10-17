USE [bodb_Licensee]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Licensee_UserPasswordUpd]  
 @UserName varchar(50),    
 @OldPwd varchar(50),   
 @NewPwd varchar(50),   
 @UserSalt varchar(50),   
 @Language varchar(20) = 'en-US',  
 @LoginIP varchar(20),  
 @ErrCode int = 0 OUTPUT,  
 @ErrMsg nvarchar(4000) = '' OUTPUT  
   
  
AS  
/*  
 * Created: 20101201@ Johnny
 * Task : User change password
 * DB: DBLIC/bodb_Licensee  
 *  
 * Revisions:     
	20140512@jim: add more filter (status='Open')
	20151023@Victor: Support New Simplified Chinese
	20171013@Alex  : only support to change password for it account [RedmineID: #84901]
*/  
BEGIN  
SET NOCOUNT ON;  

Declare @UserId int

SELECT @UserId = UserId from Users with (nolock) where Username = @UserName and UserPwd = @OldPwd and isInternal=0

If isnull(@UserId, 0) = 0
Begin
	select @ErrMsg = case @Language when 'en-us' then 'Wrong password.'  
         when 'zh-cn' then N'Wrong password.'  
         when 'zh-tw' then N'Wrong password.'  
		 when 'zh-Hans' then N'Wrong password.' 
         when 'ja' then N'Wrong password.'  
         when 'TH' then N'Wrong password.'  
         when 'KO' then N'Wrong password.'  
         else N'Wrong password.'  
        end ,@ErrCode=101    
    return 
End

if exists (select 1 from Users with (nolock) where @UserId = UserId and Status <> 'Open')
Begin
	select @ErrMsg = case @Language when 'en-us' then 'This user is not active.'  
         when 'zh-cn' then N'This user is not active.'  
         when 'zh-tw' then N'This user is not active.'  
		 when 'zh-Hans' then N'This user is not active.' 
         when 'ja' then N'This user is not active.'  
         when 'TH' then N'This user is not active.'  
         when 'KO' then N'This user is not active.'  
         else N'This user is not active.'  
        end ,@ErrCode=102
    return 
End
   
UPDATE dbo.Users   with (ROWLOCK)
SET UserPwd = @NewPwd,   
  UserSalt = @UserSalt  
WHERE Username = @UserName and isInternal=0
  AND status='Open'
 IF (@@ERROR > 0)  
  SELECT @ErrCode = 100, @ErrMsg = 'Cannot change password'  
END  
GO
GRANT EXECUTE ON [dbo].[Licensee_UserPasswordUpd] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Licensee_UserPasswordUpd] TO [vnteam] 

