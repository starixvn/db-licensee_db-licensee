ALTER PROCEDURE  [dbo].[Lrf_SelCurrency]		
	@LicenseeID INT	= 0	,
	@UserID INT
AS	
/*
Created: 20110315@Henry
Task : Get all the currency by a licensee
DB: DB052.bodb_Licensee


Revisions:
    
Param's Explanation:
@LicenseeID = 0: SELECT all currency
*/

SET NOCOUNT ON
BEGIN
	IF @LicenseeID <>0
	BEGIN
		IF @LicenseeID=1--12BET 
		BEGIN
			SELECT 
				distinct Currency, CurrencyName 
			FROM LicenseeCust (nolock)
			WHERE 
				LicenseeID = @LicenseeID
				AND CurrencyName <> 'EUR_GR'
		END
		ELSE
		BEGIN
			SELECT 
				distinct Currency, CurrencyName 
			FROM LicenseeCust (nolock)
			WHERE 
				LicenseeID = @LicenseeID
		END
	END
	ELSE
	BEGIN
	
		SELECT 
				distinct lc.Currency, lc.CurrencyName 
			FROM LicenseeCust lc (nolock)
			INNER JOIN LicenseeUser lu (nolock)
			ON lc.LicenseeID = lu.LicenseeID
			WHERE 
				lc.CurrencyName <> 'EUR_GR'
				AND lu.UserID = @UserID
	END

END

GO
GRANT EXECUTE ON [dbo].[Lrf_SelCurrency] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_SelCurrency] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelCurrency] TO [vnteam]