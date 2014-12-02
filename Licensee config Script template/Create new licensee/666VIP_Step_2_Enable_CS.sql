-- Casino
use [bodb_licensee]
go

DECLARE @TempLicensee AS TABLE (ID INT IDENTITY(1,1),LicenseeID INT)
DECLARE @LicenseeID INT, @i INT, @Max INT

INSERT INTO @TempLicensee (LicenseeID)
SELECT l.LicenseeID
FROM Licensees l WITH (NOLOCK)
WHERE licenseename IN ('666VIP')

SET @i = 1
SELECT @Max = Max(ID) FROM @TempLicensee

WHILE @i <= @Max
BEGIN
	SELECT @LicenseeID = LicenseeID FROM @TempLicensee WHERE ID=@i

	--LicenseeProduct3rd
	IF NOT EXISTS(SELECT 1 FROM LicenseeProduct3rd WHERE ProductID=6 and LicenseeID=@LicenseeID )
	BEGIN
		INSERT INTO LicenseeProduct3rd (LicenseeID,ProductID,Comm,Winloss)
		SELECT @LicenseeID as LicenseeID,6 as ProductID,0 as Comm,1 as Winloss
	END
		
	SELECT @i = @i + 1
END


