/*<info serverAlias="DBLIC-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelSportDetail]
	@LicenseeId		INT,
	@ProductCodes	VARCHAR(500)	= ''
AS

/*
	Created: 20131010@Don
	Task: Add more products to Customer Turnover Report
	DB: DBLIC/bodb_Licensee

	Revisions:
		- 20131127@Jim: support multi language
		- 20131205@Florent: add more bettype for V.Tennis, V.Racing
		- 20140117@Florent: add new sport 154
		- 20140425@Florent: add new sport
							+ 183 Virtual Speedway
							+ 185 Virtual Cycling 
		- 20151023@Victor: Support New Simplified Chinese
		- 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
		- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
		- 20180629@Amanda: Add new param @ProductCodes and use Lrf_f_GetSportTypeByProduct to get sports for product [Redmine: #80941]
		- 20181218@Joseph: Remove vnteam [Redmine: #105409]
		- 20181213@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
		- 20190227@Joseph: Betting ticket center phase 3b [RedmineID: #108221]
		- 20190516@Amanda: Rename product Keno [RedmineID: #113398]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
					- Remove input param @LangKey
		- 20220224@Hogan: Integrate Virtual Sports 3 (Leap Gaming)[RedmineID: #145337]
		- 20220429@Kos: Support Bitcoin [RedmineID: #160160]
		- 20230801@Evan: Integrate Virtual Sports 3 (Leap Gaming New) [RedmineID: #190908]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only  + Remove VS3 (old) [RedmineID: #199523]
		- 20242901@Evan: Integrate VS4 [RedmineID: #199347]
		- 20241024@Kelvin: LAP - Integrate Betby (VS6) [RedmineID: #212446]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]
		
	Param's Explanation:
		- @ProductCodes = '' - Get all
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Product3rds AS TABLE (Code VARCHAR(10), Productid INT)

	INSERT INTO @Product3rds(Code, Productid)
	SELECT p.ProductPrefix, p.Productid
	FROM dbo.Product3rd AS p WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd AS l WITH (NOLOCK) ON p.Productid = l.ProductID
	WHERE l.LicenseeID = @LicenseeID
		AND p.ProductPrefix IN ('NG', 'VS', 'KN', 'LT', 'CO', 'TG', 'I4D')
		AND (@ProductCodes = ''
			OR ',' + @ProductCodes + ',' LIKE '%,' + p.ProductPrefix + ',%')

	INSERT INTO @Product3rds (Code, Productid)
	SELECT lf.ProductPrefix, lf.ProductId 
	FROM @Product3rds p 
		INNER JOIN bodb02.dbo.Lrf_f_GroupProduct() lf ON p.ProductID = lf.GroupProductId AND lf.GroupProductId <> lf.ProductId

	DECLARE @ProductSport TABLE (
		Id			INT,
		Name		NVARCHAR(50),
		ParentId	SMALLINT
	)

	-- SB --
	IF @ProductCodes = ''
		OR ',' + @ProductCodes + ',' LIKE '%,SB,%'
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 0, 'SB', NULL
		UNION ALL
		SELECT Id, NULL, 0
		FROM dbo.Lrf_f_GetSportTypeByProduct('SB')
		UNION ALL
		SELECT Id, NULL, 0
		FROM dbo.Lrf_f_GetSportTypeByProduct('SLT')
		WHERE ',' + @ProductCodes + ',' LIKE '%,SLT,%'
		UNION ALL
		SELECT Id, NULL, 0
		FROM dbo.Lrf_f_GetSportTypeByProduct('BTC')
		WHERE ',' + @ProductCodes + ',' LIKE '%,BTC,%'
	END

	-- VS --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'VS')
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 999, 'VS', NULL
		UNION ALL
		SELECT Id, NULL, 999
		FROM dbo.Lrf_f_GetSportTypeByProduct('VS')
		UNION ALL
		SELECT Id, NULL, 999
		FROM dbo.Lrf_f_GetSportTypeByProduct('VS2')
		UNION ALL
		SELECT Id, NULL, 999
		FROM dbo.Lrf_f_GetSportTypeByProduct('LG')
		UNION ALL
		SELECT Id, NULL, 999
		FROM dbo.Lrf_f_GetSportTypeByProduct('VS4')
		UNION ALL
		SELECT Id, NULL, 999
		FROM dbo.Lrf_f_GetSportTypeByProduct('VS6')
	END

	-- NG --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'NG')
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 161, 'NG', NULL
		UNION ALL
		SELECT Id, NULL, 161
		FROM dbo.Lrf_f_GetSportTypeByProduct('NG')
	END

	-- KN --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'KN')
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 202, 'KN', NULL
		UNION ALL
		SELECT Id, NULL, 202
		FROM dbo.Lrf_f_GetSportTypeByProduct('KN')
	END

	-- LT --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'LT')
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 220, 'LT', NULL
		UNION ALL
		SELECT Id, NULL, 220
		FROM dbo.Lrf_f_GetSportTypeByProduct('LT')
	END

	-- CO --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'CO')
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 1, 'CO', NULL
		UNION ALL
		SELECT Id, NULL, 1
		FROM dbo.Lrf_f_GetSportTypeByProduct('CO')
	END

	-- TG --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'TG')
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 222, 'TG', NULL
		UNION ALL
		SELECT Id, NULL, 222
		FROM dbo.Lrf_f_GetSportTypeByProduct('TG')
	END

	-- I4D --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'I4D')
	BEGIN
		INSERT INTO @ProductSport(Id, Name, ParentId)
		SELECT 223, 'I4D', NULL
		UNION ALL
		SELECT Id, NULL, 223
		FROM dbo.Lrf_f_GetSportTypeByProduct('I4D')
	END

	SELECT
		ps.Id,
		ps.ParentId,
		ps.Name
	FROM @ProductSport AS ps
	WHERE ps.ParentID IS NULL
	UNION ALL
	SELECT
		ps.Id,
		ps.ParentId,
		s.SportName AS Name
	FROM @ProductSport AS ps
		INNER JOIN bodb02.dbo.Sports AS s WITH (NOLOCK) ON ps.ID = s.SportType AND ps.ParentID IS NOT NULL
	ORDER BY ps.Id
END
GO
