/*<info serverAlias="DBCUST-CustDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerSelEditCustomer_xtest]
    @CustID INT
AS
---- exec Lrf_CustomerSelEditCustomer_20744 @CustID=4351589
/*
Created: 
Task : Agent edit member
DB: DBCUST.CustDB
Original: Acc_CustomerSelEditCustomer

Revisions:
	- 20110519@Henry: Remove Number Game (use Number game in SP: Lrf_CustomerSelEditNG)
	- 20120326@Dom: Change CustSetting to Dep_CustSetting, CustSetting3rd to Dep_CustSetting3rd
	- 20140212@Jim: support HorseRacingFixedOdds
	- 20140821@Jim: add more value DisableEsports in result
	- 20150609@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB)
	- 20151015@Jim: Integrate Sportbook2 (Feature #44759)
	- 20181009@Winnie: Remove Racing  (Feature #99378)
	- 20181029@Winnie: Remove Esports  (Feature #100721)
	- 20190906@Eden: 3rd party products - Remove InActive Products Phase 2 [Redmine: #118699]
	- 20200615@Johnson: add soccer parlay [redmine:#135261]
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
		@MinBetv1MP_Max MONEY, @MaxBetv1MP_Min MONEY, @MaxPerMatchv1MP_Min MONEY, @MaxPerMatchv1MP_Max MONEY,
        @MinBetv99MP_Max MONEY, @MaxBetv99MP_Min MONEY, @MaxPerMatchv99MP_Min MONEY, @MaxPerMatchv99MP_Max MONEY
        
        
    


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @mrecommend INT, @recommend INT, @Asuspended BIT 
SELECT    @mrecommend = mrecommend, @recommend=recommend FROM dbo.custinfo WITH (NOLOCK) WHERE custid = @custid


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  

SELECT
    @MinBet_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBet_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=1
WHERE ci.custid = @CustID

SELECT 
    @MinBetv2_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv2_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=2
WHERE ci.custid = @CustID


SELECT 
    @MinBetv3_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv3_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo as ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=3
WHERE ci.custid = @CustID

SELECT 
    @MinBetv5_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv5_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=5
WHERE ci.custid = @CustID

SELECT 
    @MinBetv8_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv8_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=8
WHERE ci.custid = @CustID

SELECT 
    @MinBetv10_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv10_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=10
WHERE ci.custid = @CustID

SELECT 
    @MinBetv11_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv11_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=11
WHERE ci.custid = @CustID


SELECT 
    @MinBetv99_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv99_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
from 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 1 AND cs.sporttype=99
WHERE ci.custid = @CustID

SELECT 
    @MinBetv99MP_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv99MP_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 9 AND cs.sporttype=99
WHERE ci.custid = @CustID

SELECT 
    @MinBetv1MP_Max = MAX(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
    @MaxBetv1MP_Min = MIN(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END)
FROM 
    dbo.Dep_CustSetting AS cs WITH (NOLOCK)
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
    AND cs.bettype = 9 AND cs.sporttype=1
WHERE ci.custid = @CustID

SELECT 
    @MaxPerMatch_Min = 0, 
    @MaxperMatch_Max = MIN(CASE WHEN cs.MaxPerMatch = 0 THEN NULL ELSE cs.MaxPerMatch END), 
    
    @MaxPerMatchv2_Min = 0,
    @MaxPerMatchv2_Max = MIN(CASE WHEN cs.MaxPerMatch2 = 0 THEN NULL ELSE cs.MaxPerMatch2 END), 

    @MaxPerMatchv3_Min = 0,
    @MaxPerMatchv3_Max = MIN(CASE WHEN cs.MaxPerMatch3 = 0 THEN NULL ELSE cs.MaxPerMatch3 END), 

    @MaxPerMatchv5_Min = 0,
    @MaxPerMatchv5_Max = MIN(CASE WHEN cs.MaxPerMatch5 = 0 THEN NULL ELSE cs.MaxPerMatch5 END), 
    
    @MaxPerMatchv8_Min = 0,
    @MaxPerMatchv8_Max = MIN(CASE WHEN cs.MaxPerMatch8 = 0 THEN NULL ELSE cs.MaxPerMatch8 END), 

    @MaxPerMatchv10_Min = 0,
    @MaxPerMatchv10_Max = MIN(CASE WHEN cs.MaxPerMatch10 = 0 THEN NULL ELSE cs.MaxPerMatch10 END), 
    
    @MaxPerMatchv11_Min = 0,
    @MaxPerMatchv11_Max = MIN(CASE WHEN cs.MaxPerMatch11 = 0 THEN NULL ELSE cs.MaxPerMatch11 END), 
	--
    
    @MaxPerMatchv99_Min = 0,
    @MaxPerMatchv99_Max = MIN(CASE WHEN cs.MaxPerMatch99 = 0 THEN NULL ELSE cs.MaxPerMatch99 END),
    
	@MaxPerMatchv1MP_Min = 0,
    @MaxPerMatchv1MP_Max = MIN(CASE WHEN cs.MaxPerMatch1MP = 0 THEN NULL ELSE cs.MaxPerMatch1MP END),
    	
    @MaxPerMatchv99MP_Min = 0,
    @MaxPerMatchv99MP_Max = MIN(CASE WHEN cs.MaxPerMatch99MP = 0 THEN NULL ELSE cs.MaxPerMatch99MP END)
    
FROM 
    dbo.custinfo AS cs WITH (NOLOCK) 
    INNER JOIN dbo.custinfo AS ci WITH (NOLOCK) ON (cs.CustID = ci.Recommend OR cs.CustID = ci.MRecommend OR cs.CustID = ci.SRecommend)
WHERE ci.custid = @CustID

SELECT 
    Ci.username, 
    ISNULL(Ci.maxpermatch, 0) AS maxpermatch,
    ISNULL(ci.maxpermatch2, 0) AS maxpermatchv2,
    ISNULL(ci.maxpermatch3, 0) AS maxpermatchv3,
    ISNULL(ci.maxpermatch5, 0) AS maxpermatchv5,
    ISNULL(ci.maxpermatch8, 0) AS maxpermatchv8,
    ISNULL(ci.maxpermatch10, 0) AS maxpermatchv10,
    ISNULL(ci.maxpermatch11, 0) AS maxpermatchv11,
    ISNULL(ci.maxpermatch99, 0) AS maxpermatchv99,
	ISNULL(ci.maxpermatch1MP, 0) AS maxpermatchv1MP,
    ISNULL(ci.maxpermatch99MP, 0) AS maxpermatchv99MP,
    ISNULL(exchange.minbet, 0) AS defaultminbet,

    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.minbet ELSE 0 END), 0) AS minbet,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.maxbet ELSE 0 END), 0) AS maxbet,
    
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.minbet ELSE 0 END), 0) AS MinBetv2,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv2,
    
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.minbet ELSE 0 END), 0) AS MinBetv3,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv3,

    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.minbet ELSE 0 END), 0) AS MinBetv5,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv5,

    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.minbet ELSE 0 END), 0) AS MinBetv8,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv8,

    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.minbet ELSE 0 END), 0) AS MinBetv10,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv10,

    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.minbet ELSE 0 END), 0) AS MinBetv11,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv11,
    
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.minbet ELSE 0 END), 0) AS MinBetv99,
    ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv99,
    
	
    ISNULL(MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=1 THEN cs.minbet ELSE 0 END), 0) AS MinBetv1MP,
    ISNULL(MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=1 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv1MP,
	
    ISNULL(MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.minbet ELSE 0 END), 0) AS MinBetv99MP,
    ISNULL(MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.maxbet ELSE 0 END), 0) AS MaxBetv99MP,
    
    ISNULL(@MinBet_Max, 0) AS MinBet_Max,
    ISNULL(@MaxBet_Min, 0) AS MaxBet_Min,
    ISNULL(@MaxPerMatch_Min, 0) AS MaxPerMatch_Min,
    ISNULL(@MaxPerMatch_Max, 0) AS MaxPerMatch_Max,
    
    ISNULL(@MinBetv2_Max, 0) AS MinBetv2_Max,    
    ISNULL(@MaxBetv2_Min, 0) AS MaxBetv2_Min,    
    ISNULL(@MaxPerMatchv2_Min, 0) AS MaxPerMatchv2_Min,    
    ISNULL(@MaxPerMatchv2_Max, 0) AS MaxPerMatchv2_Max,    
    
    ISNULL(@MinBetv3_Max, 0) AS MinBetv3_Max,    
    ISNULL(@MaxBetv3_Min, 0) AS MaxBetv3_Min,    
    ISNULL(@MaxPerMatchv3_Min, 0) AS MaxPerMatchv3_Min,    
    ISNULL(@MaxPerMatchv3_Max, 0) AS MaxPerMatchv3_Max,

    ISNULL(@MinBetv5_Max, 0) AS MinBetv5_Max,    
    ISNULL(@MaxBetv5_Min, 0) AS MaxBetv5_Min,    
    ISNULL(@MaxPerMatchv5_Min, 0) AS MaxPerMatchv5_Min,    
    ISNULL(@MaxPerMatchv5_Max, 0) AS MaxPerMatchv5_Max,

    ISNULL(@MinBetv8_Max, 0) AS MinBetv8_Max,    
    ISNULL(@MaxBetv8_Min, 0) AS MaxBetv8_Min,    
    ISNULL(@MaxPerMatchv8_Min, 0) AS MaxPerMatchv8_Min,    
    ISNULL(@MaxPerMatchv8_Max, 0) AS MaxPerMatchv8_Max,

    ISNULL(@MinBetv10_Max, 0) AS MinBetv10_Max,    
    ISNULL(@MaxBetv10_Min, 0) AS MaxBetv10_Min,    
    ISNULL(@MaxPerMatchv10_Min, 0) AS MaxPerMatchv10_Min,    
    ISNULL(@MaxPerMatchv10_Max, 0) AS MaxPerMatchv10_Max,

    ISNULL(@MinBetv11_Max, 0) AS MinBetv11_Max,    
    ISNULL(@MaxBetv11_Min, 0) AS MaxBetv11_Min,    
    ISNULL(@MaxPerMatchv11_Min, 0) AS MaxPerMatchv11_Min,    
    ISNULL(@MaxPerMatchv11_Max, 0) AS MaxPerMatchv11_Max,

    
    ISNULL(@MinBetv99_Max, 0) AS MinBetv99_Max,    
    ISNULL(@MaxBetv99_Min, 0) AS MaxBetv99_Min,    
    ISNULL(@MaxPerMatchv99_Min, 0) AS MaxPerMatchv99_Min,    
    ISNULL(@MaxPerMatchv99_Max, 0) AS MaxPerMatchv99_Max,
    
	ISNULL(@MinBetv1MP_Max, 0) AS MinBetv1MP_Max,    
    ISNULL(@MaxBetv1MP_Min, 0) AS MaxBetv1MP_Min,    
    ISNULL(@MaxPerMatchv1MP_Min, 0) AS MaxPerMatchv1MP_Min,    
    ISNULL(@MaxPerMatchv1MP_Max, 0) AS MaxPerMatchv1MP_Max,
	
    ISNULL(@MinBetv99MP_Max, 0) AS MinBetv99MP_Max,    
    ISNULL(@MaxBetv99MP_Min, 0) AS MaxBetv99MP_Min,    
    ISNULL(@MaxPerMatchv99MP_Min, 0) AS MaxPerMatchv99MP_Min,    
    ISNULL(@MaxPerMatchv99MP_Max, 0) AS MaxPerMatchv99MP_Max
    
    
FROM dbo.CustInfo AS ci WITH (NOLOCK)
    INNER JOIN dbo.Dep_CustSetting AS cs WITH (NOLOCK) on ci.custid = cs.custid
    INNER JOIN dbo.Dep_CustSetting3rd cs3 WITH (NOLOCK) on cs.custid = cs3.custid
    INNER JOIN dbo.exchange WITH (NOLOCK) ON Ci.currency=exchange.exchangeid
WHERE Ci.custid=@CustID
GROUP BY
    Ci.username, 
    Ci.maxpermatch,
    ci.maxpermatch2,
    ci.maxpermatch3,
    ci.maxpermatch5,
    ci.maxpermatch8,
    ci.maxpermatch10, 
    ci.maxpermatch11, 
    ci.maxpermatch99,
	ci.maxpermatch1MP,
    ci.maxpermatch99MP,
    exchange.minbet


GO 
