ALTER PROCEDURE [dbo].[Lrf_CustomerUpdUserSearch]
	@LicenseeID INT,
	@UserID INT,
	@search VARCHAR(50)
AS 
/*
Created: 20110309@Henry
Task : For updating Licensee Quick search
DB: DB052.bodb_Licensee
Original: 

Revisions:
   
Param's Explanation:

*/
SET NOCOUNT ON
IF NOT EXISTS (SELECT userid FROM custsearch (NOLOCK) WHERE LicenseeId=@LicenseeID AND userid = @userid AND username=@search)
BEGIN
	--Insert
	INSERT INTO custsearch(LicenseeId,userid, username, searchcount)
	VALUES (@LicenseeID,@userid, @search, 0)	
END
ELSE
BEGIN
	--Update count
		UPDATE custsearch WITH (ROWLOCK,UPDLOCK)
		SET [searchcount] = [searchcount] + 1
			
		WHERE LicenseeId=@LicenseeID AND userid = @userid AND username=@search
END

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdUserSearch] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerUpdUserSearch] TO [vnteam]