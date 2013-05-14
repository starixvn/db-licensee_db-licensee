set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_LicenseeProduct3rdSel]
	@LicenseeID INT = 0,
	@ProductPrefix VARCHAR(10) = '',
	@Langkey VARCHAR(10)='en-US'
	
AS
/*
Created: Henry@20110410
Task: Get Product3rd of a Licensee
DB: DB052.bodb_licensee
Original:  
	
Revisions:
	- 20111122@Henry: Add filter @ProductPrefix + default values
*/
SET NOCOUNT ON

SET @ProductPrefix = LTRIM(RTRIM(@ProductPrefix))

SELECT 
	lp.LicenseeID,
	l.LicenseeName,
	p.ProductName,
	p.ProductPrefix,
	lp.Comm,
	lp.Winloss 

from
	LicenseeProduct3rd lp (nolock)
	inner join Licensees l (nolock) on lp.LicenseeID = l.LicenseeID
	inner join Product3rd p (nolock) on lp.Productid = p.ProductID
WHERE 
	(@LicenseeID=0 OR (@LicenseeID<>0 AND l.LicenseeID = @LicenseeID))
	AND
	(@ProductPrefix='' OR (@ProductPrefix<>'' AND p.ProductPrefix = @ProductPrefix))


GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeProduct3rdSel] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeProduct3rdSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeProduct3rdSel] TO [vnteam]
