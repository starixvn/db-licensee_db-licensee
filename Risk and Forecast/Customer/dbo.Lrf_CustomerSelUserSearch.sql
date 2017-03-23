USE bodb_Licensee
GO

ALTER PROCEDURE [dbo].[Lrf_CustomerSelUserSearch]
	@UserID		INT,
	@username VARCHAR(50),
	@AgentList		VARCHAR(MAX)
AS 

/*
Created: 20110309@Henry
Task : For Licensee Quick search
DB: DB052.bodb_Licensee
Original: 

Revisions:
   - 20121004@Jim: replace @currencyname input param by @currencyID
Param's Explanation:
	20110322@Henry: support 2 kinds of search (inside & outside)
	20120326@Henry: replace "where username like '%' + @username + '%'" (index scan) by "where username like @username + '%'" (index seek).
	20130619@Jim: Restrict permission of Licensee Users by currency	
	20141112@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
	20170228@Paul: remove @LicenseeID, @CurrencyID, @LicenseeType and add @AgentList due to logic change [Redmine: #71679]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg		TABLE (CustId INT, Currency INT)

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
	
	DECLARE @tmpUsername TABLE(Username VARCHAR(30),SearchCount INT)

	INSERT INTO @tmpUsername (Username,SearchCount)
	SELECT top 10 Username, SearchCount
	FROM custsearch with (nolock) 
	WHERE  userid=@UserID AND username LIKE '%' + @username  + '%'
	ORDER BY [searchcount] DESC

	IF @@ROWCOUNT < 10
	BEGIN
		INSERT INTO @tmpUsername (username,searchcount)
		SELECT TOP 10 
				SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)), 
				-1 AS searchcount
		FROM LicenseeCustinfo c WITH (NOLOCK)
			INNER JOIN @TempAg lc ON c.recommend = lc.custid AND c.currency = lc.Currency
		WHERE (c.username2 LIKE + '%$' + @Username + '%' OR c.username LIKE @Username + '%')
		ORDER BY username
	END

	SELECT TOP 10 username 
	FROM 
		(	SELECT 
				username, searchcount
			FROM 
				@tmpUsername  
			WHERE 
				searchcount >= 0
			UNION ALL 
			SELECT 
				username, searchcount
			FROM  
				@tmpUsername 
			WHERE 
				username NOT IN (SELECT username FROM @tmpUsername WHERE searchcount >= 0) 
		)a
	ORDER BY searchcount DESC, username
	


END

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelUserSearch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelUserSearch] TO vnteam
