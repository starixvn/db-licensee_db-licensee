
ALTER FUNCTION  [dbo].[Lrf_f_StringSplit] ( @string NVARCHAR( MAX), @splitter CHAR( 1) )
RETURNS @res TABLE ( id INT PRIMARY KEY, rank INT, val NVARCHAR( MAX) )
AS
 /*
	Created: 20140612@Victor
	Task : Create String Split function that can work with string over 4000 characters
	DB: DBEXT.bodb02
	Revisions:	
*/
BEGIN
     IF SUBSTRING ( @string, LEN ( @string), 1)<>@splitter
          SET @string= @string+@splitter
     DECLARE @start INT, @word NVARCHAR(MAX), @charindex INT, @i INT
     SET @i=1
     SET @start=1
     SET @charindex= CHARINDEX( @splitter, @string, @start)
     WHILE (@charindex <> 0)BEGIN
          SET @word= SUBSTRING( @string, @start, @charindex - @start)
          SET @start= @charindex +1
          SET @charindex= CHARINDEX( @splitter, @string, @start)
          INSERT INTO @res  VALUES ( @start, @i, @word)
          SET @i=@i+1
     END
     RETURN
END
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_StringSplit] TO [vnteam]
GO
GRANT SELECT ON [dbo].[Lrf_f_StringSplit] TO [bodbLicenseeNet]
GO