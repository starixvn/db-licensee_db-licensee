USE bodb_licensee
GO

/*
	Created: 20170719@Harper	
	Description: Toobet - Terminate licensee
*/

--- Uwin18
EXEC [dbo].[DBA_Lrf_ActiveLicenseeSystem]
	@LicenseeName  		= 'Toobet'
	,@SystemDeactivate    = 'Accounting'
GO

--EXEC [dbo].[DBA_Lrf_ActiveLicenseeSystem]
--	@LicenseeName  		='Uwin18'
--	,@SystemDeactivate    ='LRF'
--GO

--SELECT * FROM dbo.SystemLicensee
--WHERE LicenseeID IN (SELECT LicenseeID FROM Licensees WHERE LicenseeName = 'Toobet')
