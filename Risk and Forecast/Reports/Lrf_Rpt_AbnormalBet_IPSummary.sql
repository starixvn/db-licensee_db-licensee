/*<info serverAlias="DBWH-bodb_DWRS" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Lrf_Rpt_AbnormalBet_IPSummary
	@AgentList		VARCHAR(MAX) ='',
	@FromDate	DATE = '' , 
	@ToDate	DATE = '',
	@SportTypeList	VARCHAR(MAX) = 'All',
	@LeagueName	NVARCHAR(100) = N'',
	@BetTypeList	VARCHAR(MAX) = 'All',
	@LiveIndicator VARCHAR(10)  = '0,1,2',
	@ReasonList	VARCHAR(MAX) = 'All',
	@Username	VARCHAR(50)  = '',  
	@IP	VARCHAR(40)='',
	@SearchLanguage	VARCHAR(10)		= 'en-US',
	@PageSize	INT = 0,
	@PageIndex	INT = 0
AS
BEGIN 
/*
Created: 20221013@Evan
Task : Abnormal Bet Report (#174308)
DB: DBDW2/bodb_dwrs 
Origin: Acc_Rpt_AbnormalBet_Member
Revisions:
	- 20221013@Evan: Initial [RedmineID: #174308]
					 Support Saba E-Sports PinGoal
	- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]
	- 20230708@Evan: Support CN3, INDO & THAI language on LAP [RedmineID: #187132]
	- 20240304@Evan: Integrate Saba Ice Hockey [RedmineID: #201283]
	- 20240508@Bobby: Integrate Saba Kabaddi [RedmineID: #203612]
	- 20250425@Kelvin: Integrate Saba Soccer Marble [RedmineID: #225015]

Param's Explanation:
	- @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12346" Currency="5"/>
			</ROOT>
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
	- @Username: exact System ID or External ID
	- @IP: exact IP
	- @Liveindicator : indicate that whether the report will get live data or not
		+ 0: Non - Live data only
		+ 1: Live data only
		+ 2: Mix Live & Non-Live
	- @PageIndex: starts from 1, set 0 to disable pagination
	- @SearchLanguage: search language
			+ en-US: English
			+ zh-CN: Chinese Simplified
			+ vi-VN: CN3 (Vietnamese)
			+ th-TH: Thailand
	- @PageSize: Number of records per page
 	 			 
*/
	SET NOCOUNT ON;

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)
	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId);

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #TempCust (CustId INT PRIMARY KEY)

	IF @Username IS NOT NULL AND @Username <> ''
	BEGIN
		INSERT INTO #TempCust  
		SELECT c.custid  
		FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN #TempAg AS a ON c.recommend = a.CustId
		WHERE c.roleid = 1
			AND (c.username LIKE + '%' + @Username + '%'
				OR c.username2 LIKE + '%$%' + @Username + '%')
	END

	CREATE TABLE #tmpReason (ReasonID INT)
	CREATE TABLE #tmpSport (SportID INT)
	CREATE TABLE #SabaSporttype (SabaSportType INT, SportType INT, LeagueGroupID INT, CutOffDate SMALLDATETIME)
	CREATE TABLE #tmpBetType (BetTypeID INT)
	
	IF @ReasonList = 'All'
		INSERT INTO #tmpReason (ReasonID)
		SELECT SubIssueTypeId 
		FROM bodb_Account.dbo.TicketVoiding_SubIssueType WITH(NOLOCK)
		WHERE IssueTypeId = 11
	ELSE
		INSERT INTO #tmpReason (ReasonID)
		SELECT value
		FROM STRING_SPLIT(@ReasonList, ',')

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
		INSERT INTO #tmpBetType (BetTypeID)
		SELECT DISTINCT b.BetType
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

	CREATE TABLE #tmpData(
		CustID INT,
		TicketIPs VARCHAR(MAX),
		LastIP VARCHAR(40)
	)	

	CREATE TABLE #Src
	(
		TransID BIGINT,
		CustID INT,
		IP VARCHAR(40)
	)
	
	;WITH cte_Src AS
	(
		SELECT 	f.TransId,
			 	f.CustID ,
			 	TRIM(IP) AS IP,
			 	CASE WHEN saba.SabaSportType IS NOT NULL THEN saba.SabaSportType ELSE l.SportType END AS SportType
		FROM bodb_Account.dbo.AbnormalBetTransaction f WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Custinfo c WITH(NOLOCK) ON c.custid = f.CustID
				INNER JOIN #TempAg AS tma ON tma.CustID = c.recommend  
				INNER JOIN #League l ON l.LeagueId = f.leagueid
				LEFT JOIN #SabaSporttype saba ON saba.SportType = l.SportType AND saba.LeagueGroupID = l.LeagueGroupId AND f.CreatedDate >= ISNULL(saba.CutOffDate, f.CreatedDate)
			WHERE CreatedDate >= @FromDate
				AND CreatedDate < DATEADD(d, 1, @ToDate)
				AND EXISTS(SELECT TOP 1 1 FROM #tmpReason r WHERE f.SubIssueTypeID = r.ReasonID)
				AND EXISTS(SELECT TOP 1 1 FROM #tmpBetType b WHERE f.BetType = b.BetTypeID)
				AND (@UserName = '' OR EXISTS(SELECT 1 FROM #TempCust tc WHERE tc.CustId = f.CustID))
				AND ((BetType IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveHomeScore) + ',%')
					OR (BetType NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveIndicator) + ',%'))
				AND (@IP = '' OR IP = @IP)
	)
	INSERT INTO #Src (TransID,CustID,IP)
	SELECT MAX(TransId) TransId,  CustID , TRIM(IP) IP
	FROM cte_Src
	WHERE 
		@SportTypeList = 'All' OR ',' + @SportTypeList + ',' LIKE '%,' + CAST(SportType AS VARCHAR(5)) + ',%'
	GROUP BY TRIM(IP), CustID
	OPTION (RECOMPILE)

	IF ISNULL(@IP, '') <> ''
	BEGIN
		DELETE #Src WHERE IP <> @IP
	END
	
	;WITH cte_tmp AS 
	(
		SELECT	s.CustID, STRING_AGG(s.IP,', ') TicketIPs,
				ROW_NUMBER() OVER (ORDER BY s.CustID DESC) RN
		FROM #Src s
		GROUP BY s.CustID
	)
	INSERT INTO #tmpData(CustID , TicketIPs, LastIP)
	SELECT CustID , TicketIPs, a.IP
	FROM cte_tmp t
		CROSS APPLY (SELECT TOP 1 s.IP FROM #Src s WHERE t.CustID = s.CustID ORDER BY s.TransId DESC) a
	WHERE (RN >= (@PageIndex - 1) * @PageSize + 1 AND RN < @PageIndex * @PageSize + 1) 
		OR (@PageIndex = 0)

	SELECT
		c.custid,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS [ExternalID],
		c.username [SystemID],
		c.iplogin, 
		d.TicketIPs,
		LastIP
	FROM #tmpData d
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = d.custid

	DROP TABLE #tmpData
	DROP TABLE #tmpReason
	DROP TABLE #tmpSport
	DROP TABLE #tmpBetType
	DROP TABLE #League
	DROP TABLE #Src
	DROP TABLE #TempCust
	DROP TABLE #TempAg
	DROP TABLE #SabaSporttype

END;

GO