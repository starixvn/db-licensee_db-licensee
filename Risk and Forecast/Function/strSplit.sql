/*<info serverAlias="DBCUST-CUSTDB,DBPOL-NAP_UserControl,DBCUST-bodb_Licensee,DBBAL-bodb02" selecters="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO
 
--deploy on DBCUST, DBCUST replicated servers, casino servers

ALTER FUNCTION [dbo].[strSplit](@string [nvarchar](MAX), @splitter [char](1))
RETURNS @res TABLE (
	[id] [int] NOT NULL,
	[rank] [int] NULL,
	[val] [nvarchar](MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)
) WITH EXECUTE AS CALLER
AS 
/*
		Created: Helen
		Date: 2018-03-13
		Task: Split string
		DB: DBCUST/CUSTDB, DBCUST/NAP_UserControl, DBCUST/bodb_Licensee
		
		Revisions:
			- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		Parameter's Explanation:
*/
begin
     if substring ( @string, len ( @string), 1)<>@splitter
          set @string= @string+@splitter
     declare @start int, @word nvarchar(max), @charindex int, @i int
     set @i=1
     set @start=1
     set @charindex= charindex( @splitter, @string, @start)
     while (@charindex <> 0)begin
          set @word= substring( @string, @start, @charindex - @start)
          set @start= @charindex +1
          set @charindex= charindex( @splitter, @string, @start)
          insert into @res  values ( @start, @i, @word)
          set @i=@i+1
     end
     return
end
