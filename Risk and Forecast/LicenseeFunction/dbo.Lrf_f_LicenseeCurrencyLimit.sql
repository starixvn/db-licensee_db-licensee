
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  User Defined Function dbo.Lrf_f_LicenseeCurrencyLimit    Script Date: 5/30/2016 11:30:31 AM ******/
CREATE FUNCTION [dbo].[Lrf_f_LicenseeCurrencyLimit] 
(
)
RETURNS  @tblLicenseeCurrency TABLE (LicenseeID INT, CurrencyID INT)
AS
/*
Created: 20160520@Jim
Task : Get LicenseeList whose not offer Currency SGD (#53882)
DB: DBLIC/bodb_licensees
 */

BEGIN
	DECLARE @CurrencyID INT
	SELECT @CurrencyID = ExchangeID 
	FROM bodb02.dbo.Exchange WITH (NOLOCK)
	WHERE Code ='SGD'

	INSERT INTO @tblLicenseeCurrency (LicenseeID, CurrencyID)
	SELECT LicenseeId,@CurrencyID AS CurrencyID
	FROM dbo.Licensees WITH (NOLOCK) 
	WHERE LicenseeName IN (
							'asiabet88'
							,'mansion88'
							,'12Bet'
							,'alog'
							,'DELA'
							,'Bezbet'
							,'Bodog'
							,'VCasia'
							,'ITCbet'
							,'Ae88'
							)
	RETURN						
END	

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_f_LicenseeCurrencyLimit] TO [vnteam]
GO 
 GRANT SELECT ON [dbo].[Lrf_f_LicenseeCurrencyLimit] TO [bodbLicenseeNet]
GO 
