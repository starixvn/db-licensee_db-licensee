/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet,Dot_Member" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_OfferProduct]
	@LicenseeName		VARCHAR(MAX),
	@ProductCode		VARCHAR(MAX),
	@EffectiveDate		DATE ='',
	@IsPullService		BIT = 1,
	@ErrMsg				NVARCHAR(MAX) = '' OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2018-11-12
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 Original: DBA_Lrf_OfferProduct
	 
	 Revisions:
	  - 20181112@Amanda: Offer Product from Licensee [Redmine: #83584]
	  - 20190102@Amanda: Modify to support offer multi products for multi licensees [Redmine: #83584]
	  - 20190419@Amanda: Move code from DBA_Lrf_OfferProduct to this [Redmine: #111321]
	  - 20191202@Amanda: Remove OA_ tables [Redmine: #119443]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tblProductPrefix		AS TABLE(ID INT IDENTITY(1,1), ProductId INT, ProductCode VARCHAR(10))  
	DECLARE @tblProductFunctions	AS TABLE(ProductId INT, FunctionId INT, TypeId INT)  
	DECLARE @tblLicensee			AS TABLE(ID INT IDENTITY(1,1), LicenseeId INT, LicenseeName VARCHAR(50))
	DECLARE @tblAdminUserID			AS TABLE (id INT IDENTITY(1,1), UserID INT)

	CREATE TABLE #tblLicenseeProduct (ProductId INT, ProductCode VARCHAR(10))
	CREATE TABLE #tblLicenseeFunction (FunctionId INT, TypeId INT)

	DECLARE  @ProductName	VARCHAR(10)  
			,@n				INT  
			,@m				INT
			,@tmpEffectiveDate	SMALLDATETIME = NULL
			,@Licensee		VARCHAR(50) 
			,@LicenseeId	INT
			,@ResellerId	INT
	
	IF ISNULL(@EffectiveDate,'') <> ''
	BEGIN
		SET @tmpEffectiveDate = @EffectiveDate
	END
	
	--1-----------------------------------------* GET LICENSEE LIST *------------------------------------- 

	INSERT INTO @tblLicensee (LicenseeName)
	SELECT DISTINCT val
	FROM CUSTDB.dbo.strSplit(@LicenseeName,',')

	UPDATE tl  
	SET tl.LicenseeId = l.LicenseeID
	FROM @tblLicensee tl 
	INNER JOIN dbo.Licensees l WITH (NOLOCK) ON tl.LicenseeName = l.LicenseeName


	IF EXISTS (SELECT 1 FROM @tblLicensee WHERE LicenseeId IS NULL)
	BEGIN
		SELECT @ErrMsg = 'Invalid licensee(s): ' + STUFF((
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
    
		INSERT INTO @tblProductFunctions
		EXEC Nap_LM_Function_GetByProduct @ProductCode = @ProductName
      
		SET @n = @n +1
	END
	
	DELETE pf
	FROM @tblProductFunctions pf
	INNER JOIN dbo.Functions fs WITH (NOLOCK) ON pf.FunctionId = fs.FunctionId
	WHERE (pf.TypeId = 1 OR pf.TypeId = 3) AND fs.IsActive = 0
	
	IF EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductId IS NULL)
	BEGIN
		IF ISNULL(@ErrMsg, '') <> ''
		BEGIN
			SET @ErrMsg = @ErrMsg + ';';
		END
	
		SELECT @ErrMsg = @ErrMsg + 'Invalid product(s): ' + STUFF((
							SELECT ',' + ProductCode
							FROM @tblProductPrefix
							WHERE ProductId IS NULL
						FOR XML PATH('')), 1, 1, '')

		DELETE @tblProductPrefix
		WHERE ProductId IS NULL
	END
	
	--3--------------------------------------* OFFER PRODUCT TO LICENSEE *----------------------------------
	IF EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductCode = 'BA')
	BEGIN 
		INSERT INTO @tblAdminUserID(UserID)
		SELECT userid FROM dbo.users WITH (NOLOCK)
		WHERE username IN ('justin','martin','anthony')
			AND UserRole = 'admin'
			AND isInternal = 0
			AND [Status] = 'Open'
	END

	SELECT @n = 1
		,@m = MAX(ID) FROM @tblLicensee
	WHILE (@n <= @m)
	BEGIN
		SELECT @LicenseeId = LicenseeId, @Licensee = LicenseeName
		FROM @tblLicensee
		WHERE ID = @n
		
		IF @LicenseeId IS NOT NULL
		BEGIN
			;WITH LicenseeProduct_CTE AS (
				SELECT ProductId   
				FROM dbo.LicenseeProduct3rd WITH (NOLOCK)   
				WHERE LicenseeId = @LicenseeId
			)
			INSERT INTO #tblLicenseeProduct(ProductId, ProductCode)
			SELECT p.ProductId, p.ProductCode
			FROM @tblProductPrefix p
			LEFT JOIN LicenseeProduct_CTE c ON p.ProductId = c.ProductID
			WHERE c.ProductID IS NULL

			INSERT INTO dbo.LicenseeProduct3rd(LicenseeID, ProductID, Comm, Winloss, EffectiveDate)
			SELECT @LicenseeId, ProductId, 0, 1, @tmpEffectiveDate
			FROM #tblLicenseeProduct

			-- 3.1 Open report on LRF/LAP
			INSERT INTO #tblLicenseeFunction(FunctionId, TypeId)
			SELECT DISTINCT f.FunctionId, f.TypeId
			FROM @tblProductFunctions f
			INNER JOIN #tblLicenseeProduct p ON f.ProductId = p.ProductId
			WHERE f.TypeId = 1 OR f.TypeId = 2 OR f.TypeId = 3

			INSERT INTO dbo.LicenseeFunctions (FunctionId, licenseeID)  
			SELECT f.FunctionId, @LicenseeId
			FROM #tblLicenseeFunction f
			WHERE f.TypeId = 1
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.LicenseeFunctions lf WITH (NOLOCK)
					WHERE lf.LicenseeId = @LicenseeId AND lf.FunctionId = f.FunctionId 
					)
			
			-- 3.2 LicenseeUserFunctions

			;WITH LicenseeUser_CTE AS (
				SELECT u.UserID
				FROM dbo.Users u WITH (NOLOCK)
				INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON u.UserID = lu.UserID
				WHERE lu.LicenseeID = @LicenseeId AND u.[Status] = 'Open' AND lu.isActive = 1
			)
			INSERT INTO dbo.LicenseeUserFunctions(UserId, FunctionId, LicenseeId)
			SELECT c.UserID, lf.FunctionId, @LicenseeId
			FROM LicenseeUser_CTE c
			CROSS JOIN #tblLicenseeFunction lf
			WHERE lf.TypeId = 1
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.LicenseeUserFunctions luf WITH (NOLOCK)
					WHERE luf.LicenseeId = @LicenseeId
						AND luf.FunctionId = lf.FunctionId
						AND luf.UserId = c.UserID
					)

			-- 3.4 PULL DATA INTO SERVICE
			IF EXISTS (SELECT 1 FROM #tblLicenseeProduct WHERE ProductCode = 'AGC') AND @IsPullService =1
			BEGIN   
				EXEC DBPTCS.bodb_PlaytechCS.[dbo].[Nap_LM_PullServiceSetting] @LicenseeID = @LicenseeId, @LicenseeName = @Licensee, @SettingName ='AGCasino_VersionKey'
			END  

			IF EXISTS (SELECT 1 FROM #tblLicenseeProduct WHERE ProductCode = 'GD') AND @IsPullService =1  
			BEGIN   
				EXEC DBPTCS.bodb_PlaytechCS.[dbo].[Nap_LM_PullServiceSetting] @LicenseeID = @LicenseeId, @LicenseeName = @Licensee, @SettingName ='GoldDeluxe_VersionKey'
			END

			-- 3.5 Config BA
			IF EXISTS (SELECT 1 FROM #tblLicenseeProduct WHERE ProductCode = 'BA')  
			BEGIN  
				IF NOT EXISTS(SELECT 1 FROM dbo.LicenseeReseller WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND ResellerID = 3)
				BEGIN
					-- Add Licensee to BA reseller  
					INSERT INTO dbo.LicenseeReseller (ResellerID,LicenseeID,TnxRate)
					VALUES (3, @LicenseeID,0.13)
				END
			
				-- Insert BA permission
				INSERT INTO dbo.LicenseeFunctions (FunctionId, licenseeID)  
				SELECT f.FunctionId, @LicenseeId
				FROM #tblLicenseeFunction f
				WHERE f.TypeId = 3
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.LicenseeFunctions lf WITH (NOLOCK)
					WHERE lf.LicenseeId = @LicenseeId AND lf.FunctionId = f.FunctionId 
					)
			
				-- Insert SpecialBA for justin,martin,anthony
				DECLARE @j		INT, 
						@k		INT,
						@UserId	INT

				SET @j = 1
				SELECT @k = MAX(id) FROM @tblAdminUserID

				WHILE @j <= @k
				BEGIN			
					SELECT @UserID = UserID FROM @tblAdminUserID WHERE id = @j

					IF EXISTS (SELECT 1 FROM dbo.LicenseeUser WITH (NOLOCK) WHERE licenseeid=@LicenseeId AND Userid=@UserId AND isActive = 1)
						AND NOT EXISTS (SELECT 1 FROM dbo.LicenseeUserFunctions WITH (NOLOCK) WHERE licenseeid=@LicenseeId AND Userid=@UserId AND Functionid = 54)
					BEGIN  
						INSERT INTO dbo.LicenseeUserFunctions(LicenseeId, UserId, FunctionId)
						SELECT @LicenseeId, @UserId, 54
					END
					
					SET @j = @j + 1
				END
			END

			TRUNCATE TABLE #tblLicenseeProduct
			TRUNCATE TABLE #tblLicenseeFunction
		END
		
		SET @n = @n +1
	END
	
	DROP TABLE #tblLicenseeProduct
	DROP TABLE #tblLicenseeFunction
END
GO