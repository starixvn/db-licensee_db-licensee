ALTER PROCEDURE [dbo].[Lrf_LicenseeUserSelCheckBelonging]
	@LicenseeID INT,
	@UserID INT,
	@status BIT OUTPUT
AS
/*
Created: Henry@20110408
Task: check user belonging licensee
DB: DB052.bodb_licensee
Original:  
	
Revisions:
*/
SET NOCOUNT ON
SET @status = 1
IF NOT EXISTS (SELECT 1 FROM LicenseeUser (nolock) WHERE LicenseeID = @LicenseeID AND UserID = @UserID)
BEGIN
	SET @status = 0
END



GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeUserSelCheckBelonging] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeUserSelCheckBelonging] TO [vnteam]