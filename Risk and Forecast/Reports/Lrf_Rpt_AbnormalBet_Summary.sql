/*<info serverAlias="DBWH-bodb_DWRS" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Lrf_Rpt_AbnormalBet_Summary
	@LicenseeName	VARCHAR(50) = '',
	@FromDate DATE,
	@ToDate	DATE,
	@SportTypeList	VARCHAR(MAX) = 'All',
	@LeagueName	NVARCHAR(100) = N'',
	@BetTypeList	VARCHAR(MAX) = 'All',
	@LiveIndicator VARCHAR(10)  = '0,1,2',
	@ReasonList	VARCHAR(MAX) = 'All',
	@SearchLanguage	VARCHAR(10)		= 'en-US',
	@PageSize 	 INT = 0,
	@PageIndex   INT = 0
AS
BEGIN
/*
	Created: 20221013@Evan
	Task : Abnormal Bet Report (#174308)
	DB: DBDW2/bodb_dwrs 
	Origin: Acc_Rpt_AbnormalBet_Licensee
	Revisions:
		- 20221013@Evan: Initial [RedmineID: #174308]
						 Support Saba E-Sports PinGoal
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]
		- 20230708@Evan: Support CN3, INDO & THAI language on LAP [RedmineID: #187132]
		- 20230920@Evan: Clean code un-use  [RedmineID: #193757]
		- 20240304@Evan: Integrate Saba Ice Hockey [RedmineID: #201283]
		- 20240508@Bobby: Integrate Saba Kabaddi [RedmineID: #203612]
		- 20250425@Kelvin: Integrate Saba Soccer Marble [RedmineID: #225015]

	Param's Explanation:
		- @SportTypeList: sporttype list separated by ','
			'All': all sport types
			-2	 :SABA Soccer	{"Sporttype":1, "LeagueGroupID": [42,74]}
			-3	 :SABA Futsal	{"Sporttype":1, "LeagueGroupID": [108]}
			-4	 :SABA Soccer PinGoal	{"Sporttype":1, "LeagueGroupID": [113]}
			-5	 :SABA Basketball	{"Sporttype":2, "LeagueGroupID": [42]}
			-6	 :SABA Basketball PinGoal	{"Sporttype":2, "LeagueGroupID": [122]}
			-7	 :SABA ESports PinGoal	{"Sporttype":43, "LeagueGroupID": [151]}
			-8	 :SABA Cricket	{"Sporttype":50, "LeagueGroupID": [42]}
			-9	 :SABA Tennis	{"Sporttype":5, "LeagueGroupID": [42]}
			-10	 :SABA Ice Hockey	{"Sporttype":4, "LeagueGroupID": [42]}
			-11	 :SABA Kabaddi	{"Sporttype":47, "LeagueGroupID": [42]}
			-12	 :Saba Soccer Marble {"Sporttype":1, "LeagueGroupID": [252]}

		- @BetTypeList: bettype list separated by ','
			+ 'All': all bettypes
		- @ReasonList: Reason list separated by ','
			+ 'All': all Reason
		- @LiveIndicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: Mix Live & Non-Live
		- @SearchLanguage: search language
			+ en-US: English
			+ zh-CN: Chinese Simplified
			+ vi-VN: CN3 (Vietnamese)
			+ th-TH: Thailand
		- @PageIndex: starts from 1, set 0 to disable pagination
		- @PageSize: Number of records per page

*/
	SET NOCOUNT ON;

	CREATE TABLE #tmpReason (ReasonID INT)
	CREATE TABLE #tmpSport (SportID INT)
	CREATE TABLE #SabaSporttype (SabaSportType INT, SportType INT, LeagueGroupID INT, CutOffDate SMALLDATETIME)
	CREATE TABLE #tmpBetType (BetTypeID INT, EventType TINYINT)

	IF @ReasonList = 'All'
		INSERT INTO #tmpReason (ReasonID)
		SELECT SubIssueTypeId 
		FROM bodb_Account.dbo.TicketVoiding_SubIssueType WITH (NOLOCK)
		WHERE IssueTypeId = 11
	ELSE
		INSERT INTO #tmpReason (ReasonID)
		SELECT value
		FROM STRING_SPLIT(@ReasonList, ',')     #

	IF @SportTypeList = 'All'
	BEGIN
		INSERT INTO #tmpSport (SportID)
		SELECT DISTINCT SportType
		FROM bodb02.dbo.SportBettypeMatrix WITH(NOLOCK)
		WHERE ProductID = 1
	END
	ELSE
	BEGIN
		INSERT INTO #tmpSport (SportID)
		SELECT value
		FROM STRING_SPLIT(@SportTypeList, ',') 
	END

	/* Get Saba Sport */
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	INSERT INTO #SabaSporttype (SabaSportType, SportType, LeagueGroupID, CutOffDate)
	SELECT saba.SabaSportType, t.SportType, t.LeagueGroupID, saba.CutOffDate
	FROM bodb02.[dbo].[LAP_f_WinlossAnalysis_SabaSportSel] () AS saba
	OUTER APPLY
	(
		SELECT Sporttype, LeagueGroupID
		FROM OPENJSON(saba.SporttypeRef)
		WITH (Sporttype INT '$.Sporttype', 
			LeagueGroupIDs NVARCHAR(MAX) '$.LeagueGroupID' AS JSON
		)
		OUTER APPLY OPENJSON(LeagueGroupIDs) WITH (LeagueGroupID INT '$')
	) AS t
	WHERE saba.IsShowUI = 1
	-----------------------------------------------------------------------------------------------------------------------------------------------------------

	IF EXISTS (SELECT 1 FROM #tmpSport WHERE SportID < 0)
	BEGIN
		INSERT INTO #tmpSport
		SELECT DISTINCT a.SportType
		FROM #SabaSporttype a 
			LEFT JOIN #tmpSport b ON a.SportType = b.SportID AND b.SportID > 0
		WHERE b.SportID IS NULL
			AND EXISTS (SELECT 1 FROM #tmpSport t WHERE t.SportID < 0 AND t.SportID = a.SabaSportType)
	END

	IF @BetTypeList = 'All'
		INSERT INTO #tmpBetType (BetTypeID,EventType)
		SELECT DISTINCT b.BetType, b.EventType
		FROM bodb02.dbo.SportBettypeMatrix b WITH(NOLOCK)
			INNER JOIN #tmpSport s ON b.SportType = s.SportID
		WHERE b.ProductID = 1
	ELSE
		INSERT INTO #tmpBetType (BetTypeID,EventType)
		SELECT DISTINCT value, b.EventType
		FROM STRING_SPLIT(@BetTypeList, ',')
			INNER JOIN bodb02.dbo.SportBettypeMatrix b WITH(NOLOCK) ON value = b.BetType
			INNER JOIN #tmpSport s ON b.SportType = s.SportID
		WHERE b.ProductID = 1
	
	IF @LeagueName <> '' OR @SportTypeList <> 'All'
		DELETE #tmpBetType WHERE BetTypeID = 29

	-- Get league list
	CREATE TABLE #League (LeagueId INT, SportType SMALLINT, LeagueGroupId SMALLINT)
	CREATE CLUSTERED INDEX IX_LeagueId ON #League (LeagueId)

	INSERT INTO #League (
		LeagueId,
		SportType, 
		LeagueGroupId )
	SELECT
		l.leagueid,
		l.sporttype,
		l.LeagueGroupID
	FROM bodb02.dbo.League AS l WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #tmpSport t WHERE t.SportID=l.sporttype)
		AND (@LeagueName = '' OR CASE
									WHEN @SearchLanguage = 'zh-CN' AND ISNULL(l.leaguenamecn,'') <> '' THEN l.leaguenamecn
									WHEN @SearchLanguage = 'vi-VN' AND ISNULL(l.leaguenameVN,'') <> '' THEN l.leaguenameVN
									WHEN @SearchLanguage = 'th-TH' AND ISNULL(l.leaguenameth,'') <> '' THEN l.leaguenameth
									ELSE l.leaguename
								END LIKE '%' + @LeagueName +'%')
		
	IF @SportTypeList <> 'All'
	BEGIN
		DELETE l 
		FROM #League l
			INNER JOIN #SabaSporttype saba ON saba.SportType = l.SportType AND saba.LeagueGroupID = l.LeagueGroupId
		WHERE ',' + @SportTypeList + ',' NOT LIKE '%,' + CAST(saba.SabaSportType AS varchar(10)) + ',%'
	END
	
	-- Insert League for Parlay
	IF @SportTypeList = 'All'
		AND @LeagueName = ''
		AND (@BetTypeList = 'All' OR ',' + @BetTypeList + ',' LIKE '%,29,%')
	BEGIN
		INSERT INTO #League (LeagueId, SportType, LeagueGroupId)
		SELECT -1, 0, 0
		WHERE NOT EXISTS (SELECT 1 FROM #League WHERE LeagueId = -1)
	END

	CREATE TABLE #Src(
		RptDate DATE,
		CreatedDate DATE,
		SiteID INT,
		CurrencyID INT,
		SportType INT,
		LeagueID INT,
		LeagueGroupId SMALLINT,
		MatchID INT,
		SubIssueTypeID TINYINT,
		LiveStatus TINYINT,
		BetCount INT,
		BetType INT,
		EventType TINYINT,
		BetTeam NVARCHAR(10),
		LiveHomeScore SMALLINT,
		LiveAwayScore SMALLINT
	)

	CREATE TABLE #tmpMatch (
		Matchid	INT,
		Homeid	INT,
		Awayid	INT,
		Finalhomescore	INT,
		Finalawayscore	INT,
		GlobalShowTime	SMALLDATETIME,
		IsNeutral	BIT
	)
	
	CREATE TABLE #tmpData
	(
		CreatedDate DATE,
		GlobalShowTime SMALLDATETIME,
		CurrencyID INT,
		SportType INT,
		LeagueID INT,
		LeagueGroupId SMALLINT,
		SubIssueTypeID SMALLINT,
		LiveStatus TINYINT,
		BetCount INT,
		BetType INT,
		Matchid INT,
		EventType TINYINT,
		BetTeam NVARCHAR(10),
		RN INT
	)

	INSERT INTO #Src(
		RptDate ,
		CreatedDate ,
		SiteID ,
		CurrencyID ,
		SportType,
		LeagueID ,
		LeagueGroupId ,
		MatchID ,
		SubIssueTypeID ,
		LiveStatus ,
		BetCount,
		BetType ,
		EventType ,
		BetTeam ,
		LiveHomeScore ,
		LiveAwayScore)
	SELECT RptDate ,
		CreatedDate ,
		f.SiteID ,
		CurrencyID ,
		l.SportType,
		l.LeagueId ,
		l.LeagueGroupId ,
		MatchID ,
		SubIssueTypeID,
		LiveStatus,
		SUM(BetCount),
		BetType ,
		b.EventType ,
		BetTeam ,
		LiveHomeScore ,
		LiveAwayScore
	FROM bodb_Account.dbo.FactSiteAbnormalBet f WITH(NOLOCK)
		INNER JOIN #tmpBetType b  WITH (NOLOCK) ON f.BetType = b.BetTypeID
		INNER JOIN #League l ON l.LeagueId = f.leagueid
		LEFT JOIN bodb_Account.dbo.tbl_Site s WITH (NOLOCK) ON f.SiteID = s.SiteID
	WHERE CreatedDate BETWEEN @FromDate AND @ToDate 
		AND EXISTS(SELECT TOP 1 1 FROM #tmpReason r WHERE f.SubIssueTypeID = r.ReasonID)
		AND ((BetType IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveHomeScore) + ',%')
			OR (BetType NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveStatus) + ',%'))
		AND (@LicenseeName = '' OR s.site = @LicenseeName)
		AND (l.LeagueId IS NOT NULL OR @LeagueName = '')
	GROUP BY RptDate ,
		CreatedDate ,
		f.SiteID ,
		CurrencyID ,
		l.SportType,
		l.LeagueID ,
		l.LeagueGroupId ,
		MatchID ,
		SubIssueTypeID,
		LiveStatus,
		BetType ,
		b.EventType ,
		BetTeam ,
		LiveHomeScore ,
		LiveAwayScore 
	OPTION(RECOMPILE)
	
	;WITH CTE_Matches AS (
		SELECT m.matchid,
			   m.homeid,
			   m.awayid,
			   m.finalhomescore,
			   m.finalawayscore,
			   m.GlobalShowTime,
			   m.IsNeutral
		FROM bodb_Account.dbo.match m WITH (NOLOCK)
		UNION
		SELECT m.matchid,
			   m.homeid,
			   m.awayid,
			   m.finalhomescore,
			   m.finalawayscore,
			   m.GlobalShowTime,
			   m.IsNeutral
		FROM bodb_Archive.dbo.match m WITH (NOLOCK)
	) 
	INSERT INTO #tmpMatch (Matchid,Homeid,Awayid,Finalhomescore,Finalawayscore,GlobalShowTime,IsNeutral)
	SELECT	matchid,
			homeid,
			awayid,
			finalhomescore,
			finalawayscore,
			GlobalShowTime,
			IsNeutral 
	FROM CTE_Matches
	WHERE matchid IN (SELECT matchid FROM #Src)

	;WITH tmp_Data AS(
		SELECT CreatedDate,
			d.CurrencyID,
			d.SportType ,
			d.LeagueID ,
			d.LeagueGroupId ,
			d.BetType,
			d.EventType,
			d.SubIssueTypeID,
			d.LiveStatus ,
			SUM(d.BetCount) BetCount,
			d.BetTeam ,
			d.Matchid,
			ROW_NUMBER() OVER (ORDER BY CreatedDate DESC) RN
		FROM #Src d
		GROUP BY 
			CreatedDate,
			d.CurrencyID,
			d.SportType,
			d.LeagueID,
			d.LeagueGroupId,
			d.BetType,
			d.EventType,
			d.SubIssueTypeID ,
			d.LiveStatus,
			d.BetTeam,
			d.MatchID
	)
	INSERT INTO #tmpData(CreatedDate,CurrencyID,SportType,LeagueID,LeagueGroupId,BetType,EventType,SubIssueTypeID,LiveStatus,BetCount,BetTeam,Matchid,RN)
	SELECT CreatedDate,CurrencyID,SportType,LeagueID,LeagueGroupId,BetType,EventType,SubIssueTypeID,LiveStatus,BetCount,BetTeam,Matchid,RN 
	FROM tmp_Data
	WHERE (RN >= (@PageIndex - 1) * @PageSize + 1 AND RN < @PageIndex * @PageSize + 1) 
		OR (@PageIndex = 0)		--defaults to all	

	SELECT	Date,
			Sport,
			League,
			BetType,
			homeid,
			awayid,
			IsNeutral,
			KOTime,
			Live,
			TotalTransaction,
			BetType,
			Choice,
			Reason,
			FinalScore
	FROM (	SELECT 
				CONVERT(VARCHAR(20), CreatedDate, 107) AS [Date]
				,CASE WHEN saba.SabaSportType IS NOT NULL THEN saba.SabaSportType ELSE d.SportType END AS Sport
				,LeagueID AS League
				,BetType
				,m.homeid
				,m.awayid
				,m.IsNeutral
				,m.GlobalShowTime AS [KOTime]
				,LiveStatus AS Live
				,BetCount [TotalTransaction]
				,BetTeam AS Choice
				,SubIssueTypeID AS Reason
				,CASE WHEN d.BetType = 29 THEN '-' 
					ELSE CAST(m.finalhomescore AS NVARCHAR(10))+ '-' + CAST(m.finalawayscore AS NVARCHAR(10)) END AS FinalScore
			FROM #tmpData d
				LEFT JOIN #tmpMatch m  ON d.MatchID = m.matchid
				LEFT JOIN #SabaSporttype saba ON saba.SportType = d.SportType AND saba.LeagueGroupID = d.LeagueGroupId AND d.CreatedDate >= ISNULL(saba.CutOffDate, d.CreatedDate)
		) AS a
	WHERE 
		@SportTypeList = 'All' OR ',' + @SportTypeList + ',' LIKE '%,' + CAST(Sport AS VARCHAR(5)) + ',%'
	ORDER BY CONVERT (SMALLDATETIME, [Date])
	
	DROP TABLE #tmpData
	DROP TABLE #tmpReason
	DROP TABLE #tmpSport
	DROP TABLE #tmpBetType
	DROP TABLE #Src
	DROP TABLE #League
	DROP TABLE #tmpMatch
	DROP TABLE #SabaSporttype
END;

GO