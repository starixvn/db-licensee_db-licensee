ALTER   PROCEDURE dbo.Lrf_CustomerSelMember_MinMaxBetVS
	@custid INT
AS

/*
Created: 20130912@Jim
Task : SELECT customer's bet setting of virtual sport
DB: DB052.bodb02
Original: Lrf_CustomerSelMember_MinMaxBet181

Revisions:
   -20131007@Jim: offer Virtual Tennis
Param's Explanation:
• @CustID: customer id.   
*/

DECLARE	@UserName VARCHAR(30), @recommend INT

DECLARE @minminbet180 MONEY,
			@maxmaxbet180 MONEY,
			@maxmaxpermatch180 MONEY,
			@minminbet181 MONEY,
			@maxmaxbet181 MONEY,
			@maxmaxpermatch181 MONEY,
			@minminbet186 MONEY,
			@maxmaxbet186 MONEY,
			@maxmaxpermatch186 MONEY
			
SELECT @UserName = username, @recommend = recommend
from customer with (NOLOCK)
WHERE roleid = 1 AND CustID = @CustID

IF (@username = NULL) RETURN
SELECT cs.sporttype,
	   cs.bettype,
	   MinBet,
	   MaxBet		
	INTO #tempMinMax
from 
	Dep_CustSetting3rd as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype IN(1201,1231,1232,1233,1237,1238,1220) AND cs.sporttype IN (180,181,186)
WHERE ci.custid = @recommend
		
SELECT
	@MinMinBet180 =  Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet180 =  Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM #tempMinMax
WHERE 
	bettype=1201
	AND sporttype=180

SELECT
	@MinMinBet181 =Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet181 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM #tempMinMax
WHERE 
	bettype IN (1231,1232,1233,1237,1238)
	AND sporttype=181

SELECT
	@MinMinBet186 =Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet186 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM #tempMinMax
WHERE 
	bettype =1220
	AND sporttype=186
	
DROP TABLE #tempMinMax

SELECT @MaxMaxperMatch180 = Min(CASE WHEN cs.maxpermatch180 = 0 THEN NULL ELSE cs.maxpermatch180 END)
	   ,@MaxMaxperMatch181 = Min(CASE WHEN cs.maxpermatch181 = 0 THEN NULL ELSE cs.maxpermatch181 END)	
	   ,@MaxMaxperMatch186 = Min(CASE WHEN cs.maxpermatch186 = 0 THEN NULL ELSE cs.maxpermatch186 END)	
from 
	custinfo as cs WITH (NOLOCK) 
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
WHERE ci.custid = @recommend

SELECT isnull(@minminbet180,0) minminbet,
		isnull(@maxmaxbet180,0) maxmaxbet,
		isnull(@maxmaxpermatch180,0) maxmaxpermatch,
		0 AS maxpermatch_min,
		ci.maxpermatch180 maxpermatch,
		cs.minbet,
		cs.maxbet,
		cs.sporttype	
FROM custinfo ci WITH(NOLOCK)
INNER JOIN Dep_CustSetting3rd cs ON ci.custid = cs.custid
WHERE ci.custid = @custid AND cs.bettype =1201 AND cs.sporttype =180
UNION ALL
SELECT isnull(@minminbet181,0) minminbet,
		isnull(@maxmaxbet181,0) maxmaxbet,
		isnull(@maxmaxpermatch181,0) maxmaxpermatch,
		0 AS maxpermatch_min,
		ci.maxpermatch181 maxpermatch,
		cs.minbet,
		cs.maxbet,
		cs.sporttype	
FROM custinfo ci WITH(NOLOCK)
INNER JOIN Dep_CustSetting3rd cs ON ci.custid = cs.custid
WHERE ci.custid = @custid AND cs.bettype IN(1231,1232,1233,1237,1238) AND cs.sporttype =181
UNION ALL
SELECT isnull(@minminbet186,0) minminbet,
		isnull(@maxmaxbet186,0) maxmaxbet,
		isnull(@maxmaxpermatch186,0) maxmaxpermatch,
		0 AS maxpermatch_min,
		ci.maxpermatch186 maxpermatch,
		cs.minbet,
		cs.maxbet,
		cs.sporttype	
FROM custinfo ci WITH(NOLOCK)
INNER JOIN Dep_CustSetting3rd cs ON ci.custid = cs.custid
WHERE ci.custid = @custid AND cs.bettype=1220 AND cs.sporttype =186

GO

GRANT EXECUTE ON [dbo].[Lrf_CustomerSelMember_MinMaxBetVS] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelMember_MinMaxBetVS] TO vnteam

