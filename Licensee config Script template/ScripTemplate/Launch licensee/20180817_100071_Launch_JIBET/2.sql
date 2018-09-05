USE bodb_licensee
GO



/*
	Created: 20180817@Harper
	Support: #100071: [JIBET] New Licensee Launch (Boping API)

	Licensee Name: JIBET        
	Licensee Type: Boping API licensee
	Launch product: Sportsbook, Virtual Sports x2, Number Game, BA, Cashout.
	Terms: Min EURO 5000 with 3 month waiver
	Launch date :  Aug 15, 2018

	Enable on:
		  » NAP Report
		  » LRF
		  » LA		 
*/
------------------------------------------------- The first one

-- Lauch Licensee
EXEC dbo.DBA_Lrf_LaunchLicensee 
	@LicenseeName = 'JIBET', 
    @AffectedDate = '2018-08-15'
GO

-- Lauch Product
-- 1.
EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'JIBET', 
    @ProductCode = 'SB', 
    @EffectiveDate = '2018-08-15' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'JIBET', 
    @ProductCode = 'NG', 
    @EffectiveDate = '2018-08-15' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'JIBET', 
    @ProductCode = 'VS', 
    @EffectiveDate = '2018-08-15' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'JIBET', 
    @ProductCode = 'VS2', 
    @EffectiveDate = '2018-08-15' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'JIBET', 
    @ProductCode = 'BA', 
    @EffectiveDate = '2018-08-15' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'JIBET', 
    @ProductCode = 'CO', 
    @EffectiveDate = '2018-08-15' 
GO

-- Active Licensee Sys
EXEC dbo.DBA_Lrf_ActiveLicenseeSystem 
	@LicenseeName = 'JIBET', 
    @SystemisActive = 'Accounting'
GO
