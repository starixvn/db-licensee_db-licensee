ALTER  PROCEDURE [dbo].[Lrf_UserInfoSel]
	@UserId INT,  
	@LicenseeId INT
AS
/*
	Created by: [20111005@AlexNguyen ]
	Task: Get User Information Detail AND Page Access
	DB: DB052.bodb_Licensee
	Revisions:
	
*/  
SET NOCOUNT ON  
  
SELECT 
	u.UserID  
	,u.UserName  
	,u.FirstName  
	,u.LastName  
	,l.PageAccess  
	,u.Status  
	,u.IsInternal as IsInternal 
FROM  
Users u (NOLOCK)  
INNER JOIN licenseeuser l (NOLOCK) ON u.UserID = l.UserID  
WHERE  
	u.UserID = @UserId  
	AND l.LicenseeID = @LicenseeId   
 
GO
GRANT EXECUTE ON [dbo].[Lrf_UserInfoSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserInfoSel] TO [vnteam]
 