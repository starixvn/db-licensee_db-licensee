-- Virtual Sports
USE [bodb_Licensee]
GO

DECLARE @TempLicensee AS TABLE (ID int IDENTITY(1,1),LicenseeID int)
DECLARE @LicenseeID int
		,@i int
		,@Max int
		,@ResellerId INT

INSERT INTO @TempLicensee (LicenseeID)
SELECT l.LicenseeID
FROM Licensees l WITH (NOLOCK)
WHERE licenseename IN ('666VIP')

SET @i = 1
SELECT @Max = Max(ID) FROM @TempLicensee

WHILE @i <= @Max
BEGIN
	SELECT @LicenseeID = LicenseeID FROM @TempLicensee WHERE ID=@i
	SELECT @ResellerId=ResellerId
	FROM dbo.LicenseeReseller WITH(NOLOCK) 
	WHERE LicenseeId=@LicenseeID
	
	--LicenseeProduct3rd
	IF NOT EXISTS(SELECT 1 FROM LicenseeProduct3rd WHERE ProductID=5 AND LicenseeID=@LicenseeID )
	BEGIN
		INSERT INTO LicenseeProduct3rd (LicenseeID,ProductID,Comm,Winloss)
		SELECT @LicenseeID as LicenseeID,5 as ProductID,0 as Comm,1 as Winloss
	END
	
	SELECT @i = @i + 1
END

