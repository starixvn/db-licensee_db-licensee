-- Virtual Sports
USE [bodb_Licensee]
GO

DECLARE @TempLicensee AS TABLE (ID INT IDENTITY(1,1),LicenseeID INT)
DECLARE @LicenseeID INT
		,@i INT
		,@Max INT
		,@ResellerId INT
		 

INSERT INTO @TempLicensee (LicenseeID)
SELECT l.LicenseeID
FROM Licensees l WITH (NOLOCK)
WHERE licenseename IN ('67Bet')

SET @i = 1
SELECT @Max = Max(ID) FROM @TempLicensee

WHILE @i <= @Max
BEGIN
	SELECT @LicenseeID = LicenseeID FROM @TempLicensee WHERE ID = @i
	SELECT @ResellerId = ResellerId
	FROM dbo.LicenseeReseller WITH(NOLOCK) 
	WHERE LicenseeId = @LicenseeID
	
	--LicenseeProduct3rd
	IF NOT EXISTS(SELECT 1 FROM LicenseeProduct3rd WHERE ProductID = 5 AND LicenseeID = @LicenseeID )
	BEGIN
		INSERT INTO LicenseeProduct3rd (LicenseeID,ProductID,Comm,Winloss,EffectiveDate)
		SELECT @LicenseeID as LicenseeID,5 as ProductID,0 as Comm,1 as Winloss , NULL AS EffectiveDate
	END
	
	SELECT @i = @i + 1
END

IF NOT EXISTS (SELECT 1 FROM dbo.OA_FunctionLicensees WITH (NOLOCK)
						WHERE resellerid = @resellerid 
						AND LicenseeID = @LicenseeID
						AND FunctionId IN (16)
				)
BEGIN 
	INSERT INTO OA_FunctionLicensees
	SELECT functionid, @resellerid, @LicenseeID
	FROM OA_Functions (NOLOCK)
	WHERE FunctionID IN 
		(16 --Virtual Sports
		)
END

