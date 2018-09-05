USE bodb_licensee
GO
DECLARE @CurrencyID INT
DECLARE @tblLicensee AS TABLE (LicenseeId INT)

SELECT @CurrencyID= exchangeid
FROM bodb02.dbo.Exchange WITH (NOLOCK)
WHERE Code='SGD'
 
INSERT INTO @tblLicensee (LicenseeId)
SELECT LicenseeID
FROM dbo.Licensees WITH (NOLOCK) 
WHERE LicenseeName IN ('asiabet88','mansion88','12Bet','alog','DELA','Bezbet','Bodog','VCasia','ITCbet','Ae88')

UPDATE dbo.CurrencyUser WITH (ROWLOCK,UPDLOCK)
SET isActive = 0
WHERE CurrencyID = @CurrencyID
	AND LicenseeID IN (SELECT LicenseeID FROM @tblLicensee)
