ALTER PROCEDURE [dbo].[PIH_ExchangeDailyOandaSel]  
	@tstamp timestamp
AS  
/*  Created: Viet  
	Date: 2012-07-16    
    DB: DB054.bodb_PIH
   
    Revisions:  
		
	Param's Explanation:  
*/  
 
SET NOCOUNT ON  
	
SELECT TOP 100 exchangedate, exchangeid, code, myr, usd, eur, cny, actualrate, tstamp	
FROM bodb02.dbo.ExchangeDailyOanda with(nolock)	
WHERE tstamp > @tstamp		
ORDER BY tstamp ASC
FOR XML PATH('exchangedailyoanda'), ROOT ('root')	   

GO
GRANT EXECUTE ON [dbo].[PIH_ExchangeDailyOandaSel] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PIH_ExchangeDailyOandaSel] TO [vnTeam] AS [dbo]