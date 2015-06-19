USE [bodb_licensee]
GO
 
ALTER PROCEDURE	[dbo].[Lrf_LicenseeProductSel]
	@LicenseeID	INT
AS
/*
	Created: 20150608@Jim
	Task: Get Product list which offered for selected licensees
	DB: DBLIC/bodb_licensee
	Original:
	Revisions:
	Param's Explanation:
*/

 /*
 dbo.Lrf_LicenseeProductSel_xtest
	@LicenseeID=2
 */
 
 
BEGIN
	DECLARE @site VARCHAR(20)
	DECLARE @tblSuper AS TABLE (SrecommendID INT)
	DECLARE @tblProductActive AS TABLE (ProductID INT,ProductName VARCHAR(50) ,ProductCode VARCHAR(10),isEnable BIT)
	
	SELECT @Site = LicenseeName
	FROM dbo.Licensees WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeiD 
	INSERT INTO @tblSuper (SrecommendID)
	SELECT CustID
	FROM DBTXN.CustDb.dbo.Dep_CustSuper WITH (NOLOCK)
	WHERE Site = @Site
	
	IF EXISTS(SELECT 1 FROM @tblSuper ) 
	BEGIN
		INSERT INTO @tblProductActive (ProductID,ProductName,ProductCode,isEnable)
		SELECT 
			p.ProductId
			,p.ProductName
			,p.ProductPrefix AS  ProductCode
			,CASE WHEN p.ProductID IN (10,11,12,14) THEN 0 ELSE 1 END 
		FROM dbo.Product3rd p WITH (NOLOCK) 
			INNER JOIN dbo.LicenseeProduct3rd lp WITH (NOLOCK) ON p.ProductId = lp.ProductId 	
		WHERE lp.LicenseeID  = @LicenseeID
		UNION ALL
		SELECT 0
			   ,'Sportsbook'
			   ,'SB'
			   ,1
			   
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 10)	-- AGCasino
			BEGIN
				IF EXISTS (SELECT 1 FROM DBTXN.CustDB.dbo.Dep_SuperSetting_AGCasino s WITH (NOLOCK) INNER JOIN @tblSuper su ON s.CustID = su.SrecommendID WHERE IsEnabled=1)
				UPDATE @tblProductActive
				SET isEnable =1
				WHERE ProductID = 10
			END
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 11)   -- Gold Deluxe	
			BEGIN 
				IF EXISTS (SELECT 1 FROM  bodb02.dbo.CustInfo ci WITH (NOLOCK) INNER JOIN @tblSuper r ON ci.srecommend = r.SrecommendID WHERE ci.DisableGoldDeluxe = 0)
				UPDATE @tblProductActive
				SET isEnable =1
				WHERE ProductID = 11	
			END
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 12)	-- Vegas Games
			BEGIN 
				IF EXISTS (SELECT 1 FROM DBTXN.CustDB.dbo.Dep_SupperProductSetting s WITH (NOLOCK) INNER JOIN @tblSuper su ON s.CustID = su.SrecommendID WHERE  s.ProductID = 12 AND IsEnabled=1)
				UPDATE @tblProductActive
				SET isEnable =1
				WHERE ProductID = 12
			END
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 14)	---Microgaming
			BEGIN 
				IF EXISTS (SELECT 1 FROM  bodb02.dbo.CustInfo ci WITH (NOLOCK) INNER JOIN @tblSuper r ON ci.srecommend = r.SrecommendID WHERE ci.DisableMicrogame = 0)
				UPDATE @tblProductActive
				SET isEnable =1
				WHERE ProductID = 14	
			END
			
	END
	SELECT ProductID
		   ,ProductName
		   ,ProductCode
		   ,isEnable
	FROM @tblProductActive t 
	WHERE ProductID NOT IN (3,7)
	ORDER BY ProductID ASC
END
GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeProductSel] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_LicenseeProductSel] TO [bodbLicenseeNet]
GO 