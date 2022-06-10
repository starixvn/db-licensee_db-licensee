/*<info serverAlias="DBCUST-bodb_licensee,DBCUST-CustDB,DBCUST-bodb_CustomerLog" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_SplitString](@string nvarchar(max),@splitter nvarchar(max))
/*          
	Created: 20200520@Helen          
	Task: LAP Tuning      
	DB: DBCUST-bodb_licensee,DBCUST-CustDB,DBCUST-bodb_CustomerLog : call string_split , built in function
		,DBLOG-bodb_CustomerLog : Keep old content
	Original:          
	       
	Revisions: 
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]      
		- 20220517@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831]  
	      
	Param's Explanation:    
	You need to use option: option (maxrecursion 0) at the statement if the lengh of string exceed 100 levels      
	        
*/        
RETURNS TABLE
AS
RETURN
     SELECT value AS val FROM string_split(@String,@splitter)  
GO



