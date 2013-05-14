ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommSel]
	@LicenseeID INT,
	@GroupName VARCHAR(100) = ''
AS  
/*  
 * Created: 20120726@Henry
 * Task : Select Group Commission
 * DB: DB052.bodb_Licensee  
 *  
 * Revisions:     
 - 20121227@Henry: Add column IsDefault
	
*/  
BEGIN  
SET NOCOUNT ON;  

SELECT @GroupName = ltrim(rtrim(@GroupName))

SELECT g.ID AS GroupCommID,g.GroupName,g.SBComm,g.RacingComm,g.NGComm,g.color AS GroupColor, count(c.GroupCommID) AS NumberOfCustomer, g.IsDefault
FROM LicenseeGroupComm g WITH (NOLOCK) 
	LEFT JOIN LicenseeCustComm c WITH (NOLOCK) ON g.id=c.GroupCommID
WHERE 
	IsActive = 1 
	AND (@GroupName='' OR (@GroupName<>'' AND GroupName LIKE '%' + @GroupName + '%'))
	AND g.LicenseeID = @LicenseeID
GROUP BY
	g.ID ,g.GroupName,g.SBComm,g.RacingComm,g.NGComm,g.color, g.IsDefault
	

END
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeGroupCommSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeGroupCommSel] TO [vnteam]  