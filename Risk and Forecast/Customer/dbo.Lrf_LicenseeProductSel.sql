/*<info serverAlias="DBLIC-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE	[dbo].[Lrf_LicenseeProductSel]
(
	@LicenseeID	INT
)	
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
		- 20170724@Helen: Lottery in DCS Structure - [Redmine:79997]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180315@Winnie: Bet Setting - Cash Out product is not listed in Product dropdown box [HotFix #92097]
		- 20180405@Amanda: Bet Setting - Hide RB product [Redmine #92291]
		- 20180620@Johnson: Integrate Pragmatic [Redmine: #92318]
		- 20190322@Amanda: Remove MGCLC & MGRnG [RedmineID: #107704]
		- 20190724@Amanda: Bet Setting - Hide CC product [RedmineID: #115449]
		- 20191212@Vickie: Integrate SpadeGaming [RedmineID: #124103]
		- 20200108@Vickie: Bet Setting - Hide VRG product [RedmineID: #124911]
		- 20200323@Vickie: Bet Setting - Hide Indo 4D product [RedmineID: #130859]
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
	FROM DBCUST.CUSTDB.dbo.Dep_CustSuper WITH (NOLOCK)
	WHERE Site = @Site
				
	IF EXISTS(SELECT 1 FROM @tblSuper ) 
	BEGIN
		INSERT INTO @tblProductActive (ProductID,ProductName,ProductCode,isEnable)
		SELECT 
			p.ProductId
			,p.ProductName
			,p.ProductPrefix AS  ProductCode
			,CASE WHEN p.ProductID IN (10,11,12) OR ApplyDCS = 1 THEN 0 ELSE 1 END 
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
		
		--check DCS setting
		;WITH tmp AS(
		SELECT DISTINCT ps.ProductID 
		FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting lps WITH (NOLOCK)
			INNER JOIN DBCUST.CustDB.dbo.Dep_ProductSetting ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
			INNER JOIN @tblSuper su ON lps.CustID = su.SrecommendID
		WHERE ps.ProductID IN (SELECT productID FROM dbo.Product3rd p WITH (NOLOCK) WHERE applyDCS = 1)
		)
		UPDATE t
		SET isEnable = 1
		FROM @tblProductActive t
		WHERE productID IN (SELECT productID FROM tmp)	   
	END
	
	SELECT ProductID
		   ,ProductName
		   ,ProductCode
		   ,isEnable
	FROM @tblProductActive t 
	WHERE ProductID NOT IN (3,7,9,4,1,14,17,34,36,37,38,43)-- Hide Setting for CashOut,LC,RB,Microgaming,CC,SG,SPR,VRG,I4D
	ORDER BY ProductID ASC
	
END

GO 
