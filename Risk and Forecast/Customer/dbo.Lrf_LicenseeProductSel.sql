/*<info serverAlias="DBLIC-bodb_licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE	[dbo].[Lrf_LicenseeProductSel]
	@LicenseeID	INT
AS
/*
	Created: 20150608@Jim
	Task: Get Product list which offered for selected licensees
	DB: DBLIC/bodb_licensee
	Original:
	Revisions:
		- 20150722@Jim: apply new DBCust structure
		- 20151108@Jim: Separated MicroGaming into 2 product
		- 20160419@Helen: VoidBridge IN DCS Structure - [Redmine: 55057]
		- 20161122@Helen: Fishing World IN DCS Structure - [Redmine: 66737]
		- 20160801@Helen: Allbet IN DCS Structure - [Redmine: 61066]
		- 20170517@Winnie: Hide Setting for CashOut - [Redmine: 72171]
		- 20170302@Helen: Betradar Virtual Sports  -Integration for Cash [Redmine: 77274]
		
	Param's Explanation:
*/

 /*
 EXEC Lrf_LicenseeProductSel
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
	FROM DBCUST.CustDb.dbo.Dep_CustSuper WITH (NOLOCK)
	WHERE Site = @Site
	
	IF EXISTS(SELECT 1 FROM @tblSuper ) 
	BEGIN
		INSERT INTO @tblProductActive (ProductID,ProductName,ProductCode,isEnable)
		SELECT 
			p.ProductId
			,p.ProductName
			,p.ProductPrefix AS  ProductCode
			,CASE WHEN p.ProductID IN (10,11,12,14,17,22,24,21,5,27) THEN 0 ELSE 1 END 
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
				IF EXISTS (SELECT 1 FROM DBCUST.CustDB.dbo.Dep_SuperSetting_AGCasino s WITH (NOLOCK) INNER JOIN @tblSuper su ON s.CustID = su.SrecommendID WHERE IsEnabled=1)
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
				IF EXISTS (SELECT 1 FROM DBCUST.CustDB.dbo.Dep_SupperProductSetting s WITH (NOLOCK) INNER JOIN @tblSuper su ON s.CustID = su.SrecommendID WHERE  s.ProductID = 12 AND IsEnabled=1)
				UPDATE @tblProductActive
				SET isEnable =1
				WHERE ProductID = 12
			END
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 14)	---Microgaming
			BEGIN 
				IF EXISTS (SELECT 1 FROM  bodb02.dbo.CustInfo ci WITH (NOLOCK) INNER JOIN @tblSuper r ON ci.srecommend = r.SrecommendID WHERE ci.DisableMicrogameLC = 0)
				UPDATE @tblProductActive
				SET isEnable =1
				WHERE ProductID = 14	
			END
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 17)	---Microgaming
			BEGIN 
				IF EXISTS (SELECT 1 FROM  bodb02.dbo.CustInfo ci WITH (NOLOCK) INNER JOIN @tblSuper r ON ci.srecommend = r.SrecommendID WHERE ci.DisableMicrogameRNG = 0)
				UPDATE @tblProductActive
				SET isEnable =1
				WHERE ProductID = 17	
			END	
		
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 22)	---VoidBridge
		BEGIN 
			IF EXISTS (SELECT 1 
				   FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting lps WITH (NOLOCK)
						INNER JOIN DBCUST.CustDB.dbo.Dep_ProductSetting ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
						INNER JOIN @tblSuper su ON lps.CustID = su.SrecommendID
				   WHERE ps.ProductID= 22)
				   
			UPDATE @tblProductActive
			SET isEnable =1
			WHERE ProductID = 22	
		END		
		
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 24)	---Fishing World
		BEGIN 
			IF EXISTS (SELECT 1 
				   FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting lps WITH (NOLOCK)
						INNER JOIN DBCUST.CustDB.dbo.Dep_ProductSetting ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
						INNER JOIN @tblSuper su ON lps.CustID = su.SrecommendID
				   WHERE ps.ProductID= 24)
				   
			UPDATE @tblProductActive
			SET isEnable =1
			WHERE ProductID = 24	
		END	
		
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 21)	---Allbet
		BEGIN 
			IF EXISTS (SELECT 1 
				   FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting lps WITH (NOLOCK)
						INNER JOIN DBCUST.CustDB.dbo.Dep_ProductSetting ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
						INNER JOIN @tblSuper su ON lps.CustID = su.SrecommendID
				   WHERE ps.ProductID= 21)
				   
			UPDATE @tblProductActive
			SET isEnable =1
			WHERE ProductID = 21	
		END	
		
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 5)	---Virtual Sport
		BEGIN 
			IF EXISTS (SELECT 1 
				   FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting lps WITH (NOLOCK)
						INNER JOIN DBCUST.CustDB.dbo.Dep_ProductSetting ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
						INNER JOIN @tblSuper su ON lps.CustID = su.SrecommendID
				   WHERE ps.ProductID= 5)
				   
			UPDATE @tblProductActive
				SET isEnable =1
			WHERE ProductID = 5	
		END	
		
		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 27)	---Betradar
		BEGIN 
			IF EXISTS (SELECT 1 
				   FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting lps WITH (NOLOCK)
						INNER JOIN DBCUST.CustDB.dbo.Dep_ProductSetting ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
						INNER JOIN @tblSuper su ON lps.CustID = su.SrecommendID
				   WHERE ps.ProductID= 27)
				   
			UPDATE @tblProductActive
				SET isEnable =1
			WHERE ProductID = 27	
		END	
		
	END
	
	SELECT ProductID
		   ,ProductName
		   ,ProductCode
		   ,isEnable
	FROM @tblProductActive t 
	WHERE ProductID NOT IN (3,7,9,25)-- Hide Setting for CashOut
	ORDER BY ProductID ASC
	
END

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeProductSel] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Lrf_LicenseeProductSel] TO [bodbLicenseeNet]
GO 
