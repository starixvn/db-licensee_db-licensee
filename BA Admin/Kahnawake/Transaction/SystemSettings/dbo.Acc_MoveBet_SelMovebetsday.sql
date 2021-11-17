ALTER PROCEDURE [dbo].[Acc_MoveBet_SelMoveBetsday]  
AS  
/*  Created: Henry  
	Date: 2012-03-23
    TASk : Get movebetsday data to insert to Licensees in Kahnawake server
    DB: DB052.bodb02
   
    Revisions:  
		
	Param's Explanation:  
*/  
BEGIN  
SET NOCOUNT ON  
	
	SELECT          
		'MoveBetsDay' as vname,
		CONVERT(VARCHAR(10), MAX(eventdate), 120) AS vvalue
	FROM match14 WITH(NOLOCK) 
	FOR XML PATH('systemsettings'), ROOT ('root')

	

END   

GO
GRANT EXECUTE ON [dbo].[Acc_MoveBet_SelMoveBetsday] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_MoveBet_SelMoveBetsday] TO [vnteam] 

     