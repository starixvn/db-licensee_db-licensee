USE [bodb02]
GO
ALTER VIEW [dbo].[LRF_view_bettype_SS]
AS
/*  
Created: 20141020@Jim
Task : Apply for the change in Sporting Solution structure
DB: DBEXT.bodb02
*/

SELECT  CASE
			WHEN typeid = 1303 THEN 1
			WHEN typeid = 1305 THEN 2
			WHEN typeid = 1306 THEN 3
			WHEN typeid = 1301 THEN 20
			WHEN typeid = 1308 THEN 153
			WHEN typeid = 1311 THEN 154
			WHEN typeid = 1316 THEN 155
			WHEN typeid = 1312 THEN 156
			ELSE typeid 
			END typeid 
	   ,typeID  AS bettypeID
FROM dbo.bettype AS b WITH (NOLOCK)
WHERE typeid IN (
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
				1324
				)
 
GO
GRANT SELECT ON [dbo].[LRF_view_bettype_SS] TO [bodbLicenseeNet]  
GO
GRANT VIEW DEFINITION ON [dbo].[LRF_view_bettype_SS] TO [vnteam] 


