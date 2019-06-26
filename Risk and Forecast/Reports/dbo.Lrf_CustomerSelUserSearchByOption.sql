/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerSelUserSearchByOption]	
	@username VARCHAR(50),
	@searchOption 	TINYINT,	
	@AgentList		VARCHAR(MAX)
AS 
/*
Created: 20190625@Johnson
Task : Suggest for user search 
DB: DBEXT/bodb02
Original:Lrf_CustomerSelUserSearch 

Revisions:
	- 20190625@Johnson: initial sp [redmine: #112658]

Parameter's explantions:	
	+ @searchOption: 1- Quick search
						 2- Match prefix
						 3- Match case	
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	SELECT top 10 SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) as username
	FROM bodb02.dbo.Customer c WITH (NOLOCK, INDEX(IX_agent))
		INNER JOIN #TempAg lc ON c.recommend = lc.custid AND c.currency = lc.Currency
	WHERE (@searchOption = 1 AND c.username2 LIKE '%$' + @Username) 
			OR (@searchOption = 2 AND c.username2 LIKE '%$' + @Username + '%') 
			OR (@searchOption = 3 AND c.username2 LIKE '%' + @Username + '%') 
			OR c.username LIKE @Username +'%')
		AND c.RoleId = 1	
	ORDER BY username
	
END
GO