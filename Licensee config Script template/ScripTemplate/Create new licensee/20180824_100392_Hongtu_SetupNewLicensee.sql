USE bodb_licensee
GO

/*
	Created:	20180824@Harper
	Support:	#100392: Hongtu - New Boping API Integration - Setup a new licensee

	- Site Name: Hongtu  
 
	- Boping API licensee

	- Product:  Sportsbook, Cashout, Number Game, Virtual Sports, New Virtual Sports (BetRadar),  and BA

*/

-- Create new licensee
EXEC [DBA_Lrf_CreateNewLicensee]
	@LicenseeName   		= 'Hongtu'
	,@SuperWildCard  	 	= 'HongtuSuper%'
	,@ResellerName   	  	= 'Boping' -- Boping
	,@IsSpecial      	 	= 0
	,@ProductCode	  	 	= 'SB,CO,NG,VS,VS2,BA'
	,@SystemisActive 	  	= ''
	,@IsAllowedDW 		   	= 0
	,@IsOfferLas		    = 0
	,@IsAllowMemberComm     = 1
	,@IsAllowWLbyLeague	    = 0
	,@IsDeposit				= 1 
	,@IsPullService			= 0
GO
