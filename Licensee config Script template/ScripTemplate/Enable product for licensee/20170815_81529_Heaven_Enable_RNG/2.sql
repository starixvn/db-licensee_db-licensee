USE bodb_licensee
GO

/*
	Created: 20170815@Harper
	Support: #81529: Heaven - Enable RNG
*/

DECLARE @tmpLicensee AS TABLE (ID INT IDENTITY(1,1), LicenseeID INT)
INSERT INTO @tmpLicensee (LicenseeID)
SELECT LicenseeID
FROM dbo.Licensees (NOLOCK)
WHERE LicenseeName IN ('Heaven')

DECLARE @tmpFunction AS TABLE (ID INT IDENTITY(1,1), FunctionID INT )
INSERT INTO @tmpFunction (FunctionID)
SELECT FunctionID 
FROM dbo.Functions WITH (NOLOCK)
WHERE Name IN ('Edit Bet Setting','Customer List')

DECLARE @tmplicenseeuserfunctions AS TABLE (UserID INT ,FunctionID INT,LicenseeID INT)

UPDATE l
SET EditBetSetting =1 
FROM licensees l WITH (NOLOCK)
	INNER JOIN @tmpLicensee t ON l.LicenseeId = t.LicenseeId

DECLARE @i INT
		,@maxID INT
		,@FunctionID INT
SELECT @i= 1 
		,@maxID = MAX(ID)	
FROM  @tmpFunction
WHILE (@i <= @maxID)		
	BEGIN
		SELECT @FunctionID = FunctionID
		FROM @tmpFunction
		WHERE ID = @i
		
		INSERT INTO dbo.licenseefunctions (LicenseeId,FunctionId)
		SELECT LicenseeID,@FunctionID
		FROM @tmpLicensee
		WHERE LicenseeID NOT IN (SELECT lf.LicenseeID FROM dbo.licenseefunctions lf WITH (NOLOCK) 
													INNER JOIN @tmpLicensee t ON lf.LicenseeId = t.LicenseeID
													WHERE lf.FunctionID = @FunctionID)
		INSERT INTO @tmplicenseeuserfunctions (UserID,FunctionID,LicenseeID)												
		SELECT UserId,@FunctionID,luf.LicenseeID
		FROM dbo.licenseeuserfunctions luf WITH (NOLOCK)
			INNER JOIN @tmpLicensee t ON luf.LicenseeID = t.LicenseeID
		 
		SET @i = @i +1
	END
	
INSERT INTO dbo.licenseeuserfunctions (UserID,FunctionID,LicenseeID)	
SELECT a.UserID,a.FunctionID,a.LicenseeID
FROM @tmplicenseeuserfunctions a
EXCEPT
SELECT b.UserID,b.FunctionID,b.LicenseeID
FROM licenseeuserfunctions b WITH (NOLOCK)
	INNER JOIN @tmpLicensee t ON b.LicenseeID = t.LicenseeID 
	