/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
GO
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
	- 20190926@Eden: 3rd party products - Remove InActive Products Phase 2 [Redmine: #118699]
*/    
  
BEGIN
	SET NOCOUNT ON
	SELECT Sporttype
		,SportName
	FROM Sports WITH (NOLOCK)
	WHERE sporttype <= 99 
END
  
GO
