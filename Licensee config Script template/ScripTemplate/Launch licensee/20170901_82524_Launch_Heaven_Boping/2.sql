USE bodb_licensee
GO

/*
	Created: 20170901@Harper
	Support: #82524: Heaven - Launch new licensee

	Licensee Name: Heaven   
	Licensee Type: Boping licensee
	Launch product:
		SB: 15%
			Min Fee: 5000 EUR
			Waive: 3 months.
		VS: 15%
		NG: 15%		
		BA

	Launch date: 31-Aug-17
	
	Enable on:
		NAP
		LA
		LRF
		KPI
*/

------------------------------------------------- The first one

-- Lauch Licensee
EXEC dbo.DBA_Lrf_LaunchLicensee 
	@LicenseeName = 'Heaven', 
    @AffectedDate = '2017-08-31'
GO

-- Lauch Product
EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'Heaven', 
    @ProductCode = 'SB', 
    @EffectiveDate = '2017-08-31' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'Heaven', 
    @ProductCode = 'VS', 
    @EffectiveDate = '2017-08-31' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'Heaven', 
    @ProductCode = 'NG', 
    @EffectiveDate = '2017-08-31' 
GO

EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'Heaven', 
    @ProductCode = 'BA', 
    @EffectiveDate = '2017-08-31' 
GO

-- Active Licensee Sys
EXEC dbo.DBA_Lrf_ActiveLicenseeSystem 
	@LicenseeName = 'Heaven', 
    @SystemisActive = 'Accounting'
GO
