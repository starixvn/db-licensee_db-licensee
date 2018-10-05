/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="1" isNested="1"></info>*/

CREATE FUNCTION [dbo].[Lrf_f_EncodeXMLValue_Main](@value NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
/* 
	Created:20181005@Amanda
    Task: Replace special characters
    Original [DBEXT].[bodb_Licensee].[dbo].[Lrf_f_EncodeXMLValue] 
    DB: DBCUST.bodb_Licensee
    
    Revisions:
		- 20181005@Amanda: Clone function from DBEXT.bodb_Licensee [RedmineId: #99855]

*/

BEGIN
	/*
		# &amp; refers to an ampersand (&) 
		# &lt; refers to a less-than symbol (<) 
		# &gt; refers to a greater-than symbol (>) 
		# &quot; refers to a double-quote mark (") 
		# &apos; refers to an apostrophe (')	
	*/
		
	SET @value = REPLACE(@value, '&', '&amp;')
	SET @value = REPLACE(@value, '<', '&lt;')
	SET @value = REPLACE(@value, '>', '&gt;')
	SET @value = REPLACE(@value, '"', '&quot;')
	SET @value = REPLACE(@value, '', '&apos;')
	
	RETURN @value
END
GO