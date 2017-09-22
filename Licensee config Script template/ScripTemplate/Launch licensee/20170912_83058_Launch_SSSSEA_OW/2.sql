USE bodb_licensee
GO

/*
	Created: 20170912@Harper
	Support: #83058: SSSSEA  - Launch new licensee

	Licensee Name: SSSSEA    
	Licensee Type: ONEworks licensee
	Launch product:
		SB: 15%
			Min Fee: 5000 EUR
			Waive: 3 months.
		VS: 15%
		NG: 15%
		BA		
		
	Launch date: 09-Sep-17
	
	Enable on:
		NAP
		LA
		LRF
		KPI
		OWA
*/

------------------------------------------------- The first one

-- Lauch Licensee
EXEC dbo.DBA_Lrf_LaunchLicensee 
	@LicenseeName = 'SSSSEA', 
    @AffectedDate = '2017-09-09'
GO

-- Lauch Product
EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'SSSSEA', 
    @ProductCode = 'SB', 
    @EffectiveDate = '2017-09-09' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'SSSSEA', 
    @ProductCode = 'VS', 
    @EffectiveDate = '2017-09-09' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'SSSSEA', 
    @ProductCode = 'NG', 
    @EffectiveDate = '2017-09-09' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'SSSSEA', 
    @ProductCode = 'BA', 
    @EffectiveDate = '2017-09-09' 
GO

-- Active Licensee Sys
EXEC dbo.DBA_Lrf_ActiveLicenseeSystem 
	@LicenseeName = 'SSSSEA', 
    @SystemisActive = 'Accounting'
GO
