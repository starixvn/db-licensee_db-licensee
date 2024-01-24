/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBSID-bodb02" selecters="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
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
*/

RETURN
	SELECT 5 AS ProductId, 5 AS GroupProductId, 'VS' AS ProductPrefix, 'VS' AS GroupProductPrefix
	UNION ALL
	SELECT 27, 5, 'VS2' , 'VS' 
	UNION ALL
	SELECT 77, 5, 'LG' , 'VS' 

GO