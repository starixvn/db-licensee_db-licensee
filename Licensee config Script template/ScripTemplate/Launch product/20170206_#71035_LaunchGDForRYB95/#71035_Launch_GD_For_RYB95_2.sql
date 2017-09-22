
USE bodb_licensee
GO

/*
	Created:	20170206@Harper
	Support:	#71035

	Boping API licensee RYB95 has launched GD Casino on January 26, 2017 
	Charge rate = 8%
*/

EXEC [dbo].[DBA_Lrf_LaunchProduct] 
	@LicenseeName = 'RYB95', -- varchar(10)
    @ProductCode = 'GD', -- varchar(100)
    @EffectiveDate = '2017-01-26' -- smalldatetime
GO

EXEC [dbo].[DBA_Lrf_ActiveLicenseeSystem]
	@LicenseeName  	  = 'RYB95',
	@SystemisActive  = 'Accounting'	