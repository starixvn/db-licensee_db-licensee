/*<info serverAlias="DBEXT-bodb02" selecters="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[Lrf_f_GroupBettype] ()
RETURNS TABLE
RETURN

/*
	Created: 20240118@Evan
	Task:	Merge VS, VS2, VS3 as VS only
	DB:		DBEXT-bodb02
 	
	Revisions: 
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]

	Remark: Sportsbook + VS sport
*/
	WITH CTE_bettype AS
	(
		SELECT bt.typeid AS bettype, bt.DisplayedTypeId AS GroupTypeId
		FROM dbo.bettype bt WITH (NOLOCK)
		WHERE bt.typeid <> bt.DisplayedTypeId
			AND EXISTS (SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK) WHERE bt.typeid = s.bettype AND s.ProductId IN (1,5,27,77))
	)
	SELECT DISTINCT t.bettype, t.GroupTypeId
	FROM CTE_bettype b
		CROSS APPLY (
			SELECT bettype, GroupTypeId
			UNION ALL
			SELECT GroupTypeId, GroupTypeId
		) t
GO