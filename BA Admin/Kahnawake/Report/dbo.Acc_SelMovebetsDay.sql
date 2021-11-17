ALTER PROCEDURE  [dbo].[Acc_SelMovebetsDay]		
		
AS	
/*
Created: 20120713@Henry
Task : Get move bet day
DB: bodb_Movebet
Original: 

Revisions:
    
Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	
	SELECT 
		VValue as MoveBetsDay
	FROM SystemSettings WITH(NOLOCK)
	WHERE VName = 'MoveBetsDay'
		
END

GO
GRANT EXECUTE ON [dbo].[Acc_SelMovebetsDay] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_SelMovebetsDay] TO [vnteam] 