USE [bodb_licensee]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_LicenseeProduct3rdSel_active] 
	@LicenseeID INT = 0
	, @ProductPrefix VARCHAR(10) = ''
	, @Langkey VARCHAR(10) = 'en-US'
AS
/*
Created: Henry@20110410
Task: Get Product3rd of a Licensee
DB: DB052.bodb_licensee
Original:  
	
Revisions:
	- 20111122@Henry: Add filter @ProductPrefix + default values
	- 20150407@Winnie: Add ProductId
	- 20151019@Jim: clone sp from Lrf_LicenseeProduct3rdSel
	 
*/
SET NOCOUNT ON
SET @ProductPrefix = LTRIM(RTRIM(@ProductPrefix))

SELECT lp.LicenseeID
	, l.LicenseeName
	, p.ProductName
	, p.ProductPrefix
	, p.Productid
	, lp.Comm
	, lp.Winloss
FROM LicenseeProduct3rd lp(NOLOCK)
INNER JOIN Licensees l(NOLOCK)
	ON lp.LicenseeID = l.LicenseeID
INNER JOIN Product3rd p(NOLOCK)
	ON lp.Productid = p.ProductID
WHERE (
		@LicenseeID = 0
		OR (
			@LicenseeID <> 0
			AND l.LicenseeID = @LicenseeID
			)
		)
	AND (
		@ProductPrefix = ''
		OR (
			@ProductPrefix <> ''
			AND p.ProductPrefix = @ProductPrefix
			)
		)

 
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeProduct3rdSel_active] TO [bodbLicenseeNet]  
GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeProduct3rdSel_active] TO [vnteam]  
 
 
