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
	20130930@Victor: Revert back formular for HDP tickets
	20131010@Victor: Update forecast business logic for handicap tickets
	20131010@Victor: Fix @IsLive parameter issue
	20131024@Victor: Basketball and Baseball dont use Live score in formular
	20131028@Victor: Update list of Sports that use Live score in formular
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
	SELECT  DISTINCT CustID  
	FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK )  
			INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
	WHERE   [Description] = COALESCE(@LicenseeType,[Description])

	DROP TABLE #currency

	DECLARE @IsLive BIT

	-- Update Output values
	SELECT  @HomeScore = ISNULL(livehomescore,0), 
			@AwayScore = ISNULL(liveawayscore,0),
			@MatchTime =	CASE 
								WHEN eventstatus =  'running' AND kickofftime > GETDATE() THEN kickofftime
								WHEN eventstatus =  'running' AND kickofftime <= GETDATE() THEN NULL
								ELSE NULL
							END,
			@IsLive = CASE WHEN eventstatus = 'running' AND kickofftime <= GETDATE() THEN 1 ELSE 0 END
	FROM bodb02.dbo.match (NOLOCK)	
	WHERE matchid = @MatchID

	
	DECLARE @MatchSportType INT
	SELECT @MatchSportType = sporttype FROM match where matchid = @MatchId

	-- hdp, bettype, stake, odds
	SELECT 
		CASE 
			WHEN bettype IN (7,8) THEN 1
			ELSE 3
		END AS [Type],
		CASE WHEN bettype IN (3,8) THEN hdp1
			ELSE hdp2 - hdp1
		END AS hdp,
		bettype, stake, odds, betteam, currency, 
		ISNULL(livehomescore,0) AS livehomescore,  
		ISNULL(liveawayscore,0) AS liveawayscore
	INTO #Data
	FROM bodb02.dbo.bettrans b (NOLOCK)
	WHERE	b.recommend IN ( SELECT custid FROM   @TempAg )
			AND b.matchid = @MatchID
			AND b.statusID IN ( 0, 1 )
			AND b.bettype IN (1,3,7,8) -- Handicap & Over/Under
			AND b.ruben = 0
			AND b.tpositiontaking <> 0
	
	-- Get Handicap detail resultset
	IF (@IsLive = 0 OR @MatchSportType NOT IN (1,3,4,8,24,26,28)) -- Non-Live match OR not a Live handicap Sporttype: forecast with WIN - WIN method
	BEGIN
		;WITH LCWinloss AS
		(
			SELECT d.bettype, d.hdp, d.currency,
				CASE d.betteam
					WHEN 'h' THEN -((CASE WHEN odds < 0 THEN 1 ELSE odds END) * stake)
					WHEN 'a' THEN (CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END) * stake
					ELSE 0
				END AS HWinLCWinloss,
				CASE d.betteam
					WHEN 'h' THEN (CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END) * stake
					WHEN 'a' THEN -((CASE WHEN odds < 0 THEN 1 ELSE odds END) * stake)
					ELSE 0
				END AS AWinLCWinloss
			FROM #Data d
			WHERE d.bettype IN (1,7) -- Handicap only
		)

		INSERT INTO #SecondRS
		SELECT bettype, 
			hdp, 
			SUM(HWinLCWinloss) AS HomeWinloss,
			SUM(HWinLCWinloss*e.USD) AS HomeWinlossUSD,
			SUM(HWinLCWinloss*e.EUR) AS HomeWinlossEUR,
			SUM(AWinLCWinloss) AS AwayWinloss,
			SUM(AWinLCWinloss*e.USD) AS AwayWinlossUSD,
			SUM(AWinLCWinloss*e.EUR) AS AwayWinlossEUR
		FROM LCWinloss lc
			INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = lc.currency
		GROUP BY bettype, hdp
		ORDER BY 2

	END
	ELSE -- Live match: forecast with real time settlement method
	BEGIN
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
			SELECT  d.*,
					(CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END) * stake * (CASE WHEN ABS(ScoreDiff) = 0.25 THEN 0.5 ELSE 1 END) AS LCWin,
					-((CASE WHEN odds < 0 THEN 1 ELSE odds END) * stake * (CASE WHEN ABS(ScoreDiff) = 0.25 THEN 0.5 ELSE 1 END)) AS LCLose
			FROM ScoreDiff d
		)
		, HomeAwayWL AS
		(
			SELECT d.*,
				CASE 
					WHEN (ScoreDiff = 0) THEN 0
					WHEN ((ScoreDiff < 0 AND betteam LIKE 'h') OR (ScoreDiff > 0 AND betteam LIKE 'a')) THEN LCWin
					ELSE LCLose
				END AS HomeWL,
				CASE 
					WHEN (ScoreDiff = 0) THEN 0
					WHEN ((ScoreDiff < 0 AND betteam LIKE 'h') OR (ScoreDiff > 0 AND betteam LIKE 'a')) THEN LCLose
					ELSE LCWin
				END AS AwayWL
			FROM LCWinloss d
		)
		INSERT INTO #SecondRS
		SELECT bettype, 
			hdp, 
			SUM(HomeWL) AS HomeWinloss,
			SUM(HomeWL*e.USD) AS HomeWinlossUSD,
			SUM(HomeWL*e.EUR) AS HomeWinlossEUR,
			SUM(AwayWL) AS AwayWinloss,
			SUM(AwayWL * e.USD) AS AwayWinlossUSD,
			SUM(AwayWL * e.EUR) AS AwayWinlossEUR
		FROM HomeAwayWL lc
			INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = lc.currency
		GROUP BY bettype, hdp
		ORDER BY 2
	END

	-- Get Over/Under detail resultset
	;WITH LCWinloss AS
	(
		SELECT d.bettype, d.hdp, d.currency,
			CASE d.betteam
				WHEN 'h' THEN -((CASE WHEN odds < 0 THEN 1 ELSE odds END) * stake)
				WHEN 'a' THEN (CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END) * stake
				ELSE 0
			END AS HWinLCWinloss,
			CASE d.betteam
				WHEN 'h' THEN (CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END) * stake
				WHEN 'a' THEN -((CASE WHEN odds < 0 THEN 1 ELSE odds END) * stake)
				ELSE 0
			END AS AWinLCWinloss
		FROM #Data d
		WHERE d.bettype IN (3,8)
	)

	INSERT INTO #SecondRS
	SELECT bettype, 
		hdp, 
		SUM(HWinLCWinloss) AS HomeWinloss,
		SUM(HWinLCWinloss*e.USD) AS HomeWinlossUSD,
		SUM(HWinLCWinloss*e.EUR) AS HomeWinlossEUR,
		SUM(AWinLCWinloss) AS AwayWinloss,
		SUM(AWinLCWinloss*e.USD) AS AwayWinlossUSD,
		SUM(AWinLCWinloss*e.EUR) AS AwayWinlossEUR
	FROM LCWinloss lc
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = lc.currency
	GROUP BY bettype, hdp
	ORDER BY 2

	-- Retrieve total Info
	SELECT 
		d.[Type],
		COUNT(*) AS TotalTickets,
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
	GROUP BY d.[Type]
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