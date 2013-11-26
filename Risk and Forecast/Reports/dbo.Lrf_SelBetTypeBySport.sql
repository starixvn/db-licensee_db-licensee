USE [bodb_Licensee]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_SelBetTypeBySport]
	@LicenseeID int
	,@SportList nvarchar(4000)
	,@Langkey nvarchar(20) ='en-US'
AS 
/*
Created: 20131010@Don
Task : Add more products to Customer Turnover Report
DB: DBLIC/bodb_Licensee

Revisions:
   20131126@Jim: return English Name when Korean Name is NULL or not ready
Param's Explanation:
	
*/
/*SET @LicenseeID = 1
DECLARE @SportList nvarchar(4000)
SET @SportList = 
N'
<products>
<product ID="0" Sport="1,2,3,4"> 
</product>
<product ID="2" Sport=""> 
</product>
<product ID="3" Sport=""> 
</product>
</products>'*/

DECLARE @iDoc int
DECLARE @checkVS bit
DECLARE @checkNG bit 
SELECT @checkVS=0,@checkNG=0

EXEC sp_xml_preparedocument @iDoc OUTPUT, @SportList

SELECT *
INTO #input
FROM OPENXML (@iDoc, '/products/product',1) WITH(ID tinyint, Sport nvarchar(128))

EXEC sp_xml_removedocument @iDoc

DECLARE @Bettype TABLE (
	BettypeID smallint
	,BettypeName nvarchar(50)
)
SELECT 
	b.typeID,
	CASE @Langkey
							WHEN 'zh-CN'	THEN typenamcn
							WHEN 'zh-TW'	THEN typenamecn
							WHEN 'th-TH'	THEN typenameth
							WHEN 'ja-JP'	THEN typenamej
							WHEN 'ko-KR'	THEN 
											CASE  WHEN (ISNULL(typenameko,'')='' OR len(typenameko)=0) THEN typenamee 
												   ELSE typenameko END
							WHEN 'es'  	    THEN typenameES
							WHEN 'vi-VN'	THEN typenamee
							ELSE typenamee END typenamee
INTO #bettype		
FROM 
	bodb02.dbo.bettype  b WITH (NOLOCK)
	
IF EXISTS(SELECT * FROM #input WHERE ID = 0 AND ISNULL(Sport,'') <> '')
BEGIN

	INSERT INTO @Bettype
		SELECT typeid, typenamee
		FROM #bettype
		WHERE (typeid < 31 OR (typeid BETWEEN 121 AND 999))

END

IF EXISTS(SELECT * FROM #input WHERE ID > 0)
BEGIN
	IF EXISTS (SELECT 1 FROM #input WHERE ID=161)
		SET @checkNG=1
	IF EXISTS (SELECT 1 FROM #input WHERE ID=180)
		SET @checkVS=1
		
	INSERT INTO @Bettype
		SELECT typeid,
			CASE WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238)) THEN  N'V.Soccer - '+typenamee
			END as 	typenamee 
		FROM #bettype
		WHERE (
				(typeid BETWEEN 81 AND 120 AND @checkNG=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238) AND @checkVS=1)
				)

END

DROP TABLE #input
DROP TABLE #bettype

SELECT * FROM @Bettype
GO
GRANT EXECUTE ON [dbo].[Lrf_SelBetTypeBySport] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelBetTypeBySport] TO [vnteam] AS [dbo]