/*<info serverAlias="DBCUST-bodb_licensee" executers="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[API_SiteBuilder_OfferProduct]
	@LicenseeID		INT,
	@ProductCode	VARCHAR(MAX),
	@EffectiveDate	DATE ='',
	@IsPullService	BIT = 1,
	@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS

/*
	Created: 20240705@Eden  
	Task : SiteBuider --> Offer product on Licensee DB for New Licensee 
	DB: DBCUST-bodb_Licensee
	Original sp: Nap_LM_Licensee_OfferProduct
	
	Revisions: 
		- 20240705@Eden  : Scale out DBCUST - Licensee Customer in GlobCustDB [redmine: #207474]  

	Param's Explanation: 
		Sample Format:
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @tblProductPrefix		AS TABLE(ID INT IDENTITY(1,1), ProductId INT, ProductCode VARCHAR(10))  
	DECLARE @tblProductFunctions	AS TABLE(ProductId INT, FunctionId INT, TypeId INT)  

	CREATE TABLE #tblLicenseeProduct (ProductId INT, ProductCode VARCHAR(10))
	CREATE TABLE #tblLicenseeFunction (FunctionId INT, TypeId INT)

	DECLARE  @ProductName	VARCHAR(10)
			,@tmpEffectiveDate	SMALLDATETIME = NULL
			,@ResellerId	INT
			,@n				INT
			,@m				INT

	IF ISNULL(@EffectiveDate,'') <> ''
	BEGIN
		SET @tmpEffectiveDate = @EffectiveDate
	END

	IF NOT EXISTS (SELECT 1 FROM Licensees WITH(NOLOCK) WHERE LicenseeID = @LicenseeID)
	BEGIN
		SELECT @ErrMsg = 'Invalid licensee'
	END

	INSERT INTO @tblProductPrefix (ProductCode)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ProductCode, ',')

	UPDATE a
	SET a.ProductId = b.ProductId
	FROM @tblProductPrefix a
		INNER JOIN dbo.Product3rd b WITH (NOLOCK) ON a.ProductCode = b.ProductPrefix

	UPDATE @tblProductPrefix
	SET ProductId = 0
	WHERE ProductCode = 'SB'

	SELECT @n = 1
		,@m = MAX(ID) FROM @tblProductPrefix

	WHILE @n <= @m
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

	DROP TABLE #tblLicenseeProduct
	DROP TABLE #tblLicenseeFunction
END
GO
