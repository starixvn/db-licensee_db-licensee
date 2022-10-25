/*<info serverAlias="DBWH-bodb_DWRS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Lrf_Rpt_AbnormalBet_Detail
	@AgentList		VARCHAR(MAX) ='',
	@FromDate	DATE = '20220501' , 
    @ToDate	DATE = '20220901',
    @SportTypeList	VARCHAR(MAX) = 'All',
	@LeagueName	NVARCHAR(500) = N'',
    @BetTypeList	VARCHAR(MAX) = 'All',
	@LiveIndicator VARCHAR(10)  = '0,1,2',
    @ReasonList	VARCHAR(MAX) = 'All',
	@Username	VARCHAR(50)  = '',  
	@IP	VARCHAR(40)='',
	@Refno	BIGINT = 0,
	@BaseCurrency	VARCHAR(3) = 'USD',
 	@ConvertToBaseCur BIT    = 1, -- Convert to base currency or not  
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
	CREATE TABLE #tmpLeague (LeagueID INT,LeagueName NVARCHAR(500))
	CREATE TABLE #tmpCurrency (CurrencyID INT)
	CREATE TABLE #ExchangeRate 
	(
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT,
		USD			FLOAT,
		EUR			FLOAT,
		GBP			FLOAT,
		DefaultRate	FLOAT
	)

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
	
	CREATE TABLE #tmpData(
		TransID BIGINT,
		CustID INT,
		SportType INT,
		LeagueID INT,    
		MatchID INT,
		SubIssueTypeID TINYINT,
		Odds SMALLMONEY,
		OddsType INT,
		BetType INT,
		BetTeam NVARCHAR(10),
		CurrencyID INT,		
		Stake DECIMAL(19,4),
		HDP SMALLMONEY,
		LiveIndicator BIT,
		LiveHomeScore SMALLINT,
		LiveAwayScore SMALLINT,
		RptDate SMALLDATETIME,
		IP VARCHAR(45),
		TransDate DATETIME
	)	

	CREATE TABLE #Src
	(
		TransID BIGINT,
		CustID INT,
		SportType INT,
		LeagueID INT,
		MatchID INT,
		SubIssueTypeID SMALLINT,
		Odds SMALLMONEY,
		OddsType INT,
		BetType INT,
		BetTeam NVARCHAR(10),
		CurrencyID INT,		
		Stake DECIMAL(19, 4),
		HDP SMALLMONEY,
		LiveIndicator BIT,
		LiveHomeScore SMALLINT,
		LiveAwayScore SMALLINT,
		RptDate DATE,
		IP VARCHAR(40),
		TransDate DATETIME,
		RN INT
	)

	INSERT INTO #Src(TransID,CustID,SportType,LeagueID,MatchID,SubIssueTypeID,Odds,OddsType,BetType,BetTeam,CurrencyID,Stake,HDP,LiveIndicator,LiveHomeScore,LiveAwayScore,RptDate,IP,TransDate,RN)
	SELECT  TransID ,
			f.CustID ,
			SportType ,
			f.LeagueID ,
			MatchID ,
			SubIssueTypeID ,
			Odds ,
			OddsType ,
			BetType,
			BetTeam,
			CurrencyID ,		
			Stake,
			HDP ,
			LiveIndicator ,
			LiveHomeScore ,
			LiveAwayScore ,
			RptDate ,
			TRIM(IP) IP,
			TransDate,
			ROW_NUMBER() OVER (ORDER BY TransID DESC) RN
	FROM bodb_Account.dbo.AbnormalBetTransaction f WITH(NOLOCK)
		--INNER JOIN bodb02.dbo.Custinfo c WITH(NOLOCK) ON c.custid = f.CustID
		--INNER JOIN #TempAg AS tma ON tma.CustID = c.recommend  
		--INNER JOIN #tmpLeague AS l ON l.LeagueId = f.leagueid
	WHERE CreatedDate >= @FromDate 
		AND CreatedDate < DATEADD(d, 1, @ToDate)
		AND EXISTS(SELECT TOP 1 1 FROM #tmpReason r WHERE f.SubIssueTypeID = r.ReasonID)
		AND (f.BetType = 29
			OR EXISTS(SELECT TOP 1 1 FROM #tmpSport s WHERE f.SportType = s.SportID))
		AND EXISTS(SELECT TOP 1 1 FROM #tmpBetType b WHERE f.BetType = b.BetTypeID)
		AND (@LeagueName = ''OR EXISTS (SELECT 1 FROM #tmpLeague b WHERE f.LeagueID = b.LeagueID))
		AND (@UserName = '' OR EXISTS(SELECT 1 FROM #TempCust tc WHERE tc.CustId = f.CustID))
		AND ((BetType IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveHomeScore) + ',%')  
     			OR (BetType NOT IN (9, 29) AND ',' + @LiveIndicator + ',' LIKE '%,' + CONVERT(VARCHAR(3), LiveIndicator) + ',%')) 
		AND (@Refno = 0 OR TransId = @Refno)
	OPTION (RECOMPILE)

	 IF ISNULL(@IP, '') <> ''  
	 BEGIN  
		DELETE #Src WHERE IP <> @IP  
	 END  

	INSERT INTO #tmpData(TransID ,
						 CustID ,
						 SportType ,
						 LeagueID ,
						 MatchID ,
						 SubIssueTypeID ,
						 Odds ,
						 OddsType ,
						 BetType,
						 BetTeam,
						 CurrencyID ,		
						 Stake ,
						 HDP ,
						 LiveIndicator ,
						 LiveHomeScore ,
						 LiveAwayScore ,
						 RptDate ,
						 IP)
	SELECT  TransID ,
			CustID ,
			SportType ,
			LeagueID ,
			MatchID ,
			SubIssueTypeID ,
			Odds ,
			OddsType ,
			BetType,
			BetTeam,
			CurrencyID ,		
			Stake ,
			HDP ,
			LiveIndicator ,
			LiveHomeScore ,
			LiveAwayScore ,
 			RptDate ,
			IP
	FROM #Src AS T
	WHERE (RN >= (@PageIndex - 1) * @PageSize + 1 AND RN < @PageIndex * @PageSize + 1) 
		OR (@PageIndex = 0)

	IF EXISTS(SELECT TOP 1 1 FROM #tmpData) AND @ConvertToBaseCur = 1
	BEGIN
		INSERT INTO #ExchangeRate(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, @BaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM #TempAg a WHERE e.ExchangeID = a.Currency)
	END

	CREATE TABLE #tmpMatch (
		Matchid	INT,
		Homeid	INT,
		Awayid	INT,
		Finalhomescore	INT,
		Finalawayscore	INT,
		GlobalShowTime	SMALLDATETIME
	)

	;WITH CTE_Matches AS (
		SELECT m.matchid,
			   m.homeid,
			   m.awayid,
			   m.finalhomescore,
			   m.finalawayscore,
			   m.GlobalShowTime
		FROM bodb_Account.dbo.match m WITH (NOLOCK)
		UNION
		SELECT m.matchid,
			   m.homeid,
			   m.awayid,
			   m.finalhomescore,
			   m.finalawayscore,
			   m.GlobalShowTime
		FROM bodb_Archive.dbo.match m WITH (NOLOCK)
	) 
	INSERT INTO #tmpMatch (Matchid,Homeid,Awayid,Finalhomescore,Finalawayscore,GlobalShowTime)
	SELECT	matchid,
			homeid,
			awayid,
			finalhomescore,
			finalawayscore,
			GlobalShowTime 
	FROM CTE_Matches
	WHERE matchid IN (SELECT matchid FROM #tmpData)
		
	SELECT
		RptDate AS [Date] ,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS [ExternalID],
		c.username AS [SystemID],
		e.currency AS Currency,	
		d.TransID AS [RefNo],
		CASE WHEN d.BetType = 29 THEN 0
			WHEN d.OddsType = 1 AND b.SupportMultipleOdds = 1 THEN d.Odds + 1 ELSE d.Odds END AS Odds,
		Stake  * ISNULL(er.DefaultRate,1),
		CASE WHEN d.BetType = 29 THEN 0 ELSE HDP END AS HDP,
		CASE WHEN d.BetType = 29 THEN '-' 
			ELSE CAST(d.LiveHomeScore AS NVARCHAR(10)) + '-' + CAST(d.LiveAwayScore AS NVARCHAR(10)) END AS Score,
		CASE WHEN d.BetType = 29 THEN '-' ELSE s.Sport END AS Sport,
		b.typenamee AS [BetType],
		CASE WHEN d.BetType IN (1, 7, 153, 609, 9059, 20, 9001) AND d.BetTeam = 'a' THEN 'Away'
			WHEN d.BetType IN (1, 7, 153, 609, 9059, 20, 9001) AND d.BetTeam = 'h' THEN 'Home'
			WHEN d.BetType IN (3, 8) AND d.BetTeam = 'h' THEN 'Over'
			WHEN d.BetType IN (3, 8) AND d.BetTeam = 'a' THEN 'Under'
			WHEN d.BetType IN (401, 402, 403, 404, 610, 615, 616, 9003) AND d.BetTeam = 'o' THEN 'Over'
			WHEN d.BetType IN (401, 402, 403, 404, 610, 615, 616, 9003) AND d.BetTeam = 'u' THEN 'Under'
			WHEN d.BetType = 29 THEN '-'
			ELSE d.BetTeam END AS [Choice],
		TransDate AS TransTime, 
		CASE WHEN d.BetType = 29 THEN '-' ELSE l.leaguename END League,   
		m.GlobalShowTime AS [KOTime],
		LiveIndicator AS Live,
		CASE WHEN d.BetType = 29 THEN '-' 
			ELSE CAST(m.finalhomescore AS NVARCHAR(10))+ '-' + CAST(m.finalawayscore AS NVARCHAR(10)) END AS [FinalScore],
		IP,
		i.SubIssueTypeName AS Reason
	FROM #tmpData d
		LEFT JOIN bodb_Account.dbo.tbl_Sport s WITH(NOLOCK) ON d.SportType = s.sportid
		LEFT JOIN #tmpLeague l  ON l.LeagueID = d.LeagueID
		LEFT JOIN #tmpMatch m  ON d.MatchID = m.matchid
		LEFT JOIN bodb_Account.dbo.team h WITH (NOLOCK) ON m.homeid = h.teamid
		LEFT JOIN bodb_Account.dbo.team a WITH (NOLOCK) ON m.awayid = a.teamid
		LEFT JOIN bodb_Account.dbo.TicketVoiding_SubIssueType i WITH (NOLOCK) ON d.SubIssueTypeID = i.SubIssueTypeID
		LEFT JOIN bodb_Account.dbo.bettype b WITH (NOLOCK) ON d.BetType = b.typeid
		LEFT JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON d.CurrencyID = e.exchangeid 
		LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON d.custid = c.custid
		LEFT JOIN #ExchangeRate er ON d.RptDate BETWEEN er.FromDate AND er.ToDate AND er.ExchangeId = e.ExchangeId
	WHERE c.custid IS NOT NULL

	DROP TABLE #tmpData
	DROP TABLE #tmpReason
	DROP TABLE #tmpSport 
	DROP TABLE #tmpBetType 
	DROP TABLE #tmpLeague
	DROP TABLE #tmpCurrency
	DROP TABLE #Src
	DROP TABLE #TempLeague
	DROP TABLE #tmpMatch
    DROP TABLE #ExchangeRate  
    DROP TABLE #TempCust  
    DROP TABLE #TempAg  

END;

GO
