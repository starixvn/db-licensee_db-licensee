ALTER FUNCTION [dbo].[Lrf_f_EncodeXMLValue](@value NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
/* Created:20110414@Henry
    Task: Replace special characters
    Original [f_EncodeXMLValue] 
    DB: DB052.bodb_Licensee

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
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_EncodeXMLValue] TO [vnteam]