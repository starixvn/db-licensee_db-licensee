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
   - 20151023@Victor: Support New Simplified Chinese
   - 20151210@Bobby: Fixbug#49033-49298 and apply SportBettypeMatrix & group bettype
   - 20151217@Bobby: Fixbug#49486 - Remove unsupported and mixed bettype
   - 20160217@Jim: exclude bettype 500 (Charge Commission),502 (Match Winner 1X2) since those bettype not offer for deposit model (redmine #50759 )
   - 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
   - 20170330@Paul: Implement Cash Out [RedmineID: #71727]

	Param's Explanation:  
Param's Explanation:
	
*/
BEGIN
	DECLARE @iDoc     	  INT  
	DECLARE @checkVS  	  BIT
	DECLARE @checkNG  	  BIT
	DECLARE @checkVTennis BIT
	DECLARE @checkVR 	  BIT 
	DECLARE @checkVSW 	  BIT --Virtual Speedway
	DECLARE @strSport 	  VARCHAR(5000)
	
	CREATE TABLE #SportBettype (
		ProductID 		TINYINT
		, SportType 	SMALLINT
		, Bettype 		SMALLINT
		, EventType 	TINYINT
		, SubProduct 	VARCHAR(500)
	)

	DECLARE @sportFilter TABLE (sporttype SMALLINT)

	INSERT INTO #SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=2

	SELECT @checkVS = 0
		  ,@checkNG = 0
		  ,@checkVTennis = 0
		  ,@checkVR = 0
		  ,@checkVSW = 0

	EXEC sp_xml_preparedocument @iDoc OUTPUT, @SportList

	SELECT *
	INTO #INPUT
	FROM OPENXML (@iDoc, '/products/product',1) WITH(ID SMALLINT, Sport NVARCHAR(1000))

	EXEC sp_xml_removedocument @iDoc
	
	SELECT @strSport = COALESCE(@strSport + ',', '') + CAST(Sport AS Nvarchar(1000))
	FROM #INPUT

	INSERT INTO @sportFilter
	SELECT VAL
	FROM bodb02.dbo.strSplit(@strSport,',')
	
	-- Soccer - business logic
	IF(EXISTS(SELECT 1 FROM @sportFilter WHERE sporttype = 1))
	BEGIN
		INSERT INTO @sportFilter
		SELECT 99 -- OtherSports
		WHERE NOT EXISTS (SELECT 1 FROM @sportFilter WHERE sporttype = 99)
	END
	
	DELETE sp
	FROM #SportBettype sp
	WHERE NOT EXISTS (SELECT 1 FROM @sportFilter AS f WHERE sp.sporttype = f.sporttype)
		OR sp.bettype IN (901,902,903,904) -- bettrade
		OR sp.bettype BETWEEN 301 AND 304 -- MO
		OR sp.bettype BETWEEN 801 AND 899 -- MG
		OR sp.bettype IN (500,502) --Criket
		OR sp.bettype IN (911,912,913,914) -- Cash Out

	-- Tenis - business logic
	DELETE sp
	FROM #SportBettype sp
	WHERE SportType = 5
		AND bettype IN(5, 15)
			
	DECLARE @Bettype TABLE (
		sporttype SMALLINT
		,BettypeID SMALLINT
		,BettypeName NVARCHAR(50)
	)
	;WITH CTE_GroupBettype AS (
		SELECT ISNULL(ss.GroupTypeId, sp.bettype) AS bettype
		FROM #SportBettype sp 
			LEFT JOIN bodb02.dbo.f_GroupBettype() ss 
			ON sp.bettype = ss.bettype
		GROUP BY ISNULL(ss.GroupTypeId, sp.bettype)
	)
	SELECT 
		b.typeID,
		CASE @Langkey
					WHEN 'zh-CN'	THEN CASE  WHEN (ISNULL(typenamecn,'')='' OR LEN(typenamecn)=0) THEN typenamee 
										   ELSE typenamecn END
					WHEN 'zh-TW'	THEN CASE  WHEN (ISNULL(typenamecn,'')='' OR LEN(typenamecn)=0) THEN typenamee 
										   ELSE typenamecn END
					WHEN 'zh-Hans'	THEN CASE  WHEN (ISNULL(typenamecn,'')='' OR LEN(typenamecn)=0) THEN typenamee 
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
		INNER JOIN CTE_GroupBettype bt 
		ON b.typeID = bt.bettype
		
	SELECT   
		DISTINCT typeID AS BettypeID
		, CASE 
			WHEN typeid BETWEEN 81 AND 120 THEN  N'NG - ' + typenamee
			WHEN (typeid BETWEEN 1201 AND 1299) THEN  N'VS - '+typenamee + CASE WHEN typeid = 1204 THEN '(Soccer)'
																				WHEN typeid = 1235 THEN '(Tennis)'
																				ELSE '' 
																			END
			ELSE typenamee 																 
		END AS BettypeName
	
	FROM #bettype
	ORDER BY BettypeID
	
	DROP TABLE #input
	DROP TABLE #bettype
	DROP TABLE #SportBettype
	
END
GO

GRANT EXECUTE ON [dbo].[Lrf_SelBetTypeBySport] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelBetTypeBySport] TO [vnteam] 