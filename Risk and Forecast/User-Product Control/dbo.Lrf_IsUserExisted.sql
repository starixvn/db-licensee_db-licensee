ALTER PROCEDURE [dbo].[Lrf_IsUserExisted]   
 @UserName VARCHAR(50),  
 @IsUserExisted BIT = 0 OUTPUT  
AS  
/*
	Created by: [20110510@Henry]
	Task: Check availablity of a Username
	DB: DB052.bodb_Licensee
	Param's Explanation:
	
	
	Revisions:
	- 20111004@Henry: check only LRF pure users (isInternal=0)
*/
SET NOCOUNT ON

IF EXISTS (SELECT 1 FROM Users (nolock) WHERE Username = @Username AND isInternal=0)
	SET @IsUserExisted = 1
ELSE
	SET @IsUserExisted = 0
	

GO
GRANT EXECUTE ON [dbo].[Lrf_IsUserExisted] TO [bodbLicenseeNet] 
GO
GRANT EXECUTE ON [dbo].[Lrf_IsUserExisted] TO [bodbAdminNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_IsUserExisted] TO [vnteam] 	
