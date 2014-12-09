USE bodb_licensee
GO
DECLARE @LicenseeID INT
DECLARE @tblFunctions AS TABLE (FunctionID INT)

INSERT INTO @tblFunctions (FunctionID )
SELECT FunctionID
FROM dbo.Functions WITH (NOLOCK)
WHERE Name IN ('WinLoss By League','Playtech Casino Win Loss')

SELECT @LicenseeID=LicenseeID
FROM dbo.Licensees WITH (NOLOCK)
WHERE LicenseeName='666VIP'
--- for checking
SELECT * FROM LicenseeFunctions WITH (NOLOCK)
	WHERE licenseeId=@LicenseeID
	AND FunctionID IN (SELECT FunctionID FROM @tblFunctions)
	
--- re-voke Function :'WinLoss By League','Playtech Casino Win Loss'
DELETE LicenseeFunctions
WHERE licenseeId=@LicenseeID
	AND FunctionID IN (SELECT FunctionID FROM @tblFunctions)
	