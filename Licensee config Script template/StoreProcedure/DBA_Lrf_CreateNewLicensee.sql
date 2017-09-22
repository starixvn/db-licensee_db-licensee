/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[DBA_Lrf_CreateNewLicensee] (
	@LicenseeName VARCHAR(50)
	, @SuperWildCard VARCHAR(100) = ''
	, @ResellerName VARCHAR(50) = ''
	, @IsSpecial BIT = 0
	, @ProductCode VARCHAR(100) = ''
	, @SystemisActive VARCHAR(100) = ''
	, @IsAllowedDW BIT = 0
	, @IsOfferLas BIT = 0
	, @IsAllowMemberComm BIT = 0
	, @IsAllowWLbyLeague BIT = 0
	, @IsDeposit BIT = 0
	, @IsPullService BIT = 1
	, @ErrCode INT = 0 OUTPUT
	, @ErrMsg NVARCHAR(1000) = '' OUTPUT
	)
AS
/*  
Created: Henry  
Date: 20120409  
Task : Procedure to create a new Licensee  
DB: DBLIC.bodb_Licensee  
Original:  
  
Revisions:  
	 +20120716@Jim: add IsActive config for new licensee   
	 +20121205@henry: add param @SuperWildCard  
	 +20130204@Jim: add param @ResellerID   
	 +20130603@Jim: grant currency permission   
	 +20130624@Jim: set default for new licensee on Accounting system is inactive   
	 +20130725@Jim: restrict permission for DW function   
	 +20140318@Jim: hard-code to grant 'Account managerment' role just for 'CSD_11101'  
	 +20140404@Jim: + hard-code to grant 'Account managerment' role for special user  
					+ hard-code to not grant Agency System Function for new licensee  
	 +20140422@Jim: re-arrange data flow         
	 +20150504@Jim: correct function permission for GD,Void Bridge,AG,Playtech,  
	 +20160224@Jim: add pull service option  
	 +20160526@Jim: add more admin users  
	 +20160909@Jim: config edit betsetting role
	 +20170912@Harper: Remove Some Special Admin [RedmineID: #82673] 

Param's Explanation:  
	 + @IsSpecial: if 1 then update column Description to normal, or affiliate or banner depend on:  
				  - username ending with 01: normal  
				  - username ending with 02: affiliate  
				  - username ending with 03: banner  
				  - username ending with 04: income access  
	 + @SuperWildCard example: 12BETSuper%  
	 + @ResellerID : Reseller who new Licensee must to belong   
	 + @IsAllowedDW : offer DW :1  else :0  
*/

BEGIN
	SET NOCOUNT ON
		  
	DECLARE @AdminUser AS TABLE ( id		INT IDENTITY(1, 1)
								, UserID	INT
								, Username	VARCHAR(50)
								)

	DECLARE @SpecialAdmin AS TABLE ( id			INT IDENTITY(1, 1)
									, UserID	INT
									, Username	VARCHAR(50)
									)

	DECLARE @CommonFunction AS TABLE (id		 INT IDENTITY(1, 1)
									, FunctionId INT
									, TypeId	 INT
									)

	DECLARE @LicenseeId INT
		, @i			INT
		, @MAXID		INT
		, @UserID		INT
		, @Username		VARCHAR(50)
		, @ResellerID	INT

	-------------------------------------------* CREATE AGENT *-------------------------------------
	IF LTRIM(RTRIM(ISNULL(@SuperWildCard, ''))) = ''
		SET @SuperWildCard = @LicenseeName + 'Super%'

	EXEC DBA_CreateLicenseeAgent @LicenseeName = @LicenseeName
		, @SuperWildCard = @SuperWildCard
		, @IsSpecial = @IsSpecial

	SELECT @LicenseeId = licenseeid
	FROM dbo.licensees WITH (NOLOCK)
	WHERE licenseename = @LicenseeName

	IF ISNULL(@licenseeid, 0) = 0
		RAISERROR ('Could not insert new licensee, please check again', 16, 1)

	-------------------------------------------* SYSTEMLICENSEE *---------------------------------------
	IF NOT EXISTS ( SELECT 1 FROM dbo.SystemLicensee WITH (NOLOCK) WHERE LicenseeID = @licenseeid )
	BEGIN
		INSERT INTO dbo.SystemLicensee (SystemID, LicenseeID, IsActive)
		SELECT ID, @LicenseeID 
			, CASE WHEN ID IN (1, 2) THEN 1	ELSE 0 END 
		FROM dbo.Systems WITH (NOLOCK)
	END
	ELSE
	BEGIN
		INSERT INTO dbo.SystemLicensee (SystemID, LicenseeID, IsActive)
		SELECT ID, @LicenseeID 
			, CASE WHEN ID IN (1, 2) THEN 1 ELSE 0 END
		FROM dbo.Systems WITH (NOLOCK)
		WHERE ID NOT IN (
							SELECT DISTINCT SystemID
							FROM dbo.SystemLicensee WITH (NOLOCK)
							WHERE LicenseeID = @licenseeid
						)
	END

	-- Active Licensee for Systems
	IF ISNULL(@SystemisActive, '') <> ''
	BEGIN
		EXEC DBA_Lrf_ActiveLicenseeSystem @LicenseeName = @LicenseeName, @SystemisActive = @SystemisActive
	END

	-------------------------------------------* RESELLER *---------------------------------------	
	IF EXISTS (	SELECT 1 FROM dbo.Resellers WITH (NOLOCK) WHERE ResellerName = @ResellerName)
	BEGIN
		INSERT INTO dbo.LicenseeReseller (ResellerID, LicenseeID, TnxRate)
		SELECT ResellerId, @LicenseeID , 0.13
		FROM dbo.Resellers WITH (NOLOCK)
		WHERE ResellerName = @ResellerName
	END
	ELSE
	BEGIN
		INSERT INTO dbo.Resellers (ResellerName, Description, ResellerType)
		SELECT @ResellerName, NULL, 2

		INSERT INTO dbo.LicenseeReseller (ResellerID, LicenseeID, TnxRate)
		SELECT ResellerId, @LicenseeID, 0.13
		FROM dbo.Resellers WITH (NOLOCK)
		WHERE ResellerName = @ResellerName
	END

	SELECT @ResellerID = ResellerID
	FROM dbo.Resellers WITH (NOLOCK)
	WHERE ResellerName = @ResellerName
		
	----------------------------------------* REGIST NEW RESELLER IN L.A *------------------------------------
	IF NOT EXISTS ( SELECT 1	
					FROM dbo.OA_GroupLicensees WITH (NOLOCK) 
					WHERE ResellerID = @ResellerID	
						AND LicenseeID = @LicenseeID )
	BEGIN
		INSERT INTO dbo.OA_GroupLicensees (	GroupID, ResellerID, LicenseeID	)
		SELECT Groupid, @resellerid, @LicenseeID		
		FROM dbo.OA_GroupLicensees WITH (NOLOCK)
		WHERE licenseeid = 9 AND resellerid = 2
	END

	IF NOT EXISTS ( SELECT 1
					FROM dbo.OA_UserLicensees WITH (NOLOCK)
					WHERE ResellerID = @ResellerID
						AND LicenseeID = @LicenseeID )
	BEGIN
		INSERT INTO dbo.OA_UserLicensees ( UserID, ResellerID, LicenseeID)
		SELECT Userid, @resellerid, @LicenseeID
		FROM dbo.OA_UserLicensees WITH (NOLOCK)
		WHERE licenseeid = 9 AND resellerid = 2
	END	

	----------------------------------------* SET BETSETTING IS ACTIVE AS DEFAULT *------------------------------------
	IF @ResellerName IN ('Zelianta','Boping')
	BEGIN 
		UPDATE dbo.Licensees WITH (ROWLOCK,UPDLOCK)
		SET EditBetSetting =1 
		WHERE LicenseeID = @LicenseeID
	END

	--------------------------------------------------* OFFER PRODUCT3rd *------------------------------------
	IF ISNULL(@ProductCode, '') <> ''
	BEGIN
		EXEC DBA_Lrf_OfferProduct @ResellerID = @ResellerID
			, @LicenseeId = @LicenseeId
			, @ProductCode = @ProductCode
			, @IsPullService = @IsPullService
	END

	IF @IsAllowMemberComm = 1
	BEGIN
		EXEC DBA_Lrf_EnablePlayerComm @LicenseeName = @LicenseeName
	END

	---------------------------------------* SETTING LICENSEE FUNCTIONS *------------------------------------

	-- Setting Special Admin for New Licensee
	INSERT INTO @AdminUser ( UserID, Username)
	SELECT UserID, Username
	FROM dbo.Users WITH (NOLOCK)
	WHERE userrole = 'admin' AND STATUS = 'Open'

	INSERT INTO @SpecialAdmin ( UserID, Username)
	SELECT UserID, Username
	FROM @AdminUser
	WHERE UserID IN (			
			63
			, -- Martin  
			64
			, -- Justin  			 
			74
			, -- pgmkiwi  
			87
			, -- CSD_11101  
			157
			, -- pgmAnn  
			160
			, -- Anthony  
			369
			, -- dbaDon  
			2939
			, -- standbyteam  			
			3652
			, -- pgmWilliam  			
			3784
			, -- twKai  			 
			8436
			, -- StarixQC2  
			8437
			, -- StarixQC3  
			8438
			, -- StarixQC4  
			8439
			, -- StarixQC5  
			8440
			, -- starix1  
			8441
			, -- starix2  
			8442 -- starix3  
			)
	
	INSERT INTO @CommonFunction ( FunctionId, TypeId) --- will use ProductOffer  
	EXEC DBA_Lrf_FunctionUserRole @UserRole = 'admin'

	-- Insert data for Licensee Function
	INSERT INTO dbo.LicenseeFunctions (LicenseeId, FunctionId)
	SELECT @LicenseeId, Functionid
	FROM @CommonFunction
	WHERE TypeId = 11 
		AND FunctionID NOT IN (
								SELECT FunctionId
								FROM dbo.LicenseeFunctions WITH (NOLOCK)
								WHERE LicenseeId = @LicenseeId
							)		

	IF (@IsAllowedDW = 1)
	BEGIN		
		
		DELETE dbo.LicenseeFunctions
		WHERE LicenseeId = @LicenseeId
			AND FunctionID IN (5, 44, 45)

		INSERT INTO dbo.LicenseeFunctions (LicenseeId, FunctionId)
		SELECT @LicenseeId, Functionid
		FROM dbo.Functions WITH (NOLOCK)
		WHERE FunctionID IN (5, 44, 45)		

		DELETE dbo.LicenseeUserFunctions
		WHERE LicenseeId = @LicenseeId
			AND FunctionID IN (5, 44, 45)

		INSERT INTO dbo.LicenseeUserFunctions ( UserId, FunctionId, LicenseeId )
		SELECT lu.UserId, lf.FunctionId, @LicenseeID
		FROM dbo.LicenseeFunctions lf WITH (NOLOCK)
			INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lf.LicenseeId = lu.LicenseeId
		WHERE lf.LicenseeId = @LicenseeId
			AND lf.FunctionId IN (5, 44, 45)
	END

	IF (@IsAllowWLbyLeague = 1)
	BEGIN		
		IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeFunctions WITH (NOLOCK) WHERE LicenseeId = @LicenseeId AND FunctionId = 59)
		BEGIN
			INSERT INTO dbo.LicenseeFunctions (LicenseeId, FunctionId)
			SELECT @LicenseeId, 59
		END

		DELETE dbo.LicenseeUserFunctions
		WHERE LicenseeId = @LicenseeId
			AND FunctionID = 59

		INSERT INTO dbo.LicenseeUserFunctions (UserId, FunctionId, LicenseeId)
		SELECT lu.UserId, lf.FunctionId, @LicenseeID
		FROM dbo.LicenseeFunctions lf WITH (NOLOCK)
			INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON lf.LicenseeId = lu.LicenseeId
		WHERE lf.LicenseeId = @LicenseeId
			AND lf.FunctionId = 59
	END

	-- Setting data for LicenseeUserFunction
	SELECT @i = 0
		, @MAXID = MAX(id)
	FROM @AdminUser

	WHILE (@i <= @maxId)
	BEGIN
		SET @i = @i + 1

		SELECT @UserId = UserId
			, @Username = Username
		FROM @AdminUser
		WHERE ID = @i

		IF EXISTS ( SELECT 1
					FROM dbo.LicenseeUser WITH (NOLOCK)
					WHERE LicenseeID = @licenseeid
						AND UserID = @UserID
					)
		BEGIN
			UPDATE dbo.LicenseeUser	WITH (ROWLOCK, UPDLOCK)
			SET isActive = 1
				, PageAccess = ''
			WHERE LicenseeID = @licenseeid AND UserID = @UserID
		END
		ELSE
		BEGIN
			INSERT INTO dbo.LicenseeUser (LicenseeID, UserID, isActive, PageAccess)
			SELECT @licenseeid, @UserID, 1, ''
		END

		INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
		SELECT DISTINCT lf.LicenseeId, @UserId, f.FunctionId
		FROM @CommonFunction f
			INNER JOIN dbo.LicenseeFunctions lf WITH (NOLOCK) ON f.FunctionId = lf.Functionid
		WHERE f.FunctionId NOT IN (
									SELECT FunctionId
									FROM dbo.LicenseeUserFunctions WITH (NOLOCK)
									WHERE LicenseeId = @LicenseeId AND UserId = @UserId
									)
			AND f.TypeId = 1
			AND lf.LicenseeId = @LicenseeId

		IF EXISTS (
					SELECT TOP 1 1
					FROM @SpecialAdmin a
						INNER JOIN @AdminUser b ON a.UserId = b.UserId
					WHERE a.UserId = @UserId
				)
		BEGIN
			INSERT INTO dbo.LicenseeUserFunctions (LicenseeId, UserId, FunctionId)
			SELECT DISTINCT @LicenseeId, @UserId, f.FunctionId
			FROM @CommonFunction f
				INNER JOIN dbo.LicenseeFunctions lf WITH (NOLOCK) ON f.FunctionId = lf.Functionid
			WHERE f.FunctionId NOT IN (
										SELECT FunctionId
										FROM dbo.LicenseeUserFunctions WITH (NOLOCK)
										WHERE LicenseeId = @LicenseeId AND UserId = @UserId
									)
				AND f.TypeId = 11
		END
	END
	  
	-- Grant currency permission to Licensee's Users  
	 
	DECLARE @Currency	AS TABLE ( LicenseeID INT, CurrencyID INT )
	DECLARE @usr		AS TABLE (LicenseeID INT, UserID INT)

	INSERT INTO @Currency (	LicenseeID, CurrencyID)
	SELECT DISTINCT LicenseeID, Currency
	FROM dbo.LicenseeCust WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID

	INSERT INTO @usr (LicenseeID, UserID)
	SELECT DISTINCT LicenseeID, UserID
	FROM dbo.LicenseeUser WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID

	INSERT INTO dbo.CurrencyUser (usrID, LicenseeID, CurrencyID, SystemID, isActive	)
	SELECT u.UserID, @LicenseeID, c.CurrencyID, 1, 1 --- SystemID = 1 is default for Lrf  
	FROM @usr u
		INNER JOIN @Currency c ON u.LicenseeID = c.LicenseeID

	EXCEPT

	SELECT usrID, LicenseeID, CurrencyID, 1, 1
	FROM dbo.CurrencyUser WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID

	---------------------------------------* MAP LICENSEE TO LICENSEEBACONFIG *----------------------------------	
	EXEC DBA_LicenseeBAConfig_Ins @LicenseeID = @licenseeid
		, @groupa = 0.0025
		, @groupb = 0.005
		, @groupc = 0.0075
		, @groupd = 0.01
		, @1x2Comm = 0.005
		, @OtherComm = 0.005
		, @EnableBA = 0
		, @UserID = 862400 --pgmViet
END
GO