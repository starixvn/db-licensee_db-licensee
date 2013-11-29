set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

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
Param's Explanation:
	
*/
/* sample test case:
	[Lrf_SelSportDetail]
	@LicenseeID=1

*/
DECLARE @ProductSport TABLE (
	ID smallint
	,Name nvarchar(50)
	,ParentID tinyint
)

INSERT INTO @ProductSport(ID, Name, ParentID)
	SELECT 0
			,
			CASE @Langkey
							WHEN 'zh-CN'	THEN N'????'
							WHEN 'zh-TW'	THEN N'????'
							WHEN 'th-TH'	THEN N'?????????????????????????'
							WHEN 'ja-JP'	THEN N'??????? '
							WHEN 'ko-KR'	THEN N'???? '
							WHEN 'es'  	    THEN N'Sportsbook'
							WHEN 'vi-VN'	THEN N'Th? thao'
							ELSE N'Sportbook' END 
			, NULL
	UNION ALL
	SELECT SportType
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
	WHERE SportType <= 99
	UNION ALL
	SELECT CASE p1.ProductID WHEN 2 THEN 161
										 WHEN 5 THEN 180	
				END 
			,CASE  p1.Productid WHEN 5 THEN 
											CASE @Langkey
												WHEN 'zh-CN'	THEN N'????'
												WHEN 'zh-TW'	THEN N'????'
												WHEN 'th-TH'	THEN N'???????????????'
												WHEN 'ja-JP'	THEN N'Virtual Soccer'
												WHEN 'ko-KR'	THEN N'?? ??'
												WHEN 'es'  	    THEN N'Virtual Soccer'
												WHEN 'vi-VN'	THEN N'Virtual Soccer'
												ELSE N'Virtual Soccer' END 
									WHEN 2 THEN 
											CASE @Langkey
												WHEN 'zh-CN'	THEN N'???'
												WHEN 'zh-TW'	THEN N'???'
												WHEN 'th-TH'	THEN N'??????????'
												WHEN 'ja-JP'	THEN N'?????'
												WHEN 'ko-KR'	THEN N'?????'
												WHEN 'es'  	    THEN N'Number Game'
												WHEN 'vi-VN'	THEN N'Number Game'
												ELSE N'Number Game' END 
													
								
								END
			, NULL
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (2,5)
	
SELECT * FROM @ProductSport
ORDER BY ID ASC 

Go
GRANT EXECUTE ON [dbo].[Lrf_SelSportDetail] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelSportDetail] TO [vnteam] 