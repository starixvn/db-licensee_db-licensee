-- BA
use [bodb_licensee]
go

DECLARE @TempLicensee AS TABLE (ID INT IDENTITY(1,1),LicenseeID INT)
DECLARE @LicenseeID INT, @i INT, @Max INT,@Rate MONEY
DECLARE @TempGroupID AS TABLE (id INT IDENTITY,GroupID INT)
DECLARE @TempUserID AS TABLE (id INT IDENTITY,UserID INT)
DECLARE @j INT, @maxID INT,@GroupID INT, @UserID INT

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
	IF NOT EXISTS(SELECT 1 FROM LicenseeProduct3rd WHERE ProductID=3 and LicenseeID=@LicenseeID )
	BEGIN
		INSERT INTO LicenseeProduct3rd (LicenseeID,ProductID,Comm,Winloss)
		SELECT @LicenseeID as LicenseeID,3 as ProductID,0 as Comm,1 as Winloss  ---BA
		---  Add licensee to BA Reseller and Grant BA permission 
		/*
		EXEC DBA_AddLicenseeToBA
			 @LicenseeId=@LicenseeID
		*/
		--Add Licensee to BA reseller
		SELECT @Rate = 0.13
		IF NOT EXISTS(SELECT 1 FROM	LicenseeReseller (NOLOCK) WHERE LicenseeID = @LicenseeID AND ResellerID = 3 )
		BEGIN
			--Add Licensee to BA reseller
			INSERT INTO LicenseeReseller (ResellerID,LicenseeID,TnxRate)
			VALUES (3,@LicenseeID,@Rate)
		END
		--insert Licensee to BA reseller to OA group (OA_GroupLicensees)
		INSERT INTO @TempGroupID(GroupID)
		SELECT DISTINCT GroupID FROM OA_GroupLicensees (NOLOCK)
		SET @j = 0
		SELECT @MAXID = MAX(id) FROM @TempGroupID
		
		WHILE @j < @MAXID
		BEGIN
			SET @j = @j + 1
			SELECT @GroupID = GroupID FROM @TempGroupID WHERE id = @j
			
			IF EXISTS (SELECT 1 FROM OA_GroupLicensees (NOLOCK) WHERE GroupID = @GroupID AND ResellerID <> 3 AND LicenseeID = @LicenseeID)
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM OA_GroupLicensees (NOLOCK) WHERE GroupID=@GroupID AND ResellerID = 3 AND LicenseeID = @LicenseeID)
				BEGIN
					INSERT INTO	OA_GroupLicensees (GroupID,ResellerID,LicenseeID) VALUES (@GroupID,3,@LicenseeID)
				END
			END 
			
 
		END
		--insert Licensee to BA reseller to OA Users (OA_UserLicensees)
		INSERT INTO @TempUserID(UserID)
		SELECT DISTINCT UserID FROM OA_UserLicensees (NOLOCK)

		SET @j = 0
		SELECT @MAXID = MAX(id) FROM @TempUserID

		WHILE @j < @MAXID
		BEGIN
			SET @j = @j + 1
			SELECT @UserID = UserID FROM @TempUserID WHERE id = @j
			
			IF EXISTS (SELECT 1 FROM OA_UserLicensees (NOLOCK) WHERE UserID = @UserID AND ResellerID <> 3 AND LicenseeID = @LicenseeID)
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM OA_UserLicensees (NOLOCK) WHERE UserID=@UserID AND ResellerID = 3 AND LicenseeID = @LicenseeID)
				BEGIN
					INSERT INTO	OA_UserLicensees (UserID,ResellerID,LicenseeID) VALUES (@UserID,3,@LicenseeID)
				END
			END 
		END
		
		--insert justin,martin,anthony to SpecialBA for this license
		DELETE FROM @TempUserID
		INSERT INTO @TempUserID(UserID)
		SELECT userid FROM users (nolock)
		WHERE username IN ('justin','martin','anthony')
			AND UserRole = 'admin' 
			AND isInternal = 0
		
		SET @j = 0
		SELECT @MAXID = MAX(id) FROM @TempUserID

		WHILE @j < @MAXID
		BEGIN
			SET @j = @j + 1
			SELECT @UserID = UserID FROM @TempUserID WHERE id = @j
			
			IF NOT EXISTS (SELECT 1 FROM [LicenseeUserFunctions] WHERE licenseeid=@LicenseeId AND Userid=@UserId AND Functionid = 54)
			BEGIN
				INSERT INTO [LicenseeUserFunctions](LicenseeId, UserId, FunctionId)
				SELECT @LicenseeId, @UserId, 54
			END
		END
	END
	
	SELECT @i = @i + 1
END


