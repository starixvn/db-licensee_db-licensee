ALTER PROCEDURE [dbo].[Acc_MoveBet_LicenseeCustSel]  
	@CustID INT = 0
AS  
/*  Created: Henry  
	Date: 2012-02-22
    TASk : Get data to insert to LicenseeCust in Kahnawake server
    DB: DB052.bodb_Licensee
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	SELECT
		lc.licenseeid,
		lc.custid,
		lc.roleid,
		lc.currency
		
	FROM licenseecust lc  WITH (NOLOCK)
	INNER JOIN LicenseeBAConfig l WITH (NOLOCK)	ON lc.LicenseeID=l.LicenseeID
	WHERE
		lc.CustID > @CustID
		AND l.EnableBA=1
	ORDER BY lc.CustID ASC
	FOR XML PATH('licenseecust'), ROOT ('root')

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_LicenseeCustSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_MoveBet_LicenseeCustSel] TO [vnteam] 

    