-- Remove real playercomm for Spondemo

 /*
Created: 20141113@JIm
Task : turnoff real playercomm for spond demo
DB: DBLIC.bodb_licensee

Revisions:
    
Param's Explanation:
*/
USE bodb_licensee
GO

DECLARE @LicenseeId INT

SELECT @LicenseeId =l.LicenseeID
FROM dbo.Licensees l WITH (NOLOCK)
WHERE l.licenseename  IN 
						('spondemo'
						)

UPDATE dbo.Licensees WITH(ROWLOCK,UPDLOCK)
SET IsAllowedMemberComm = 0
WHERE LicenseeId = @LicenseeId

IF   EXISTS (SELECT 1 FROM dbo.LicenseeCustComm (NOLOCK) WHERE LicenseeID = @LicenseeID)
BEGIN 
	SELECT lcc.* 
		INTO #backup
	FROM dbo.LicenseeCustComm  lcc WITH (NOLOCK) 
		INNER JOIN 	dbo.LicenseeCustInfo  lci WITH (NOLOCK) ON  lcc.CustId = Lci.CustId 
	WHERE lcc.LicenseeId = @LicenseeId 
		  AND lci.Currency = 20	
	
	DELETE dbo.LicenseeCustComm
	WHERE LicenseeId = @LicenseeId
		AND CustID IN (SELECT CustId FROM #backup)
	SELECT * 
	FROM #backup
	--- DROP TABLE #backup
END

