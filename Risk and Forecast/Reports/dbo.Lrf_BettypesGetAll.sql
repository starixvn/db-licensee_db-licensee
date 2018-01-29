/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetTypesGetAll]  
 @ShowSB BIT = 0,  
 @ShowRB BIT = 0,  
 @ShowNG BIT = 0,  
 @ShowBA BIT = 0,   
 @ShowVS BIT = 0,
 @ShowCS BIT = 0, --- RNG Casino  
 @ShowBG BIT = 0 --- Bingo  
  
AS  
/*      
 Created : Henry      
 Date : 2011-12-29   
    Task : Get all bettypes    
    DB  : DB052.bodb02      
       
    Revisions:        
    - 20120111@Henry: remove Total corners, 2nd HDP, 2nd Over/Under, Substitutes, Next Goal, Next Corner since they were not offered any more  
    - 20120823@Henry: add show Live Casino bettype  
    - 20120905@Jim:   add show Virtual  bettype  
    - 20130401@Scott: add more parameter @ShowCS,@ShowBG 
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
*/    
  
BEGIN    
	 SET NOCOUNT ON     
	 SELECT   
		typeid AS Bettype,  
		CASE WHEN typeid BETWEEN 81 AND 120 THEN 'NG - ' + typenamee ELSE typenamee END AS BettypeName  
	 FROM bettype WITH (NOLOCK)  
	 WHERE   
		  typeid NOT IN (11,17,18,19,22,23) --currently not offer Total corners, 2nd HDP, 2nd Over/Under, Substitutes, Next Goal, Next Corner  
		  AND  
		  (  
		   ((@ShowSB=1 OR @ShowBA=1) AND (typeid < 31 OR typeid BETWEEN 121 AND 999))  
		   OR  
		   (@ShowRB=1 AND typeid BETWEEN 31 AND 33)  
		   OR  
		   (@ShowNG=1 AND typeid BETWEEN 81 AND 120)       
		   OR   
		   (@ShowVS=1 AND typeid BETWEEN 1201 AND 1299)  
	  )  
	 ORDER BY BettypeName  
END  
GO

GRANT EXECUTE ON [dbo].[Lrf_BetTypesGetAll] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetTypesGetAll] TO [vnteam]    