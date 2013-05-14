ALTER  PROCEDURE [dbo].[Lrf_PageAccessByLicenseeSel]
	@LicenseeID INT,
	@UserID INT
	
AS

/*
	Created by: [20110406@Henry]
	Task: Get PageAcess of a user
	DB: DB052.bodb_Licensee
	Revisions:
	
*/

SET NOCOUNT ON
	SELECT PageAccess FROM LicenseeUser (nolock)
	WHERE 
		LicenseeID = @LicenseeID
		AND UserID = @UserID


GO
GRANT EXECUTE ON [dbo].[Lrf_PageAccessByLicenseeSel] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_PageAccessByLicenseeSel] TO [vnteam]

