/*<info serverAlias="DBCUST-bodb_licensee" executers="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_LM_Licensee_Insert_New]
	@LicenseeName			VARCHAR(50)
	, @SuperWildCard		VARCHAR(100) = ''
	, @LicenseeType			VARCHAR(50)
	, @IsSpecial			BIT = 0
	, @ProductCode			VARCHAR(MAX) = ''
	, @SystemisActive		VARCHAR(100) = ''
	, @IsAllowMemberComm	BIT = 0
	, @EffectiveDate		DATE = ''
	, @Description			VARCHAR(100) = NULL
	, @BrandName			VARCHAR(100) = ''
	, @CompanyName			VARCHAR(100) = ''
	, @ErrCode				INT = 0 OUTPUT
	, @ErrMsg				NVARCHAR(MAX) = '' OUTPUT
	, @LicenseeId			INT = 0 OUTPUT
AS
/*
	Created: 20240705@Eden  
	Task : SiteBuider --> Create new licensee setting on Licensee DB
	DB: DBCUST-bodb_Licensee
	Original sp: Nap_LM_Licensee_Insert
	
	Revisions: 
		- 20240705@Eden  : Scale out DBCUST - Licensee Customer in GlobCustDB [redmine: #207474]

	Param's Explanation: 
		Sample Format:
*/
BEGIN
	SET NOCOUNT ON;

	SET @LicenseeName = LTRIM(RTRIM(@LicenseeName))
	
	IF EXISTS (SELECT 1 FROM dbo.Licensees WHERE LicenseeName = @LicenseeName)
	BEGIN
		SELECT @ErrCode = 50100, @ErrMsg = 'Licensee Name already exists.'
		RETURN
	END

	--- DECLARE VARIABLE  
	DECLARE @AdminUser AS TABLE (
			id			INT IDENTITY(1, 1)
		,	UserID		INT
		,	Username	VARCHAR(50)
		)
	DECLARE @SpecialAdmin AS TABLE (
			id			INT IDENTITY(1, 1)
		,	UserID		INT
		,	Username	VARCHAR(50)
		)
	DECLARE @ResellerName		VARCHAR(50)
			, @tmpSuperWildCard	VARCHAR(100)
			, @ResellerID		INT
			, @SPErrMsg			NVARCHAR(MAX)
	DECLARE @Error AS TABLE (Msg NVARCHAR(MAX))

	IF (@LicenseeType = 'Zelianta')
	BEGIN
		SET @ResellerName = @LicenseeName
	END
	ELSE
	BEGIN
		SET @ResellerName = @LicenseeType
	END

	IF LTRIM(RTRIM(ISNULL(@SuperWildCard, ''))) = ''
	BEGIN
		SET @tmpSuperWildCard = @LicenseeName + 'Super'
	END
	ELSE
	BEGIN
		SET @tmpSuperWildCard = @SuperWildCard
	END
	
	--- CREATE LICENSEE
	BEGIN TRY
		DECLARE @AffectedDate DATETIME, @EditBetSetting BIT = 0
	
		IF ISNULL(@EffectiveDate, '') <> ''
		BEGIN
			SET @AffectedDate = @EffectiveDate 
		END
		
		IF @ResellerName IN ('Zelianta','Boping')
		BEGIN 
			SET @EditBetSetting =1 
		END
	
		SELECT @LicenseeID = MAX(LicenseeID) + 1
		FROM dbo.Licensees WITH (NOLOCK)

		IF @LicenseeID < 50000 
		BEGIN
			SELECT @LicenseeID = 50000
		END
	
		INSERT INTO dbo.Licensees
		(
			LicenseeID,
			LicenseeName,
			IsDeposit,
			[Description],
			BrandName,
			CompanyName,
			AffectedDate,
			EditBetSetting
		)
		VALUES
		(
			@LicenseeId,
			@LicenseeName,
			1,
			@Description,
			@BrandName,
			@CompanyName,
			@AffectedDate,
			@EditBetSetting
		)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50101
			, @ErrMsg = 'Fail to create licensee. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
		RETURN
	END CATCH
	--- END: CREATE LICENSEE
	
	--- CREATE AGENT
	BEGIN TRY
		SET @SPErrMsg = ''
		EXEC Nap_LM_Licensee_AddAgent_New 
			@LicenseeName		= @LicenseeName
			, @SuperWildCard	= @tmpSuperWildCard
			, @IsSpecial		= @IsSpecial
			, @ErrMsg			= @SPErrMsg OUTPUT

		INSERT INTO @Error (Msg)
		VALUES (@SPErrMsg)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50102
			, @ErrMsg = 'Fail to create licensee agents. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
		RETURN
	END CATCH
	--- END: CREATE AGENT
	
	--- ADD NEW LICENSEE CONFIG INTO SYSTEMLICENSEE
	BEGIN TRY
		INSERT INTO dbo.SystemLicensee (
			SystemID
			, LicenseeID
			, IsActive
		)
		SELECT s.ID
			, @LicenseeID AS LicenseeID
			, CASE 
					WHEN s.ID IN (1, 2) THEN 1 -- LRF, LA
					ELSE 0
				END AS IsActive
		FROM dbo.Systems s WITH (NOLOCK)
		WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.SystemLicensee sl WITH (NOLOCK)
				WHERE sl.LicenseeID = @licenseeid AND sl.SystemId = s.id
		)
	 
		IF ISNULL(@SystemisActive, '') <> ''
		BEGIN
			SET @SPErrMsg = ''
			EXEC Nap_LM_Licensee_ActivateSystem
					@LicenseeName	= @LicenseeName
				,	@SystemName		= @SystemisActive
				,	@ErrMsg			= @SPErrMsg OUTPUT
				
			INSERT INTO @Error (Msg)
			VALUES (@SPErrMsg)
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50103
			, @ErrMsg = 'Fail to create licensee systems. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
		RETURN
	END CATCH
	--- END: ADD NEW LICENSEE CONFIG INTO SYSTEMLICENSEE
	
	--- ADD RESELLER LICENSEE
	BEGIN TRY
		IF NOT EXISTS (
				SELECT 1
				FROM dbo.Resellers WITH (NOLOCK)
				WHERE ResellerName = @ResellerName
				)
		BEGIN
			INSERT INTO dbo.Resellers (
					ResellerName
				,	[Description]
				,	ResellerType
				)
			SELECT	@ResellerName
				,	NULL
				,	2
		END

		INSERT INTO dbo.LicenseeReseller (
				ResellerID
			,	LicenseeID
			,	TnxRate
			)
		SELECT	ResellerId
			,	@LicenseeID AS LicenseeID
			,	0.13 AS TnxRate
		FROM dbo.Resellers WITH (NOLOCK)
		WHERE ResellerName = @ResellerName
		
		SELECT @ResellerID = ResellerID
		FROM dbo.Resellers WITH (NOLOCK)
		WHERE ResellerName = @ResellerName
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50104
			, @ErrMsg = 'Fail to create licensee reseller. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
		RETURN
	END CATCH
	--- END: ADD RESELLER LICENSEE
	
	BEGIN TRY
	--- ADD ADMIN USER INTO NEW LICENSEE
		INSERT INTO @AdminUser (UserID, Username)
		SELECT UserID, Username
		FROM dbo.Users WITH (NOLOCK)
		WHERE userrole = 'admin' AND [STATUS] = 'Open'

		-- Update existing licensee user
		UPDATE dbo.LicenseeUser WITH (ROWLOCK, UPDLOCK)
		SET isActive = 1, PageAccess = ''
		WHERE LicenseeID = @licenseeid	

		-- Insert admin user
		INSERT INTO dbo.LicenseeUser (LicenseeID, UserID, isActive, PageAccess)
		SELECT @licenseeid, a.UserID, 1, ''
		FROM @AdminUser a
		WHERE NOT EXISTS (SELECT 1 FROM dbo.LicenseeUser l WITH (NOLOCK) WHERE l.LicenseeID = @licenseeid AND l.UserId = a.UserId)

		INSERT INTO @SpecialAdmin (UserID, Username)
		SELECT UserID, Username
		FROM @AdminUser
		WHERE UserID IN (
					1, -- dbaThien
					3, -- pgmviet
					5, -- pgmSon
					63, -- Martin
					64, -- Justin
					68, -- pgmChuong
					74, -- pgmkiwi
					87, -- CSD_11101
					157, -- pgmAnn
					160, -- Anthony
					369, -- dbaDon
					2939, -- standbyteam
					3232, -- dbaVictor
					3652, -- pgmWilliam
					3783, -- twLesley
					3784, -- twKai
					3834, --dbaFrancis
					8436, -- StarixQC2
					8437, -- StarixQC3
					8438, -- StarixQC4
					8439, -- StarixQC5
					8440, -- starix1
					8441, -- starix2
					8442 -- starix3
				)

		-- Add admin permission		
		IF EXISTS (SELECT TOP(1) 1 FROM @SpecialAdmin)
		BEGIN
			INSERT INTO dbo.LicenseeFunctions(LicenseeId, FunctionId)
			SELECT @licenseeid, f.FunctionId
			FROM dbo.Functions f WITH (NOLOCK)
			WHERE (f.ParentId IN (6, 74) OR f.FunctionId IN (6, 74))
					AND NOT EXISTS (SELECT 1 
									FROM dbo.LicenseeFunctions l WITH (NOLOCK)
									WHERE l.LicenseeID = @licenseeid AND l.FunctionId = f.FunctionId)
					
			INSERT INTO dbo.LicenseeUserFunctions(LicenseeId, UserId, FunctionId)
			SELECT @licenseeid, a.UserID, f.FunctionId	
			FROM @SpecialAdmin a, dbo.Functions f WITH (NOLOCK)
			WHERE (f.ParentId IN (6, 74) OR f.FunctionId IN (6, 74))
					AND NOT EXISTS (SELECT 1 
									FROM dbo.LicenseeUserFunctions l WITH (NOLOCK)
									WHERE l.LicenseeID = @licenseeid AND l.UserId = a.UserId AND l.FunctionId = f.FunctionId)
		END
	--- END: ADD ADMIN USER INTO NEW LICENSEE

	--- GRANT CURRENCY PERMISSION  
		DECLARE @Currency AS TABLE (
				CurrencyID	INT
		)

		INSERT INTO @Currency (
				CurrencyID
		)
		SELECT DISTINCT Currency CurrencyID
		FROM dbo.LicenseeCust WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID

		INSERT INTO dbo.CurrencyUser (
				usrID
			,	LicenseeID
			,	CurrencyID
			,	SystemID
			,	isActive
			)
		SELECT	u.UserID
			,	@LicenseeID
			,	c.CurrencyID
			,	1 ---SystemID=1 is default for Lrf 
			,	1 
		FROM dbo.LicenseeUser u WITH (NOLOCK), @Currency c
		WHERE u.LicenseeID = @LicenseeID
			AND NOT EXISTS (
					SELECT 1
					FROM dbo.CurrencyUser cu
					WHERE cu.usrID = u.UserID
						AND cu.LicenseeID = @LicenseeId
						AND cu.SystemID = 1
						AND cu.CurrencyID = c.CurrencyID				
					)

	--- END: GRANT CURRENCY PERMISSION
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50105
			, @ErrMsg = 'Fail to create licensee admin users. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
		RETURN
	END CATCH

	--- OFFER PRODUCT3rd
	BEGIN TRY
		IF ISNULL(@ProductCode, '') <> ''
		BEGIN
			SET @SPErrMsg = ''
			EXEC API_SiteBuilder_OfferProduct
				  @LicenseeID		= @LicenseeID
				, @ProductCode		= @ProductCode
				, @EffectiveDate	= @EffectiveDate
				, @ErrMsg			= @SPErrMsg OUTPUT
				
			INSERT INTO @Error (Msg)
			VALUES (@SPErrMsg)
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50106
			, @ErrMsg = 'Fail to enable products. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
		RETURN
	END CATCH
	--- END: OFFER PRODUCT3rd

	--- ENABLE PLAYER COMM
	BEGIN TRY
		IF @IsAllowMemberComm = 1
		BEGIN
			EXEC Nap_LM_Licensee_EnablePlayerComm_New @LicenseeName = @LicenseeName
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50107
			, @ErrMsg = 'Fail to enable player commission. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
		RETURN
	END CATCH	
	--- END: ENABLE PLAYER COMM

	------------------------------------------------------  
	-- Map Licencee to LicenseeBAConfig  
	------------------------------------------------------  
	--BEGIN TRY
	--	SET @SPErrMsg = ''
	--	EXEC Nap_LM_LicenseeBAConfig_Ins @LicenseeID = @licenseeid
	--		, @groupa		= 0.0025
	--		, @groupb		= 0.005
	--		, @groupc		= 0.0075
	--		, @groupd		= 0.01
	--		, @1x2Comm		= 0.005
	--		, @OtherComm	= 0.005
	--		, @EnableBA		= 0
	--		, @UserID		= 862400 --pgmViet
	--		, @ErrMsg		= @SPErrMsg OUTPUT
			
	--	INSERT INTO @Error (Msg)
	--	VALUES (@SPErrMsg)
	--END TRY
	--BEGIN CATCH
	--	SELECT @ErrCode = 50108
	--		, @ErrMsg = 'Fail to add BA configuration. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
		
	--	RETURN
	--END CATCH
	
	IF EXISTS (SELECT 1 FROM @Error WHERE ISNULL(Msg, '') <> '')
	BEGIN
		SELECT	@ErrCode = 50109,
				@ErrMsg = 'Process has completed. Warning: ' + STUFF((
							SELECT ';' + Msg
							FROM @Error
							WHERE ISNULL(Msg, '') <> ''
							FOR XML PATH('')), 1, 1, '')
		
		RETURN
	END
END
GO