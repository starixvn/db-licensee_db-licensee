SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE Lrf_Forecast_MatchTotalForecast 
(
	@LicenseeID INT,
	@LicenseeType VARCHAR(100) = NULL,
	@CurrencyID INT=0,
	@UserID INT,
	@MatchID INT,
	@HomeScore INT OUTPUT,
	@AwayScore INT OUTPUT,
	@MatchTime DATETIME=NULL OUTPUT
)
AS

/*
Created: Victor@20130805
Task : Forecast
DB: DB052.bodb02
Original: [Lrf_Forecast_MatchTotalForecast]
Revisions:    

*/

BEGIN
	SET NOCOUNT ON

	-- Init data
	CREATE TABLE #SecondRS
	(
		Bettype INT,	
		hdp SMALLMONEY,
		HomeWinloss MONEY,
		HomeWinlossUSD MONEY,
		HomeWinlossEUR MONEY,
		AwayWinloss MONEY,
		AwayWinlossUSD MONEY,
		AwayWinlossEUR MONEY
	)
	DECLARE @Today SMALLDATETIME 
	DECLARE @CurScore INT

	
    SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
	
	SELECT  currencyID,LicenseeID into #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@LicenseeID,@UserID,1)-- System is default=1 (LRF)
	WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
	
	DECLARE @TempAg AS TABLE ( CustId INT )
    INSERT  INTO @TempAg ( CustId)
	SELECT  CustID  
	FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
			INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
	WHERE   [Description] = COALESCE(@LicenseeType,[Description])

	DROP TABLE #currency

	-- Update Output values
	SELECT  @HomeScore = ISNULL(livehomescore,0), 
			@AwayScore = ISNULL(liveawayscore,0),
			@MatchTime =	CASE 
								WHEN eventstatus =  'running' AND kickofftime > GETDATE() THEN kickofftime
								WHEN eventstatus =  'running' AND kickofftime <= GETDATE() THEN NULL
								ELSE NULL
							END
	FROM bodb02.dbo.match (NOLOCK)	
	WHERE matchid = @MatchID

	-- hdp, bettype, stake, odds
	SELECT 
		CASE 
			WHEN bettype IN (7,8) THEN 1
			--WHEN bettype IN (17,18) THEN 2
			ELSE 3
		END AS [Type],
		CASE WHEN bettype IN (3,8) THEN hdp1
			ELSE hdp2 - hdp1
		END AS hdp,
		bettype, stake, odds, betteam, currency, ISNULL(livehomescore,0) AS livehomescore, ISNULL(liveawayscore,0) AS liveawayscore
	INTO #Data
	FROM bodb02.dbo.bettrans b (NOLOCK)
	WHERE	b.recommend IN ( SELECT custid FROM   @TempAg )
			AND b.matchid = @MatchID
			AND b.statusID IN ( 0, 1 )
			AND b.bettype IN (1,3,7,8) -- Handicap & Over/Under
			AND b.ruben = 0
			AND b.tpositiontaking <> 0
	
	-- Handicap detail resultset
	;WITH ScoreDiff AS
	(
		SELECT  
			b.[Type],b.hdp,bettype, stake, odds, betteam, currency,
			CASE
				WHEN betteam LIKE 'h' THEN hdp
				ELSE -hdp
			END	+
			CASE
				WHEN betteam LIKE 'h' THEN (@HomeScore - livehomescore) - (@AwayScore - liveawayscore)
				ELSE (@AwayScore - liveawayscore) - (@HomeScore - livehomescore)
			END AS ScoreDiff
	
		FROM #Data b
		WHERE b.bettype IN (1,7) -- Handicap only
	)
	, LCWinloss AS
	(
		SELECT d.*,
			CASE 
				WHEN ScoreDiff < 0 THEN -- Licensee Win
					(CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END) * stake * (CASE WHEN ABS(ScoreDiff) = 0.25 THEN 0.5 ELSE 1 END)
				WHEN ScoreDiff > 0  -- Licensee Lose
					THEN -((CASE WHEN odds < 0 THEN 1 ELSE odds END) * stake * (CASE WHEN ABS(ScoreDiff) = 0.25 THEN 0.5 ELSE 1 END))
				ELSE 0
			END AS LCWinloss
		FROM ScoreDiff d
	)

	INSERT INTO #SecondRS
	SELECT bettype, 
		hdp, 
		SUM(CASE betteam WHEN 'h' THEN LCWinloss ELSE 0 END) AS HomeWinloss,
		SUM((CASE betteam WHEN 'h' THEN LCWinloss ELSE 0 END)*e.USD) AS HomeWinlossUSD,
		SUM((CASE betteam WHEN 'h' THEN LCWinloss ELSE 0 END)*e.EUR) AS HomeWinlossEUR,
		SUM(CASE betteam WHEN 'a' THEN LCWinloss ELSE 0 END) AS AwayWinloss,
		SUM((CASE betteam WHEN 'a' THEN LCWinloss ELSE 0 END) * e.USD) AS AwayWinlossUSD,
		SUM((CASE betteam WHEN 'a' THEN LCWinloss ELSE 0 END) * e.EUR) AS AwayWinlossEUR
	FROM LCWinloss lc
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = lc.currency
	GROUP BY bettype, hdp
	ORDER BY 2

	-- Over/Under detail resultset
	DECLARE @TotalScore INT
	SET @TotalScore = @HomeScore + @AwayScore

	;WITH ScoreDiff AS
	(
		SELECT [Type], hdp, bettype, stake, odds, betteam, currency, 
			CASE WHEN betteam LIKE 'h' THEN @TotalScore - hdp ELSE hdp - @TotalScore END AS ScoreDiff
		FROM #Data d
		WHERE bettype IN (3,8)
	), LCWinloss AS
	(
		SELECT d.*,
			CASE 
				WHEN ScoreDiff < 0 THEN -- Licensee Win
					(CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END) * stake * (CASE WHEN ABS(ScoreDiff) = 0.25 THEN 0.5 ELSE 1 END)
				WHEN ScoreDiff > 0  -- Licensee Lose
					THEN -((CASE WHEN odds < 0 THEN 1 ELSE odds END) * stake * (CASE WHEN ABS(ScoreDiff) = 0.25 THEN 0.5 ELSE 1 END))
				ELSE 0
			END AS LCWinloss
		FROM ScoreDiff d
	)

	INSERT INTO #SecondRS
	SELECT bettype, 
		hdp, 
		SUM(CASE betteam WHEN 'h' THEN LCWinloss ELSE 0 END) AS HomeWinloss,
		SUM((CASE betteam WHEN 'h' THEN LCWinloss ELSE 0 END)*e.USD) AS HomeWinlossUSD,
		SUM((CASE betteam WHEN 'h' THEN LCWinloss ELSE 0 END)*e.EUR) AS HomeWinlossEUR,
		SUM(CASE betteam WHEN 'a' THEN LCWinloss ELSE 0 END) AS AwayWinloss,
		SUM((CASE betteam WHEN 'a' THEN LCWinloss ELSE 0 END) * e.USD) AS AwayWinlossUSD,
		SUM((CASE betteam WHEN 'a' THEN LCWinloss ELSE 0 END) * e.EUR) AS AwayWinlossEUR
	FROM LCWinloss lc
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = lc.currency
	GROUP BY bettype, hdp
	ORDER BY 2 DESC

	-- Retrieve total Info
	;WITH BettypeWL AS
	(
		SELECT CASE 
				WHEN bettype IN (7,8) THEN 1
				--WHEN bettype IN (17,18) THEN 2
				ELSE 3
			END AS [Type], bettype,
			SUM(HomeWinloss + AwayWinloss) AS Outcome,
			SUM(HomeWinlossUSD + AwayWinlossUSD) AS OutcomeUSD,
			SUM(HomeWinlossEUR + AwayWinlossEUR) AS OutcomeEUR
		FROM #SecondRS
		GROUP BY bettype
	), TypeWL AS
	(
		SELECT [Type], 
			SUM(CASE WHEN bettype IN (1,7) THEN Outcome ELSE 0 END) AS OutcomeHDP,
			SUM(CASE WHEN bettype IN (1,7) THEN OutcomeUSD ELSE 0 END) AS OutcomeHDPUSD,
			SUM(CASE WHEN bettype IN (1,7) THEN OutcomeEUR ELSE 0 END) AS OutcomeHDPEUR,
			SUM(CASE WHEN bettype IN (3,8) THEN Outcome ELSE 0 END) AS OutcomeOU,
			SUM(CASE WHEN bettype IN (3,8) THEN OutcomeUSD ELSE 0 END) AS OutcomeOUUSD,
			SUM(CASE WHEN bettype IN (3,8) THEN OutcomeEUR ELSE 0 END) AS OutcomeOUEUR
		FROM BettypeWL
		GROUP BY [Type]
	)
	SELECT 
		d.[Type],
		COUNT(*) AS TotalTickets,
		w.OutcomeHDP,
		w.OutcomeHDPUSD,
		w.OutcomeHDPEUR,
		w.OutcomeOU,
		w.OutcomeOUUSD,
		w.OutcomeOUEUR,
		SUM(CASE WHEN bettype IN (1,7) AND betteam LIKE 'h' THEN stake ELSE 0 END) AS HomeTurnover,
		SUM(CASE WHEN bettype IN (1,7) AND betteam LIKE 'h' THEN stake*e.USD ELSE 0 END) AS HomeTurnoverUSD,
		SUM(CASE WHEN bettype IN (1,7) AND betteam LIKE 'h' THEN stake*e.EUR ELSE 0 END) AS HomeTurnoverEUR,
		SUM(CASE WHEN bettype IN (1,7) AND betteam LIKE 'a' THEN stake ELSE 0 END) AS AwayTurnover,
		SUM(CASE WHEN bettype IN (1,7) AND betteam LIKE 'a' THEN stake*e.USD ELSE 0 END) AS AwayTurnoverUSD,
		SUM(CASE WHEN bettype IN (1,7) AND betteam LIKE 'a' THEN stake*e.EUR ELSE 0 END) AS AwayTurnoverEUR,

		SUM(CASE WHEN bettype IN (3,8) AND betteam LIKE 'h' THEN stake ELSE 0 END) AS OverTurnover,
		SUM(CASE WHEN bettype IN (3,8) AND betteam LIKE 'h' THEN stake*e.USD ELSE 0 END) AS OverTurnoverUSD,
		SUM(CASE WHEN bettype IN (3,8) AND betteam LIKE 'h' THEN stake*e.EUR ELSE 0 END) AS OverTurnoverEUR,
		SUM(CASE WHEN bettype IN (3,8) AND betteam LIKE 'a' THEN stake ELSE 0 END) AS UnderTurnover,
		SUM(CASE WHEN bettype IN (3,8) AND betteam LIKE 'a' THEN stake*e.USD ELSE 0 END) AS UnderTurnoverUSD,
		SUM(CASE WHEN bettype IN (3,8) AND betteam LIKE 'a' THEN stake*e.EUR ELSE 0 END) AS UnderTurnoverEUR

		FROM #Data d
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = d.currency
		INNER JOIN TypeWL w ON d.[Type] = w.[Type]
	GROUP BY d.[Type], w.OutcomeHDP,w.OutcomeHDPUSD,w.OutcomeHDPEUR,w.OutcomeOU,w.OutcomeOUUSD,w.OutcomeOUEUR
	ORDER BY 1

	
	-- Insert running bet-lines without any tickets placed
	;WITH BetLines AS
	(
		SELECT 
			bettype,
			ISNULL(CASE WHEN bettype IN (3,8) THEN hdp1
					ELSE hdp2 - hdp1
				END,0) AS hdp
		FROM odds o
		WHERE oddsstatus LIKE 'running'  AND bettype IN (1,3,7,8) AND matchid = @MatchID
	)

	INSERT INTO #SecondRS
	SELECT bettype,hdp,0,0,0,0,0,0 
	FROM BetLines l
	WHERE NOT EXISTS (SELECT 1 FROM #SecondRS s WHERE s.bettype = l.bettype AND s.hdp = l.hdp)

	-- Retrieve Second Resultset
	SELECT * 
	FROM #SecondRS
	
	-- Drop temp tables
	DROP TABLE #Data
	DROP TABLE #SecondRS

END
GO

GRANT EXECUTE ON [dbo].[Lrf_Forecast_MatchTotalForecast] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast_MatchTotalForecast] TO vnteam
GO