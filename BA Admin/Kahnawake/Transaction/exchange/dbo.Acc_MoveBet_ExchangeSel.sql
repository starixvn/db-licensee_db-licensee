ALTER PROCEDURE [dbo].[Acc_MoveBet_ExchangeSel]  
	@ExchangeId INT = 0
AS  
/*  Created: Henry  
	Date: 2012-02-21
    TASk : Get data to insert to exchange in Kahnawake server
    DB: DB052.bodb02
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	SELECT
		distinct
		e.exchangeid
		,e.currency
		,e.code
		,e.multipliedby
		
	FROM exchange e WITH (NOLOCK)
	INNER JOIN bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK) ON e.exchangeid = lc.Currency
	INNER JOIN bodb_Licensee.dbo.LicenseeBAConfig lba WITH (NOLOCK)  ON lc.LicenseeID = lba.LicenseeID
	WHERE	
		exchangeid > @ExchangeId
		AND lba.EnableBA = 1
	FOR XML PATH('exchange'), ROOT ('root')

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_ExchangeSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_MoveBet_ExchangeSel] TO [vnteam] 

   