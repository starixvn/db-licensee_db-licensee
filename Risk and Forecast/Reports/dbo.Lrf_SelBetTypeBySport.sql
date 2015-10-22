USE [bodb_licensee]
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
Param's Explanation:
	
*/

DECLARE @iDoc     	  INT  
DECLARE @checkVS  	  BIT
DECLARE @checkNG  	  BIT
DECLARE @checkVTennis BIT
DECLARE @checkVR 	  BIT 
DECLARE @checkVSW 	  BIT --Virtual Speedway
DECLARE @strSport 	  VARCHAR(5000)

SELECT @checkVS = 0
	  ,@checkNG = 0
	  ,@checkVTennis = 0
	  ,@checkVR = 0
	  ,@checkVSW = 0

EXEC sp_xml_preparedocument @iDoc OUTPUT, @SportList

SELECT *
INTO #INPUT
FROM OPENXML (@iDoc, '/products/product',1) WITH(ID SMALLINT, Sport NVARCHAR(128))

EXEC sp_xml_removedocument @iDoc

SELECT @strSport =  Sport 
FROM #INPUT
WHERE ID=0

DECLARE @Bettype TABLE (
						sporttype SMALLINT
						,BettypeID SMALLINT
						,BettypeName NVARCHAR(50)
						)
SELECT 
	b.typeID,
	CASE @Langkey
				WHEN 'zh-CN'	THEN CASE  WHEN (ISNULL(typenamecn,'')='' OR LEN(typenamecn)=0) THEN typenamee 
									   ELSE typenamecn END
				WHEN 'zh-TW'	THEN CASE  WHEN (ISNULL(typenamecn,'')='' OR LEN(typenamecn)=0) THEN typenamee 
									   ELSE typenamecn END
				WHEN 'th-TH'	THEN CASE  WHEN (ISNULL(typenameth,'')='' OR LEN(typenameth)=0) THEN typenamee 
									   ELSE typenameth END
				WHEN 'ja-JP'	THEN CASE  WHEN (ISNULL(typenamej,'')='' OR LEN(typenamej)=0) THEN typenamee 
									   ELSE typenamej END
				WHEN 'ko-KR'	THEN CASE  WHEN (ISNULL(typenameko,'')='' OR LEN(typenameko)=0) THEN typenamee 
									   ELSE typenameko END
				WHEN 'es'  	    THEN CASE  WHEN (ISNULL(typenameES,'')='' OR LEN(typenameES)=0) THEN typenamee 
									   ELSE typenameES END
				WHEN 'vi-VN'	THEN CASE  WHEN (ISNULL(typenamee,'')='' OR LEN(typenamee)=0) THEN typenamee 
									   ELSE typenamee END
				ELSE typenamee END typenamee
				
INTO #bettype		
FROM bodb02.dbo.bettype  b WITH (NOLOCK)
WHERE b.typeid NOT IN (901,902,903)
IF ISNULL(@strSport,'')<>''
BEGIN

	SET @strSport = ISNULL(@strSport,'')
	SELECT VAL  AS SportID
	INTO #SBsport
	FROM bodb02.dbo.strSplit(@strSport,',')


	IF EXISTS (SELECT 1 FROM #SBsport WHERE SportID=154)
	BEGIN
		INSERT INTO @Bettype
		SELECT 0,typeid, typenamee
		FROM #bettype
		WHERE typeid = 20	
	END
	IF EXISTS (SELECT 1 FROM #SBsport WHERE SportID=43)
	BEGIN
		INSERT INTO @Bettype
		SELECT 0,typeid, typenamee
		FROM #bettype
		WHERE typeid IN (1,3,20)	
	END

	IF EXISTS (SELECT 1 FROM #SBsport WHERE SportID=5)
	BEGIN
		INSERT INTO @Bettype
		SELECT DISTINCT 0,b.typeid, b.typenamee
		FROM #bettype b
			INNER JOIN dbo.f_GroupBettype() ss ON b.typeid=ss.GroupTypeId
		
	END
	
	IF EXISTS(SELECT 1 FROM #SBsport WHERE  SportID NOT IN (43,5,154,44))
	BEGIN

		INSERT INTO @Bettype
			SELECT 0,typeid, typenamee
			FROM #bettype
			WHERE (typeid < 31 OR (typeid BETWEEN 121 AND 999)
							   OR (typeid BETWEEN 1301 and 1399)) --new tennis's bettypes
			 
	END
	IF EXISTS(SELECT 1 FROM #SBsport WHERE  SportID =44)
	BEGIN

		INSERT INTO @Bettype
			SELECT 44,typeid, typenamee
			FROM #bettype
			WHERE typeid IN(1,3)
			 
	END
	
	DROP TABLE #SBsport
END

IF EXISTS(SELECT * FROM #input WHERE ID > 0 AND sport<>',')
BEGIN
	IF EXISTS (SELECT 1 FROM #input WHERE ID=161)
		SET @checkNG=1
	IF EXISTS (SELECT 1 FROM #input WHERE ID=999 AND charindex('180',Sport)<>0)
		SET @checkVS=1	
	IF EXISTS (SELECT 1 FROM #input WHERE ID=999 AND charindex('186',Sport)<>0)
		SET @checkVtennis=1
	IF EXISTS (SELECT 1 FROM #input 
	           WHERE ID=999 
	           AND (charindex('181',sport)<>0
				OR charindex('182',sport)<>0
				OR charindex('184',sport)<>0
				OR charindex('185',sport)<>0
				))
		SET @checkVR=1
	IF EXISTS (SELECT 1 FROM #input WHERE ID=999 and charindex('183',sport)<>0)
		SET @checkVSW=1
	
	INSERT INTO @Bettype
		SELECT CASE WHEN typeid BETWEEN 81 AND 120 THEN  161 --NG
				 WHEN (typeid BETWEEN 1201 AND 1299) THEN  180
			END as 	sporttype
			,typeid,
			CASE WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + typenamee
				 WHEN (typeid BETWEEN 1201 AND 1299) THEN  N'VS - '+typenamee + CASE WHEN typeid = 1204 THEN '(Soccer)'
																					WHEN typeid = 1235 THEN '(Tennis)'
																					ELSE ''
																				END
			END as 	typenamee 
		FROM #bettype
		WHERE (
				(typeid BETWEEN 81 AND 120 AND @checkNG=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid NOT IN (1220,1235,1236,1231,1232,1233,1237,1238) AND @checkVS=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid IN (1231,1232,1233) AND @checkVR=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid IN (1220,1235,1236) AND @checkVTennis=1)
				OR (typeid BETWEEN 1201 AND 1299 AND typeid IN (1231) AND @checkVSW=1)
				)

END

DROP TABLE #input
DROP TABLE #bettype

SELECT  BettypeID
	   ,BettypeName
FROM @Bettype
GROUP BY sporttype,BettypeID,BettypeName
ORDER BY sporttype
GO

GRANT EXECUTE ON [dbo].[Lrf_SelBetTypeBySport] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelBetTypeBySport] TO [vnteam] 