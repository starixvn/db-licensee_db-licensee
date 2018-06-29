/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelSportDetail]
	@LicenseeID		INT,
	@langkey		VARCHAR(20)='en-US',
	@ProductCodes	VARCHAR(50)=''
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
	- 20180629@Amanda: Add new param @ProductCodes [Redmine: #80941]
	
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
		WHERE l.LicenseeID = @LicenseeID AND p.ProductPrefix IN ('NG', 'VS', 'VS2')
	END
	ELSE
	BEGIN
		INSERT INTO @Product3rds(Code)
		SELECT p.ProductPrefix
		FROM @Products po
		INNER JOIN dbo.Product3rd p WITH (NOLOCK) ON p.ProductPrefix = po.Code
		INNER JOIN dbo.LicenseeProduct3rd l WITH (NOLOCK) ON p.Productid = l.ProductID
		WHERE l.LicenseeID = @LicenseeID AND p.ProductPrefix IN ('NG', 'VS', 'VS2')
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
		SELECT 0--cast(0 AS VARCHAR)
				,
				CASE @Langkey
								WHEN 'zh-CN'	THEN N'体育博彩'
								WHEN 'zh-TW'	THEN N'體育博彩'
								WHEN 'zh-Hans'	THEN N'体育博彩'
								WHEN 'th-TH'	THEN N'อัตราค่าตอบแทนจากหน้ากีฬา'
								WHEN 'ja-JP'	THEN N'スポーツベット '
								WHEN 'ko-KR'	THEN N'스포츠북 '
								WHEN 'es'  	    THEN N'Sportsbook'
								WHEN 'vi-VN'	THEN N'Thể thao'
								ELSE N'Sportbook' END 
				, NULL
		UNION ALL
		SELECT SportType--cast (SportType AS VARCHAR)
				,CASE @Langkey
				WHEN 'zh-CN'	THEN CASE  WHEN (ISNULL(SportNameCs,'')='' OR len(SportNameCs)=0) THEN SportName 
								ELSE SportNameCs END
				WHEN 'zh-TW'	THEN CASE  WHEN (ISNULL(SportNameCh,'')='' OR len(SportNameCh)=0) THEN SportName 
								ELSE SportNameCh END
				WHEN 'zh-Hans'	THEN CASE  WHEN (ISNULL(SportNameCs,'')='' OR len(SportNameCs)=0) THEN SportName 
								ELSE SportNameCs END
				WHEN 'th-TH'	THEN CASE  WHEN (ISNULL(SportNameTh,'')='' OR len(SportNameTh)=0) THEN SportName 
								ELSE SportNameTh END
				WHEN 'ja-JP'	THEN CASE  WHEN (ISNULL(SportNameJp,'')='' OR len(SportNameJp)=0) THEN SportName 
								ELSE SportNameJp END
				WHEN 'ko-KR'	THEN CASE  WHEN (ISNULL(SportNameKo,'')='' OR len(SportNameKo)=0) THEN SportName 
								ELSE SportNameKo END
				WHEN 'es'  	    THEN CASE  WHEN (ISNULL(SportNameES,'')='' OR len(SportNameES)=0) THEN SportName 
								ELSE SportNameES END
				WHEN 'vi-VN'	THEN CASE  WHEN (ISNULL(SportNameVN,'')='' OR len(SportNameVN)=0) THEN SportName 
								ELSE SportNameVN END
				ELSE SportName END
				SportName
				, 0
		FROM bodb02.dbo.Sports WITH(NOLOCK)
		WHERE SportType <= 99 OR SportType = 154
	END
	-- VS --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'VS')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		VALUES	
		(999,
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
		 NULL),
		(180,
		 CASE @Langkey
			WHEN 'zh-CN'	THEN N'虛擬足球'
			WHEN 'zh-TW'	THEN N'虚拟足球'
			WHEN 'zh-Hans'	THEN N'虛擬足球'
			WHEN 'th-TH'	THEN N'ฟุตบอลอนิเมชั่น'
			WHEN 'ja-JP'	THEN N'Virtual Soccer'
			WHEN 'ko-KR'	THEN N'가상 축구'
			WHEN 'es'  	    THEN N'Virtual Soccer'
			WHEN 'vi-VN'	THEN N'Virtual Soccer'
			ELSE N'Virtual Soccer' END,
		 999),
		(186, N'Virtual Tennis', 999),
		(184, N'Virtual Motor Racing', 999),
		(181, N'Virtual Horse Racing', 999),
		(182, N'Virtual Greyhounds', 999),
		(183, N'Virtual Speedway', 999),
		(185, 'Virtual Cycling', 999)
	END
	-- VS2 --
	IF EXISTS (SELECT 1 FROM @Product3rds WHERE Code = 'VS2')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		VALUES 
		(990,
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
		 NULL),
		(190, N'Virtual Soccer League', 990),
		(191, N'Virtual Soccer Nation', 990),
		(192, N'Virtual Soccer World Cup', 990),
		(193, N'Virtual Basketball', 990)
	END
	-- NG --
	IF EXISTS (SELECT 1 FROM @Products WHERE Code = '' OR Code = 'NG')
	BEGIN
		INSERT INTO @ProductSport(ID, Name, ParentID)
		VALUES
		(161,
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
		 NULL)
	END

SELECT * FROM @ProductSport
--ORDER BY ID ASC 
END

GO
GRANT EXECUTE ON [dbo].[Lrf_SelSportDetail] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelSportDetail] TO [vnteam]