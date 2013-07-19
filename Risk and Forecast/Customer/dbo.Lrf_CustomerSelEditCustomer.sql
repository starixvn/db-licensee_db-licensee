ALTER PROCEDURE [dbo].[Lrf_CustomerSelEditCustomer]
	@CustID INT
AS

/*
Created: 
Task : Agent edit member
DB: DB052.bodb02
Original: Acc_CustomerSelEditCustomer

Revisions:
    - 20110519@Henry: Remove Number Game (use Number game in SP: Lrf_CustomerSelEditNG)
	- 20120326@Dom: Change CustSetting to Dep_CustSetting, CustSetting3rd to Dep_CustSetting3rd
	- 20130718@Jim: remove status Suspended
Param's Explanation:
• @CustID: member ID
*/


DECLARE @MinBet_Max MONEY, @MaxBet_Min MONEY, @MaxPerMatch_Min MONEY, @MaxPerMatch_Max MONEY,
		@MinBetv2_Max MONEY, @MaxBetv2_Min MONEY, @MaxPerMatchv2_Min MONEY, @MaxPerMatchv2_Max MONEY,
		@MinBetv3_Max MONEY, @MaxBetv3_Min MONEY, @MaxPerMatchv3_Min MONEY, @MaxPerMatchv3_Max MONEY,
		@MinBetv5_Max MONEY, @MaxBetv5_Min MONEY, @MaxPerMatchv5_Min MONEY, @MaxPerMatchv5_Max MONEY,
		@MinBetv8_Max MONEY, @MaxBetv8_Min MONEY, @MaxPerMatchv8_Min MONEY, @MaxPerMatchv8_Max MONEY,
		@MinBetv10_Max MONEY, @MaxBetv10_Min MONEY, @MaxPerMatchv10_Min MONEY, @MaxPerMatchv10_Max MONEY,
		@MinBetv11_Max MONEY, @MaxBetv11_Min MONEY, @MaxPerMatchv11_Min MONEY, @MaxPerMatchv11_Max MONEY,
		@MinBetv99_Max MONEY, @MaxBetv99_Min MONEY, @MaxPerMatchv99_Min MONEY, @MaxPerMatchv99_Max MONEY,
		@MinBetv99MP_Max MONEY, @MaxBetv99MP_Min MONEY, @MaxPerMatchv99MP_Min MONEY, @MaxPerMatchv99MP_Max MONEY
		
		
	


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @mrecommend INT, @recommend INT---, @Asuspended BIT
SELECT	@mrecommend = mrecommend, @recommend=recommend from custinfo with (NOLOCK) WHERE custid = @custid

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				  

SELECT
	@MinBet_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBet_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=1
WHERE ci.custid = @CustID

SELECT 
	@MinBetv2_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv2_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=2
WHERE ci.custid = @CustID


SELECT 
	@MinBetv3_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv3_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=3
WHERE ci.custid = @CustID

SELECT 
	@MinBetv5_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv5_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=5
WHERE ci.custid = @CustID

SELECT 
	@MinBetv8_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv8_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=8
WHERE ci.custid = @CustID

SELECT 
	@MinBetv10_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv10_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=10
WHERE ci.custid = @CustID

SELECT 
	@MinBetv11_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv11_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=11
WHERE ci.custid = @CustID

SELECT 
	@MinBetv99_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv99_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 1 AND cs.sporttype=99
WHERE ci.custid = @CustID

SELECT 
	@MinBetv99MP_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBetv99MP_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
	Dep_CustSetting as cs 
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype = 9 AND cs.sporttype=99
WHERE ci.custid = @CustID



SELECT 
	@MaxPerMatch_Min = 0, 
	@MaxperMatch_Max = Min(CASE WHEN cs.MaxPerMatch = 0 THEN NULL ELSE cs.MaxPerMatch END), 
	
	@MaxPerMatchv2_Min = 0,
	@MaxPerMatchv2_Max = Min(CASE WHEN cs.MaxPerMatch2 = 0 THEN NULL ELSE cs.MaxPerMatch2 END), 

	@MaxPerMatchv3_Min = 0,
	@MaxPerMatchv3_Max = Min(CASE WHEN cs.MaxPerMatch3 = 0 THEN NULL ELSE cs.MaxPerMatch3 END), 

	@MaxPerMatchv5_Min = 0,
	@MaxPerMatchv5_Max = Min(CASE WHEN cs.MaxPerMatch5 = 0 THEN NULL ELSE cs.MaxPerMatch5 END), 
	
	@MaxPerMatchv8_Min = 0,
	@MaxPerMatchv8_Max = Min(CASE WHEN cs.MaxPerMatch8 = 0 THEN NULL ELSE cs.MaxPerMatch8 END), 

	@MaxPerMatchv10_Min = 0,
	@MaxPerMatchv10_Max = Min(CASE WHEN cs.MaxPerMatch10 = 0 THEN NULL ELSE cs.MaxPerMatch10 END), 
	
	@MaxPerMatchv11_Min = 0,
	@MaxPerMatchv11_Max = Min(CASE WHEN cs.MaxPerMatch11 = 0 THEN NULL ELSE cs.MaxPerMatch11 END), 

	@MaxPerMatchv99_Min = 0,
	@MaxPerMatchv99_Max = Min(CASE WHEN cs.MaxPerMatch99 = 0 THEN NULL ELSE cs.MaxPerMatch99 END),
	
	@MaxPerMatchv99MP_Min = 0,
	@MaxPerMatchv99MP_Max = Min(CASE WHEN cs.MaxPerMatch99MP = 0 THEN NULL ELSE cs.MaxPerMatch99MP END)
	
	
	
from 
	custinfo as cs WITH (NOLOCK) 
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
WHERE ci.custid = @CustID




SELECT 
	Ci.username, 
	isnull(Ci.maxpermatch, 0) as maxpermatch,
	isnull(ci.maxpermatch2, 0) as maxpermatchv2,
	isnull(ci.maxpermatch3, 0) as maxpermatchv3,
	isnull(ci.maxpermatch5, 0) as maxpermatchv5,
	isnull(ci.maxpermatch8, 0) as maxpermatchv8,
	isnull(ci.maxpermatch10, 0) as maxpermatchv10,
	isnull(ci.maxpermatch11, 0) as maxpermatchv11,
	isnull(ci.maxpermatch99, 0) as maxpermatchv99,
	isnull(ci.maxpermatch99MP, 0) as maxpermatchv99MP,
	

	isnull(exchange.minbet, 0) AS defaultminbet,

	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.minbet ELSE 0 END), 0) as minbet,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.maxbet ELSE 0 END), 0) as maxbet,
	
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.minbet ELSE 0 END), 0) as MinBetv2,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv2,
	
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.minbet ELSE 0 END), 0) as MinBetv3,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv3,

	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.minbet ELSE 0 END), 0) as MinBetv5,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv5,

	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.minbet ELSE 0 END), 0) as MinBetv8,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv8,

	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.minbet ELSE 0 END), 0) as MinBetv10,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv10,

	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.minbet ELSE 0 END), 0) as MinBetv11,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv11,

	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.minbet ELSE 0 END), 0) as MinBetv99,
	isnull(max(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv99,
	
	isnull(max(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.minbet ELSE 0 END), 0) as MinBetv99MP,
	isnull(max(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.maxbet ELSE 0 END), 0) as MaxBetv99MP,
	
	
	IsNull(@MinBet_Max, 0) as MinBet_Max,
	IsNull(@MaxBet_Min, 0) as MaxBet_Min,
	IsNull(@MaxPerMatch_Min, 0) as MaxPerMatch_Min,
	IsNull(@MaxPerMatch_Max, 0) as MaxPerMatch_Max,
	
	IsNull(@MinBetv2_Max, 0) as MinBetv2_Max,	
	IsNull(@MaxBetv2_Min, 0) as MaxBetv2_Min,	
	IsNull(@MaxPerMatchv2_Min, 0) as MaxPerMatchv2_Min,	
	IsNull(@MaxPerMatchv2_Max, 0) as MaxPerMatchv2_Max,	
	
	IsNull(@MinBetv3_Max, 0) as MinBetv3_Max,	
	IsNull(@MaxBetv3_Min, 0) as MaxBetv3_Min,	
	IsNull(@MaxPerMatchv3_Min, 0) as MaxPerMatchv3_Min,	
	IsNull(@MaxPerMatchv3_Max, 0) as MaxPerMatchv3_Max,

	IsNull(@MinBetv5_Max, 0) as MinBetv5_Max,	
	IsNull(@MaxBetv5_Min, 0) as MaxBetv5_Min,	
	IsNull(@MaxPerMatchv5_Min, 0) as MaxPerMatchv5_Min,	
	IsNull(@MaxPerMatchv5_Max, 0) as MaxPerMatchv5_Max,

	IsNull(@MinBetv8_Max, 0) as MinBetv8_Max,	
	IsNull(@MaxBetv8_Min, 0) as MaxBetv8_Min,	
	IsNull(@MaxPerMatchv8_Min, 0) as MaxPerMatchv8_Min,	
	IsNull(@MaxPerMatchv8_Max, 0) as MaxPerMatchv8_Max,

	IsNull(@MinBetv10_Max, 0) as MinBetv10_Max,	
	IsNull(@MaxBetv10_Min, 0) as MaxBetv10_Min,	
	IsNull(@MaxPerMatchv10_Min, 0) as MaxPerMatchv10_Min,	
	IsNull(@MaxPerMatchv10_Max, 0) as MaxPerMatchv10_Max,

	IsNull(@MinBetv11_Max, 0) as MinBetv11_Max,	
	IsNull(@MaxBetv11_Min, 0) as MaxBetv11_Min,	
	IsNull(@MaxPerMatchv11_Min, 0) as MaxPerMatchv11_Min,	
	IsNull(@MaxPerMatchv11_Max, 0) as MaxPerMatchv11_Max,

	IsNull(@MinBetv99_Max, 0) as MinBetv99_Max,	
	IsNull(@MaxBetv99_Min, 0) as MaxBetv99_Min,	
	IsNull(@MaxPerMatchv99_Min, 0) as MaxPerMatchv99_Min,	
	IsNull(@MaxPerMatchv99_Max, 0) as MaxPerMatchv99_Max,
	
	IsNull(@MinBetv99MP_Max, 0) as MinBetv99MP_Max,	
	IsNull(@MaxBetv99MP_Min, 0) as MaxBetv99MP_Min,	
	IsNull(@MaxPerMatchv99MP_Min, 0) as MaxPerMatchv99MP_Min,	
	IsNull(@MaxPerMatchv99MP_Max, 0) as MaxPerMatchv99MP_Max
	
from 
	
	CustInfo as ci with (NOLOCK)
	INNER JOIN Dep_CustSetting as cs with (NOLOCK) on ci.custid = cs.custid
	INNER JOIN Dep_CustSetting3rd cs3 with (NOLOCK) on cs.custid = cs3.custid
	INNER JOIN exchange with (NOLOCK) ON Ci.currency=exchange.exchangeid
WHERE Ci.custid=@CustID
group by 
	Ci.username, 
	Ci.maxpermatch,
	ci.maxpermatch2,
	ci.maxpermatch3,
	ci.maxpermatch5,
	ci.maxpermatch8,
	ci.maxpermatch10, 
	ci.maxpermatch11,
	ci.maxpermatch99,
	ci.maxpermatch99MP,
	exchange.minbet

GO 
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelEditCustomer] TO [bodbLicenseeNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelEditCustomer] TO [vnteam]