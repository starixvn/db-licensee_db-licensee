/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

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
   - 20170710@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
   - 20170919@Percy: Change way get SportBettypeMatrix [RedmineID: #83442]
   - 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
   - 20180424@Joseph: Fix bug group VS2: BasketBall - Virual Soccer [RedmineID: #93844]
   - 20180703@Amanda: Refactor code [RedmineID: #80941]
   - 20181214@Joseph: Integrate Happy 5 for NumberGame [RedmineID: #103698]
   - 20190531@Amanda: Get correct translation [RedmineID: #114464]

	Param's Explanation:
Param's Explanation:
	
*/
BEGIN
	DECLARE @iDoc     	  INT  
	DECLARE @strSport 	  VARCHAR(5000)
	
	CREATE TABLE #SportBettype (
		  SportType 	SMALLINT
		, Bettype 		SMALLINT
	)

	DECLARE @sportFilter TABLE (sporttype SMALLINT)

	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

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
	IF(EXISTS(SELECT 1 FROM @sportFilter WHERE sporttype = 1) AND NOT EXISTS (SELECT 1 FROM @sportFilter WHERE sporttype = 99))
	BEGIN
		INSERT INTO @sportFilter(sporttype)
		VALUES (99) -- OtherSports
	END
	
	INSERT INTO #SportBettype (SportType, Bettype)
	SELECT s.SportType, Bettype
	FROM bodb02.dbo.SportBettypeMatrix s WITH (NOLOCK)
	INNER JOIN @sportFilter f ON s.SportType = f.sporttype
	WHERE	IsTest <= @isTest
			AND s.bettype NOT IN (901,902,903,904/*bettrade*/,500,502/*Criket*/,300,301,302,303,304/*MO*/,911,912,913,914/*Cash out*/)
			AND (s.bettype < 801 OR s.BetType > 899) -- MG
	GROUP BY s.SportType, Bettype

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
		SELECT ISNULL(COALESCE(ss.GroupTypeId,bt.GroupTypeId), sp.bettype) AS bettype
		FROM #SportBettype sp 
			LEFT JOIN bodb02.dbo.f_GroupBettype() ss ON sp.bettype = ss.bettype
			LEFT JOIN bodb02.dbo.f_GroupBettype3rd() bt on sp.bettype = bt.bettype
		GROUP BY ISNULL(COALESCE(ss.GroupTypeId, bt.GroupTypeId), sp.bettype)
	)
	SELECT 
		b.typeID,
		CASE
			WHEN @Langkey = 'zh-CN'		AND ISNULL(typenamecn,'')		<> ''	THEN typenamecn
			WHEN @Langkey = 'zh-TW'		AND ISNULL(typenamec_uni,'')	<> ''	THEN typenamec_uni
			WHEN @Langkey = 'zh-Hans'	AND ISNULL(typenamecn,'')		<> ''	THEN typenamecn
			WHEN @Langkey = 'th-TH'		AND ISNULL(typenameth,'')		<> ''	THEN typenameth
			WHEN @Langkey = 'ja-JP'		AND ISNULL(typenamej,'')		<> ''	THEN typenamej
			WHEN @Langkey = 'ko-KR'		AND ISNULL(typenameko,'')		<> ''	THEN typenameko
			WHEN @Langkey = 'es'		AND ISNULL(typenameES,'')		<> ''	THEN typenameES
			WHEN @Langkey = 'vi-VN'		AND ISNULL(typenamee,'')		<> ''	THEN typenamee
			ELSE typenamee 
		END typenamee
	INTO #bettype		
	FROM bodb02.dbo.bettype  b WITH (NOLOCK)
		INNER JOIN CTE_GroupBettype bt 
		ON b.typeID = bt.bettype
		
	SELECT   
		DISTINCT typeID AS BettypeID
		, CASE 
			WHEN (typeid BETWEEN 81 AND 120) OR (typeid BETWEEN 8101 AND 8120) 
				THEN  N'NG - ' + typenamee 
			WHEN (typeid BETWEEN 1201 AND 1299) THEN  N'VS - '+typenamee
			WHEN (typeid BETWEEN 2701 AND 2829) THEN  N'VS2 - ' + typenamee
			ELSE typenamee 																 
		END AS BettypeName
	
	FROM #bettype
	ORDER BY BettypeID
	
	DROP TABLE #input
	DROP TABLE #bettype
	DROP TABLE #SportBettype
	
END
GO