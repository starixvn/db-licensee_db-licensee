USE bodb02
GO
CREATE PROCEDURE [dbo].[LRF_MicroGamingWinloss_Bettype] 
	@TypeID BIT =0
AS 
/*  Created: Jim
	Date: 2015-07-28
    Task : MicroGaming Win Loss report 
    DB: DBEXT.bodb02  
    Revisions:  
		 20150921@Jim: support RNG bettype
	Param's Explanation:  
	  + @TypeID: 0: All
				 1: generic game
				 2: branded game
*/ 
	BEGIN
		;WITH cte_kind
		AS (
			SELECT TypeID Bettype,
				 CASE WHEN TypeID IN (2001,2002,2003,2004) THEN 1
					  WHEN TypeID IN (2009) THEN 3
					  WHEN TypeID IN (2005,2006,2007) THEN 2
					  WHEN TypeID IN (2008) THEN 4
				      ELSE 0
					  END TypeID
				,CASE WHEN TypeID IN (2001,2002,2003,2004 ) THEN 'Live Casino Generic Games'
					  WHEN TypeID IN (2009) THEN 'RNG Generic Games'
					  WHEN TypeID IN (2005,2006,2007) THEN 'Live Casino Branded Games'
					  WHEN TypeID IN (2008) THEN 'RNG Branded Games'
				      ELSE ''
					  END TypeName		
			FROM dbo.bettype WITH (NOLOCK) 
			WHERE typeID BETWEEN 2001 AND 2099
			
			)
		SELECT  Bettype
				,TypeID
				,TypeName
		FROM cte_kind
		WHERE @TypeID = 0 OR (@TypeID =1 AND TypeId=1) OR (@TypeID =2 AND TypeId=2)
			
	END
GO
GRANT EXECUTE ON [dbo].[LRF_MicroGamingWinloss_Bettype] TO [bodbLicenseeNet]  
GO
GRANT EXECUTE ON [dbo].[LRF_MicroGamingWinloss_Bettype] TO [vnteam]  
 