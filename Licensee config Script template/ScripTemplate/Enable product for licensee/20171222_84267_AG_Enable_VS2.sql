USE bodb_licensee
GO

/*
	Created:	20171222@Harper
	Support:	AG - Set up VS2 [RedmineID: #84267]

	Enable VS2 in LRF & NAP for AG
*/

DECLARE @LicenseeID INT,
		@ResellerID INT,
		@n INT,@m INT
-- Licensee

DECLARE @tmpLicensee AS TABLE (ID INT IDENTITY(1,1), LicenseeID INT)
INSERT INTO @tmpLicensee (LicenseeID)
SELECT LicenseeID
FROM dbo.Licensees (NOLOCK)
WHERE LicenseeName IN ('AG')
	
SELECT @n = 1
	  ,@m = MAX(ID) FROM @tmpLicensee
WHILE (@n <= @m)	  
BEGIN
	SELECT @LicenseeID = LicenseeID FROM @tmpLicensee WHERE ID = @n

	SELECT @ResellerID = ResellerID
	FROM dbo.LicenseeReseller WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID AND ResellerID <> 3 

	SELECT @LicenseeID LicenseeID ,	 @ResellerID ResellerID

	EXEC [dbo].[DBA_Lrf_OfferProduct]
		@ResellerID		= @ResellerID,
		@LicenseeId  	= @LicenseeID,
		@ProductCode  	= 'VS2', -- Virtual Sport 2
		@EffectiveDate	= ''

	SET @n = @n + 1 	
END
