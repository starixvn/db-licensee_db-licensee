/*<info serverAlias="DBCUST-bodb_Licensee" selecters="bodbAdminNet,bodbLicenseeNet" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION  [dbo].[Lrf_f_StringSplit] ( @string NVARCHAR( MAX), @splitter CHAR( 1) )
RETURNS TABLE
AS
/*
	Created: 20180924@Elodie
	Task : Create String Split function that can work with string over 4000 characters
	Original: Lrf_f_StringSplit
	DB: DBCUST/bodb_Licensee

	Revisions:	
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20210816@Sophia: add DBBAL [Redmine: #154300]
		- 20220517@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831]  
*/
RETURN
	WITH TMP AS(
	 SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 0)) AS id, 
		value AS val 
	 FROM string_split(CASE WHEN CHARINDEX(@splitter, @string, LEN(@string)) = LEN(@string) AND @string <> '' THEN   SUBSTRING(@string, 1, LEN(@string) - 1) ELSE @string END,@splitter) 
	 )
	 SELECT id, id as [rank],val FROM tmp
GO