/*<info serverAlias="DBCUST-bodb_licensee,DBCUST-CustDB,DBLOG-bodb_CustomerLog,DBCUST-bodb_CustomerLog" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_SplitString](@string nvarchar(max),@splitter nvarchar(max))
/*          
	Created: 20200520@Helen          
	Task: LAP Tuning      
	DB: DBCUST/bodb_licensee, DBCUST/CustDB        
	Original:          
	       
	Revisions: 
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]      
	      
	Param's Explanation:    
	You need to use option: option (maxrecursion 0) at the statement if the lengh of string exceed 100 levels      
	        
*/        
RETURNS TABLE
AS
RETURN
    WITH cte AS(
        SELECT	CAST(0 AS BIGINT) as idx1,CHARINDEX(@splitter, @string) idx2
        UNION ALL
        SELECT	idx2 + LEN(@splitter), CHARINDEX(@splitter, @string, idx2 + LEN(@splitter))
        FROM	cte
        WHERE	idx2 > 0
    )
    SELECT	SUBSTRING(@string,idx1,COALESCE(NULLIF(idx2,0),LEN(@string)+1)-idx1) as val
    FROM	cte

GO



