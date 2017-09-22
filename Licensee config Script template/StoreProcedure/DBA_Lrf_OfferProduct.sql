/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
   
ALTER PROCEDURE [dbo].[DBA_Lrf_OfferProduct]  
( 
	@ResellerID INT,  
	@LicenseeId  INT,  
	@ProductCode   VARCHAR(100)='',  
	@EffectiveDate SMALLDATETIME ='',  
	@IsPullService   BIT  = 1  
)  
AS  
/*  
	Created: 20140502@Jim  
	Task : re-structure create new licensee flow  
	DB: DBLIC.bodb_licensee  
	Original :  
   
	Revisions:  
	  - 20150320@Jim: add more funtion permission for 'Active Customer Summary' report  
	  - 20150427@Jim: support product Gold Deluxe   
	  - 20160224@Jim: add pull service option  
	  - 20170912@Harper: Clean code [RedmineID: #82673] 

	Param's Explanation:    
   
*/  
  
BEGIN   
	DECLARE @tblProductPrefix		AS TABLE(ID INT IDENTITY(1,1), ProductId INT, ProductCode VARCHAR(100), EffectiveDate SMALLDATETIME)  
	DECLARE @tblProductFunctions	AS TABLE(ID INT IDENTITY(1,1), ProductId INT, FunctionId INT, TypeId INT)  
	DECLARE @tblLicenseeUser		AS TABLE (ID  INT IDENTITY(1,1) , LicenseeID INT,UserId INT)  

	DECLARE @MaxID			INT  
			,@i				INT  
			,@k				INT  
			,@UserID		INT  
			,@ProductName	VARCHAR(5)  
			,@n				INT  
			,@m				INT  
			,@LicenseeName	VARCHAR(50)  
  
	SELECT  @LicenseeName = LicenseeName  
	FROM  dbo.Licensees WITH (NOLOCK)  
	WHERE LicenseeId = @LicenseeId  
   
	-------------------------------------------* GET PRODUCT LIST *-------------------------------------
	INSERT INTO @tblProductPrefix (ProductId,ProductCode,EffectiveDate)  
	SELECT 0,val,null  
	FROM bodb02.dbo.strSplit(@ProductCode,',')  
   
	UPDATE a  
	SET ProductId = b.ProductId   
	FROM @tblProductPrefix a  
	INNER JOIN dbo.Product3rd b WITH (NOLOCK) ON a.ProductCode = b.ProductPrefix  
    
	SELECT @MaxID = MAX(ID)  
	FROM @tblProductPrefix  
   
	IF (@MaxID=1 AND @EffectiveDate IS NOT NULL)  
	BEGIN   
		UPDATE @tblProductPrefix  
		SET EffectiveDate = @EffectiveDate  
	END  
   
	SELECT @n = 1  
		,@m = MAX(ID) FROM @tblProductPrefix  
	WHILE (@n <= @m)     
	BEGIN  
		SELECT @ProductName = ProductCode FROM @tblProductPrefix WHERE ID = @n  
    
		INSERT INTO @tblProductFunctions  
		EXEC DBA_Lrf_FunctionProduct @ProductCode = @ProductName  
      
		SET @n = @n +1   
	END   
	
	----------------------------------------* OFFER PRODUCT TO LICENSEE *----------------------------------
	INSERT INTO dbo.LicenseeProduct3rd(LicenseeID, ProductID, Comm, Winloss, EffectiveDate)   
	SELECT DISTINCT  @LicenseeID, ProductId, 0, 1, EffectiveDate  
	FROM @tblProductPrefix   
	WHERE ProductId NOT IN (	
								SELECT ProductId   
								FROM dbo.LicenseeProduct3rd WITH (NOLOCK)   
								WHERE LicenseeId = @LicenseeID  
							)  

	INSERT INTO dbo.LicenseeFunctions (licenseeID, FunctionId)   
	SELECT  DISTINCT @LicenseeID ,pf.FunctionId  
	FROM @tblProductFunctions pf   
		INNER JOIN @tblProductPrefix pp ON pf.ProductId = pp.ProductId  
	WHERE pf.TypeId = 1  
		AND pf.FunctionId NOT IN (
									SELECT FunctionId 
									FROM dbo.LicenseeFunctions WITH (NOLOCK) 
									WHERE LicenseeId = @LicenseeId 
								)  
	--- LicenseeUserFunctions  
	INSERT INTO @tblLicenseeUser (LicenseeId,UserId )  
	SELECT @LicenseeID, u.UserId   
	FROM dbo.Users u WITH (NOLOCK)   
		INNER JOIN dbo.LicenseeUser lu WITH (NOLOCK) ON u.UserID = lu.UserID   
	WHERE lu.LicenseeID = @LicenseeID   
		AND u.Status='Open'  
		 
	SELECT @i = 1  
		,@k = MAX(ID)  
	FROM @tblLicenseeUser  
	
	WHILE (@i <= @k)  
	BEGIN   
		SELECT @UserID = UserID   
		FROM @tblLicenseeUser   
		WHERE ID = @i  

		INSERT INTO dbo.LicenseeUserFunctions(UserId, FunctionId, LicenseeId)  
		SELECT DISTINCT @UserID  
			,lf.FunctionId  
			,@LicenseeID  
		FROM dbo.LicenseeFunctions lf WITH (NOLOCK)  
			INNER JOIN @tblProductFunctions pf ON lf.FunctionId = pf.FunctionId  
			INNER JOIN @tblProductPrefix pp ON pf.ProductId = pp.ProductId  
		WHERE lf.LicenseeId = @LicenseeId  
			AND pf.TypeId = 1  
			AND lf.FunctionId NOT IN (
										SELECT uf.FunctionId   
										FROM dbo.LicenseeUserFunctions uf WITH (NOLOCK)  
										WHERE uf.UserId = @UserId AND LicenseeID = @LicenseeID
									)    
		SET @i = @i +1            
	END           
	
	-- OA_Function

	INSERT INTO dbo.OA_FunctionResellers (FunctionID, ResellerId)  
	SELECT oaf.FunctionID, @ResellerID  
	FROM dbo.OA_Functions oaf WITH (NOLOCK)    
		INNER JOIN @tblProductFunctions pf ON oaf.FunctionID = pf.FunctionId  
	WHERE pf.FunctionId NOT IN (SELECT FunctionId  
		FROM dbo.OA_FunctionResellers WITH (NOLOCK)  
		WHERE ResellerID = @ResellerID  
		)  
	AND pf.TypeId = 2  

	INSERT INTO dbo.OA_FunctionLicensees (FunctionID, ResellerID, LicenseeID)  
	SELECT DISTINCT oaf.FunctionID  
		,@ResellerID  
		,@LicenseeId  
	FROM dbo.OA_Functions oaf WITH (NOLOCK)    
	INNER JOIN @tblProductFunctions pf ON oaf.FunctionID = pf.FunctionId  
	WHERE pf.FunctionId NOT IN (SELECT FunctionId  
		FROM dbo.OA_FunctionLicensees WITH (NOLOCK)  
		WHERE LicenseeID   = @LicenseeId   
			AND ResellerID = @ResellerID  
		)  
	AND pf.TypeId = 2  

	----------------------------------------* PULL DATA INTO SERVICE *----------------------------------
	IF EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductCode = 'AGC') AND @IsPullService =1  
	BEGIN   
		EXEC DBPTCS.bodb_PlaytechCS.[dbo].[DBA_EnableAGCasinoService] @LicenseeName = @LicenseeName, @SettingName ='AGCasino_VersionKey'  
	END  

	IF EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductCode = 'GD') AND @IsPullService =1  
	BEGIN   
		EXEC DBPTCS.bodb_PlaytechCS.[dbo].[DBA_EnableGoldDeluxeService] @LicenseeName = @LicenseeName, @SettingName ='GoldDeluxe_VersionKey'  
	END   

	IF EXISTS (SELECT 1 FROM @tblProductPrefix WHERE ProductCode = 'BA')  
	BEGIN  
		IF NOT EXISTS(SELECT 1 FROM dbo.LicenseeReseller WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND ResellerID = 3 )  
		BEGIN  
			DECLARE @TempGroupID AS TABLE (id INT IDENTITY,GroupID INT)  
			DECLARE @TempUserID AS TABLE (id INT IDENTITY,UserID INT)  
			DECLARE @j INT  
				,@GroupID INT  

			SET  @UserID  = 0   

			--Add Licensee to BA reseller  
			INSERT INTO dbo.LicenseeReseller (ResellerID,LicenseeID,TnxRate)  
			VALUES (3,@LicenseeID,0.13)  
     
			--insert Licensee to BA reseller to OA group (OA_GroupLicensees)  
			INSERT INTO @TempGroupID(GroupID)  
			SELECT DISTINCT GroupID FROM dbo.OA_GroupLicensees WITH (NOLOCK)  
		
			SET @j = 0  
			SELECT @MaxID = MAX(id) FROM @TempGroupID  
			WHILE @j < @MaxID  
			BEGIN  
				SET @j = @j + 1  
				SELECT @GroupID = GroupID FROM @TempGroupID WHERE id = @j  
      
				IF EXISTS (SELECT 1 FROM dbo.OA_GroupLicensees WITH (NOLOCK) WHERE GroupID = @GroupID AND ResellerID <> 3 AND LicenseeID = @LicenseeID)  
				BEGIN  
					IF NOT EXISTS (SELECT 1 FROM dbo.OA_GroupLicensees WITH (NOLOCK) WHERE GroupID=@GroupID AND ResellerID = 3 AND LicenseeID = @LicenseeID)  
					BEGIN  
						INSERT INTO dbo.OA_GroupLicensees (GroupID,ResellerID,LicenseeID) VALUES (@GroupID,3,@LicenseeID)  
					END  
				END   

				--insert Licensee to BA reseller to OA Users (OA_UserLicensees)  
				INSERT INTO @TempUserID(UserID)  
				SELECT DISTINCT UserID FROM dbo.OA_UserLicensees WITH (NOLOCK)  
  
				SET @j = 0  
				SELECT @MAXID = MAX(id) FROM @TempUserID  
  
				WHILE @j < @MAXID  
				BEGIN  
					SET @j = @j + 1  
					SELECT @UserID = UserID FROM @TempUserID WHERE id = @j  
       
					IF EXISTS (SELECT 1 FROM dbo.OA_UserLicensees WITH (NOLOCK) WHERE UserID = @UserID AND ResellerID <> 3 AND LicenseeID = @LicenseeID)  
					BEGIN  
						IF NOT EXISTS (SELECT 1 FROM dbo.OA_UserLicensees WITH (NOLOCK) WHERE UserID=@UserID AND ResellerID = 3 AND LicenseeID = @LicenseeID)  
						BEGIN  
							INSERT INTO dbo.OA_UserLicensees (UserID,ResellerID,LicenseeID) VALUES (@UserID,3,@LicenseeID)  
						END  
					END   
				END  

				--insert justin,martin,anthony to SpecialBA for this license  
				DELETE FROM @TempUserID  
				INSERT INTO @TempUserID(UserID)  
				SELECT userid FROM dbo.users WITH (NOLOCK)  
				WHERE username IN ('justin','martin','anthony')  
					AND UserRole = 'admin'   
					AND isInternal = 0  
      
				SET @j = 0  
				SELECT @MAXID = MAX(id) FROM @TempUserID  
  
				WHILE @j < @MAXID  
				BEGIN  
					SET @j = @j + 1  
					SELECT @UserID = UserID FROM @TempUserID WHERE id = @j  
       
					IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeUserFunctions WITH (NOLOCK) WHERE licenseeid=@LicenseeId AND Userid=@UserId AND Functionid = 54)  
					BEGIN  
						INSERT INTO dbo.LicenseeUserFunctions(LicenseeId, UserId, FunctionId)  
						SELECT @LicenseeId, @UserId, 54  
					END  
				END   
			END 
		END  
	END  
END
GO