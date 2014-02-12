ALTER PROCEDURE [dbo].[Lrf_SportsGetAll]  
AS  
/*      
 Created : Henry      
 Date : 2011-12-29    
    Task : Get all sport types    
    DB  : DB052.bodb02      
       
    Revisions:        
    - 20120823@henry: remove Live Casino and virtual soccer  
    - 20130418@Scott: remove order by Sportname
	- 20140117@Florent: add new sport 154
*/    
  
BEGIN
	SET NOCOUNT ON
	SELECT Sporttype
		,SportName
	FROM Sports WITH (NOLOCK)
	WHERE sporttype <= 99 
	or sporttype=154
END
  
  

GO
GRANT EXECUTE ON [dbo].[Lrf_SportsGetAll] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SportsGetAll] TO [vnteam]   