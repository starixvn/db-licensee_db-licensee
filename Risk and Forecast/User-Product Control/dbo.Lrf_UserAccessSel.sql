ALTER  PROCEDURE [dbo].[Lrf_UserAccessSel]
	@LicenseeID INT	,
	@IsInternal BIT = 0
AS

/*  
 Created by: [20110405@Henry]  
 Task: Get User Detail AND Page Access  
 DB: DB052.bodb_Licensee  
 Revisions:  
 - 20111004@Henry: Add Param @IsInternal, remove param @UserID  
 - 20111220@Henry: Return IsManageAccount column  
 - 20120419@Henry: Only admin can login to LRF site directly, 
				   Admin has IsInternal = 0
				   Licensee has IsInternal = 1
				   Admin can view all users
				   Licesee can view licensee user only
*/  
  
SET NOCOUNT ON  
  
SELECT   
 u.UserID, u.UserName, u.FirstName, u.LastName, u.Status, u.isInternal as IsInternal,   
 CASE WHEN luf.UserId IS NULL THEN 0 ELSE 1 END AS IsManageAccount  
FROM   
 users u (nolock)  
INNER JOIN licenseeuser l (nolock) ON u.UserID = l.UserID  
LEFT JOIN   
(  
 SELECT UserId   
 FROM LicenseeUserFunctions uf (NOLOCK)    
  INNER JOIN Functions f (NOLOCK) ON uf.functionid = f.FunctionId  
 WHERE   
  uf.LicenseeID =@LicenseeID and   
  f.Name = 'Manage Account'  
) luf  ON u.UserID = luf.UserId  
  
WHERE   
 LicenseeID = @LicenseeID AND (@IsInternal = 0 or (u.UserRole =  'Licensee' AND @IsInternal=1 AND u.IsInternal=1 ))  
 AND u.Username NOT LIKE 'DELETE_%'
ORDER BY u.status DESC,u.isInternal,u.Username

GO
GRANT EXECUTE ON [dbo].[Lrf_UserAccessSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserAccessSel] TO [vnteam]

