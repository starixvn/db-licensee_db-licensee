
USE bodb_licensee
GO

/*
	Created:	20170327@Harper
	Support:	#73997: Uwoniwin - Setup new licensee

	- Site Name: Uwoniwin

	- Boping API

	- Product: Sportsbook, Virtual Sports, Number Game, AG, GD (don't put in data service yet), 
		ALLBET (DBA will arrange), RNG Casino, Macau Games (DBA will arrange), Keno, GG Fishing (DBA will arrange) and BA.

	- Currency: MYR, USD, IDR and UUS
*/

-- Create new licensee
EXEC [DBA_Lrf_CreateNewLicensee]
	@LicenseeName   		='Uwoniwin'
	,@SuperWildCard  	 	= 'UwoniwinSuper%'
	,@ResellerName   	  	= 'Boping' 
	,@IsSpecial      	 	= 0
	,@ProductCode	  	 	= 'SB'
	,@SystemisActive 	  	= ''
	,@IsAllowedDW 		   	= 0
	,@IsOfferLas		    = 0
	,@IsAllowMemberComm     = 1
	,@IsAllowWLbyLeague	    = 0
	,@IsDeposit				= 1 
	,@IsPullService			= 0
GO

-- Offer Product List
DECLARE @LicenseeId INT
		,@ResellerID INT

SELECT @LicenseeiD = LicenseeId
FROM dbo.Licensees WITH (NOLOCK)
WHERE LicenseeName ='Uwoniwin'	
 
SELECT @ResellerID = ResellerID
FROM dbo.LicenseeReseller  WITH (NOLOCK)
WHERE LicenseeId = @LicenseeId
	 AND ResellerID <> 3 -- startlit
 
SELECT @LicenseeId LicenseeID ,	 @ResellerID ResellerID

EXEC [dbo].[DBA_Lrf_OfferProduct]
	@ResellerID		= @ResellerID,
	@LicenseeId  	= @LicenseeId,
	@ProductCode  	= 'VS,NG,AGC,GD,AB,CS,VB,KN,FW,BA',
	@EffectiveDate	= '',
    @IsPullService = 0 -- don't put in data service yet
	
GO
