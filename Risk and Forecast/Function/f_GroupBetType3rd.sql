/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[f_GroupBetType3rd] ()
RETURNS TABLE
RETURN

/*
	Created: 20180308@Kos
	Task: Get grouped bettype for 3rd products
	DB: DBAGE.bodb02, DBEXT.bodb02, DBACC.bodb02

	Revisions:
		- 20180308@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
*/

	-- Grouped bettype for Betradar Virtual Basketball
	SELECT 2703 AS Bettype, 2703 AS GroupTypeId		-- Over/Under
	UNION ALL
	SELECT 2803, 2703

	UNION ALL
	SELECT 2704, 2704		-- 1H Over/Under
	UNION ALL
	SELECT 2704, 2804

	UNION ALL
	SELECT 2705, 2705		-- Handicap
	UNION ALL
	SELECT 2705, 2805

	UNION ALL
	SELECT 2706, 2706		-- 1H Handicap
	UNION ALL
	SELECT 2706, 2806
GO



GRANT SELECT ON [dbo].[f_GroupBetType3rd] TO [bodbDownlineNet]
GO
GRANT SELECT ON [dbo].[f_GroupBetType3rd] TO [bodbDownlineNetView]
GO
GRANT SELECT ON [dbo].[f_GroupBetType3rd] TO [bodbAdminNet]
GO
