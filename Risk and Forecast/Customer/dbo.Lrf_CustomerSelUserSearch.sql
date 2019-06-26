/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerSelUserSearch]
	@UserID		INT,
	@username VARCHAR(50),
	@AgentList		VARCHAR(MAX),
	@IsIncludeDormant BIT = 0
AS 

/*
Created: 20110309@Henry
Task : For Licensee Quick search
DB: DB052.bodb_Licensee
Original: 

Revisions:
   - 20121004@Jim: replace @currencyname input param by @currencyID
Param's Explanation:
	- 20110322@Henry: support 2 kinds of search (inside & outside)
	- 20120326@Henry: replace "where username like '%' + @username + '%'" (index scan) by "where username like @username + '%'" (index seek).
	- 20130619@Jim: Restrict permission of Licensee Users by currency	
	- 20141112@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
	- 20170228@Paul: remove @LicenseeID, @CurrencyID, @LicenseeType and add @AgentList due to logic change [Redmine: #71679]
	- 20180416@Joseph: Increase column size of table #tmpUsername (column username) to fix error [Redmine: #98294]
	- 20180810@Sophia: HA - remove LicenseeCustinfo table [Redmine: #99464]
	- 20180925@Joseph: Remove table CustSearch [Feature #99855]
	- 20181121@Joseph: Imlement search for dormant customer [#102680]
	- 20181219@Joseph: Force index hint IX_agent [#105409]
	- 20190626@Elodie: Use table variable to use IX_recommend index [#105409]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @TempAg(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	CREATE TABLE #tmpUsername (Username VARCHAR(50))
	INSERT INTO #tmpUsername (Username)
	SELECT top 10 SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) as username
	FROM bodb02.dbo.Customer c WITH (NOLOCK, INDEX(IX_agent))
		INNER JOIN @TempAg lc ON c.recommend = lc.custid AND c.currency = lc.Currency
	WHERE (c.username2 LIKE + '%$' + @Username + '%' OR c.username LIKE @Username + '%') AND c.RoleId = 1
	ORDER BY username

	IF (@IsIncludeDormant = 1)
	BEGIN
		SELECT TOP 10 username
		FROM (
			SELECT username from #tmpUsername
			UNION
			SELECT TOP 10 SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) as username
			FROM bodb02.dbo.Dep_Customer_Archived c WITH (NOLOCK)
				INNER JOIN @TempAg lc ON c.recommend = lc.custid 
			WHERE c.username2 LIKE + '%$' + @Username + '%' OR c.username LIKE @Username + '%'
			ORDER BY username
			) as customer
		ORDER BY username
	END
	ELSE
	BEGIN
		SELECT username from #tmpUsername
	END

	DROP TABLE #tmpUsername

END

GO