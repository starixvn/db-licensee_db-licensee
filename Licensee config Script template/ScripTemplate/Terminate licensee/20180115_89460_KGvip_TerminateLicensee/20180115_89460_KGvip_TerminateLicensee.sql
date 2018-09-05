USE bodb_licensee
GO

/*
	Created: 20180115@Harper	
	Description: [KGvip] Service Termination on Jan 12, 2018
*/

--- KGvip
UPDATE dbo.Licensees
SET IsActive = 0
WHERE LicenseeName = 'KGvip'

EXEC [dbo].[DBA_Lrf_ActiveLicenseeSystem]
	@LicenseeName  		= 'KGvip'
	,@SystemDeactivate    = 'OA'
GO

EXEC [dbo].[DBA_Lrf_ActiveLicenseeSystem]
	@LicenseeName  		='KGvip'
	,@SystemDeactivate    ='LRF'
GO

EXEC [dbo].[DBA_Lrf_ActiveLicenseeSystem]
	@LicenseeName  		='KGvip'
	,@SystemDeactivate    ='Accounting'
GO

--SELECT * 
--FROM dbo.SystemLicensee l
--	INNER JOIN dbo.Systems s ON s.id = l.SystemID
--WHERE LicenseeID IN (SELECT LicenseeID FROM Licensees WHERE LicenseeName = 'KGvip')
