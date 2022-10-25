/*<info serverAlias="DBWH-bodb_DWRS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Lrf_Rpt_AbnormalBet_Summary
	@LicenseeName	VARCHAR(50) = '',
	@FromDate	DATE = '20220501' , 
    @ToDate	DATE = '20220901',
    @SportTypeList	VARCHAR(MAX) = 'All',
	@LeagueName	NVARCHAR(100) = N'',
    @BetTypeList	VARCHAR(MAX) = 'All',
	@LiveIndicator VARCHAR(10)  = '0,1,2',
    @ReasonList	VARCHAR(MAX) = 'All',
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
		20221013@Evan: Initial [RedmineID: #174308]	
	
	Param's Explanation:
		@AgentList: XML structure
				<ROOT>
					<Agent AgentId="12345" Currency="3"/>
					<Agent AgentId="12346" Currency="5"/>
				</ROOT>

		@LiveIndicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: Mix Live & Non-Live
			+ 3: All
		@PageIndex: starts from 1, set 0 to disable pagination
		@PageSize: Number of records per page
 	 			 
*/
	SET NOCOUNT ON;

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)
	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId);

	DECLARE @DocHandler INT

	CREATE TABLE #tmpReason (ReasonID INT)
	CREATE TABLE #tmpSport (SportID INT)
	CREATE TABLE #tmpBetType (BetTypeID INT)
	CREATE TABLE #tmpLeague (LeagueID INT,LeagueName NVARCHAR(500))
	
	-- Get league list
	CREATE TABLE #TempLeague (LeagueId INT)

	CREATE CLUSTERED INDEX IX_LeagueId ON #tmpLeague (LeagueId)
	CREATE CLUSTERED INDEX IX_LeagueId ON #TempLeague (LeagueId)

	INSERT INTO #TempLeague
	SELECT DISTINCT leagueid
	FROM bodb02.dbo.match WITH (NOLOCK) WHERE eventdate BETWEEN @FromDate AND @ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM bodb02.dbo.match14 WITH (NOLOCK) WHERE eventdate BETWEEN @FromDate AND @ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK) WHERE eventdate BETWEEN @FromDate AND @ToDate
	UNION 
	SELECT DISTINCT leagueid
	FROM bodb02.dbo.outright WITH (NOLOCK) WHERE eventdate BETWEEN @FromDate AND @ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM bodb02.dbo.outright14 WITH (NOLOCK) WHERE eventdate BETWEEN @FromDate AND @ToDate
	UNION
	SELECT DISTINCT leagueid
	FROM DBARC.bodb_Archive.dbo.outright_bk WITH (NOLOCK) WHERE eventdate BETWEEN @FromDate AND @ToDate

	INSERT INTO #tmpLeague (LeagueId,LeagueName)
	SELECT
		l.leagueid,
		l.leaguename
	FROM bodb02.dbo.League AS l WITH (NOLOCK)
	WHERE (@LeagueName = '' OR l.leaguename LIKE '%' + @LeagueName +'%')
		AND l.sporttype IN ( SELECT SportType FROM #tmpBetType )
		AND EXISTS (SELECT 1 FROM #TempLeague WHERE leagueid = l.leagueid)

	IF @ReasonList = 'All'
		INSERT INTO #tmpReason (ReasonID)
		SELECT SubIssueTypeId 
		FROM bodb_Account.dbo.TicketVoiding_SubIssueType WITH (NOLOCK)
		WHERE IssueTypeId = 11
	ELSE    
        INSERT INTO #tmpReason (ReasonID)
        SELECT value
        FROM STRING_SPLIT(@ReasonList, ',')     
    
    IF @SportTypeList = 'All'
		INSERT INTO #tmpSport (SportID)
		SELECT DISTINCT SportType
		FROM bodb02.dbo.SportBettypeMatrix WITH(NOLOCK)
		WHERE ProductID = 1
    ELSE 
        INSERT INTO #tmpSport (SportID)
        SELECT value
        FROM STRING_SPLIT(@SportTypeList, ',') 
    
    IF @BetTypeList = 'All'
		INSERT INTO #tmpBetType (BetTypeID)
        SELECT b.BetType
        FROM bodb02.dbo.SportBettypeMatrix b WITH(NOLOCK)
			INNER JOIN #tmpSport s ON b.SportType = s.SportID
		WHERE b.ProductID = 1
    ELSE   
        INSERT INTO #tmpBetType (BetTypeID)
        SELECT value
        FROM STRING_SPLIT(@BetTypeList, ',')  
			INNER JOIN bodb02.dbo.SportBettypeMatrix b WITH(NOLOCK) ON value = b.BetType 
			INNER JOIN #tmpSport s ON b.SportType = s.SportID
		WHERE b.ProductID = 1
		
	IF @LeagueName <> '' OR @SportTypeList <> 'All'
		DELETE #tmpBetType WHERE BetTypeID = 29

	CREATE TABLE #tmpData(
		RptDate DATE,
		CreatedDate DATE,
		SiteID INT,
		CurrencyID INT,
		SportType INT,
		LeagueID INT,
		MatchID INT,
		SubIssueTypeID TINYINT,
		LiveStatus TINYINT,
		BetCount INT,
		BetType INT,
		BetTeam NVARCHAR(10),
		LiveHomeScore SMALLINT,
		LiveAwayScore SMALLINT,
		HDP SMALLMONEY,
		Stake DECIMAL(19,4),
		TurnoverIBC DECIMAL(19,4)
	)
	
	INSERT INTO #tmpData(
		RptDate ,
		CreatedDate ,
		SiteID ,
		CurrencyID ,
		SportType,
		LeagueID ,
		MatchID ,
		SubIssueTypeID ,
		LiveStatus ,
		BetCount,
		BetType ,
		BetTeam ,
		LiveHomeScore ,
		LiveAwayScore ,
		HDP ,
		Stake,
		TurnoverIBC )
	SELECT RptDate ,
		CreatedDate ,
		f.SiteID ,
		CurrencyID ,
		SportType,
		LeagueID ,
		MatchID ,
		SubIssueTypeID,
		LiveStatus,
		SUM(BetCount),
		BetType ,
		BetTeam ,
		LiveHomeScore ,
		LiveAwayScore ,
		HDP ,
		SUM(Stake),  
		SUM(TurnoverIBC)
	FROM bodb_Account.dbo.FactSiteAbnormalBet f WITH(NOLOCK)
		LEFT JOIN bodb_Account.dbo.tbl_Site s WITH (NOLOCK) ON f.SiteID = s.SiteID
	WHERE CreatedDate BETWEEN @FromDate AND @ToDate 
		AND EXISTS(SELECT TOP 1 1 FROM #tmpReason r WHERE f.SubIssueTypeID = r.ReasonID)
		AND (f.BetType = 29 OR EXISTS(SELECT TOP 1 1 FROM #tmpSport s WHERE f.SportType = s.SportID))
		AND EXISTS(SELECT TOP 1 1 FROM #tmpBetType b WHERE f.BetType = b.BetTypeID)
		AND (@LeagueName = ''OR EXISTS (SELECT 1 FROM #tmpLeague b WHERE f.LeagueID = b.LeagueID))
		AND ((BetType IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveHomeScore) + ',%')  
     			OR (BetType NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveStatus) + ',%')) 
		AND (@LicenseeName = '' OR s.site = @LicenseeName)
	GROUP BY RptDate ,
		CreatedDate ,
		f.SiteID ,
		CurrencyID ,
		SportType,
		LeagueID ,
		MatchID ,
		SubIssueTypeID,
		LiveStatus,
		BetType ,
		BetTeam ,
		LiveHomeScore ,
		LiveAwayScore ,
		HDP
	OPTION(RECOMPILE)

	;WITH CTE_Matches AS (
		SELECT m.matchid,
			   m.homeid,
			   m.awayid,
			   m.hthomescore,
			   m.htawayscore,
			   m.finalhomescore,
			   m.finalawayscore,
			   m.eventdate,
			   m.GlobalShowTime
		FROM bodb_Account.dbo.match m WITH (NOLOCK)
		UNION
		SELECT m.matchid,
			   m.homeid,
			   m.awayid,
			   m.hthomescore,
			   m.htawayscore,
			   m.finalhomescore,
			   m.finalawayscore,
			   m.eventdate,
			   m.GlobalShowTime
		FROM bodb_Archive.dbo.match m WITH (NOLOCK)
	) SELECT * 
	INTO #tmpMatch
	FROM CTE_Matches
	WHERE matchid IN (SELECT matchid FROM #tmpData)

	SELECT CONVERT(VARCHAR(20), CreatedDate, 107) AS [Date],
		e.currency Currency,
		CASE WHEN d.BetType = 29 THEN '-' ELSE sp.sport END Sport,
		CASE WHEN d.BetType = 29 THEN '-' ELSE l.LeagueName END League,
		CASE WHEN d.BetType = 29 THEN '-' ELSE h.teamname + ' -vs- ' + a.teamname END AS Match,
		m.GlobalShowTime [KOTime],
		i.SubIssueTypeName AS Reason,
		CASE WHEN d.LiveStatus = 0 THEN 'Non Live' 
			WHEN d.LiveStatus = 1 THEN 'Live'
			ELSE 'Mixed' END AS Live,
		SUM(d.BetCount) BetCount,
		CASE WHEN d.BetType = 29 AND d.BetTeam = '1' THEN 'Mix Parlay' ELSE b.typenamee END AS BetType,
		CASE WHEN d.BetType IN (1, 7, 153, 609, 9059, 20, 9001) AND d.BetTeam = 'a' THEN 'Away'
			WHEN d.BetType IN (1, 7, 153, 609, 9059, 20, 9001) AND d.BetTeam = 'h' THEN 'Home'
			WHEN d.BetType IN (3, 8) AND d.BetTeam = 'h' THEN 'Over'
			WHEN d.BetType IN (3, 8) AND d.BetTeam = 'a' THEN 'Under'
			WHEN d.BetType IN (401, 402, 403, 404, 610, 615, 616, 9003) AND d.BetTeam = 'o' THEN 'Over'
			WHEN d.BetType IN (401, 402, 403, 404, 610, 615, 616, 9003) AND d.BetTeam = 'u' THEN 'Under'
			WHEN d.BetType = 29 THEN '-'
			ELSE d.BetTeam END Choice,
		CASE WHEN d.BetType = 29 THEN '-' 
			ELSE CAST(d.LiveHomeScore AS NVARCHAR(10)) + '-' + CAST(d.LiveAwayScore AS NVARCHAR(10)) END AS BettingScore,
		CASE WHEN d.BetType = 29 THEN '-' 
			ELSE CAST(m.finalhomescore AS NVARCHAR(10))+ '-' + CAST(m.finalawayscore AS NVARCHAR(10)) END AS FinalScore,
		ROW_NUMBER() OVER (ORDER BY CreatedDate DESC) RN
	INTO #Src
	FROM #tmpData d
		LEFT JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON d.CurrencyID = e.exchangeid 
		LEFT JOIN #tmpLeague l ON d.LeagueID = l.leagueid
		LEFT JOIN #tmpMatch m  ON d.MatchID = m.matchid
		LEFT JOIN bodb_Account.dbo.team h WITH (NOLOCK) ON m.homeid = h.teamid
		LEFT JOIN bodb_Account.dbo.team a WITH (NOLOCK) ON m.awayid = a.teamid
		LEFT JOIN bodb_Account.dbo.TicketVoiding_SubIssueType i WITH (NOLOCK) ON d.SubIssueTypeID = i.SubIssueTypeID
		LEFT JOIN bodb_Account.dbo.bettype b WITH (NOLOCK) ON d.BetType = b.typeid
		LEFT JOIN bodb_Account.dbo.tbl_Sport sp WITH (NOLOCK) ON d.SportType = sp.sportid
	GROUP BY 
		CreatedDate ,
		e.currency ,
		CASE WHEN d.BetType = 29 THEN '-' ELSE sp.sport END,
		CASE WHEN d.BetType = 29 THEN '-' ELSE l.leaguename END,
		CASE WHEN d.BetType = 29 THEN '-' ELSE h.teamname + ' -vs- ' + a.teamname END,
		m.GlobalShowTime,
		i.SubIssueTypeName ,
		CASE WHEN d.LiveStatus = 0 THEN 'Non Live' 
			WHEN d.LiveStatus = 1 THEN 'Live'
			ELSE 'Mixed' END,
		CASE WHEN d.BetType = 29 AND d.BetTeam = '1' THEN 'Mix Parlay' ELSE b.typenamee END,
		CASE WHEN d.BetType IN (1, 7, 153, 609, 9059, 20, 9001) AND d.BetTeam = 'a' THEN 'Away'
			WHEN d.BetType IN (1, 7, 153, 609, 9059, 20, 9001) AND d.BetTeam = 'h' THEN 'Home'
			WHEN d.BetType IN (3, 8) AND d.BetTeam = 'h' THEN 'Over'
			WHEN d.BetType IN (3, 8) AND d.BetTeam = 'a' THEN 'Under'
			WHEN d.BetType IN (401, 402, 403, 404, 610, 615, 616, 9003) AND d.BetTeam = 'o' THEN 'Over'
			WHEN d.BetType IN (401, 402, 403, 404, 610, 615, 616, 9003) AND d.BetTeam = 'u' THEN 'Under'
			WHEN d.BetType = 29 THEN '-'
			ELSE d.BetTeam END ,
		CASE WHEN d.BetType = 29 THEN '-' 
			ELSE CAST(d.LiveHomeScore AS NVARCHAR(10)) + '-' + CAST(d.LiveAwayScore AS NVARCHAR(10)) END,
		CASE WHEN BetType = 29 THEN 0 ELSE d.HDP END,
		CASE WHEN d.BetType = 29 THEN '-' 
			ELSE CAST(m.hthomescore AS NVARCHAR(10)) + '-' + CAST(m.htawayscore AS NVARCHAR(10)) END,
		CASE WHEN d.BetType = 29 THEN '-' 
			ELSE CAST(m.finalhomescore AS NVARCHAR(10))+ '-' + CAST(m.finalawayscore AS NVARCHAR(10)) END
	OPTION (RECOMPILE)

	SELECT [Date]
		,Sport
		,League
		,Match
		,[KOTime]
		,Live
		,BetCount [TotalTransaction]
		,BetType [BetType]
		,Choice
		,Reason
		,BettingScore [FinalSocre]
	FROM #Src T
	WHERE (RN >= (@PageIndex - 1) * @PageSize + 1 AND RN < @PageIndex * @PageSize + 1) 
		OR (@PageIndex = 0) --defaults to all	

	DROP TABLE #tmpData
	DROP TABLE #tmpReason
	DROP TABLE #tmpSport 
	DROP TABLE #tmpBetType 
 	DROP TABLE #Src
	DROP TABLE #tmpLeague
	DROP TABLE #TempLeague
	DROP TABLE #tmpMatch
	   
END;

GO
