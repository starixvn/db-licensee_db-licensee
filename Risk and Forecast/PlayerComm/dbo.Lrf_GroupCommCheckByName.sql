 ALTER PROCEDURE [dbo].[Lrf_GroupCommCheckByName]
	@LicenseeID INT,
	@GroupName VARCHAR(100)
AS  
/*  
 * Created: 20120726@Henry
 * Task : Check the existence of Group Name
 * DB: DB052.bodb_Licensee  
 *  
 * Revisions:     
	
*/  
BEGIN  
SET NOCOUNT ON;  

DECLARE @isAvailable BIT



SELECT @GroupName = ltrim(rtrim(@GroupName))

IF EXISTS (
	SELECT 1 FROM LicenseeGroupComm WITH (NOLOCK)
	WHERE 
		LicenseeID = @LicenseeID
		AND GroupName = @GroupName
		AND IsActive = 1
)
BEGIN
	SELECT 0 AS IsAvailable
END
ELSE
BEGIN
	SELECT 1 AS IsAvailable
END

	

END
GO
GRANT EXECUTE ON [dbo].[Lrf_GroupCommCheckByName] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GroupCommCheckByName] TO [vnteam]  