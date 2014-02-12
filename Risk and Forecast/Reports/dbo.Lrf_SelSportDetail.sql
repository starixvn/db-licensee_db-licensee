USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_SelSportDetail]    Script Date: 12/02/2014 10:09:10 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_SelSportDetail]
	@LicenseeID int,
	@langkey VARCHAR(20)='en-US'
AS 
/*
Created: 20131010@Don
Task : Add more products to Customer Turnover Report
DB: DBLIC/bodb_Licensee

Revisions:
	- 20131127@Jim: support multi language
	- 20131205@Florent: add more bettype for V.Tennis, V.Racing
	- 20140117@Florent: add new sport 154
Param's Explanation:
	
*/
/* sample test case:
	[Lrf_SelSportDetail]
	@LicenseeID=1

*/
DECLARE @ProductSport TABLE (
	ID INT 
	,Name nvarchar(50)
	,ParentID smallint
)

INSERT INTO @ProductSport(ID, Name, ParentID)
	SELECT 0--cast(0 AS VARCHAR)
			,
			CASE @Langkey
							WHEN 'zh-CN'	THEN N'体育博彩'
							WHEN 'zh-TW'	THEN N'體育博彩'
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
			WHEN 'zh-CN'	THEN CASE  WHEN (ISNULL(SportNameCh,'')='' OR len(SportNameCh)=0) THEN SportName 
												   ELSE SportNameCh END
			WHEN 'zh-TW'	THEN CASE  WHEN (ISNULL(SportNameCs,'')='' OR len(SportNameCs)=0) THEN SportName 
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
	WHERE SportType <= 99 OR SportType =154
	
	/*
	 * add more product
	 */
	 UNION ALL
	 SELECT 999--cast(0 AS VARCHAR)
			,
			CASE @Langkey
							/*WHEN 'zh-CN'	THEN N'体育博彩'
							WHEN 'zh-TW'	THEN N'體育博彩'
							WHEN 'th-TH'	THEN N'อัตราค่าตอบแทนจากหน้ากีฬา'
							WHEN 'ja-JP'	THEN N'スポーツベット '
							WHEN 'ko-KR'	THEN N'스포츠북 '*/
							WHEN 'es'  	    THEN N'Virtual Sports'
							WHEN 'vi-VN'	THEN N'Virtual Sports'
							ELSE N'Virtual Sports' END 
			, NULL
	 FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (5)	
	/*
	* 	end 
	*/
	
	UNION ALL
	SELECT 161,
		CASE @Langkey
			WHEN 'zh-CN'	THEN N'百練賽'
			WHEN 'zh-TW'	THEN N'百练赛'
			WHEN 'th-TH'	THEN N'เกมหมายเลข'
			WHEN 'ja-JP'	THEN N'番号ゲーム'
			WHEN 'ko-KR'	THEN N'라이브빙고'
			WHEN 'es'  	    THEN N'Number Game'
			WHEN 'vi-VN'	THEN N'Number Game'
			ELSE N'Number Game' END  
			, NULL 
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (2)
		
	UNION ALL
	SELECT 180,
		CASE @Langkey
		WHEN 'zh-CN'	THEN N'虛擬足球'
		WHEN 'zh-TW'	THEN N'虚拟足球'
		WHEN 'th-TH'	THEN N'ฟุตบอลอนิเมชั่น'
		WHEN 'ja-JP'	THEN N'Virtual Soccer'
		WHEN 'ko-KR'	THEN N'가상 축구'
		WHEN 'es'  	    THEN N'Virtual Soccer'
		WHEN 'vi-VN'	THEN N'Virtual Soccer'
		ELSE N'Virtual Soccer' END  
			, 999 
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (5)
	/*UNION ALL
	SELECT CASE p1.ProductID WHEN 2 THEN 161--'161'
										 WHEN 5 THEN 180--'180'	
				END 
			,CASE  p1.Productid WHEN 5 THEN 
											CASE @Langkey
												WHEN 'zh-CN'	THEN N'虛擬足球'
												WHEN 'zh-TW'	THEN N'虚拟足球'
												WHEN 'th-TH'	THEN N'ฟุตบอลอนิเมชั่น'
												WHEN 'ja-JP'	THEN N'Virtual Soccer'
												WHEN 'ko-KR'	THEN N'가상 축구'
												WHEN 'es'  	    THEN N'Virtual Soccer'
												WHEN 'vi-VN'	THEN N'Virtual Soccer'
												ELSE N'Virtual Soccer' END 
									WHEN 2 THEN 
											CASE @Langkey
												WHEN 'zh-CN'	THEN N'百練賽'
												WHEN 'zh-TW'	THEN N'百练赛'
												WHEN 'th-TH'	THEN N'เกมหมายเลข'
												WHEN 'ja-JP'	THEN N'番号ゲーム'
												WHEN 'ko-KR'	THEN N'라이브빙고'
												WHEN 'es'  	    THEN N'Number Game'
												WHEN 'vi-VN'	THEN N'Number Game'
												ELSE N'Number Game' END 
													
								
								END
			, CASE WHEN p1.Productid =5 THEN 999 END 
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (2,5)	
	*/
	/*
	 * add more sproduct
	 */
	 
	UNION ALL
	SELECT CASE p1.ProductID WHEN 5 THEN 186--'186'
			  END 
			,CASE  p1.Productid WHEN 5 THEN 
											CASE @Langkey												
												WHEN 'es'  	    THEN N'Virtual Tennis'
												WHEN 'vi-VN'	THEN N'Virtual Tennis'
												ELSE N'Virtual Tennis' END END
			, 999
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (5)
		
	UNION ALL
	SELECT CASE p1.ProductID WHEN 5 THEN 184 END 
			,CASE  p1.Productid WHEN 5 THEN 
											CASE @Langkey												
												WHEN 'es'  	    THEN N'Virtual Motor Racing'
												WHEN 'vi-VN'	THEN N'Virtual Motor Racing'
												ELSE N'Virtual Motor Racing' END END
			, 999
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (5)
		
	UNION ALL
	SELECT CASE p1.ProductID WHEN 5 THEN 181 END 
			,CASE  p1.Productid WHEN 5 THEN 
											CASE @Langkey												
												WHEN 'es'  	    THEN N'Virtual Horse Racing'
												WHEN 'vi-VN'	THEN N'Virtual Horse Racing'
												ELSE N'Virtual Horse Racing' END END
			, 999
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (5)
		
	UNION ALL
	SELECT CASE p1.ProductID WHEN 5 THEN 182 END 
			,CASE  p1.Productid WHEN 5 THEN 
											CASE @Langkey												
												WHEN 'es'  	    THEN N'Virtual Greyhounds'
												WHEN 'vi-VN'	THEN N'Virtual Greyhounds'
												ELSE N'Virtual Greyhounds' END END
			, 999
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (5)	
	/*
	 * end add more
	 */
	 
SELECT * FROM @ProductSport
--ORDER BY ID ASC 
GO
GRANT EXECUTE ON [dbo].[Lrf_SelSportDetail] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelSportDetail] TO [vnteam]    