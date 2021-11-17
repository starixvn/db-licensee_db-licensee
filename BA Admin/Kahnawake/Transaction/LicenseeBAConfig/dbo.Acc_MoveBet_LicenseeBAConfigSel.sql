ALTER PROCEDURE [dbo].[Acc_MoveBet_LicenseeBAConfigSel]  
	@LicenseeID INT = 0
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Get data to insert to LicenseeBAConfig in Kahnawake server
    DB: DB052.bodb_Licensee
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	SELECT
		licenseeid,
		[1x2Comm] as c1x2comm,
		othercomm,
		groupa,
		groupb,
		groupc,
		groupd
		
	FROM LicenseeBAConfig WITH (NOLOCK)
	WHERE
		LicenseeID > @LicenseeID
		AND EnableBA=1
	ORDER BY LicenseeID ASC	
	FOR XML PATH('licenseebaconfig'), ROOT ('root')

	
 
END    

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_LicenseeBAConfigSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_MoveBet_LicenseeBAConfigSel] TO [vnteam] 

     