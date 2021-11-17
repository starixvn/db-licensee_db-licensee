ALTER PROCEDURE [dbo].[Acc_MoveBet_ExchangeDailySel]  
	@ExchangeDate SMALLDATETIME
AS  
/*  Created: Henry  
	Date: 2012-03-07
    TASk : Get data to insert to exchangedaily in Kahnawake server
    DB: DB052.bodb02
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	SELECT
		exchangedate,
		exchangeid,
		code,
		myr,
		usd,
		eur,
		cny,
		actualrate
		
	FROM ExchangeDaily  WITH (NOLOCK)
	WHERE
		exchangedate = @ExchangeDate
	FOR XML PATH('exchangedaily'), ROOT ('root')

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_ExchangeDailySel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_MoveBet_ExchangeDailySel] TO [vnteam] 

    