/*<info serverAlias="DBLIC-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE	[dbo].[Lrf_LicenseeProductSel]
	@LicenseeId	INT
AS

/*
	Created: 20150608@Jim
	Task: Get Product list which offered for selected licensees
	DB: DBLIC.bodb_licensee

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
		- 20200423@Hogan: Bet Setting - Hide Table Game product [RedmineID: #133097]
		- 20200427@Hogan: Bet Setting - Hide Sexy Gaming product [RedmineID: #132829]
		- 20200427@Vickie: Bet Setting - Hide SBC product [RedmineID: #132702]
		- 20200615@Hogan: Integrate SA Gaming [RedmineID: #128493]
		- 20210305@Hogan: Integrate Sport Lottery [RedmineID: #150872]

	EXEC Lrf_LicenseeProductSel @LicenseeID = 2
*/
 
BEGIN
	SET NOCOUNT ON

	DECLARE @Site VARCHAR(20)
	DECLARE @tblSuper TABLE (SrecommendID INT)

	DECLARE @tblProductActive TABLE (
		ProductId	INT,
		ProductName	VARCHAR(50),
		ProductCode	VARCHAR(10),
		IsEnable	BIT)

	SELECT @Site = LicenseeName
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeId 

	INSERT INTO @tblSuper (SrecommendID)
	SELECT CustID
	FROM DBCUST.CUSTDB.dbo.Dep_CustSuper WITH (NOLOCK)
	WHERE Site = @Site

	IF EXISTS (SELECT 1 FROM @tblSuper)
	BEGIN
		INSERT INTO @tblProductActive (
			ProductId,
			ProductName,
			ProductCode,
			IsEnable)
		SELECT
			p.ProductID,
			p.ProductName,
			p.ProductPrefix AS ProductCode,
			CASE
				WHEN p.ProductID IN (10, 11, 12) OR p.ApplyDCS = 1 THEN 0
				ELSE 1
			END
		FROM dbo.Product3rd AS p WITH (NOLOCK)
			INNER JOIN dbo.LicenseeProduct3rd AS lp WITH (NOLOCK) ON p.Productid = lp.ProductID
		WHERE lp.LicenseeID  = @LicenseeId

		UNION ALL

		SELECT
			0,
			'Sportsbook',
			'SB',
			1

		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductId = 10)	-- AGCasino
		BEGIN
			IF EXISTS ( SELECT 1
						FROM DBCUST.CustDB.dbo.Dep_SuperSetting_AGCasino AS s WITH (NOLOCK)
							INNER JOIN @tblSuper AS su ON s.CustID = su.SrecommendID
						WHERE IsEnabled = 1)
				UPDATE @tblProductActive
				SET IsEnable = 1
				WHERE ProductId = 10
		END

		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductId = 11)	-- Gold Deluxe
		BEGIN
			IF EXISTS (	SELECT 1
						FROM bodb02.dbo.CustInfo AS ci WITH (NOLOCK)
							INNER JOIN @tblSuper AS r ON ci.srecommend = r.SrecommendID
						WHERE ci.DisableGoldDeluxe = 0)
				UPDATE @tblProductActive
				SET IsEnable = 1
				WHERE ProductId = 11
		END

		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductId = 12)	-- Vegas Games
		BEGIN
			IF EXISTS ( SELECT 1
						FROM DBCUST.CustDB.dbo.Dep_SupperProductSetting AS s WITH (NOLOCK)
							INNER JOIN @tblSuper AS su ON s.CustID = su.SrecommendID
						WHERE s.ProductID = 12 AND IsEnabled = 1)
				UPDATE @tblProductActive
				SET IsEnable = 1
				WHERE ProductId = 12
		END

		--check DCS setting
		;WITH tmp AS(
		SELECT DISTINCT ps.ProductID 
		FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting AS lps WITH (NOLOCK)
			INNER JOIN DBCUST.CustDB.dbo.Dep_ProductSetting AS ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
			INNER JOIN @tblSuper AS su ON lps.CustID = su.SrecommendID
		WHERE ps.ProductID IN (SELECT productID FROM dbo.Product3rd p WITH (NOLOCK) WHERE applyDCS = 1)
		)
		UPDATE t
		SET IsEnable = 1
		FROM @tblProductActive t
		WHERE productID IN (SELECT productID FROM tmp)
	END

	SELECT
		ProductID,
		ProductName,
		ProductCode,
		IsEnable
	FROM @tblProductActive
	WHERE ProductID NOT IN (1, 3, 4, 7, 9, 14, 17)
		AND (ProductID < 34 OR ProductID = 63)
	ORDER BY ProductID ASC
END

GO 
