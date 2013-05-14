ALTER PROCEDURE [dbo].[Lrf_CustomerSelEditNG]
	@custid INT
AS
/*
Created: 20110519@Henry
Task : Get Number Game information
DB: DB052.bodb02

Revisions:
   20120326@Dom: change custsetting3rd to Dep_custsetting3rd

Param's Explanation:

*/
SET NOCOUNT ON
DECLARE @MinBetv161_Max MONEY, @MaxBetv161_Min MONEY, @MaxPerMatchv161_Min MONEY, @MaxPerMatchv161_Max MONEY,
		@MaxPerBallv161_Max MONEY
	
SELECT 
	@MinBetv161_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv161_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	dep_custsetting3rd as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 81 AND cs.sporttype=161
WHERE ci.custid = @CustID
	
SELECT 
	@MaxPerMatchv161_Min = 0,
	@MaxPerMatchv161_Max = Min(CASE WHEN cs.MaxPerMatch161 = 0 THEN NULL ELSE cs.MaxPerMatch161 END),
	@MaxPerBallv161_Max = Min(CASE WHEN cs.MaxPerBall161 = 0  THEN NULL ELSE cs.MaxPerBall161 END)
	
from 
	custinfo as cs WITH (NOLOCK) 
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
WHERE ci.custid = @CustID	
	

	--customer info
SELECT 
	c.username,
	isnull(max(CASE WHEN cs3.bettype = 81 AND cs3.sporttype=161 THEN cs3.minbet ELSE 0 END), 0) as MinBetv161,  
	isnull(max(CASE WHEN cs3.bettype = 81 AND cs3.sporttype=161 THEN cs3.maxbet ELSE 0 END), 0) as MaxBetv161,  
	isnull(c.maxpermatch161, 0)			as maxpermatchv161, 
	isnull(c.maxperball161,0)			as maxperballv161, 
	ISNULL(@MinBetv161_Max,0)			AS MinBetv161_Max,
	ISNULL(@MaxBetv161_Min,0)			AS MaxBetv161_Min,
	ISNULL(@MaxPerMatchv161_Min,0)		AS MaxPerMatchv161_Min,
	ISNULL(@MaxPerMatchv161_Max,0)		AS MaxPerMatchv161_Max,
	ISNull(@MaxPerBallv161_Max, 0)		as MaxPerBallv161_Max
 
   
		
		
FROM CustInfo c WITH (NOLOCK)
INNER JOIN Dep_CustSetting3rd cs3 with (NOLOCK) on c.custid = cs3.custid 
WHERE c.custid = @custid 
group by c.username,c.maxperball161, c.maxpermatch161
	
	
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelEditNG] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelEditNG] TO [vnteam]

