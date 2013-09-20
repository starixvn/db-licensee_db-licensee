ALTER   PROCEDURE dbo.Lrf_CustomerSelMember_MinMaxBetVS
	@custid INT
AS

/*
Created: 20130912@Jim
Task : SELECT customer's bet setting of virtual sport
DB: DB052.bodb02
Original: Lrf_CustomerSelMember_MinMaxBet181

Revisions:
   
Param's Explanation:
• @CustID: customer id.   
*/

DECLARE	@UserName VARCHAR(30), @recommend INT

DECLARE @minminbet180 MONEY,
	@maxmaxbet180 MONEY,
	@minminbet181 MONEY,
	@maxmaxbet181 MONEY,
	@maxmaxpermatch180 MONEY,
	@maxmaxpermatch181 MONEY
	
SELECT @UserName = username, @recommend = recommend
from customer with (NOLOCK)
WHERE roleid = 1 AND CustID = @CustID

IF (@username = NULL) RETURN

SELECT
	@MinMinBet180 = CASE WHEN cs.bettype=1201 AND cs.sporttype=180 THEN   Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END) ELSE 0 END, 
	@MaxMaxBet180 = CASE WHEN cs.bettype=1201 AND cs.sporttype=180 THEN Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END) ELSE 0 END,
	@MinMinBet181 = CASE WHEN cs.bettype IN (1231,1232,1233,1237,1238) AND cs.sporttype=181 THEN   Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END) ELSE 0 END, 
	@MaxMaxBet181 = CASE WHEN cs.bettype IN (1231,1232,1233,1237,1238) AND cs.sporttype=181 THEN Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END) ELSE 0 END
from 
	Dep_CustSetting3rd as cs WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on (cs.CustID = ci.Recommend or cs.CustID = ci.MRecommend or cs.CustID = ci.SRecommend)
	AND cs.bettype IN(1201,1231,1232,1233,1237,1238) AND cs.sporttype IN (180,181)
WHERE ci.custid = @recommend
GROUP BY cs.bettype,
		cs.sporttype

SELECT @MaxMaxperMatch180 = Min(CASE WHEN cs.maxpermatch180 = 0 THEN NULL ELSE cs.maxpermatch180 END)
	   ,@MaxMaxperMatch181 = Min(CASE WHEN cs.maxpermatch181 = 0 THEN NULL ELSE cs.maxpermatch181 END)	
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

GO

GRANT EXECUTE ON [dbo].[Lrf_CustomerSelMember_MinMaxBetVS] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelMember_MinMaxBetVS] TO vnteam

