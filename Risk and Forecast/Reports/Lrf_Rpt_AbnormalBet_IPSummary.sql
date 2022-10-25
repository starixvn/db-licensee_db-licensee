/*<info serverAlias="DBWH-bodb_DWRS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Lrf_Rpt_AbnormalBet_IPSummary
	@AgentList		VARCHAR(MAX) ='',
	@FromDate	DATE = '20220501' , 
    @ToDate	DATE = '20220901',
    @SportTypeList	VARCHAR(MAX) = 'All',
	@LeagueName	NVARCHAR(100) = N'',
    @BetTypeList	VARCHAR(MAX) = 'All',
	@LiveIndicator VARCHAR(10)  = '0,1,2',
    @ReasonList	VARCHAR(MAX) = 'All',
	@Username	VARCHAR(50)  = '',  
	@IP	VARCHAR(40)='',
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
	20221013@Evan: Initial [RedmineID: #174308]	
	
Param's Explanation:
	- @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12346" Currency="5"/>
			</ROOT>
	- @SportTypeList: sporttype list separated by ','
		+ 'All': all sport types
	- @BetTypeList: bettype list separated by ','
		+ 'All': all bettypes
	- @Username: exact System ID or External ID
	- @IP: exact IP
	- @Liveindicator : indicate that whether the report will get live data or not
		+ 0: Non - Live data only
		+ 1: Live data only
		+ 2: Mix Live & Non-Live
	- @PageIndex: starts from 1, set 0 to disable pagination
	- @PageSize: Number of records per page
 	 			 
*/
	SET NOCOUNT ON;

	-- Get agent list
	CREATE TABLE #TempAg (CustId INT, Currency INT)
	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId);

	DECLARE @DocHandler INT

	--BEGIN TRY
	--	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

	--	INSERT INTO #TempAg (CustId, Currency)
	--	SELECT AgentId, Currency
	--	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

	--	EXEC sp_xml_removedocument @DocHandler
	--END TRY

	--BEGIN CATCH
	--	SELECT ErrCode = 100
	--		,ErrMsg = N'Paramter invalid.'

	--	RETURN
	--END CATCH;

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
	CREATE TABLE #tmpBetType (BetTypeID INT)
	CREATE TABLE #tmpLeague (LeagueID INT)

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

	INSERT INTO #tmpLeague (LeagueId)
	SELECT
		l.leagueid
	FROM bodb02.dbo.League AS l WITH (NOLOCK)
	WHERE (@LeagueName = '' OR l.leaguename LIKE '%' + @LeagueName +'%')
		AND l.sporttype IN ( SELECT SportType FROM #tmpBetType )
		AND EXISTS (SELECT 1 FROM #TempLeague WHERE leagueid = l.leagueid)
	
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

	INSERT INTO #Src (TransID,CustID,IP)
	SELECT MAX(f.TransId) TransId,  f.CustID , TRIM(IP) IP
	FROM bodb_Account.dbo.AbnormalBetTransaction f WITH(NOLOCK)
		--INNER JOIN bodb02.dbo.Custinfo c WITH(NOLOCK) ON c.custid = f.CustID
		--INNER JOIN #TempAg AS tma ON tma.CustID = c.recommend  
	WHERE CreatedDate >= @FromDate 
		AND CreatedDate < DATEADD(d, 1, @ToDate)
		AND EXISTS(SELECT TOP 1 1 FROM #tmpReason r WHERE f.SubIssueTypeID = r.ReasonID)
		AND (f.BetType = 29
			OR EXISTS(SELECT TOP 1 1 FROM #tmpSport s WHERE f.SportType = s.SportID))
		AND EXISTS(SELECT TOP 1 1 FROM #tmpBetType b WHERE f.BetType = b.BetTypeID)
		AND (@UserName = '' OR EXISTS(SELECT 1 FROM #TempCust tc WHERE tc.CustId = f.CustID))
		AND (@LeagueName = '' OR EXISTS (SELECT 1 FROM #tmpLeague b WHERE f.LeagueID = b.LeagueID))
		AND ((BetType IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveHomeScore) + ',%')  
     			OR (BetType NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveIndicator) + ',%')) 
		AND (@IP = '' OR IP = @IP)
	GROUP BY TRIM(IP),f.CustID
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
	DROP TABLE #tmpLeague
	DROP TABLE #Src
	DROP TABLE #TempLeague
    DROP TABLE #TempCust  
    DROP TABLE #TempAg  

END;

GO
Lrf_Rpt_AbnormalBet_IPSummary