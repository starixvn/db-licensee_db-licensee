USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Lrf_TotalBets_Sel14]	
	@PageSize	INT=50,
	@PageIndex	INT=0,
	@TotalRows	INT=0 OUTPUT,
	@AgentList	VARCHAR(MAX)
AS
/*
Created: 20101201@Henry
Task: Retrieve Total Bet values for First Goal/Last Goal.
DB: DB052.bodb02
Original: [Age_TotalBets_Sel14_Ag]
Revisions:
	- 201134@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID.
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140508@Kyan: add new bettype 1H FG/LG (127)
	- 20140718@Hannah: Change liveindicator datatype to INT to fix running live matches are not being showed at the top list (RedmineID:19136)
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150123@Jim: support base on Currency GBP
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]

Param's Explanation:
	+ @AgentList: xml structure
			<ROOT>
			<Agent AgentId="12345" Currency="3"/>  
			<Agent AgentId="12345" Currency="5"/>  
			</ROOT>
*/

SET NOCOUNT ON
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS Table
(
	showtime NVARCHAR (50),
	leagueid INT,
	matchcode NVARCHAR(50),
	liveindicator INT,
	matchid INT,
	homeID INT,
	awayID INT,
	livehomescore INT,
	liveawayscore INT,

	WinLost_HomeFG MONEY,
	WinLost_HomeFGUSD MONEY,
	WinLost_HomeFGEUR MONEY,
	WinLost_HomeFGGBP MONEY,
	--
	WinLost_HomeFG_ori MONEY,
	WinLost_HomeFGUSD_ori MONEY,
	WinLost_HomeFGEUR_ori MONEY,
	WinLost_HomeFGGBP_ori MONEY,
	
	WinLost_HomeLG MONEY,
	WinLost_HomeLGUSD MONEY,
	WinLost_HomeLGEUR MONEY,
	WinLost_HomeLGGBP MONEY,
	--
	WinLost_HomeLG_ori MONEY,
	WinLost_HomeLGUSD_ori MONEY,
	WinLost_HomeLGEUR_ori MONEY,
	WinLost_HomeLGGBP_ori MONEY,
	
	WinLost_AwayFG MONEY,
	WinLost_AwayFGUSD MONEY,
	WinLost_AwayFGEUR MONEY,
	WinLost_AwayFGGBP MONEY,
	--
	WinLost_AwayFG_ori MONEY,
	WinLost_AwayFGUSD_ori MONEY,
	WinLost_AwayFGEUR_ori MONEY,
	WinLost_AwayFGGBP_ori MONEY,
	
	WinLost_AwayLG MONEY,
	WinLost_AwayLGUSD MONEY,
	WinLost_AwayLGEUR MONEY,
	WinLost_AwayLGGBP MONEY,
	--
	WinLost_AwayLG_ori MONEY,
	WinLost_AwayLGUSD_ori MONEY,
	WinLost_AwayLGEUR_ori MONEY,
	WinLost_AwayLGGBP_ori MONEY,
	
	WinLost_NoGoal MONEY,
	WinLost_NoGoalUSD MONEY,
	WinLost_NoGoalEUR MONEY,
	WinLost_NoGoalGBP MONEY,
	--
	WinLost_NoGoal_ori MONEY,
	WinLost_NoGoalUSD_ori MONEY,
	WinLost_NoGoalEUR_ori MONEY,
	WinLost_NoGoalGBP_ori MONEY,
	
	WinLost_1HHomeFG MONEY,
	WinLost_1HHomeFGUSD MONEY,
	WinLost_1HHomeFGEUR MONEY,
	WinLost_1HHomeFGGBP MONEY,
	--
	WinLost_1HHomeFG_ori MONEY,
	WinLost_1HHomeFGUSD_ori MONEY,
	WinLost_1HHomeFGEUR_ori MONEY,
	WinLost_1HHomeFGGBP_ori MONEY,
	
	WinLost_1HHomeLG MONEY,
	WinLost_1HHomeLGUSD MONEY,
	WinLost_1HHomeLGEUR MONEY,
	WinLost_1HHomeLGGBP MONEY,
	--
	WinLost_1HHomeLG_ori MONEY,
	WinLost_1HHomeLGUSD_ori MONEY,
	WinLost_1HHomeLGEUR_ori MONEY,
	WinLost_1HHomeLGGBP_ori MONEY,
	
	WinLost_1HAwayFG MONEY,
	WinLost_1HAwayFGUSD MONEY,
	WinLost_1HAwayFGEUR MONEY,
	WinLost_1HAwayFGGBP MONEY,
	--
	WinLost_1HAwayFG_ori MONEY,
	WinLost_1HAwayFGUSD_ori MONEY,
	WinLost_1HAwayFGEUR_ori MONEY,
	WinLost_1HAwayFGGBP_ori MONEY,
	
	WinLost_1HAwayLG MONEY,
	WinLost_1HAwayLGUSD MONEY,
	WinLost_1HAwayLGEUR MONEY,
	WinLost_1HAwayLGGBP MONEY,
	--
	WinLost_1HAwayLG_ori MONEY,
	WinLost_1HAwayLGUSD_ori MONEY,
	WinLost_1HAwayLGEUR_ori MONEY,
	WinLost_1HAwayLGGBP_ori MONEY,
	
	WinLost_1HNoGoal MONEY,
	WinLost_1HNoGoalUSD MONEY,
	WinLost_1HNoGoalEUR MONEY,
	WinLost_1HNoGoalGBP MONEY,
	--
	WinLost_1HNoGoal_ori MONEY,
	WinLost_1HNoGoalUSD_ori MONEY,
	WinLost_1HNoGoalEUR_ori MONEY,
	WinLost_1HNoGoalGBP_ori MONEY,
	
	isNeutral BIT
)

INSERT INTO @Data
SELECT
		m.showtime, 
		m.leagueid,	
		m.matchcode,
		a.liveindicator,
		m.matchid,
		m.homeid,
		m.awayid,
		a.livehomescore,
		a.liveawayscore,	
		
		-- FG/LG
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_HomeFG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_HomeFGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_HomeFGEUR,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_HomeFGGBP,
		--
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake  END END) AS WinLost_HomeFG_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.USD END END) AS WinLost_HomeFGUSD_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.EUR END END) AS WinLost_HomeFGEUR_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.GBP END END) AS WinLost_HomeFGGBP_ori,
		
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_HomeLG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_HomeLGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_HomeLGEUR,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_HomeLGGBP,
		--
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake  END END) AS WinLost_HomeLG_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*e.USD   END END) AS WinLost_HomeLGUSD_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*e.EUR   END END) AS WinLost_HomeLGEUR_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*e.GBP   END END) AS WinLost_HomeLGGBP_ori,
		
		--
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_AwayFG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_AwayFGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_AwayFGEUR,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_AwayFGGBP,
		--
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake  END END) AS WinLost_AwayFG_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake* e.USD   END END) AS WinLost_AwayFGUSD_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*e.EUR  END END) AS WinLost_AwayFGEUR_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*e.GBP  END END) AS WinLost_AwayFGGBP_ori,
		
		
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_AwayLG,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_AwayLGUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_AwayLGEUR,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_AwayLGGBP,
		---
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake   END END) AS WinLost_AwayLG_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake* e.USD  END END) AS WinLost_AwayLGUSD_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake *e.EUR  END END) AS WinLost_AwayLGEUR_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake *e.GBP  END END) AS WinLost_AwayLGGBP_ori,
		
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_NoGoal,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_NoGoalUSD,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_NoGoalEUR,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_NoGoalGBP,
		--
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake END END) AS WinLost_NoGoal_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.USD   END END) AS WinLost_NoGoalUSD_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.EUR  END END) AS WinLost_NoGoalEUR_ori,
		SUM(CASE WHEN a.bettype = 14 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.GBP  END END) AS WinLost_NoGoalGBP_ori,
		
		--1H Total FG/LG
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HHomeFG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HHomeFGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HHomeFGEUR,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_1HHomeFGGBP,
		--
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake  END END) AS WinLost_1HHomeFG_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.USD END END) AS WinLost_1HHomeFGUSD_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.EUR END END) AS WinLost_1HHomeFGEUR_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.GBP END END) AS WinLost_1HHomeFGGBP_ori,
		
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HHomeLG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HHomeLGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HHomeLGEUR,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_1HHomeLGGBP,
		--
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake END END) AS WinLost_1HHomeLG_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake *e.USD  END END) AS WinLost_1HHomeLGUSD_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake *e.EUR  END END) AS WinLost_1HHomeLGEUR_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN stake *e.GBP  END END) AS WinLost_1HHomeLGGBP_ori,
		
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HAwayFG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HAwayFGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HAwayFGEUR,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_1HAwayFGGBP,
		--
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake  END END) AS WinLost_1HAwayFG_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*e.USD  END END) AS WinLost_1HAwayFGUSD_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*e.EUR  END END) AS WinLost_1HAwayFGEUR_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN stake*e.GBP  END END) AS WinLost_1HAwayFGGBP_ori,
		
		
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HAwayLG,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HAwayLGUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HAwayLGEUR,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_1HAwayLGGBP, 
		--
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake END END) AS WinLost_1HAwayLG_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*e.USD  END END) AS WinLost_1HAwayLGUSD_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*e.EUR  END END) AS WinLost_1HAwayLGEUR_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN stake*e.GBP  END END) AS WinLost_1HAwayLGGBP_ori, 

		
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END) ELSE -actual_stake END END) AS WinLost_1HNoGoal,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.USD ELSE -actual_stake*e.USD END END) AS WinLost_1HNoGoalUSD,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.EUR ELSE -actual_stake*e.EUR END END) AS WinLost_1HNoGoalEUR,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*(CASE WHEN odds<0 THEN 1 ELSE odds-1 END)*e.GBP ELSE -actual_stake*e.GBP END END) AS WinLost_1HNoGoalGBP,
		--
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake END END) AS WinLost_1HNoGoal_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.USD  END END) AS WinLost_1HNoGoalUSD_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.EUR  END END) AS WinLost_1HNoGoalEUR_ori,
		SUM(CASE WHEN a.bettype = 127 THEN CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN stake*e.GBP  END END) AS WinLost_1HNoGoalGBP_ori,
		
		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans a WITH (NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = a.matchid 	
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = a.currency
		INNER JOIN @TempAg ag ON a.recommend = ag.CustId AND a.currency = ag.Currency
	WHERE 		
		a.bettype in (14,127) AND -- FG/LG: 14, 1H FG/LG: 127
		a.ruben=0 AND
		a.statusID = 0 AND
		m.eventstatus = 'running'  AND
		a.tpositiontaking <>0
		
	GROUP BY
		a.liveindicator,
		m.homeid,
		m.awayid,
		m.matchid,
		m.matchcode,
		m.leagueid,
		a.livehomescore,
		a.liveawayscore,
		m.showtime,
		m.isNeutral
	ORDER BY
	m.matchcode

IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(matchid) FROM @Data
END

SELECT 
	c.*
FROM
(
	SELECT
		ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
		* FROM @Data
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd


SELECT 
	SUM(WinLost_HomeFG_ori) WinLost_HomeFG,
	SUM(WinLost_HomeFGUSD_ori) WinLost_HomeFGUSD,
	SUM(WinLost_HomeFGEUR_ori) WinLost_HomeFGEUR,
	SUM(WinLost_HomeFGGBP_ori) WinLost_HomeFGGBP,
	
	SUM(WinLost_HomeLG_ori) WinLost_HomeLG,
	SUM(WinLost_HomeLGUSD_ori) WinLost_HomeLGUSD,
	SUM(WinLost_HomeLGEUR_ori) WinLost_HomeLGEUR,
	SUM(WinLost_HomeLGGBP_ori) WinLost_HomeLGGBP,
	
	--
	SUM(WinLost_AwayFG_ori) WinLost_AwayFG,
	SUM(WinLost_AwayFGUSD_ori) WinLost_AwayFGUSD,
	SUM(WinLost_AwayFGEUR_ori) WinLost_AwayFGEUR,
	SUM(WinLost_AwayFGGBP_ori) WinLost_AwayFGGBP,
	
	SUM(WinLost_AwayLG_ori) WinLost_AwayLG,
	SUM(WinLost_AwayLGUSD_ori) WinLost_AwayLGUSD,
	SUM(WinLost_AwayLGEUR_ori) WinLost_AwayLGEUR,
	SUM(WinLost_AwayLGGBP_ori) WinLost_AwayLGGBP,
	--
	SUM(WinLost_NoGoal_ori) WinLost_NoGoal,
	SUM(WinLost_NoGoalUSD_ori) WinLost_NoGoalUSD,
	SUM(WinLost_NoGoalEUR_ori) WinLost_NoGoalEUR,
	SUM(WinLost_NoGoalGBP_ori) WinLost_NoGoalGBP,
	--
	SUM(WinLost_1HHomeFG_ori) WinLost_1HHomeFG,
	SUM(WinLost_1HHomeFGUSD_ori) WinLost_1HHomeFGUSD,
	SUM(WinLost_1HHomeFGEUR_ori) WinLost_1HHomeFGEUR,
	SUM(WinLost_1HHomeFGGBP_ori) WinLost_1HHomeFGGBP,
	
	--
	SUM(WinLost_1HHomeLG_ori) WinLost_1HHomeLG,
	SUM(WinLost_1HHomeLGUSD_ori) WinLost_1HHomeLGUSD,
	SUM(WinLost_1HHomeLGEUR_ori) WinLost_1HHomeLGEUR,
	SUM(WinLost_1HHomeLGGBP_ori) WinLost_1HHomeLGGBP,
	
	--
	SUM(WinLost_1HAwayFG_ori) WinLost_1HAwayFG,
	SUM(WinLost_1HAwayFGUSD_ori) WinLost_1HAwayFGUSD,
	SUM(WinLost_1HAwayFGEUR_ori) WinLost_1HAwayFGEUR,
	SUM(WinLost_1HAwayFGGBP_ori) WinLost_1HAwayFGGBP,
	
	--
	SUM(WinLost_1HAwayLG_ori) WinLost_1HAwayLG,
	SUM(WinLost_1HAwayLGUSD_ori) WinLost_1HAwayLGUSD,
	SUM(WinLost_1HAwayLGEUR_ori) WinLost_1HAwayLGEUR,
	SUM(WinLost_1HAwayLGGBP_ori) WinLost_1HAwayLGGBP,
	--
	SUM(WinLost_1HNoGoal_ori) WinLost_1HNoGoal,
	SUM(WinLost_1HNoGoalUSD_ori) WinLost_1HNoGoalUSD,
	SUM(WinLost_1HNoGoalEUR_ori) WinLost_1HNoGoalEUR,
	SUM(WinLost_1HNoGoalGBP_ori) WinLost_1HNoGoalGBP
FROM @Data	

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel14 ] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel14 ] TO [vnteam]
