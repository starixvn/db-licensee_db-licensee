/*<info serverAlias="DBCUST-bodb_Licensee" executers="" selecters="bodbLicenseeNet" viewers="vnteam" isFunction="1"></info>*/
USE bodb_Licensee
GO

ALTER FUNCTION  [dbo].[LAP_f_StringSplit] ( @string NVARCHAR( MAX), @splitter CHAR( 1) )
RETURNS @res TABLE ( id INT PRIMARY KEY, rank INT, val NVARCHAR( MAX) )
AS
/*
	Created: 20180924@Elodie
	Task : Create String Split function that can work with string over 4000 characters
	Original: Lrf_f_StringSplit
	DB: DBCUST/bodb_Licensee

	Revisions:	
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
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
