/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_MatchMonitoringCenter]
	  @LicenseeID			INT
	, @AgentList			VARCHAR(MAX)
	, @MatchIDList			VARCHAR(MAX)	= 'ALL'
	, @MatchStatus			INT				= -1
	, @TriggeredAlert		INT				= -1
	, @BaseCurrency			VARCHAR(12)		= ''
AS
/*
	Created: 20250521@Kelvin
	DB: DBBOF-bodb02

	Revisions:
		- 20250122@Kelvin: Create [RedmineID: #216882]

	Param's Explanation:
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>

		+ @MatchIDList
			ALL
		+ @MatchStatus
			-1: ALL, 0: Non Live, 1 : Live
		+ @TriggeredAlert
			-1: ALL, 0: Safe, 1: Dangerous

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Today SMALLDATETIME 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	/* Get Agent list */
	----------------------------------------------------------------------------------------------------------------------------
	DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		RETURN
	END CATCH;
	----------------------------------------------------------------------------------------------------------------------------

	/* Get MatchID list */
	----------------------------------------------------------------------------------------------------------------------------
	DECLARE @TempMatch AS TABLE (MatchID INT)

	IF @MatchIDList <> 'ALL'
	BEGIN		
		INSERT INTO @TempMatch (MatchID)
		SELECT value
		FROM STRING_SPLIT(@MatchIDList,',')
	END
	----------------------------------------------------------------------------------------------------------------------------

	/* Get ExchangeRate */
	----------------------------------------------------------------------------------------------------------------------------
	DECLARE @ExchangeRate AS TABLE (ExchangeId INT, Rate FLOAT)

	INSERT INTO @ExchangeRate(ExchangeId, Rate)
	SELECT ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeId)
	----------------------------------------------------------------------------------------------------------------------------

	CREATE TABLE #tmpMatchMonitoring
	(
		  MonitoringID		INT PRIMARY KEY
		, MatchID			INT
		, LiveIndicator		BIT
		, LiveHomeScore		INT
		, LiveAwayScore		INT
		, IsAlerted			BIT
		, AlertRules		VARCHAR(MAX)
	)
	CREATE NONCLUSTERED INDEX IX_MatchID ON #tmpMatchMonitoring(MatchID, LiveIndicator, LiveHomeScore, LiveAwayScore)

	CREATE TABLE #tmpMatchForecast
	(
		  MatchID				INT
		, LeagueID				INT
		, SportType				SMALLINT
		, HomeID				INT
		, AwayID				INT
		, KickOffTime			DATETIME
		, IsNeutral				BIT
		, LiveIndicator			BIT
		, LiveHomeScore			INT
		, LiveAwayScore			INT
		, EventStatus			INT	-- 0:running, 1:not running
		, TotalHome				MONEY
		, TotalAway				MONEY
		, HomeStake				MONEY
		, AwayStake				MONEY
		, ForecastHome			MONEY
		, ForecastAway			MONEY
	)
	CREATE NONCLUSTERED INDEX IX_MatchID ON #tmpMatchForecast(MatchID, LiveIndicator, LiveHomeScore, LiveAwayScore)

	CREATE TABLE #tmpResult
	(
		  MonitoringID			INT
		, LeagueID				INT
		, SportType				SMALLINT
		, MatchID				INT
		, HomeID				INT
		, AwayID				INT
		, KickOffTime			DATETIME
		, LiveIndicator			BIT
		, LiveHomeScore			INT
		, LiveAwayScore			INT
		, IsNeutral				BIT
		, IsAlerted				BIT
		, AlertRules			VARCHAR(MAX)
		, IsSettled				BIT
		, TotalHome				MONEY
		, TotalAway				MONEY
		, HomeStake				MONEY
		, AwayStake				MONEY
		, ForecastHome			MONEY
		, ForecastAway			MONEY
	)

	/* Get list match monitoring */
	----------------------------------------------------------------------------------------------------------------------------
	INSERT INTO #tmpMatchMonitoring
	(
		  MonitoringID
		, MatchID
		, LiveIndicator
		, LiveHomeScore
		, LiveAwayScore
		, IsAlerted
	)
	SELECT 
		  MonitoringID
		, MatchID
		, LiveIndicator
		, LiveHomeScore
		, LiveAwayScore
		, IsAlerted
	FROM bodb_Licensee.dbo.LicenseeMatchMonitoring(NOLOCK)
	WHERE LicenseeId = @LicenseeID AND BetType = 20 AND IsActive = 1
		AND (@MatchIDList = 'ALL' OR MatchID IN (SELECT MatchID FROM @TempMatch))
		AND (@MatchStatus = -1 OR LiveIndicator = @MatchStatus)
		AND (@TriggeredAlert = -1 OR IsAlerted = @TriggeredAlert)

	;WITH CTE_SettingRules AS 
	(
		SELECT
			  s.MonitoringID
			, s.SettingID
			, s.BaseCurrency
			, s.ConditionType
			, r.RuleName
			, d.Threshold
		FROM #tmpMatchMonitoring tmp
			INNER JOIN bodb_Licensee.dbo.LicenseeMatchMonitoringSetting (NOLOCK) s ON s.MonitoringID = tmp.MonitoringID
			INNER JOIN bodb_Licensee.dbo.LicenseeMatchMonitoringSetting_Detail (NOLOCK) d ON d.SettingID = s.SettingID
			INNER JOIN bodb_Licensee.dbo.LicenseeMatchMonitoringRule (NOLOCK) r ON r.RuleID = d.RuleID
	),
	CTE_SettingDescriptions AS 
	(
		SELECT 
			  MonitoringID
			, SettingID
			, 'Negative Profit exeeds: ' + MAX(CASE WHEN RuleName = 'NegativeProfit' THEN FORMAT(Threshold, 'N2') ELSE '' END) +
			' - Based ' + MAX(BaseCurrency) + ' ' +
				CASE MAX(ConditionType)
				WHEN 0 THEN 'Or Ratio: '
				WHEN 1 THEN 'And Ratio: '
				ELSE 'Ratio: ' END + MAX(CASE WHEN RuleName = 'BetRatio' THEN FORMAT(Threshold, 'N2') + '%' ELSE '' END) 
			AS RuleDescription
		FROM CTE_SettingRules
		GROUP BY MonitoringID, SettingID
	),
	CTE_Result AS
	(
		SELECT
			  MonitoringID
			, '[' + STRING_AGG('"' + REPLACE(RuleDescription,'"','\"') + '"', ',') + ']' AS AlertRules
		FROM CTE_SettingDescriptions
		GROUP BY MonitoringID
	)
	UPDATE tmp
	SET AlertRules = rs.AlertRules
	FROM #tmpMatchMonitoring tmp
		INNER JOIN CTE_Result rs ON rs.MonitoringID = tmp.MonitoringID
	----------------------------------------------------------------------------------------------------------------------------

	/* Insert data Match Forecast*/
	;WITH CTE_ListMatch AS
	(	
		SELECT DISTINCT MatchID
		FROM #tmpMatchMonitoring
	)
	INSERT INTO #tmpMatchForecast
	(
		  MatchID
		, LeagueID
		, SportType
		, HomeID
		, AwayID
		, KickOffTime
		, IsNeutral
		, LiveIndicator
		, LiveHomeScore
		, LiveAwayScore
		, EventStatus
		, TotalHome
		, TotalAway
		, HomeStake
		, AwayStake
		, ForecastHome
		, ForecastAway
	)
	SELECT
		  m.matchid
		, m.leagueid
		, l.sporttype
		, m.homeid
		, m.awayid
		, FORMAT(DATEADD(HOUR, 12, m.GlobalShowTime), 'yyyy-MM-dd HH:mm') AS KickOffTime -- (GMT-4) -> (GMT+8)
		, m.IsNeutral
		, b.liveindicator
		, b.livehomescore
		, b.liveawayscore
		, CASE WHEN m.eventstatus = 'running' AND b.statusID IN (0,1) THEN 0 ELSE 1 END AS EventStatus
		, SUM((CASE WHEN b.betteam = 'h' THEN b.stake * e.Rate ELSE 0 END) * (CASE WHEN abs(b.odds) < 1 THEN 1 ELSE abs(b.odds) END)) AS TotalHome
		, SUM((CASE WHEN b.betteam = 'a' THEN b.stake * e.Rate ELSE 0 END) * (CASE WHEN abs(b.odds) < 1 THEN 1 ELSE abs(b.odds) END)) AS TotalAway
		, SUM(CASE WHEN b.betteam = 'h' THEN b.stake * e.Rate ELSE 0 END) AS HomeStake
		, SUM(CASE WHEN b.betteam = 'a' THEN b.stake * e.Rate ELSE 0 END) AS AwayStake
		, SUM(CASE WHEN b.betteam = 'h' THEN b.stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * e.Rate ELSE -(b.actual_stake) * e.Rate END) AS ForecastHome
		, SUM(CASE WHEN b.betteam = 'a' THEN b.stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * e.Rate ELSE -(b.actual_stake) * e.Rate END) AS ForecastAway
	FROM bettrans (NOLOCK) b
		INNER JOIN @TempAg ag ON b.recommend = ag.CustId AND b.currency = ag.Currency
		INNER JOIN CTE_ListMatch cte ON cte.MatchID = b.matchid
		INNER JOIN dbo.match (NOLOCK) m ON m.matchid = b.MatchID
		INNER JOIN dbo.League (NOLOCK) l ON l.leagueid = m.leagueid
		INNER JOIN @ExchangeRate e ON e.exchangeid = b.currency
	WHERE
		b.bettype = 20 AND b.tpositiontaking <> 0
	GROUP BY
		  m.matchid
		, m.leagueid
		, l.sporttype
		, m.homeid
		, m.awayid
		, FORMAT(DATEADD(HOUR, 12, m.GlobalShowTime), 'yyyy-MM-dd HH:mm') -- (GMT-4) -> (GMT+8)
		, m.IsNeutral
		, b.liveindicator
		, b.livehomescore
		, b.liveawayscore
		, CASE WHEN m.eventstatus = 'running' AND b.statusID IN (0,1) THEN 0 ELSE 1 END
		, m.EventStatus

	/* Insert data running */
	INSERT INTO #tmpResult
	(
		  MonitoringID
		, LeagueID
		, SportType
		, MatchID
		, HomeID
		, AwayID
		, KickOffTime
		, LiveIndicator
		, LiveHomeScore
		, LiveAwayScore
		, IsNeutral
		, IsAlerted
		, AlertRules
		, IsSettled
		, TotalHome
		, TotalAway
		, HomeStake
		, AwayStake
		, ForecastHome
		, ForecastAway
		)
	SELECT
		  m.MonitoringID
		, f.leagueid
		, f.sporttype
		, f.MatchID
		, f.homeid
		, f.awayid
		, f.KickOffTime
		, m.LiveIndicator
		, m.livehomescore
		, m.liveawayscore
		, f.IsNeutral
		, m.IsAlerted
		, m.AlertRules
		, 0 AS IsSettled
		, f.TotalHome
		, f.TotalAway
		, f.HomeStake
		, f.AwayStake
		, f.ForecastHome
		, f.ForecastAway
	FROM
		#tmpMatchMonitoring m
		INNER JOIN #tmpMatchForecast f ON f.MatchID = m.MatchID AND f.LiveIndicator = m.LiveIndicator AND f.LiveHomeScore = m.LiveHomeScore AND f.LiveAwayScore = m.LiveAwayScore
	WHERE
		f.EventStatus = 0 --running

	/* Insert data settled */
	INSERT INTO #tmpResult
	(
		  MonitoringID
		, LeagueID
		, SportType
		, MatchID
		, HomeID
		, AwayID
		, KickOffTime
		, LiveIndicator
		, LiveHomeScore
		, LiveAwayScore
		, IsNeutral
		, IsAlerted
		, AlertRules
		, IsSettled
		, TotalHome
		, TotalAway
		, HomeStake
		, AwayStake
		, ForecastHome
		, ForecastAway
		)
	SELECT
		  m.MonitoringID
		, f.leagueid
		, f.sporttype
		, f.MatchID
		, f.homeid
		, f.awayid
		, f.KickOffTime
		, m.LiveIndicator
		, m.livehomescore
		, m.liveawayscore
		, f.IsNeutral
		, m.IsAlerted
		, m.AlertRules
		, 1 AS IsSettled
		, 0 AS TotalHome
		, 0 AS TotalAway
		, 0 AS HomeStake
		, 0 AS AwayStake
		, 0 AS ForecastHome
		, 0 AS ForecastAway
	FROM
		#tmpMatchMonitoring m
		INNER JOIN #tmpMatchForecast f ON f.MatchID = m.MatchID AND f.LiveIndicator = m.LiveIndicator AND f.LiveHomeScore = m.LiveHomeScore AND f.LiveAwayScore = m.LiveAwayScore
	WHERE
		f.EventStatus = 1 -- not running

	/* Return IsSettled = 0 */
	SELECT
		  LeagueID
		, SportType
		, MonitoringID
		, MatchID
		, HomeID
		, AwayID
		, KickOffTime
		, LiveIndicator
		, LiveHomeScore
		, LiveAwayScore
		, IsNeutral
		, IsAlerted
		, AlertRules
		, IsSettled
		, TotalHome
		, TotalAway
		, HomeStake
		, AwayStake
		, ForecastHome
		, ForecastAway
	FROM #tmpResult
	WHERE IsSettled = 0
	ORDER BY LeagueID, KickOffTime DESC, IsAlerted DESC

	/* Return IsSettled = 1 */
	SELECT
		  LeagueID
		, SportType
		, MonitoringID
		, MatchID
		, HomeID
		, AwayID
		, KickOffTime
		, LiveIndicator
		, LiveHomeScore
		, LiveAwayScore
		, IsNeutral
		, IsAlerted
		, AlertRules
		, IsSettled
		, TotalHome
		, TotalAway
		, HomeStake
		, AwayStake
		, ForecastHome
		, ForecastAway
	FROM #tmpResult
	WHERE IsSettled = 1
	ORDER BY LeagueID, KickOffTime DESC, IsAlerted DESC

	DROP TABLE IF EXISTS #tmpMatchMonitoring
	DROP TABLE IF EXISTS #tmpMatchForecast
	DROP TABLE IF EXISTS #tmpResult

END
