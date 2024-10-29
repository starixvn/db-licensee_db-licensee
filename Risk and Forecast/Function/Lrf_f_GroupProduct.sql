/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBSID-bodb02" selecters="wsv_lap" isFunction="1" isNested="1"></info>*/
CREATE FUNCTION [dbo].[Lrf_f_GroupProduct]
(
)
RETURNS TABLE
AS

/*
	Created by Evan
	DB: DBEXT.bodb02
	Task: Merge VS, VS2, VS3 as VS only
	
	Revisions:
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20242901@Evan: Integrate VS4 [RedmineID: #199347]
		- 20241024@Kelvin: LAP - Integrate Betby (VS6) [RedmineID: #212446]
*/

RETURN
	SELECT 5 AS ProductId, 5 AS GroupProductId, CAST('VS' AS VARCHAR(10)) AS ProductPrefix, CAST('VS' AS VARCHAR(10)) AS GroupProductPrefix
	UNION ALL
	SELECT 27, 5, 'VS2' , 'VS' 
	UNION ALL
	SELECT 77, 5, 'LG' , 'VS' 
	UNION ALL
	SELECT 83, 5, 'VS4' , 'VS'
	UNION ALL
	SELECT 71, 5, 'VS6' , 'VS'

GO