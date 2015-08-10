USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_CustomerSelMember_MinMaxBetVS]    Script Date: 6/9/2015 1:14:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_CustomerSelMember_MinMaxBetVS]
	@custid INT
AS
----- sample test case : exec Lrf_CustomerSelMember_MinMaxBetVS_15189 @custid=3389637
/*
Created: 20130912@Jim
Task : SELECT customer's bet setting of virtual sport
DB: DBCUST.CustDB
Original: Lrf_CustomerSelMember_MinMaxBet181

Revisions:
	- 20131007@Jim: offer Virtual Tennis
	- 20131129@Jim: support :
		182 – Virtual Greyhounds
		184 – Virtual Motor Racing
	- 20140429@Jim: support :
		-Virtual Speedway (sporttype=183)
		-Virtual Cycling (sporttype=185)
	- 20150609@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB)

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
		@minminbet182 MONEY,
		@maxmaxbet182 MONEY,
		@maxmaxpermatch182 MONEY,
		
		@minminbet183 MONEY,
		@maxmaxbet183 MONEY,
		@maxmaxpermatch183 MONEY,
		
		@minminbet184 MONEY,
		@maxmaxbet184 MONEY,
		@maxmaxpermatch184 MONEY,
		
		@minminbet185 MONEY,
		@maxmaxbet185 MONEY,
		@maxmaxpermatch185 MONEY,
		
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
	AND cs.bettype IN(1201,1231,1232,1233,1237,1238,1220) AND cs.sporttype IN (180,181,182,183,184,185,186)
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
	@MinMinBet182 =Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet182 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM #tempMinMax
WHERE 
	bettype IN (1231,1232,1233,1237,1238)
	AND sporttype=182
----  Virtual Speedway
SELECT
	@MinMinBet183 =Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet183 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM #tempMinMax
WHERE 
	bettype IN (1231)
	AND sporttype=183
	
SELECT
	@MinMinBet184 =Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet184 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM #tempMinMax
WHERE 
	bettype IN (1231,1232,1233,1237,1238)
	AND sporttype=184
---Virtual Cycling
SELECT
	@MinMinBet185 =Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxMaxBet185 = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM #tempMinMax
WHERE 
	bettype IN (1231,1232,1233)
	AND sporttype=185
	
	
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
	   ,@MaxMaxperMatch182 = Min(CASE WHEN cs.maxpermatch182 = 0 THEN NULL ELSE cs.maxpermatch182 END)	
	   ,@MaxMaxperMatch183 = Min(CASE WHEN cs.maxpermatch183 = 0 THEN NULL ELSE cs.maxpermatch183 END)
	   ,@MaxMaxperMatch184 = Min(CASE WHEN cs.maxpermatch184 = 0 THEN NULL ELSE cs.maxpermatch184 END)	
	   ,@MaxMaxperMatch185 = Min(CASE WHEN cs.maxpermatch185 = 0 THEN NULL ELSE cs.maxpermatch185 END)	
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
SELECT isnull(@minminbet182,0) minminbet,
		isnull(@maxmaxbet182,0) maxmaxbet,
		isnull(@maxmaxpermatch182,0) maxmaxpermatch,
		0 AS maxpermatch_min,
		ci.maxpermatch182 maxpermatch,
		cs.minbet,
		cs.maxbet,
		cs.sporttype	
FROM custinfo ci WITH(NOLOCK)
INNER JOIN Dep_CustSetting3rd cs ON ci.custid = cs.custid
WHERE ci.custid = @custid AND cs.bettype IN(1231,1232,1233,1237,1238) AND cs.sporttype =182
UNION ALL
SELECT isnull(@minminbet183,0) minminbet,
		isnull(@maxmaxbet183,0) maxmaxbet,
		isnull(@maxmaxpermatch183,0) maxmaxpermatch,
		0 AS maxpermatch_min,
		ci.maxpermatch183 maxpermatch,
		cs.minbet,
		cs.maxbet,
		cs.sporttype	
FROM custinfo ci WITH(NOLOCK)
INNER JOIN Dep_CustSetting3rd cs ON ci.custid = cs.custid
WHERE ci.custid = @custid AND cs.bettype IN(1231) AND cs.sporttype =183

UNION ALL
SELECT isnull(@minminbet184,0) minminbet,
		isnull(@maxmaxbet184,0) maxmaxbet,
		isnull(@maxmaxpermatch184,0) maxmaxpermatch,
		0 AS maxpermatch_min,
		ci.maxpermatch184 maxpermatch,
		cs.minbet,
		cs.maxbet,
		cs.sporttype	
FROM custinfo ci WITH(NOLOCK)
INNER JOIN Dep_CustSetting3rd cs ON ci.custid = cs.custid
WHERE ci.custid = @custid AND cs.bettype IN(1231,1232,1233,1237,1238) AND cs.sporttype =184
UNION ALL
SELECT isnull(@minminbet185,0) minminbet,
		isnull(@maxmaxbet185,0) maxmaxbet,
		isnull(@maxmaxpermatch185,0) maxmaxpermatch,
		0 AS maxpermatch_min,
		ci.maxpermatch185 maxpermatch,
		cs.minbet,
		cs.maxbet,
		cs.sporttype	
FROM custinfo ci WITH(NOLOCK)
INNER JOIN Dep_CustSetting3rd cs ON ci.custid = cs.custid
WHERE ci.custid = @custid AND cs.bettype IN(1231,1232,1233) AND cs.sporttype =185
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