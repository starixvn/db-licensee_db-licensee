USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_SelBetTypeBySport]    Script Date: 13/02/2014 4:38:54 PM ******/
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
   20131126@Jim: return English Name when Other Language Name is NULL or not ready
   20131205@Florent: Add more product ( V.Tennis, V.Racing)
   20140210@Florent: add new sport Horse racing fix odds
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
DECLARE @checkNG BIT
DECLARE @checkVTennis BIT
DECLARE @checkVR bit 
SELECT @checkVS=0,@checkNG=0,@checkVTennis=0,@checkVR=0


EXEC sp_xml_preparedocument @iDoc OUTPUT, @SportList

SELECT *
INTO #input
FROM OPENXML (@iDoc, '/products/product',1) WITH(ID smallint, Sport nvarchar(128))


EXEC sp_xml_removedocument @iDoc

DECLARE @Bettype TABLE (
	BettypeID smallint
	,BettypeName nvarchar(50)
)
SELECT 
	b.typeID,
	CASE @Langkey
							WHEN 'zh-CN'	THEN CASE  WHEN (ISNULL(typenamecn,'')='' OR len(typenamecn)=0) THEN typenamee 
												   ELSE typenamecn END
							WHEN 'zh-TW'	THEN CASE  WHEN (ISNULL(typenamecn,'')='' OR len(typenamecn)=0) THEN typenamee 
												   ELSE typenamecn END
							WHEN 'th-TH'	THEN CASE  WHEN (ISNULL(typenameth,'')='' OR len(typenameth)=0) THEN typenamee 
												   ELSE typenameth END
							WHEN 'ja-JP'	THEN CASE  WHEN (ISNULL(typenamej,'')='' OR len(typenamej)=0) THEN typenamee 
												   ELSE typenamej END
							WHEN 'ko-KR'	THEN CASE  WHEN (ISNULL(typenameko,'')='' OR len(typenameko)=0) THEN typenamee 
												   ELSE typenameko END
							WHEN 'es'  	    THEN CASE  WHEN (ISNULL(typenameES,'')='' OR len(typenameES)=0) THEN typenamee 
												   ELSE typenameES END
							WHEN 'vi-VN'	THEN CASE  WHEN (ISNULL(typenamee,'')='' OR len(typenamee)=0) THEN typenamee 
												   ELSE typenamee END
							ELSE typenamee END typenamee
							
INTO #bettype		
FROM 
	bodb02.dbo.bettype  b WITH (NOLOCK)

IF EXISTS(SELECT * FROM #input WHERE ID = 0 AND ISNULL(Sport,'') <> '' and  sport like '%154%' )
BEGIN
	INSERT INTO @Bettype
		SELECT typeid, typenamee
		FROM #bettype
		WHERE typeid =20	
END

declare @strTemp nvarchar(128)

select @strTemp=REPLACE(sport,'154',' ') from #input where id=0

update #input set Sport=@strTemp where id=0

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
	/*IF EXISTS (SELECT 1 FROM #input WHERE ID=180)
		SET @checkVS=1
	
	IF EXISTS (SELECT 1 FROM #input WHERE ID=186)
		SET @checkVtennis=1
	IF EXISTS (SELECT 1 FROM #input WHERE ID in (181,182,184))
		SET @checkVR=1
		*/
	IF EXISTS (SELECT 1 FROM #input WHERE ID=999 AND Sport LIKE '%180%')
		SET @checkVS=1	
	IF EXISTS (SELECT 1 FROM #input WHERE ID=999 and sport like '%186%')
		SET @checkVtennis=1
	IF EXISTS (SELECT 1 FROM #input 
	           WHERE ID=999 
	           and (sport like '%181%'
				OR sport like '%182%'
				OR sport like '%184%'))
		SET @checkVR=1
	
	INSERT INTO @Bettype
		SELECT typeid,
			CASE WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238)) THEN  N'V.Soccer - '+typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND typeid IN (1231,1232,1233)) THEN  N'V.Racing - '+typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299 AND typeid IN (1220,1235,1236)) THEN  N'V.Tennis - '+typenamee
			END as 	typenamee 
		FROM #bettype
		WHERE (
				(typeid BETWEEN 81 AND 120 AND @checkNG=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238) AND @checkVS=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid IN (1231,1232,1233) AND @checkVR=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid IN (1220,1235,1236) AND @checkVTennis=1)
				)

END

DROP TABLE #input
DROP TABLE #bettype

SELECT BettypeID,BettypeName
FROM @Bettype
GROUP BY BettypeID,BettypeName
ORDER BY BettypeName


GO
GRANT EXECUTE ON [dbo].[Lrf_SelBetTypeBySport] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelBetTypeBySport] TO [vnteam]    