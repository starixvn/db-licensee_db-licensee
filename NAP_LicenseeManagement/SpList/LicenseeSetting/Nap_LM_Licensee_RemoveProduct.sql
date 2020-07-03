/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_RemoveProduct]
	@LicenseeNameList		VARCHAR(MAX),
	@ProductCode			VARCHAR(MAX),
	@IsRemovePullService	BIT = 0
AS
/*
	 Created: Amanda
	 Date: 2018-11-12
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181112@Amanda: Remove Product from Licensee [Redmine: #83584]
	  - 20181228@Amanda: Modify to allow remove multi products for multi licensees[Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tblLicensee AS TABLE(ID INT IDENTITY(1,1), LicenseeId INT, LicenseeName VARCHAR(50))
	DECLARE @tblProductPrefix AS TABLE(ID INT IDENTITY(1,1), ProductId INT, ProductCode VARCHAR(10))
	DECLARE @tblProductFunctions AS TABLE(ProductId INT, FunctionId INT, TypeId INT, IsParent BIT)
	DECLARE @tblParentFunction TABLE (Id INT IDENTITY(1,1), FunctionId INT)	

	DECLARE @LicenseeId		INT,
			@LicenseeName	VARCHAR(50), 
			@ProductName	VARCHAR(10),
			@n				INT, 
			@m				INT,
			@Error			VARCHAR(MAX) = ''

	--1-----------------------------------------* GET LICENSEE LIST *-------------------------------------
	INSERT INTO @tblLicensee (LicenseeName)
	SELECT DISTINCT val
	FROM CUSTDB.dbo.strSplit(@LicenseeNameList,',')

	UPDATE tl  
	SET tl.LicenseeId = l.LicenseeID
	FROM @tblLicensee tl 
	INNER JOIN dbo.Licensees l WITH (NOLOCK) ON tl.LicenseeName = l.LicenseeName

	IF EXISTS (SELECT 1 FROM @tblLicensee WHERE LicenseeId IS NULL)
	BEGIN
		SELECT @Error = 'Invalid licensee(s): ' + STUFF((
							SELECT ',' + LicenseeName
							FROM @tblLicensee
							WHERE LicenseeId IS NULL
						FOR XML PATH('')), 1, 1, '')
	END
	
	--2-----------------------------------------* GET PRODUCT LIST *-------------------------------------

	INSERT INTO @tblProductPrefix (ProductCode)
	SELECT DISTINCT val
	FROM CUSTDB.dbo.strSplit(@ProductCode,',')
   
	UPDATE a
	SET a.ProductId = b.ProductId
	FROM @tblProductPrefix a
	INNER JOIN dbo.Product3rd b WITH (NOLOCK) ON a.ProductCode = b.ProductPrefix

    UPDATE @tblProductPrefix
	SET ProductId = 0
	WHERE ProductCode = 'SB'

	SELECT @n = 1
		,@m = MAX(ID) FROM @tblProductPrefix
	WHILE (@n <= @m)
	BEGIN
		SELECT @ProductName = ProductCode FROM @tblProductPrefix WHERE ID = @n
    
		INSERT INTO @tblProductFunctions (ProductId, FunctionId, TypeId)
		EXEC Nap_LM_Function_GetByProduct @ProductCode = @ProductName
      
		SET @n = @n +1
	END
	
	UPDATE f
	SET f.IsParent = 1 
	FROM dbo.Functions af WITH (NOLOCK)
	INNER JOIN @tblProductFunctions f ON af.FunctionId = f.FunctionId
	WHERE f.TypeID IN (1, 3) AND af.ParentId = 0
	
	INSERT INTO @tblParentFunction(FunctionId)
	SELECT DISTINCT FunctionId
	FROM @tblProductFunctions
	WHERE IsParent = 1
	
	IF EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductId IS NULL)
	BEGIN
		IF ISNULL(@Error, '') <> ''
		BEGIN
			SET @Error = @Error + ';';
		END
	
		SELECT @Error = @Error + 'Invalid product(s): ' + STUFF((
							SELECT ',' + ProductCode
							FROM @tblProductPrefix
							WHERE ProductId IS NULL
						FOR XML PATH('')), 1, 1, '')
						
		DELETE @tblProductPrefix
		WHERE ProductId IS NULL
	END

	--3-----------------------------------------* DELETE PRODUCT *-------------------------------------
	SELECT @n = 1
		,@m = MAX(ID) FROM @tblLicensee
	WHILE (@n <= @m)
	BEGIN
		SELECT @LicenseeId = LicenseeId, @LicenseeName = LicenseeName
		FROM @tblLicensee
		WHERE ID = @n
	
		IF @LicenseeId IS NOT NULL
		BEGIN
			-- delete setting
			DELETE ld
			FROM dbo.LicenseeProduct3rd ld WITH(ROWLOCK)
			INNER JOIN @tblProductPrefix p ON ld.ProductID = p.ProductId
			WHERE ld.LicenseeID = @LicenseeId
			
			-- delete permission
			DELETE lf
			FROM dbo.LicenseeFunctions lf WITH(ROWLOCK)
			INNER JOIN @tblProductFunctions f ON f.FunctionId = lf.FunctionId
			WHERE lf.LicenseeId = @LicenseeId AND f.IsParent IS NULL AND f.TypeID IN (1,3) -- LRF
			
			DELETE luf
			FROM dbo.LicenseeUserFunctions luf WITH(ROWLOCK)
			INNER JOIN @tblProductFunctions f ON f.FunctionId = luf.FunctionId
			WHERE luf.LicenseeId = @LicenseeId AND f.IsParent IS NULL AND f.TypeID IN (1,3) -- LRF
			
			-- delete parent function			
			DECLARE @i INT, @j INT, @parentId INT
			SELECT @i = 1, @j = MAX(Id)
			FROM @tblParentFunction
			
			WHILE (@i <= @j)
			BEGIN
				SELECT @parentId = FunctionId
				FROM @tblParentFunction
				WHERE Id = @i
				
				IF NOT EXISTS (
					SELECT TOP(1) 1
					FROM dbo.LicenseeFunctions lf WITH (NOLOCK)
					INNER JOIN dbo.Functions f WITH (NOLOCK) ON lf.FunctionId = f.FunctionId
					WHERE lf.LicenseeId = @LicenseeId AND f.ParentId = @parentId
				)
				BEGIN
					DELETE lf
					FROM dbo.LicenseeFunctions lf WITH(ROWLOCK)
					WHERE lf.LicenseeId = @LicenseeId AND lf.FunctionId = @parentId
					
					DELETE luf
					FROM dbo.LicenseeUserFunctions luf WITH(ROWLOCK)
					WHERE luf.LicenseeId = @LicenseeId AND luf.FunctionId = @parentId
				END		
				
				SET @i = @i + 1
			END

			IF (@IsRemovePullService = 1 
				AND EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductCode = 'AGC')
				AND EXISTS (SELECT 1 FROM DBPTCS.bodb_PlaytechCS.dbo.LicIntegrationSetting WITH (NOLOCK) WHERE LicenseeID = @LicenseeId AND SettingName = 'AGCasino_VersionKey'))
			BEGIN
				EXEC [DBPTCS].[bodb_PlaytechCS].[dbo].[Nap_LM_PullServiceSetting]
					@LicenseeID = @LicenseeId, 
					@LicenseeName = @LicenseeName, 
					@SettingName = 'AGCasino_VersionKey',
					@IsDelete = 1
			END
			
			IF (@IsRemovePullService = 1 
				AND EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductCode = 'GD')
				AND EXISTS (SELECT 1 FROM DBPTCS.bodb_PlaytechCS.dbo.LicIntegrationSetting WITH (NOLOCK) WHERE LicenseeID = @LicenseeId AND SettingName = 'GoldDeluxe_VersionKey'))
			BEGIN
				EXEC [DBPTCS].[bodb_PlaytechCS].[dbo].[Nap_LM_PullServiceSetting]
					@LicenseeID = @LicenseeId, 
					@LicenseeName = @LicenseeName, 
					@SettingName = 'GoldDeluxe_VersionKey',
					@IsDelete = 1
			END
		END
		SET @n = @n + 1
	END
	
	SELECT @Error AS Error
END
GO