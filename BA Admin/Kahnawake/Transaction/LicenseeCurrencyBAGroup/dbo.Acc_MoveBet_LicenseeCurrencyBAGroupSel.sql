ALTER PROCEDURE [dbo].[Acc_MoveBet_LicenseeCurrencyBAGroupSel]  
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Get data to insert to LicenseeCurrencyBAGroup in Kahnawake server
    DB: DB052.bodb_Licensee
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
SELECT
	lc.licenseeid,
	lc.currency,
	lc.ugroup
FROM LicenseeCurrencyBAGroup lc  WITH (NOLOCK)
INNER JOIN LicenseeBAConfig l ON lc.LicenseeID=l.LicenseeID
WHERE
	l.EnableBA=1
	FOR XML PATH('licenseecurrencybagroup'), ROOT ('root')

	
	

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_LicenseeCurrencyBAGroupSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_MoveBet_LicenseeCurrencyBAGroupSel] TO [vnteam] 

      