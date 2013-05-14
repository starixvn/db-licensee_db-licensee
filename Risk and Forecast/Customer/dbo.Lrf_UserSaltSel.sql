ALTER PROCEDURE [dbo].[Lrf_UserSaltSel]  
 @UserName VARCHAR(50)
AS  
/*  
 * Created: 20101203@Anders 
 * Task : Sel Pwd Salt
 * DB: DB052.bodb_Licensee  
 *  
 * Revisions:     
	- 20111007@Henry: Add IsInternal = 0
*/  
BEGIN  
SET NOCOUNT ON;  

	SELECT TOP 1 UserSalt  
	FROM dbo.Users WITH(NOLOCK)  
	WHERE Username = @UserName  
	AND IsInternal = 0

END
GO
GRANT EXECUTE ON [dbo].[Lrf_UserSaltSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UserSaltSel] TO [vnteam] 