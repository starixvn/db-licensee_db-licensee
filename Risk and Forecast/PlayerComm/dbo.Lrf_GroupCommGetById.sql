 ALTER PROCEDURE [dbo].[Lrf_GroupCommGetById]
	@GroupCommID INT
AS  
/*  
 * Created: 20120801@Henry
 * Task : Get Group Comm Info
 * DB: DB052.bodb_Licensee  
 *  
 * Revisions:     
 - 20121227@Henry: Add column IsDefault
	
*/  
BEGIN  
SET NOCOUNT ON;  

SELECT g.ID AS GroupCommID,g.GroupName,g.SBComm,g.RacingComm,g.NGComm,g.color AS GroupColor, g.IsDefault
FROM LicenseeGroupComm g WITH (NOLOCK) 
WHERE 
	IsActive = 1 
	AND Id = @GroupCommID

END
GO
GRANT EXECUTE ON [dbo].[Lrf_GroupCommGetById] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GroupCommGetById] TO [vnteam]   