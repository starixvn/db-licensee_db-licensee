/*<info serverAlias="DBLIC-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_LicenseeProductByBetLimitSel]
	@LicenseeName VARCHAR(50)
AS

/*
	Created: 20190626@Johnson
	Task: Product list hardcode which offered for selected licensees
	DB: DBLIC/bodb_licensee
	Original: Lrf_LicenseeProductSel
	
	Revisions:
		- 20190626@Johnson: initial sp [redmine: #112658]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20210305@Hogan: Add new product Sport Lottery [RedmineID: #150872]
		- 20210629@Johnson: Add more products to support enable status [redmine:#156680]
		- 20210630@Hogan: Integrate Creative Gaming [RedmineID: #152619]
*/

 /*
 EXEC Lrf_LicenseeProductByBetLimitSel
	@LicenseeID='12bet'
 */

BEGIN
	SET NOCOUNT ON

	DECLARE @LicenseeID	INT

	DECLARE @tblSuper AS TABLE (SrecommendID INT)
	DECLARE @tblProductActive AS TABLE (
		ProductID INT,
		ProductName VARCHAR(50),
		ProductCode VARCHAR(10),
		isEnable BIT)

	SELECT @LicenseeiD = LicenseeiD
	FROM dbo.Licensees WITH (NOLOCK) 
	WHERE LicenseeName = @LicenseeName 

	INSERT INTO @tblSuper (SrecommendID)
	SELECT CustID
	FROM DBCUST.CustDB.dbo.Dep_CustSuper WITH (NOLOCK)
	WHERE Site = @LicenseeName

	IF EXISTS (SELECT 1 FROM @tblSuper)
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
			IF EXISTS (SELECT 1
						FROM DBCUST.CustDB.dbo.Dep_SuperSetting_AGCasino s WITH (NOLOCK)
							INNER JOIN @tblSuper su ON s.CustID = su.SrecommendID
						WHERE IsEnabled = 1)
				UPDATE @tblProductActive
				SET isEnable = 1
				WHERE ProductID = 10
		END

		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 11)   -- Gold Deluxe
		BEGIN
			IF EXISTS (SELECT 1
						FROM bodb02.dbo.CustInfo ci WITH (NOLOCK)
							INNER JOIN @tblSuper r ON ci.srecommend = r.SrecommendID
						WHERE ci.DisableGoldDeluxe = 0)
				UPDATE @tblProductActive
				SET isEnable = 1
				WHERE ProductID = 11
		END

		IF EXISTS (SELECT 1 FROM @tblProductActive WHERE ProductID = 12)	-- Vegas Games
		BEGIN 
			IF EXISTS (SELECT 1
				FROM DBCUST.CustDB.dbo.Dep_SupperProductSetting s WITH (NOLOCK)
					INNER JOIN @tblSuper su ON s.CustID = su.SrecommendID
				WHERE s.ProductID = 12 AND IsEnabled = 1)
				UPDATE @tblProductActive
				SET isEnable = 1
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

	--only show list products hardcode
	SELECT
		ProductID
		,ProductName
		,ProductCode
		,isEnable
	FROM @tblProductActive t 
	WHERE ProductID IN (0,--Sportsbook
			2,--	Number Game
			5,--	Virtual Sports
			27,--	Virtual Sports 2
			10,--	AG Casino
			8,--	RNG Keno
			28,--	Lottery
			40,--	Table
			43,--	I4D
			63,--	SLT
			62,--	Creative Gaming
			
			--20210629@Johnson: add more products
			6,--	RnG Casino
			15,--	Colossus Bets
			21,--	Allbet
			22,--	Macau Games
			25,--	Cash Out
			31,--	Exchange
			32,--	Pragmatic
			45,--	AE Sexy
			59,--	GDG
			61,--	Habanero
			56,--	Joker
			42,--	Saba.club
			45,--	AE Sexy
			51,--	WM
			36,--	SG
			38,--	Virtual Games
			39,--	SA Gaming
			34,--	Arcadia Gaming
			55--	PG Soft
		)
	ORDER BY ProductID ASC
END

GO 
