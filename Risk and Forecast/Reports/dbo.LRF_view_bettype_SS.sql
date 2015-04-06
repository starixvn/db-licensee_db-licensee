USE [bodb02]
GO

/****** Object:  View [dbo].[LRF_view_bettype_SS]    Script Date: 04/06/2015 14:18:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[LRF_view_bettype_SS]
AS
/*  
Created: 20141020@Jim
Task : Apply for the change in Sporting Solution structure
DB: DBEXT.bodb02
Revisions:
		- 20150406@Jim: support betradar bettype
Note:
	* bettypeId: bettype id which record in table bettype
	* typeid:   representative bettype id
*/

SELECT  CASE typeid
		WHEN	1303 THEN 1
		WHEN    1305 THEN 2
		WHEN    1306 THEN 3
		WHEN    1301 THEN 20
		WHEN    1308 THEN 153
		WHEN    1311 THEN 154
		WHEN    1316 THEN 155
		WHEN    1312 THEN 156
		-- betradar
		WHEN	157  THEN 2
		WHEN    160  THEN 22
		WHEN    163  THEN 144
		WHEN    178  THEN 18
		WHEN    183  THEN 17
		WHEN    199  THEN 11  
		ELSE typeid 
		END typeid 
	   ,typeID  AS bettypeID
FROM dbo.bettype AS b WITH (NOLOCK)
WHERE typeid IN (
				-- sporting solution
				1,
				2,
				3,
				20,
				153,
				154,
				155,
				156,
				1301,
				1302,
				1303,
				1305,
				1306,
				1308,
				1311,
				1312,
				1316,
				1317,
				1318,
				1324,
				--- betradar
				157,
				159,
				160,
				161,
				162,
				163,
				164,
				165,
				166,
				167,
				168,
				169,
				170,
				171,
				172,
				173,
				174,
				175,
				176,
				177,
				178,
				179,
				180,
				181,
				182,
				183,
				184,
				185,
				186,
				187,
				188,
				189,
				190,
				191,
				192,
				193,
				194,
				195,
				196,
				197,
				198,
				199,
				200,
				201,
				202,
				203,
				204,
				205,
				206,
				207,
				208,
				209,
				210,
				211,
				212,
				213,
				214,
				215,
				216,
				217
				
				)
 
-- select * from LRF_view_bettype_SS order by typeid
 
GO
GRANT SELECT ON [dbo].[LRF_view_bettype_SS] TO [bodbLicenseeNet]  
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_view_bettype_SS] TO [vnteam] 


