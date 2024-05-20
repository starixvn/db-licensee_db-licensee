/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_LicenseeProductByBetLimitSel]
	@LicenseeName VARCHAR(50)
	,@SettingStatus TINYINT = 0
AS

/*
	Created: 20190626@Johnson
	Task: Product list hardcode which offered for selected licensees
	DB: DBCUST/bodb_licensee
	Original: Lrf_LicenseeProductSel
	
	Revisions:
		- 20190626@Johnson: initial sp [redmine: #112658]
		- 20200406@Hogan: Add new product Table Games [RedmineID: #131447]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20210305@Hogan: Add new product Sport Lottery [RedmineID: #150872]
		- 20210629@Johnson: Add more products to support enable status [redmine:#156680]
		- 20210630@Hogan: Integrate Creative Gaming [RedmineID: #152619]
		- 20210811@Hogan: Hide Disable/Enable button of products Allbet, Macau games, SA Gaming, AE Sexy, WM, GDG[RedmineID: #160031]
		- 20210818@Johnson: Add Vgaming [redmine:#159696]
		- 20211105@Hogan: Integrate AdvantPlay RNG & Mini [RedmineID: #158186]
		- 20220224@Hogan: Integrate Virtual Sports 3 (Leap Gaming)[RedmineID: #145337]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220429@Hogan: Integrate Bitcoin [redmine:#160160]
		- 20220601@Hogan: Integrate FGG Guaranteed Gaming [RedmineID: #167897]
		- 20220601@Hogan: Integrate MaxGame [RedmineID: #172919]
		- 20220301@Eden: Deposit - Sportsbook - Revise customer settings [Redmine: #167898]
		- 20230130@Evan: Integrate Jili [RedmineID: #182914]
	    - 20230303@Evan: Remove inactive products CB, FW, GD, GDG [Redmine: 181424]  
    	- 20230523@Evan: Integrate YeeBet LC [RedmineID: #187947]
		- 20230626@Evan: Integrate MG-RNG (Normal+Promotion Game) [RedmineID: #189988]
		- 20230913@Luke: Integrate Virtual Sports 3 [Redmine: #193901]
						 Remove Virtual Sports 3 (Old)
		- 20231123@Johnson: Add Seal Entertainment [redmine: #180380]				 
		- 20231124@Luke: Integrate WE Live Casino [Redmine: #196573]
		- 20240501@Tacy: Integrate Live22 [Redmine: #197702]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports & move to DBCUST [Redmine: #199523]

*/

 /*
 EXEC Lrf_LicenseeProductByBetLimitSel
	@LicenseeName='12bet'
 */

BEGIN
	SET NOCOUNT ON

	DECLARE @LicenseeID	INT

	DECLARE @tblSuper AS TABLE (SrecommendID INT)
	DECLARE @tblProductActive AS TABLE (
		ProductID INT,
		ProductName VARCHAR(50),
		ProductCode VARCHAR(10),
		isEnable BIT DEFAULT (0))

	SELECT @LicenseeiD = LicenseeiD
	FROM dbo.Licensees WITH (NOLOCK) 
	WHERE LicenseeName = @LicenseeName 

	INSERT INTO @tblSuper (SrecommendID)
	SELECT CustID
	FROM CustDB.dbo.Dep_CustSuper WITH (NOLOCK)
	WHERE Site = @LicenseeName

	IF EXISTS (SELECT 1 FROM @tblSuper)
	BEGIN
		INSERT INTO @tblProductActive (ProductID,ProductName,ProductCode,isEnable)
		SELECT
			p.ProductId
			,p.ProductName
			,p.ProductPrefix AS  ProductCode
			,CASE WHEN p.ProductID IN (10,3,37) OR ApplyDCS = 1 THEN 0 ELSE 1 END --AG Casino, BA, Saba Promotion
		FROM dbo.Product3rd p WITH (NOLOCK) 
			INNER JOIN dbo.LicenseeProduct3rd lp WITH (NOLOCK) ON p.ProductId = lp.ProductId
		WHERE lp.LicenseeID  = @LicenseeID AND OfferSite IN (0,2)
			AND ((Enabled=1 AND ISNULL(p.EndOfSupportDate, GETDATE())>= CAST(GETDATE() AS DATE)) 
				OR p.Productid=25) --Cash Out (enabled by default, following Sportsbook [#165160])

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

		--check DCS setting
		;WITH tmp AS(
			SELECT DISTINCT ps.ProductID 
			FROM DBCUST.CustDB.dbo.Dep_LicenseeProductSetting lps WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Dep_ProductSetting ps WITH (NOLOCK) ON lps.ProductSettingID = ps.ProductSettingID
				INNER JOIN CustDB.dbo.Dep_ProductSettingDetail psd WITH (NOLOCK) ON psd.ProductSettingID = ps.ProductSettingID
				INNER JOIN @tblSuper su ON lps.CustID = su.SrecommendID
			WHERE ps.ProductID IN (SELECT productID FROM dbo.Product3rd p WITH (NOLOCK) WHERE applyDCS = 1)
				AND psd.SettingStatus<=@SettingStatus AND ps.SettingType=4 --Product Status
		)
		UPDATE t
		SET isEnable = 1
		FROM @tblProductActive t
		WHERE productID IN (SELECT productID FROM tmp)
	END

	--Alway enable for SB/NG/Keno
	UPDATE t
	SET IsEnable = 1
	FROM @tblProductActive t
	WHERE productID IN (0,2,8)

	--only show list products hardcode
	SELECT
		ProductID
		,ProductName
		,ProductCode
		,isEnable
	FROM @tblProductActive t 
	WHERE T.isEnable=1
	AND ProductID NOT IN (
			 21 -- Allbet
			,22 -- Macau Games
			,39 -- SA Gaming
			,45 -- AE Sexy
			,51 -- WM
			,57 -- BG	
		)
	ORDER BY ProductID ASC
END
GO