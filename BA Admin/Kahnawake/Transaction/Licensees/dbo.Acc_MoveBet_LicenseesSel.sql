ALTER PROCEDURE [dbo].[Acc_MoveBet_LicenseesSel]  
	@LicenseeId INT = 0
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Get data to insert to Licensees in Kahnawake server
    DB: DB052.bodb_Licensee
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	SELECT
		l.licenseeid
		,l.licenseename
	FROM Licensees l WITH (NOLOCK)
	INNER JOIN LicenseeBAConfig lc WITH (NOLOCK) ON l.LicenseeID=lc.LicenseeID
	WHERE
		lc.EnableBA=1
		AND l.LicenseeID > @licenseeid
	FOR XML PATH('licensees'), ROOT ('root')

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_LicenseesSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_MoveBet_LicenseesSel] TO [vnteam] 

    