ALTER PROCEDURE [dbo].[Acc_BA_LicConfigSel]
AS
/*
Created: Henry
Date: 20120220
Task : Get Licensee Commission Template for all Licensee
DB: bodb_MoveBet
Original:

Revisions:
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
		
	SELECT 
		A.LicenseeName, 
		B.LicenseeID, 
		B.groupa,
		B.groupb,
		B.groupc,
		B.groupd,
		B.[1x2Comm], 
		B.OtherComm
	FROM LicenseeBAConfig B WITH (NOLOCK) 
	INNER JOIN Licensees A WITH (NOLOCK) ON A.LicenseeID = B.LicenseeID
	ORDER BY A.LicenseeID 
	
	
END



GO
GRANT EXECUTE ON [dbo].[Acc_BA_LicConfigSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BA_LicConfigSel] TO [vnteam] 