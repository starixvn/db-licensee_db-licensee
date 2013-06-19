ALTER PROCEDURE [dbo].[Lrf_CustomerSelUserSearch]
	@LicenseeID INT,
	@UserID		INT,
	@CurrencyID INT=0,
	@LicenseeType VARCHAR(100) = NULL,	
	@username VARCHAR(50)
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

*/

SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  bodb02.dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

IF  isnull(@LicenseeType,'') <> ''
BEGIN
	DECLARE @TempAg as TABLE (custid INT)
	
	INSERT INTO @TempAg (custid)
	SELECT custID FROM bodb_Licensee.dbo.LicenseeCust lc (NOLOCK) 
			INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
	WHERE 
		 [Description] = COALESCE(@LicenseeType,[Description])
		
	SELECT TOP 10 
				SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS Username,
				c.custid
		FROM LicenseeCustinfo c WITH (NOLOCK)
			INNER JOIN @TempAg t ON c.recommend = t.custid
		WHERE 
			 c.username2 LIKE + '%$' + @Username + '%' OR c.username LIKE @Username + '%'
		ORDER BY username
END
ELSE
BEGIN --this for quick search
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
			INNER JOIN licenseecust lc (NOLOCK) ON c.recommend = lc.custid
			INNER JOIN #Currency cy ON lc.LicenseeID=cy.LicenseeID AND lc.Currency=cy.CurrencyID
		WHERE 
			lc.licenseeid = @LicenseeID
			AND (c.username2 LIKE + '%$' + @Username + '%' OR c.username LIKE @Username + '%')
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
	DROP TABLE #Currency 
END	

	




GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSelUserSearch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSelUserSearch] TO vnteam
