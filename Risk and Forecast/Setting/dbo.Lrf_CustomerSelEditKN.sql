SET QUOTED_IDENTIFIER ON 
GO
CREATE PROCEDURE [dbo].[Lrf_CustomerSelEditKN]
	@custid INT
AS
/*
Created: 20140326@Jim
Task : Get Keno minbet maxbet information
DB: DBEXT.bodb02

Revisions:
		- 20140605@Jim: use table DBAGE.bodb02.dbo.gametype_tmp instead of bodb02.dbo.Gametype for testing on UAT env
		- 20140606@Jim: exclude bettype 1511,1513 in temporarity 
		- 20140714@Jim: support to active bettype 	1511,1513 (Kentucky,Michigan : #redmineID :17215)
		- 20150226@Jim: use Australia setting for all other Keno's countries. (RedmineID: #30921)
Param's Explanation:

*/

/*
	Lrf_CustomerSelEditKN @custid=1368168
*/
SET NOCOUNT ON

DECLARE @MinBet_Max MONEY
		, @MaxBet_Min MONEY
		, @MaxPerMatch_Min MONEY
		, @MaxPerMatch_Max MONEY
		, @MaxPerBallv161_Max MONEY
		,@recommend 		 INT
SELECT @recommend=recommend
FROM dbo.Customer WITH (NOLOCK)
WHERE roleid=1 
	AND CustID=@custid		
	
SELECT 
	@MinBet_Max = Max(CASE WHEN MinBet = 0 THEN NULL ELSE MinBet END), 
	@MaxBet_Min = Min(CASE WHEN MaxBet = 0 THEN NULL ELSE MaxBet END),
	@MaxPerMatch_Min = 0,
	@MaxPerMatch_Max = Min(CASE WHEN cg.MaxPerGameType = 0 THEN NULL ELSE cg.MaxPerGameType END)
	
FROM 
	dbo.CustGameType AS cg WITH (NOLOCK)
	INNER JOIN custinfo as ci WITH (NOLOCK) on cg.CustID=ci.custid
	---  INNER JOIN DBAGE.bodb02.dbo.gametype_tmp gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID	 -- for UAT env
	INNER JOIN bodb02.dbo.GameType gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID        -- for Prod env
WHERE ci.custid = @recommend		
	AND gt.IBCBetTypeID BETWEEN 1501 AND 1599
	AND gt.GameTypeID = 1 --Australia Acttab
SELECT 
	ci.UserName,
	cg.GameTypeID,
	gt.IBCBetTypeID,
	gt.GameTypeName,
	ISNULL(MAX(minbet ), 0) as MinBet,  
	ISNULL(MAX(maxbet ), 0) as MaxBet,  
	@MinBet_Max				as MinBet_Max,
	@MaxBet_Min				as MaxBet_Min ,
	MAX(MaxPerGameType)		as Maxpermatch,
	@MaxPerMatch_Min		as MaxPerMatch_Min,
	@MaxPerMatch_Max		as MaxPerMatch_Max
FROM CustGameType AS cg WITH (NOLOCK)
	INNER JOIN custinfo AS ci WITH (NOLOCK) ON cg.custid =ci.custid
	---INNER JOIN DBAGE.bodb02.dbo.gametype_tmp gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID	-- for UAT   env
	INNER JOIN bodb02.dbo.GameType gt WITH (NOLOCK) ON cg.GameTypeID = gt.GameTypeID			-- for Prod  env	
WHERE ci.custid = @custid
	AND gt.IsDisabled=0
	AND gt.IBCBetTypeID BETWEEN 1501 AND 1599
	AND gt.GameTypeID = 1 --Australia Acttab
	--AND gt.IBCBetTypeID NOT IN (1511,1513)  -- for temporarity 
GROUP BY ci.UserName,cg.GameTypeID,gt.IBCBetTypeID,gt.GameTypeName

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelEditKN] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_CustomerSelEditKN] TO [bodbLicenseeNet]
GO 
