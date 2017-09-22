USE bodb_licensee
GO

/*
	Created: 20170815@Harper
	Support: #81529: Heaven - Enable RNG
*/

DECLARE @LicenseeID INT,
		@ResellerID INT

-- Lucky88

SELECT @LicenseeID = LicenseeID
FROM dbo.Licensees WITH (NOLOCK)
WHERE LicenseeName = 'Heaven' 

SELECT @ResellerID = ResellerID
FROM dbo.LicenseeReseller WITH (NOLOCK)
WHERE LicenseeID = @LicenseeID AND ResellerID <> 3 

SELECT @LicenseeID LicenseeID ,	 @ResellerID ResellerID

EXEC [dbo].[DBA_Lrf_OfferProduct]
	@ResellerID		= @ResellerID,
	@LicenseeId  	= @LicenseeID,
	@ProductCode  	= 'CS', -- RNG Casino
	@EffectiveDate	= ''