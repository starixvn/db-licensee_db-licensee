/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBSID-bodb02" selecters="wsv_lap" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[Lrf_f_GroupBettype] ()
RETURNS TABLE
RETURN

/*
	Created: 20240118@Evan
	Task:	Merge VS, VS2, VS3 as VS only
	DB:		DBEXT-bodb02
 	
	Revisions: 
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20242901@Evan: Integrate VS4 [RedmineID: #199347]
		- 20241024@Kelvin: LAP - Integrate Betby (VS6), add DBBOF-bodb02,DBSID-bodb02 [RedmineID: #212446]
		- 20241107@Kelvin: Integrate VS5, add DBBOF-bodb02,DBSID-bodb02 [RedmineID: #207582]
		- 20250311@Kelvin: Integrate Virtual Sports 7 - Kiron [RedmineID: #219083]

	Remark: Sportsbook + VS sport
*/
	WITH CTE_bettype AS
	(
		SELECT bt.typeid AS bettype, bt.DisplayedTypeId AS GroupTypeId
		FROM dbo.bettype bt WITH (NOLOCK)
		WHERE bt.typeid <> bt.DisplayedTypeId
			AND EXISTS (SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK) WHERE bt.typeid = s.bettype AND s.ProductId IN (1,5,27,77,83,71,88,106))
	)
	SELECT DISTINCT t.bettype, t.GroupTypeId
	FROM CTE_bettype b
		CROSS APPLY (
			SELECT bettype, GroupTypeId
			UNION ALL
			SELECT GroupTypeId, GroupTypeId
		) t
GO