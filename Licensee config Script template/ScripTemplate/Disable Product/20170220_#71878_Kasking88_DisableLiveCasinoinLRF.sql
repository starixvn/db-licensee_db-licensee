USE bodb_licensee
GO

/*
	Created: 20170220@Harper
	Support #71878: Kasking88 - Disable Live Casino in LRF
*/

DECLARE @LicenseeID INT,
		@ProductID INT

SELECT @LicenseeID = LicenseeID
FROM dbo.Licensees (NOLOCK)
WHERE LicenseeName = 'Kasking88'

SELECT @ProductID = Productid
FROM dbo.Product3rd (NOLOCK)
WHERE ProductName = 'Live Casino'

SELECT *
FROM dbo.LicenseeProduct3rd (NOLOCK)
WHERE LicenseeID = @LicenseeID AND ProductID = @ProductID

DELETE dbo.LicenseeProduct3rd
WHERE ProductID = @ProductID
	AND LicenseeID = @LicenseeID
