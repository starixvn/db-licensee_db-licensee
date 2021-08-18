ALTER PROCEDURE  [dbo].[Lrf_SelCurrency]		
	@LicenseeID INT	= 0	,
	@UserID INT
AS	
/*
Created: 20110315@Henry
Task : Get all the currency by a licensee
DB: DBLIC.bodb_Licensee


Revisions:
		 - 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
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
				DISTINCT Currency, CurrencyName 
			FROM    dbo.f_SelLicenseeCust(0)
			WHERE 
				LicenseeID = @LicenseeID
				AND CurrencyName <> 'EUR_GR'
		END
		ELSE
		BEGIN
			SELECT 
				DISTINCT Currency, CurrencyName 
			FROM    dbo.f_SelLicenseeCust(0)
			WHERE 
				LicenseeID = @LicenseeID
		END
	END
	ELSE
	BEGIN
	
		SELECT 
				DISTINCT lc.Currency, lc.CurrencyName 
			FROM    dbo.f_SelLicenseeCust(0) lc
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