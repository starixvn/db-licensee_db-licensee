/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelBetTypeBySport]
	@SportList VARCHAR(4000)
AS

/*
	Created: 20131010@Don
	Task: Add more products to Customer Turnover Report
	DB: DBEXT.bodb02

	Revisions:
		- 20131126@Jim: return English Name when Other Language Name is NULL or not ready
		- 20131205@Florent: Add more product ( V.Tennis, V.Racing)
		- 20140210@Florent: add new sport Horse racing fix odds
		- 20140424@Florent: add new sport Virtual Speedway & Virtual Cycling
		- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
		- 20140911@Jim: add new sport Esport
		- 20141017@Jim : Apply for the change in Sporting Solution structure (#24478)
		- 20150415@Jim: support Betradar phase 2
		- 20150714@Winnie: Exclude 901,902,903
		- 20151022@Jim: offer MuayThai
		- 20151023@Victor: Support New Simplified Chinese
		- 20151210@Bobby: Fixbug#49033-49298 and apply SportBettypeMatrix & group bettype
		- 20151217@Bobby: Fixbug#49486 - Remove unsupported and mixed bettype
		- 20160217@Jim: exclude bettype 500 (Charge Commission),502 (Match Winner 1X2) since those bettype not offer for deposit model (redmine #50759 )
		- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
		- 20170330@Paul: Implement Cash Out [RedmineID: #71727]
		- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20170919@Percy: Change way get SportBettypeMatrix [RedmineID: #83442]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180424@Joseph: Fix bug group VS2: BasketBall - Virual Soccer [RedmineID: #93844]
		- 20180703@Amanda: Refactor code [RedmineID: #80941]
		- 20181214@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190531@Amanda: Get correct translation [RedmineID: #114464]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20201231@Louis: Integrate Happy 5 Linked Games [RedmineID: #147446]
		- 20220224@Hogan: Integrate Virtual Sports 3 (Leap Gaming)[RedmineID: #145337]
		- 20220311@Kos: Support Parlay sport [RedmineID: #169282]
					- Remove input param @LicenseeID, @Langkey
					- Move SP from DBLIC.bodb_Licensee to DBEXT.bodb02
		- 20220329@Hogan: Hide Mix Parlay (bettypeID 9)[RedmineID: #170438]
		- 20220714@Hogan: Integrate Volleyball AIO [RedmineID: #175143]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]

	Param's Explanation:
		- @SportList: XML format (999: Parlay sport)
			<products>
				<product ID="1" Sport="1,2,3,99,999"></product>
				<product ID="990" Sport="190,191,192,193,194,195,196,197"></product>
			</products>
*/

BEGIN
	SET NOCOUNT ON

	-- Get product and sport type list
	DECLARE @TempProduct AS TABLE (ProductId SMALLINT, SportList VARCHAR(1000))
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @SportList

		INSERT INTO @TempProduct (ProductId, SportList)
		SELECT ID, Sport
		FROM OPENXML (@DocHandler, '/products/product',1) WITH(ID SMALLINT, Sport NVARCHAR(1000))

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	-- Get sport string
	DECLARE @StrSport VARCHAR(4000)

	SELECT @StrSport = COALESCE(@StrSport + ',', '') + CAST(SportList AS VARCHAR(1000))
	FROM @TempProduct

	-- Get sport list
	DECLARE @SportFilter TABLE (SportType SMALLINT)

	INSERT INTO @SportFilter
	SELECT DISTINCT val
	FROM dbo.strSplit(@StrSport,',')

	IF EXISTS (SELECT 1 FROM @SportFilter WHERE SportType = 1)
		AND NOT EXISTS (SELECT 1 FROM @SportFilter WHERE SportType = 99)
	BEGIN
		INSERT INTO @SportFilter(SportType) VALUES(99)
	END

	-- Get sport/bettype matrix
	CREATE TABLE #SportBetType (ProductId TINYINT, BetType SMALLINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBetType (ProductId, BetType)
	SELECT DISTINCT s.ProductID, s.BetType
	FROM dbo.SportBettypeMatrix AS s WITH (NOLOCK)
		INNER JOIN @SportFilter AS f ON f.SportType = s.SportType
	WHERE s.IsTest <= @IsTest
		AND s.bettype NOT IN (901, 902, 903, 904, 500, 502, 300, 301, 302, 303, 304, 911, 912, 913, 914, 999, 18999, 9, 29, 38)
		AND s.bettype NOT BETWEEN 801 AND 899	-- Metric Gaming
		AND (s.SportType <> 5 OR s.BetType NOT IN (5, 15))		-- Tennis

	-- Insert Parlay bettypes
	IF EXISTS (SELECT 1 FROM @SportFilter WHERE SportType = 999)
	BEGIN
		INSERT INTO #SportBetType (ProductId, BetType)
		SELECT 1, 38
		UNION SELECT 1, 29
	END

	-- Group bettypes
	DECLARE @BetType TABLE (BetType SMALLINT, ProductID INT)

	;WITH CTE_GroupBettype AS (
		SELECT ISNULL(ss.GroupTypeId, sp.BetType) AS BetType, ISNULL(lf.GroupProductId,lf.ProductId) ProductId
		FROM #SportBetType AS sp
			LEFT JOIN dbo.Lrf_f_GroupBettype() AS ss ON sp.BetType = ss.bettype
			LEFT JOIN dbo.Lrf_f_GroupProduct() AS lf on lf.ProductId = sp.ProductId
		GROUP BY ISNULL(ss.GroupTypeId, sp.BetType), ISNULL(lf.GroupProductId,lf.ProductId)
	)
	INSERT INTO @BetType (BetType, ProductID)
	SELECT DISTINCT BetType, ProductID
	FROM CTE_GroupBettype

	-- Return result
	DECLARE @SBProductCodes VARCHAR(500) = dbo.Lrf_f_GroupProductCode('SB')

	SELECT
		CASE
			WHEN ',' + @SBProductCodes + ',' LIKE '%,' + p.ProductPrefix + ',%' THEN ''
			ELSE p.ProductPrefix
		END AS ProductPrefix,
		bt.BetType
	FROM @BetType AS bt
		INNER JOIN dbo.Products AS p WITH (NOLOCK) ON p.ProductID = bt.ProductId
	ORDER BY bt.BetType ASC

	DROP TABLE #SportBetType
END
GO
