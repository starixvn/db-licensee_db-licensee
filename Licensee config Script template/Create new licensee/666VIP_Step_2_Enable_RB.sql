-- Racing
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
	IF NOT EXISTS(SELECT 1 FROM LicenseeProduct3rd WHERE ProductID=1 and LicenseeID=@LicenseeID )
	BEGIN
		INSERT INTO LicenseeProduct3rd (LicenseeID,ProductID,Comm,Winloss)
		SELECT @LicenseeID as LicenseeID,1 as ProductID,0 as Comm,1 as Winloss
	END
	--LicenseeFunctions
	--- TotalBets/HorseRacing:
	DELETE FROM LicenseeFunctions WITH (ROWLOCK,UPDLOCK) WHERE LicenseeID = @LicenseeID AND FunctionId = 22
	INSERT INTO LicenseeFunctions (licenseeID,FunctionId) 
	SELECT @LicenseeID,22
	--Report/RacingCommission:
	DELETE FROM LicenseeFunctions WITH (ROWLOCK,UPDLOCK) WHERE LicenseeID = @LicenseeID AND FunctionId = 34
	INSERT INTO LicenseeFunctions (licenseeID,FunctionId) 
	SELECT @LicenseeID,34
	-- Report/DailyRacingWinLoss:
	DELETE FROM LicenseeFunctions WITH (ROWLOCK,UPDLOCK) WHERE LicenseeID = @LicenseeID AND FunctionId = 35
	INSERT INTO LicenseeFunctions (licenseeID,FunctionId) 
	SELECT @LicenseeID,35
	
	--LicenseeUserFunctions
	
	--- TotalBets/HorseRacing:
	DELETE FROM LicenseeUserFunctions WITH (ROWLOCK,UPDLOCK)
	WHERE LicenseeId = @LicenseeID AND FunctionId = 22
	
	INSERT INTO LicenseeUserFunctions(UserId,FunctionId,LicenseeId)
	SELECT UserId,22,@LicenseeID
	FROM LicenseeUserFunctions WITH (NOLOCK)
	WHERE LicenseeId  = @LicenseeID AND FunctionId = 1 --total bets
		
	--Report/RacingCommission:
	DELETE FROM LicenseeUserFunctions WITH (ROWLOCK,UPDLOCK)
	WHERE LicenseeId = @LicenseeID AND FunctionId = 34
	
	INSERT INTO LicenseeUserFunctions(UserId,FunctionId,LicenseeId)
	SELECT UserId,34,@LicenseeID
	FROM LicenseeUserFunctions WITH (NOLOCK)
	WHERE LicenseeId  = @LicenseeID AND FunctionId = 1 --total bets
	-- Report/DailyRacingWinLoss:
	DELETE FROM LicenseeUserFunctions WITH (ROWLOCK,UPDLOCK)
	WHERE LicenseeId = @LicenseeID AND FunctionId = 35
	
	INSERT INTO LicenseeUserFunctions(UserId,FunctionId,LicenseeId)
	SELECT UserId,35,@LicenseeID
	FROM LicenseeUserFunctions WITH (NOLOCK)
	WHERE LicenseeId  = @LicenseeID AND FunctionId = 1 --total bets
	
	SELECT @i = @i + 1
END


