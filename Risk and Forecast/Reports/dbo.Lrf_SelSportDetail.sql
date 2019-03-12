/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelSportDetail]
	@LicenseeID		INT,
	@langkey		VARCHAR(20)='en-US',
	@ProductCodes	VARCHAR(500)=''
AS 
/*
Created: 20131010@Don
Task : Add more products to Customer Turnover Report
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
	
Param's Explanation:
	- @ProductCodes = '' - Get all
*/
/* sample test case:
	[Lrf_SelSportDetail]
	@LicenseeID=1,
	@ProductCodes='SB,BA'

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Products AS TABLE (Code VARCHAR(10))

	INSERT INTO @Products (Code)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	DECLARE @Product3rds AS TABLE (Code VARCHAR(10))
	IF EXISTS (SELECT 1 FROM @Products WHERE Code = '')
	BEGIN
		INSERT INTO @Product3rds(Code)
		SELECT p.ProductPrefix
		FROM dbo.Product3rd p WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd l WITH (NOLOCK) ON p.Productid = l.ProductID
		WHERE l.LicenseeID = @LicenseeID AND p.ProductPrefix IN ('BA', 'NG', 'VS', 'VS2', 'KN', 'LT', 'CO')
	END
	ELSE
	BEGIN
		INSERT INTO @Product3rds(Code)
		SELECT p.ProductPrefix
		FROM @Products po
		INNER JOIN dbo.Product3rd p WITH (NOLOCK) ON p.ProductPrefix = po.Code
		INNER JOIN dbo.LicenseeProduct3rd l WITH (NOLOCK) ON p.Productid = l.ProductID
		WHERE l.LicenseeID = @LicenseeID AND p.ProductPrefix IN ('BA', 'NG', 'VS', 'VS2', 'KN', 'LT', 'CO')
	END

	DECLARE @ProductSport TABLE (
		ID INT 
		,Name nvarchar(50)
		,ParentID smallint
	)

	-- SB --
	IF EXISTS (SELECT 1 FROM @Products WHERE Code = '' OR Code = 'SB')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT	0,
				CASE @Langkey
					WHEN 'zh-CN'	THEN N'体育博彩'
					WHEN 'zh-TW'	THEN N'體育博彩'
					WHEN 'zh-Hans'	THEN N'体育博彩'
					WHEN 'th-TH'	THEN N'อัตราค่าตอบแทนจากหน้ากีฬา'
					WHEN 'ja-JP'	THEN N'スポーツベット '
					WHEN 'ko-KR'	THEN N'스포츠북 '
					WHEN 'es'  	    THEN N'Sportsbook'
					WHEN 'vi-VN'	THEN N'Thể thao'
					ELSE N'Sportbook' END,
				NULL
		UNION ALL
		SELECT ID, NULL, 0
		FROM dbo.Lrf_f_GetSportTypeByProduct('SB')
	END
	-- BA --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'BA')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT	3,
				'Bet Aggregator',
				NULL
		UNION ALL
		SELECT ID, NULL, 0
		FROM dbo.Lrf_f_GetSportTypeByProduct('BA')
	END
	-- VS --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'VS')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT	
			999,
			CASE @Langkey
				/*WHEN 'zh-CN'	THEN N'体育博彩'
				WHEN 'zh-TW'	THEN N'體育博彩'
				WHEN 'zh-Hans'	THEN N'体育博彩'
				WHEN 'th-TH'	THEN N'อัตราค่าตอบแทนจากหน้ากีฬา'
				WHEN 'ja-JP'	THEN N'スポーツベット '
				WHEN 'ko-KR'	THEN N'스포츠북 '*/
				WHEN 'es'  	    THEN N'Virtual Sports'
				WHEN 'vi-VN'	THEN N'Virtual Sports'
				ELSE N'Virtual Sports' END,
			NULL
		UNION ALL
		SELECT ID, NULL, 999
		FROM dbo.Lrf_f_GetSportTypeByProduct('VS')
	END
	-- VS2 --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'VS2')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT 
			990,
			CASE @Langkey
				/*WHEN 'zh-CN'	THEN N'体育博彩'
				WHEN 'zh-TW'	THEN N'體育博彩'
				WHEN 'zh-Hans'	THEN N'体育博彩'
				WHEN 'th-TH'	THEN N'อัตราค่าตอบแทนจากหน้ากีฬา'
				WHEN 'ja-JP'	THEN N'スポーツベット '
				WHEN 'ko-KR'	THEN N'스포츠북 '*/
				WHEN 'es'  	    THEN N'Virtual Sports 2'
				WHEN 'vi-VN'	THEN N'Virtual Sports 2'
				ELSE N'Virtual Sports 2' END,
			NULL
		UNION ALL
		SELECT ID, NULL, 990
		FROM dbo.Lrf_f_GetSportTypeByProduct('VS2')
	END
	-- NG --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'NG')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT
			161,
		 	CASE @Langkey
				WHEN 'zh-CN'	THEN N'百練賽'
				WHEN 'zh-TW'	THEN N'百练赛'
				WHEN 'zh-Hans'	THEN N'百練賽'
				WHEN 'th-TH'	THEN N'เกมหมายเลข'
				WHEN 'ja-JP'	THEN N'番号ゲーム'
				WHEN 'ko-KR'	THEN N'라이브빙고'
				WHEN 'es'  	    THEN N'Number Game'
				WHEN 'vi-VN'	THEN N'Number Game'
				ELSE N'Number Game' END,
		 	NULL
		UNION ALL
		SELECT ID, NULL, 161
		FROM dbo.Lrf_f_GetSportTypeByProduct('NG')
	END

	-- KN --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'KN')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT 202, N'Keno', NULL
		UNION ALL
		SELECT ID, NULL, 202
		FROM dbo.Lrf_f_GetSportTypeByProduct('KN')
	END

	-- LT --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'LT')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT 220, N'Lottery', NULL
		UNION ALL
		SELECT ID, NULL, 220
		FROM dbo.Lrf_f_GetSportTypeByProduct('LT')
	END

	-- CO --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'CO')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		SELECT 1, 
		 	CASE @Langkey
				WHEN 'zh-CN'	THEN N'即时兑现'
				WHEN 'zh-TW'	THEN N'即時兌現'
				WHEN 'zh-Hans'	THEN N'即时兑现'
				ELSE N'Cash Out' END,
			NULL
		UNION ALL
		SELECT ID, NULL, 1
		FROM dbo.Lrf_f_GetSportTypeByProduct('CO')
	END

	SELECT ps.ID, ps.ParentID, ps.Name
	FROM @ProductSport ps
	WHERE ps.ParentID IS NULL
	UNION ALL
	SELECT	ps.ID, ps.ParentID,
			CASE @Langkey
				WHEN 'zh-CN'	THEN CASE  WHEN SportNameCs IS NULL OR SportNameCs = '' THEN SportName 
								ELSE SportNameCs END
				WHEN 'zh-TW'	THEN CASE  WHEN SportNameCh IS NULL OR SportNameCh = '' THEN SportName 
								ELSE SportNameCh END
				WHEN 'zh-Hans'	THEN CASE  WHEN SportNameCs IS NULL OR SportNameCs = '' THEN SportName 
								ELSE SportNameCs END
				WHEN 'th-TH'	THEN CASE  WHEN SportNameTh IS NULL OR SportNameTh = '' THEN SportName 
								ELSE SportNameTh END
				WHEN 'ja-JP'	THEN CASE  WHEN SportNameJp IS NULL OR SportNameJp = '' THEN SportName 
								ELSE SportNameJp END
				WHEN 'ko-KR'	THEN CASE  WHEN SportNameKo IS NULL OR SportNameKo = '' THEN SportName 
								ELSE SportNameKo END
				WHEN 'es'  	    THEN CASE  WHEN SportNameES IS NULL OR SportNameES = '' THEN SportName 
								ELSE SportNameES END
				WHEN 'vi-VN'	THEN CASE  WHEN SportNameVN IS NULL OR SportNameVN = '' THEN SportName 
								ELSE SportNameVN END
				ELSE SportName END
			AS Name
	FROM @ProductSport ps
	INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON ps.ID = s.SportType AND ps.ParentID IS NOT NULL
END

GO