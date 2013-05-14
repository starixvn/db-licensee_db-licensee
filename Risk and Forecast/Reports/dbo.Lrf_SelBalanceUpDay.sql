ALTER PROCEDURE  [dbo].[Lrf_SelBalanceUpDay]		
		
AS	
/*
Created: 20101210@Henry
Task : Get move bet day, balanceup day
DB: DB052.bodb02
Original: [Age_SelBalanceUpDay]

Revisions:
    
Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	DECLARE @BalanceUpDay smalldatetime, @MoveBetsDay smalldatetime
	SELECT 
		TOP 1 @BalanceUpDay = winlostdate
	FROM Bettrans WITH(NOLOCK)
	WHERE bettype = 20000 AND matchid = 0	AND custid = 3
	
	SELECT    
		@MoveBetsDay = MAX(eventdate)  
	FROM match14 WITH(NOLOCK)  

	SELECT @BalanceUpDay as BalanceUpDay, @MoveBetsDay as MoveBetsDay
END

GO
GRANT EXECUTE ON [dbo].[Lrf_SelBalanceUpDay] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelBalanceUpDay] TO [vnteam]