/*<info serverAlias="DBWH-bodb_DWRS" executers="bodbLicenseeNet,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Lrf_Rpt_AbnormalBet_Detail
	@AgentList	VARCHAR(MAX) ='',
	@FromDate	DATE, 
    @ToDate	DATE,
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
	- 20230920@Evan: Hardcode show USDKH, MP [RedmineID: #193757]
	- 20240304@Evan: Integrate Saba Ice Hockey [RedmineID: #201283]

Param's Explanation:
	- @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12346" Currency="5"/>
			</ROOT>
	-  @SportTypeList: sporttype list separated by ','
		+ 'All': all sport types
		+ -1: Saba Soccer (SportType = 1, LeagueGroupId IN (42, 74))
		+ -2: Saba Basketball (SportType = 2, LeagueGroupId IN (42))
		+ -3: Saba Cricket (SportType = 50, LeagueGroupId IN (42))
		+ -4: Saba Futsal (SportType = 1, LeagueGroupId IN (108))
		+ -5: Saba Soccer Pingoal (SportType = 1, LeagueGroupId IN (113))
		+ -6: Saba Basketball Pingoal (SportType = 2, LeagueGroupId IN (122))
		+ -7: Saba E-Sports Pingoal (SportType = 43, LeagueGroupId IN (151))
		+ -8: Saba Virtual Tennis (SportType = 5, LeagueGroupId IN (42))
		+ -9: Saba Ice Hockey (SportType = 4, LeagueGroupId IN (42))
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
	- @SearchLanguage: search language
			+ en-US: English
			+ zh-CN: Chinese Simplified
			+ vi-VN: CN3 (Vietnamese)
			+ th-TH: Thailand
	- @PageIndex: starts from 1, set 0 to disable pagination
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
   
	DECLARE @CutoffDate SMALLDATETIME;
	SELECT @CutoffDate = CutoffDate
	FROM dbo.Lrf_f_GetCutOffDate()
	WHERE TypeName = 'SabaTennis'
   	
	DECLARE @SportSaba TABLE (SportID INT)
	CREATE TABLE #tmpReason (ReasonID INT)
	CREATE TABLE #tmpSport (SportID INT)
	CREATE TABLE #tmpBetType (BetTypeID INT, EventType TINYINT)
	CREATE TABLE #tmpCurrency (CurrencyID INT, CurrencyCode VARCHAR(12))
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
    
	IF EXISTS (SELECT 1 FROM #tmpSport WHERE SportID < 0)
	BEGIN
		INSERT INTO @SportSaba (SportID)
        SELECT DISTINCT	CASE WHEN SportID IN (-1,-4,-5) THEN 1 
					WHEN SportID IN (-2,-6) THEN 2 
					WHEN SportID = -3 THEN 50 
					WHEN SportID = -7 THEN 43
					WHEN SportID = -8 THEN 5
					WHEN SportID = -9 THEN 4 END
        FROM #tmpSport  
		WHERE SportID < 0

		INSERT INTO #tmpSport
		SELECT a.SportID
		FROM @SportSaba a LEFT JOIN #tmpSport b ON a.SportID = b.SportID
		WHERE b.SportID IS NULL
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
	WHERE ( EXISTS (SELECT 1 FROM #tmpSport t WHERE t.SportID=l.sporttype)
			OR (',' + @SportTypeList + ',' LIKE '%,-1,%'
				AND l.sporttype = 1
				AND l.LeagueGroupID IN (42, 74))
			OR (',' + @SportTypeList + ',' LIKE '%,-2,%'
				AND l.sporttype = 2
				AND l.LeagueGroupID IN (42))
			OR (',' + @SportTypeList + ',' LIKE '%,-3,%'
				AND l.sporttype = 50
				AND l.LeagueGroupID IN (42))
			OR (',' + @SportTypeList + ',' LIKE '%,-4,%'
				AND l.sporttype = 1
				AND l.LeagueGroupID IN (108))
			OR (',' + @SportTypeList + ',' LIKE '%,-5,%'
				AND l.sporttype = 1
				AND l.LeagueGroupID IN (113))
			OR (',' + @SportTypeList + ',' LIKE '%,-6,%'
				AND l.sporttype = 2
				AND l.LeagueGroupID IN (122))
			OR (',' + @SportTypeList + ',' LIKE '%,-7,%'
				AND l.sporttype = 43
				AND l.LeagueGroupID IN (151))	
			OR (',' + @SportTypeList + ',' LIKE '%,-8,%'
				AND l.sporttype = 5
				AND l.LeagueGroupID IN (42))	
			OR (',' + @SportTypeList + ',' LIKE '%,-9,%'
				AND l.sporttype = 4
				AND l.LeagueGroupID IN (42))	
			)
		AND (@LeagueName = '' OR CASE
									WHEN @SearchLanguage = 'zh-CN' AND ISNULL(l.leaguenamecn,'') <> '' THEN l.leaguenamecn
									WHEN @SearchLanguage = 'vi-VN' AND ISNULL(l.leaguenameVN,'') <> '' THEN l.leaguenameVN
									WHEN @SearchLanguage = 'th-TH' AND ISNULL(l.leaguenameth,'') <> '' THEN l.leaguenameth
									ELSE l.leaguename
								END LIKE '%' + @LeagueName +'%')
	
	IF @SportTypeList <> 'All'
	BEGIN
		IF ',' + @SportTypeList + ',' NOT LIKE '%,1,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId NOT IN (42, 74, 108, 113)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,2,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 2 AND LeagueGroupId NOT IN (42, 122)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,50,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 50 AND LeagueGroupId NOT IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,43,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 43 AND LeagueGroupId NOT IN (151)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,5,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 5 AND LeagueGroupId NOT IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,4,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 4 AND LeagueGroupId NOT IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-1,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId IN (42, 74)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-2,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 2 AND LeagueGroupId IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-3,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 50 AND LeagueGroupId IN (42)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-4,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId IN (108)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-5,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 1 AND LeagueGroupId IN (113)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-6,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 2 AND LeagueGroupId IN (122)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-7,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 43 AND LeagueGroupId IN (151)
		END

		IF ',' + @SportTypeList + ',' NOT LIKE '%,-8,%'
		BEGIN
			DELETE FROM #League
			WHERE SportType = 5 AND LeagueGroupId IN (42)
				AND 1 = CASE
							WHEN @CutoffDate > @FromDate AND  ',' + @SportTypeList + ',' LIKE '%,5,%' THEN 0
							ELSE 1 
						END
		END
		
		IF ',' + @SportTypeList + ',' NOT LIKE '%,-9,%'
		BEGIN	
			DELETE FROM #League
			WHERE SportType = 4 AND LeagueGroupId IN (42)
		END
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
		TransID BIGINT,
		CustID INT,
		SportType INT,
		LeagueID INT,    
		LeagueGroupId SMALLINT,
		MatchID INT,
		SubIssueTypeID TINYINT,
		Odds SMALLMONEY,
		OddsType INT,
		BetType INT,
		EventType TINYINT,
		BetTeam NVARCHAR(10),
		CurrencyID INT,		
		Stake DECIMAL(19,4),
		HDP SMALLMONEY,
		LiveIndicator BIT,
		LiveHomeScore SMALLINT,
		LiveAwayScore SMALLINT,
		CreatedDate SMALLDATETIME,
		IP VARCHAR(45),
		TransDate DATETIME
	)	

	CREATE TABLE #Src
	(
		TransID BIGINT,
		CustID INT,
		SportType INT,
		LeagueID INT,
		LeagueGroupId SMALLINT,
		MatchID INT,
		SubIssueTypeID SMALLINT,
		Odds SMALLMONEY,
		OddsType INT,
		BetType INT,
		EventType TINYINT,
		BetTeam NVARCHAR(10),
		CurrencyID INT,		
		Stake DECIMAL(19, 4),
		HDP SMALLMONEY,
		LiveIndicator BIT,
		LiveHomeScore SMALLINT,
		LiveAwayScore SMALLINT,
		CreatedDate DATE,
		IP VARCHAR(40),
		TransDate DATETIME,
		RN INT
	)
	
	INSERT INTO #Src(
			TransID,
			CustID,
			SportType,
			LeagueID,
			LeagueGroupId,
			MatchID,
			SubIssueTypeID,
			Odds,
			OddsType,
			BetType,
			EventType,
			BetTeam,
			CurrencyID,
			Stake,
			HDP,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			CreatedDate,
			IP,
			TransDate,
			RN )
	SELECT  TransID ,
			f.CustID ,
			l.SportType ,
			l.LeagueId ,
			l.LeagueGroupId ,
			MatchID ,
			SubIssueTypeID ,
			Odds ,
			OddsType ,
			b.BetTypeID,
			b.EventType,
			BetTeam,
			CurrencyID ,		
			Stake,
			HDP ,
			LiveIndicator ,
			LiveHomeScore ,
			LiveAwayScore ,
			CreatedDate ,
			TRIM(IP) IP,
			TransDate,
			ROW_NUMBER() OVER (ORDER BY TransID DESC) RN
	FROM bodb_Account.dbo.AbnormalBetTransaction f WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Custinfo c WITH(NOLOCK) ON c.custid = f.CustID
		INNER JOIN #TempAg AS tma ON tma.CustID = c.recommend  
		INNER JOIN #tmpBetType b ON f.BetType = b.BetTypeID
		INNER JOIN #League l ON l.LeagueId = f.leagueid
	WHERE CreatedDate >= @FromDate 
		AND CreatedDate < DATEADD(d, 1, @ToDate)
		AND EXISTS(SELECT TOP 1 1 FROM #tmpReason r WHERE f.SubIssueTypeID = r.ReasonID)
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
						 LeagueGroupId ,
						 MatchID ,
						 SubIssueTypeID ,
						 Odds ,
						 OddsType ,
						 BetType,
						 EventType,
						 BetTeam,
						 CurrencyID ,		
						 Stake ,
						 HDP ,
						 LiveIndicator ,
						 LiveHomeScore ,
						 LiveAwayScore ,
						 CreatedDate ,
						 TransDate ,
						 IP)
	SELECT  TransID ,
			CustID ,
			SportType ,
			LeagueID ,
			LeagueGroupId ,
			MatchID ,
			SubIssueTypeID ,
			Odds ,
			OddsType ,
			BetType,
			EventType,
			BetTeam,
			CurrencyID ,		
			Stake ,
			HDP ,
			LiveIndicator ,
			LiveHomeScore ,
			LiveAwayScore ,
 			CreatedDate ,
 			TransDate ,
			IP
	FROM #Src AS T
	WHERE (RN >= (@PageIndex - 1) * @PageSize + 1 AND RN < @PageIndex * @PageSize + 1) 
		OR (@PageIndex = 0)

	IF EXISTS(SELECT TOP 1 1 FROM #tmpData) AND @ConvertToBaseCur = 1
	BEGIN

		DECLARE @sql VARCHAR(8000)= ''
		SELECT @sql = '	SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
						FROM OPENQUERY(DBEXT, ''SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate 
						FROM bodb02.dbo.Lrf_f_GetExchangeRate
						(''''' + CONVERT(VARCHAR(10), @FromDate, 112) + ''''',
					 	''''' + CONVERT(VARCHAR(10), @ToDate, 112) + ''''',
					 	''''' + @BaseCurrency + ''''',
					  	''''' + @BaseCurrency + ''''')
						 '')'

		INSERT INTO #ExchangeRate(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		EXEC (@sql)
		
	END
	
	CREATE TABLE #tmpMatch (
		Matchid	INT,
		Homeid	INT,
		Awayid	INT,
		Finalhomescore	INT,
		Finalawayscore	INT,
		GlobalShowTime	SMALLDATETIME,
		IsNeutral	BIT
	)

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
	WHERE matchid IN (SELECT matchid FROM #tmpData)
	
	INSERT INTO #tmpCurrency (CurrencyID, CurrencyCode)
	SELECT Id, Name FROM OPENQUERY(DBEXT,'EXEC bodb02.dbo.Lrf_CurrencySel')

	SELECT	Date, 
			ExternalID, 
			SystemID, 
			Currency , 
			RefNo, 
			Odds, 
			Stake, 
			HDP, 
			LiveHomeScore, 
			LiveAwayScore, 
			Sport, 
			LeagueGroupId, 
			BetType, 
			EventType, 
			Choice, 
			TransTime, 
			League, 
			homeid, 
			awayid, 
			IsNeutral, 
			KOTime, 
			Live, 
			FinalScore, 
			IP, 
			Reason
	FROM (	SELECT
				CreatedDate AS [Date] ,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS [ExternalID],
				c.username AS [SystemID],
				e.CurrencyCode AS Currency,	
				d.TransID AS [RefNo],
				CASE WHEN d.BetType = 29 THEN 0
					WHEN d.OddsType = 1 AND b.SupportMultipleOdds = 1 THEN d.Odds + 1 ELSE d.Odds END AS Odds,
				Stake * ISNULL(er.DefaultRate,1) AS Stake,
				CASE WHEN d.BetType = 29 THEN 0 ELSE HDP END AS HDP,
				d.LiveHomeScore,
				d.LiveAwayScore,
				CASE
					WHEN d.SportType = 1 AND d.LeagueGroupId IN (42, 74) THEN -1
					WHEN d.SportType = 2 AND d.LeagueGroupId IN (42) THEN -2
					WHEN d.SportType = 50 AND d.LeagueGroupId IN (42) THEN -3
					WHEN d.SportType = 1 AND d.LeagueGroupId IN (108) THEN -4
					WHEN d.SportType = 1 AND d.LeagueGroupId IN (113) THEN -5
					WHEN d.SportType = 2 AND d.LeagueGroupId IN (122) THEN -6
					WHEN d.SportType = 43 AND d.LeagueGroupId IN (151) THEN -7
					WHEN d.SportType = 5 AND d.LeagueGroupId IN (42) AND CreatedDate >= @CutoffDate THEN -8
					WHEN d.SportType = 4 AND d.LeagueGroupId IN (42) THEN -9
					ELSE d.SportType
				END AS Sport,
				d.LeagueGroupId,
				d.BetType,
				d.EventType,
				d.BetTeam AS [Choice],
				TransDate AS TransTime, 
				d.LeagueID AS League, 
				m.homeid,
				m.awayid,
				m.IsNeutral,
				m.GlobalShowTime AS [KOTime],
				LiveIndicator AS Live,
				CASE WHEN d.BetType = 29 THEN '-' 
					ELSE CAST(m.finalhomescore AS NVARCHAR(10))+ '-' + CAST(m.finalawayscore AS NVARCHAR(10)) END AS [FinalScore],
				IP,
				d.SubIssueTypeID AS Reason
		FROM #tmpData d
			LEFT JOIN #tmpMatch m  ON d.MatchID = m.matchid
			LEFT JOIN bodb_Account.dbo.bettype b WITH (NOLOCK) ON d.BetType = b.typeid
			LEFT JOIN #tmpCurrency e ON d.CurrencyID = e.CurrencyID 
			LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON d.custid = c.custid
			LEFT JOIN #ExchangeRate er ON d.CreatedDate BETWEEN er.FromDate AND er.ToDate AND er.ExchangeId = e.CurrencyID
		WHERE c.custid IS NOT NULL
		) AS a
	WHERE @SportTypeList = 'All' OR ',' + @SportTypeList + ',' LIKE '%,' + CAST(Sport AS VARCHAR(5)) + ',%'
	ORDER BY [Date]
	
	DROP TABLE #tmpData
	DROP TABLE #tmpReason
	DROP TABLE #tmpSport 
 	DROP TABLE #tmpBetType 
	DROP TABLE #League
	DROP TABLE #tmpCurrency
	DROP TABLE #Src
	DROP TABLE #tmpMatch
    DROP TABLE #ExchangeRate  
    DROP TABLE #TempCust  
    DROP TABLE #TempAg  

END;