/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_GroupBettype] ()
RETURNS TABLE
RETURN

/*
	Created: 20141016@Sophia
	Task :	Get grouped bettype for Sporting Solution and BetRadar
	DB:		DBAGE/bodb02, DBEXT/bodb02, DBACC/bodb02
 	Revisions: 
		- 20150414@Sophia: Support BetRadar
		- 20151204@Bobby: Grouped 6 bettypes for PH AIO
		- 20160119@Sophia: PH AIO phase 1.2 [Redmine: #51029]
		- 20160426@Sophia: Change to in line Func-High Availability Step 4 [Redmine: #55746]
		- 20160712@Percy: PH AIO phase 2 [Redmine: #53152]
		- 20161007@Sophia: PHAIO Phase 2 , add more couple of Parent - Child [Redmine: #65406]
		- 20170919@Percy: PHAIO Phase 3, add 4 new bettypes 461 - 464 [RedmineID: #83356]
*/
	-------- Grouped bettype for Sporting Solution
	SELECT 153 AS Bettype, 153 AS GroupTypeId
	UNION ALL 
	SELECT 1308, 153

	UNION ALL 
	SELECT 154, 154
	UNION ALL 
	SELECT 1311, 154

	UNION ALL 
	SELECT 155, 155
	UNION ALL 
	SELECT 1316, 155

	UNION ALL 
	SELECT 156, 156 
	UNION ALL  
	SELECT 1312, 156

	UNION ALL 
	SELECT 1, 1 
	UNION ALL  
	SELECT 1303, 1

	UNION ALL 
	SELECT 2, 2 
	UNION ALL  
	SELECT 1305, 2		 

	UNION ALL 
	SELECT 3, 3 
	UNION ALL  
	SELECT 1306, 3	

	UNION ALL 
	SELECT 20, 20
	UNION ALL  
	SELECT 1301, 20	

	-------- Grouped bettype for BetRadar
	UNION ALL 
	SELECT 157, 2

	UNION ALL  
	SELECT 22, 22	
	UNION ALL  
	SELECT 160, 22	

	UNION ALL  
	SELECT 144, 144	
	UNION ALL  
	SELECT 163, 144	

	UNION ALL  
	SELECT 18, 18	
	UNION ALL  
	SELECT 178, 18	

	UNION ALL  
	SELECT 17, 17	
	UNION ALL  
	SELECT 183, 17	
	
	UNION ALL  
	SELECT 11, 11	
	UNION ALL  
	SELECT 199, 11	
	-------- Grouped bettypes for PH AIO
	UNION ALL
	SELECT * FROM ( VALUES
		 (159, 159), (406, 159) -- Exact Total Goals
		,(161, 161), (407, 161) -- Exact Home Team Goals
		,(171, 171), (408, 171) -- Winning Margin
		,(162, 162), (409, 162) -- Exact Away Team Goals
		,(151, 151), (410, 151) -- 1H Double Chance
		,(191, 191), (411, 191) -- 1H Draw No Bet
		,(  4,   4), (413,   4) -- Correct Score
		,( 30,  30), (414,  30) -- 1H Correct Score
		,(172, 172), (415, 172) -- Result And First Team To Score
		,(152, 152), (416, 152) -- Half Time/Full Time Correct Score
		,(188, 188), (427, 188) -- 1H Both Team to Score
		,(184, 184), (428, 184) -- 2H Odd/Even
		,(177, 177), (430, 177) -- 2H 1X2
		,(186, 186), (431, 186) -- 2H Double Chance
		,(185, 185), (432, 185) -- 2H Draw No Bet
		,(146, 146), (433, 146) -- 2H Both Teams To Score
		,(189, 189), (434, 189) -- Both Halves Over 1.5 Yes/No
		,(190, 190), (435, 190) -- Both Halves Under 1.5 Yes/No
		,(147, 147), (436, 147) -- Home To Score In Both Halves
		,(148, 148), (437, 148) -- Away To Score In Both Halves
		,(133, 133), (438, 133) -- Home To Win Both Halves
		,(134, 134), (439, 134) -- Away To Win Both Halves
		,(149, 149), (440, 149) -- Home To Win Either Half
		,(150, 150), (441, 150) -- Away To Win Either Half
		,(140, 140), (442, 140) -- Highest Scoring Half
		,(141, 141), (443, 141) -- Highest Scoring Half Home Team
		,(142, 142), (444, 142) -- Highest Scoring Half Away Team

		,(429, 429), (187, 429) -- Exact 2H Goals
		,(412, 412), (179, 412) -- Exact 1H Goals

		,(401, 401), (461, 401) -- Home Team Over/Under
		,(402, 402), (462, 402) -- Away Team Over/Under
		,(403, 403), (463, 403) -- 1H Home Team Over/Under
		,(404, 404), (464, 404) -- 1 H Away Team Over/Under

	) PH (Bettype, GroupTypeId)
GO