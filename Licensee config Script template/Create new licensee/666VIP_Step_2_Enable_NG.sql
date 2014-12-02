-- Number game
USE [bodb_Licensee]
GO

DECLARE @TempLicensee AS TABLE (ID int IDENTITY(1,1),LicenseeID int)
DECLARE @LicenseeID int, @i int, @Max int

INSERT INTO @TempLicensee (LicenseeID)
SELECT l.LicenseeID
FROM Licensees l WITH (NOLOCK)
WHERE licenseename IN ('666VIP')

SET @i = 1
SELECT @Max = Max(ID) FROM @TempLicensee
SELECT @Max

WHILE @i <= @Max
BEGIN
	SELECT @LicenseeID = LicenseeID FROM @TempLicensee WHERE ID=@i

	--LicenseeProduct3rd
	IF NOT EXISTS(SELECT 1 FROM LicenseeProduct3rd WHERE ProductID=2 AND LicenseeID=@LicenseeID )
	BEGIN
		INSERT INTO LicenseeProduct3rd (LicenseeID,ProductID,Comm,Winloss)
		SELECT @LicenseeID as LicenseeID,2 as ProductID,0 as Comm,1 as Winloss
	END
	
	--LicenseeFunctions
	DELETE FROM LicenseeFunctions WITH (ROWLOCK,UPDLOCK) WHERE LicenseeID = @LicenseeID AND FunctionId = 23
	INSERT INTO LicenseeFunctions (licenseeID,FunctionId) 
	SELECT @LicenseeID,23
	
	--LicenseeUserFunctions
	DELETE FROM LicenseeUserFunctions WITH (ROWLOCK,UPDLOCK)
	WHERE LicenseeId = @LicenseeID AND FunctionId = 23
	
	INSERT INTO LicenseeUserFunctions(UserId,FunctionId,LicenseeId)
	SELECT UserId,23,@LicenseeID
	FROM LicenseeUserFunctions WITH (NOLOCK)
	WHERE LicenseeId  = @LicenseeID AND FunctionId = 1 --total bets

	SELECT @i = @i + 1
END
