/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_SabaVirtualSportsWinLoss_Ag]
	@AgentList				VARCHAR(MAX),
	@Username				VARCHAR(50)		= '',
	@FromDate				SMALLDATETIME,
	@ToDate					SMALLDATETIME,
	@MoveBetsDay			SMALLDATETIME,
	@SportType				SMALLINT		= 0,
	@LeagueId				INT				= 0,
	@DrawFilter				TINYINT			= 1,
	@BaseCurrency			VARCHAR(12)		= '',
	@DefaultBaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20200925@Kos
	Task: LAP - Saba Virtual Sports Win Loss report - Agent Level
	DB: DBEXT.bodb02

	Revisions:
		- 20200925@Kos: New SP [RedmineID: #141454]
		- 20201019@Kos: Change to use new table to check performance [RedmineID: #143310]
		- 20210521@Mark: Support Saba Soccer PinGoal [RedmineID: #155335]
		- 20220222@Kos: Support Saba Basketball PinGoal [RedmineID: #167859]
		- 20220302@Kos: Support filter by customer [RedmineID: #167825]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20221207@Evan: Support Saba E-Sports PinGoal [RedmineID: #181224]
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]
		- 20240304@Evan: Integrate Saba Ice Hockey [RedmineID: #201283]

	Param's Explanation:
		+ @DrawFilter: 1: Normal, 2: No Draw, 3: No Draw for Turnover only
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Invalid Parameter.'

		RETURN
	END CATCH;

	DECLARE @CustId INT = -1

	-- Get CustId in case of inputting Username
	IF @Username <> ''
	BEGIN
		SELECT @CustId = c.custid
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN #TempAg AS ta ON ta.CustId = c.recommend
		WHERE c.username = @Username

		IF @CustId = -1
		BEGIN
			SELECT @CustId = c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN #TempAg AS ta ON ta.CustId = c.recommend
			WHERE c.username2 LIKE + '%$' + @Username
		END

		IF @CustId = -1
		BEGIN
			SET @CustId = 0
		END
	END

	DECLARE @BetType TABLE (BetType INT, ProductCode VARCHAR(10))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Insert Bettype
	INSERT INTO @BetType (BetType, ProductCode)
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', 'SB,CO', @IsTest)
	WHERE BetType NOT IN (9, 29, 914, 901, 902, 903, 904)

	CREATE TABLE #SabaVirtualSportsLeague (LeagueId INT, PRIMARY KEY (LeagueId), SportType TINYINT, LeagueGroupID SMALLINT)

	INSERT INTO #SabaVirtualSportsLeague
	SELECT LeagueId, SportType, LeagueGroupID
	FROM dbo.League WITH (NOLOCK)
	WHERE (@LeagueId = 0 OR leagueid = @LeagueId)
		AND (@SportType = 0
			OR sporttype = CASE
							WHEN @SportType = -1 THEN 1
							WHEN @SportType = -2 THEN 2
							WHEN @SportType = -43 THEN 43
							ELSE @SportType
						END)
		AND ((@SportType IN (0, 1) AND sporttype = 1 AND LeagueGroupID IN (42, 74, 108))
			OR (@SportType IN (0, -1) AND sporttype = 1 AND LeagueGroupID IN (113))
			OR (@SportType IN (0, 2) AND sporttype = 2 AND LeagueGroupID IN (42))
			OR (@SportType IN (0, -2) AND sporttype = 2 AND LeagueGroupID IN (122))
			OR (sporttype = 50 AND LeagueGroupID IN (42))
			OR (@SportType IN (0, -43) AND sporttype = 43 AND LeagueGroupID IN (151))
			OR (@sporttype IN (0, 5) AND sporttype = 5 AND LeagueGroupID IN (42))
			OR (@sporttype IN (0, 4) AND sporttype = 4 AND LeagueGroupID IN (42))
			)

	DECLARE @Data TABLE (
		Recommend		INT,
		Currency		INT,
		WinLostDate		SMALLDATETIME,
		BetCount		BIGINT,
		TurnoverSB		MONEY,
		TurnoverBA		MONEY,
		WinLost			MONEY,
		LicenseeWLSB	MONEY,
		LicenseeWLCO	MONEY,
		PlayerComm		MONEY,
		BAComm			MONEY,
		AmtDueToBA		MONEY,
		CashOutComm		MONEY
	)

	DECLARE
		@_FromDate	SMALLDATETIME,
		@_ToDate	SMALLDATETIME

	SELECT @_FromDate = @FromDate,
		@_ToDate = @ToDate

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	DECLARE @CutoffDate SMALLDATETIME;
	SELECT @CutoffDate = CutoffDate
	FROM dbo.Lrf_f_GetCutOffDate()
	WHERE TypeName = 'SabaTennis'

	IF @_ToDate > @MoveBetsDay
	BEGIN
		SET @TempFromDate = CASE
								WHEN @_FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
								ELSE @_FromDate
							END

		INSERT INTO @Data (
			Recommend,
			Currency,
			WinLostDate,
			BetCount,
			TurnoverSB,
			TurnoverBA,
			WinLost,
			LicenseeWLSB,
			LicenseeWLCO,
			PlayerComm,
			BAComm,
			AmtDueToBA,
			CashOutComm )
		SELECT
			b.recommend,
			b.currency,
			b.winlostdate,
			SUM(CASE
					WHEN (@DrawFilter = 2 AND b.statusID = 111) OR b.bettype = 913 THEN 0
					ELSE 1
				END) AS BetCount,
			SUM(CASE
					WHEN bt.ProductCode = 'SB'
						AND b.tpositiontaking <> 0
						AND @DrawFilter = 1
						THEN b.stake
					WHEN bt.ProductCode = 'SB'
						AND b.tpositiontaking <> 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND b.modds IN (-0.25, 0.25)
						AND b.bettype NOT IN (29, 38)
						THEN 0.5 * b.stake
					WHEN bt.ProductCode = 'SB'
						AND b.tpositiontaking <> 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND (b.modds NOT IN (-0.25, 0.25) OR b.bettype IN (29, 38))
						THEN b.stake
					ELSE 0
				END) AS TurnoverSB,
			SUM(CASE
					WHEN bt.ProductCode = 'SB'
						AND b.tpositiontaking = 0
						AND @DrawFilter = 1
						THEN b.stake
					WHEN bt.ProductCode = 'SB'
						AND b.tpositiontaking = 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND b.modds IN (-0.25, 0.25)
						AND b.bettype NOT IN (29, 38)
						THEN 0.5 * b.stake
					WHEN bt.ProductCode = 'SB'
						AND b.tpositiontaking = 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND (b.modds NOT IN (-0.25, 0.25) OR b.bettype IN (29, 38))
						THEN b.stake
					ELSE 0
				END) AS TurnoverBA,
			SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost - b.actual_stake END) AS WinLost,
			-SUM(CASE WHEN bt.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWLSB,
			-SUM(CASE WHEN bt.bettype IN (911, 912) THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWLCO,
			SUM(CASE WHEN bt.ProductCode = 'CO' THEN 0 ELSE b.playerComm END) AS PlayerComm,
			SUM(CASE WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN b.comm ELSE 0 END) AS BAComm,
			-SUM(CASE
					WHEN bt.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN b.winlost - b.actual_stake + b.awinlost + b.comm
					ELSE 0
				END) AS AmtDueToBA,
			SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.bettype = b.bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
			INNER JOIN #SabaVirtualSportsLeague AS l ON l.LeagueId = m.leagueid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID IN (111, 112, 113)
			AND b.bettype <> 10
			AND (@Username = '' OR b.custid = @CustId)
		GROUP BY
			b.recommend,
			b.currency,
			b.winlostdate

		INSERT INTO @Data (
			Recommend,
			Currency,
			WinLostDate,
			BetCount,
			TurnoverSB,
			TurnoverBA,
			WinLost,
			LicenseeWLSB,
			LicenseeWLCO,
			PlayerComm,
			BAComm,
			AmtDueToBA,
			CashOutComm )
		SELECT
			b.recommend,
			b.currency,
			b.winlostdate,
			SUM(CASE
					WHEN @DrawFilter = 2 AND b.statusID = 111 THEN 0
					ELSE 1
				END) AS BetCount,
			SUM(CASE
					WHEN b.tpositiontaking <> 0 AND @DrawFilter = 1 THEN b.stake
					WHEN b.tpositiontaking <> 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND b.modds IN (-0.25, 0.25)
						AND b.bettype NOT IN (29, 38)
						THEN 0.5 * b.stake
					WHEN b.tpositiontaking <> 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND (b.modds NOT IN (-0.25, 0.25) OR b.bettype IN (29, 38))
						THEN b.stake
					ELSE 0
				END) AS TurnoverSB,
			SUM(CASE
					WHEN b.tpositiontaking = 0 AND @DrawFilter = 1 THEN b.stake
					WHEN b.tpositiontaking = 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND b.modds IN (-0.25, 0.25)
						AND b.bettype NOT IN (29, 38)
						THEN 0.5 * b.stake
					WHEN b.tpositiontaking = 0
						AND @DrawFilter IN (2, 3)
						AND b.statusID IN (112, 113)
						AND (b.modds NOT IN (-0.25, 0.25) OR b.bettype IN (29, 38))
						THEN b.stake
					ELSE 0
				END) AS TurnoverBA,
			SUM(b.winlost - b.actual_stake) AS WinLost,
			-SUM(CASE WHEN b.tpositiontaking <> 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWLSB,
			0 AS LicenseeWLCO,
			SUM(b.playerComm) AS PlayerComm,
			SUM(CASE WHEN b.tpositiontaking = 0 THEN b.comm ELSE 0 END) AS BAComm,
			-SUM(CASE
					WHEN b.tpositiontaking = 0 THEN b.winlost - b.actual_stake + b.awinlost + b.comm
					ELSE 0
				END) AS AmtDueToBA,
			0 AS CashOutComm
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			INNER JOIN @BetType AS bt ON bt.bettype = b.bettype
			INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid
			INNER JOIN #SabaVirtualSportsLeague AS l ON l.LeagueId = o.leagueid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @_ToDate
			AND b.statusID IN (111, 112, 113)
			AND b.bettype = 10
			AND (@Username = '' OR b.custid = @CustId)
		GROUP BY
			b.recommend,
			b.currency,
			b.winlostdate
	END

	IF @_FromDate <= @MoveBetsDay
	BEGIN
		SET @TempToDate = CASE
							WHEN @_ToDate >= @MoveBetsDay THEN @MoveBetsDay
							ELSE @_ToDate
						END

		CREATE TABLE #Date (Date SMALLDATETIME, PRIMARY KEY(Date))

		INSERT INTO #Date
		SELECT [Date]
		FROM f_GetDateBetweenTwoDates (@_FromDate, @TempToDate)

		IF @CustId = -1		-- Licensee level
		BEGIN
			INSERT INTO @Data (
				Recommend,
				Currency,
				WinLostDate,
				BetCount,
				TurnoverSB,
				TurnoverBA,
				WinLost,
				LicenseeWLSB,
				LicenseeWLCO,
				PlayerComm,
				BAComm,
				AmtDueToBA,
				CashOutComm )
			SELECT b.*
			FROM
				#Date AS d
				CROSS APPLY (
					SELECT
						b.recommend,
						b.Currency,
						b.winlostdate,
						SUM(CASE
								WHEN (@DrawFilter = 2 AND b.statusID = 111) OR b.bettype = 913 THEN 0
								ELSE b.betcount
							END) AS BetCount,
						SUM(CASE
								WHEN b.isBA = 0
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter = 1
									THEN b.stake
								WHEN b.isBA = 0
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (112, 113)
									THEN b.stake
								WHEN b.isBA = 0
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (114, 115)
									THEN 0.5 * b.stake
								ELSE 0
							END) AS TurnoverSB,
						SUM(CASE
								WHEN b.isBA = 1
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter = 1
									THEN b.stake
								WHEN b.isBA = 1
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (112, 113)
									THEN b.stake
								WHEN b.isBA = 1
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (114, 115)
									THEN 0.5 * b.stake
								ELSE 0
							END) AS TurnoverBA,
						SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS WinLost,
						-SUM(CASE WHEN b.isBA = 0 AND b.bettype NOT IN (911, 912, 913) THEN b.winlost ELSE 0 END) AS LicenseeWLSB,
						-SUM(CASE WHEN b.bettype IN (911, 912) THEN b.winlost ELSE 0 END) AS LicenseeWLCO,
						SUM(CASE WHEN b.bettype IN (911, 912, 913) THEN 0 ELSE b.playercomm END) AS PlayerComm,
						SUM(CASE WHEN b.isBA = 1 THEN b.comm ELSE 0 END) AS BAComm,
						-SUM(CASE WHEN b.isBA = 1 THEN b.winlost + b.awinlost + b.comm ELSE 0 END) AS AmountDueToBA,
						SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
					FROM
						bodb_LicenseeReport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS ag ON ag.CustId = b.recommend
						INNER JOIN #SabaVirtualSportsLeague AS l ON l.LeagueId = b.leagueid
					WHERE
						b.winlostdate = d.Date
						AND b.statusID <> 101	--exclude REJECT
						AND b.bettype NOT IN (901, 902, 903, 904, 914, 9, 29)
						AND 1 = CASE 
									WHEN l.SportType = 5 AND l.LeagueGroupID = 42 AND b.winlostdate < @CutoffDate THEN 0 
									ELSE 1
								END
					GROUP BY
						b.recommend,
						b.Currency,
						b.winlostdate
				) AS b
		END
		ELSE IF @CustId <> 0	-- Customer level
		BEGIN
			INSERT INTO @Data (
				Recommend,
				Currency,
				WinLostDate,
				BetCount,
				TurnoverSB,
				TurnoverBA,
				WinLost,
				LicenseeWLSB,
				LicenseeWLCO,
				PlayerComm,
				BAComm,
				AmtDueToBA,
				CashOutComm )
			SELECT b.*
			FROM
				#Date AS d
				CROSS APPLY (
					SELECT
						b.recommend,
						b.Currency,
						b.winlostdate,
						SUM(CASE
								WHEN (@DrawFilter = 2 AND b.statusID = 111) OR b.bettype = 913 THEN 0
								ELSE b.betcount
							END) AS BetCount,
						SUM(CASE
								WHEN b.isBA = 0
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter = 1
									THEN b.stake
								WHEN b.isBA = 0
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (112, 113)
									THEN b.stake
								WHEN b.isBA = 0
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (114, 115)
									THEN 0.5 * b.stake
								ELSE 0
							END) AS TurnoverSB,
						SUM(CASE
								WHEN b.isBA = 1
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter = 1
									THEN b.stake
								WHEN b.isBA = 1
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (112, 113)
									THEN b.stake
								WHEN b.isBA = 1
									AND b.bettype NOT IN (911, 912, 913)
									AND @DrawFilter IN (2, 3)
									AND b.statusID IN (114, 115)
									THEN 0.5 * b.stake
								ELSE 0
							END) AS TurnoverBA,
						SUM(CASE WHEN b.bettype = 913 THEN 0 ELSE b.winlost END) AS WinLost,
						-SUM(CASE WHEN b.isBA = 0 AND b.bettype NOT IN (911, 912, 913) THEN b.winlost ELSE 0 END) AS LicenseeWLSB,
						-SUM(CASE WHEN b.bettype IN (911, 912) THEN b.winlost ELSE 0 END) AS LicenseeWLCO,
						SUM(CASE WHEN b.bettype IN (911, 912, 913) THEN 0 ELSE b.playercomm END) AS PlayerComm,
						SUM(CASE WHEN b.isBA = 1 THEN b.comm ELSE 0 END) AS BAComm,
						-SUM(CASE WHEN b.isBA = 1 THEN b.winlost + b.awinlost + b.comm ELSE 0 END) AS AmountDueToBA,
						SUM(CASE WHEN b.bettype = 913 THEN b.awinlost ELSE 0 END) AS CashOutComm
					FROM
						bodb_LicenseeReport.dbo.rptCustomerMatch AS b WITH (NOLOCK)
						INNER JOIN #SabaVirtualSportsLeague AS l ON l.LeagueId = b.leagueid
					WHERE
						b.custid = @CustId
						AND b.winlostdate = d.Date
						AND b.statusID <> 101	--exclude REJECT
						AND b.bettype NOT IN (901, 902, 903, 904, 914, 9, 29)
						AND 1 = CASE 
									WHEN l.SportType = 5 AND l.LeagueGroupID = 42 AND b.winlostdate < @CutoffDate THEN 0 
									ELSE 1
								END
					GROUP BY
						b.recommend,
						b.Currency,
						b.winlostdate
				) AS b
		END

		DROP TABLE #Date
	END

	DELETE FROM @Data WHERE BetCount = 0

	DECLARE @ExchangeRate TABLE (
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT,
		USD			FLOAT,
		EUR			FLOAT,
		GBP			FLOAT,
		DefaultRate	FLOAT)

	IF EXISTS (SELECT TOP(1) 1 FROM @Data)
	BEGIN
		INSERT INTO @ExchangeRate(FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate)
		SELECT FromDate, ToDate, ExchangeID, USD, EUR, GBP, Rate, DefaultRate
		FROM dbo.Lrf_f_GetExchangeRate(@_FromDate, @_ToDate, @BaseCurrency, @DefaultBaseCurrency) e
		WHERE EXISTS (SELECT 1 FROM #TempAg a WHERE e.ExchangeID = a.Currency)
	END

	SELECT
		w.Recommend,
		c.username,
		w.Currency,
		CAST(SUM(w.TurnoverSB	* e.Rate) AS MONEY) AS TurnoverSB,
		CAST(SUM(w.TurnoverBA	* e.Rate) AS MONEY) AS TurnoverBA,
		CAST(SUM(w.WinLost		* e.Rate) AS MONEY) AS WinLost,
		CAST(SUM(w.LicenseeWLSB	* e.Rate) AS MONEY) AS LicenseeWLSB,
		CAST(SUM(w.LicenseeWLCO	* e.Rate) AS MONEY) AS LicenseeWLCO,
		CAST(SUM(w.PlayerComm	* e.Rate) AS MONEY) AS PlayerComm,
		CAST(SUM(w.BAComm		* e.Rate) AS MONEY) AS BAComm,
		CAST(SUM(w.AmtDueToBA	* e.Rate) AS MONEY) AS AmtDuetoBA,
		CAST(SUM(w.CashOutComm	* e.Rate) AS MONEY) AS CashOutComm,
		SUM(w.BetCount) AS Betcount
	FROM
		(SELECT
			Recommend,
			Currency,
			WinLostDate,
			SUM(BetCount) AS BetCount,
			SUM(TurnoverSB) AS TurnoverSB,
			SUM(TurnoverBA) AS TurnoverBA,
			SUM(WinLost) AS WinLost,
			SUM(LicenseeWLSB) AS LicenseeWLSB,
			SUM(LicenseeWLCO) AS LicenseeWLCO,
			SUM(PlayerComm) AS PlayerComm,
			SUM(BAComm) AS BAComm,
			SUM(AmtDueToBA) AS AmtDueToBA,
			SUM(CashOutComm) AS CashOutComm
		FROM @Data
		GROUP BY
			Recommend,
			Currency,
			WinLostDate) AS w
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = w.Recommend
		INNER JOIN @ExchangeRate AS e
			ON w.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND w.currency = e.ExchangeId
	GROUP BY
		w.Recommend,
		c.username,
		w.Currency
	ORDER BY w.Currency

	SELECT
		CAST(SUM(w.TurnoverSB	* e.USD) AS MONEY) AS TurnoverSBUSD,
		CAST(SUM(w.TurnoverBA	* e.USD) AS MONEY) AS TurnoverBAUSD,
		CAST(SUM(w.WinLost		* e.USD) AS MONEY) AS WinLostUSD,
		CAST(SUM(w.LicenseeWLSB	* e.USD) AS MONEY) AS LicenseeWLSBUSD,
		CAST(SUM(w.LicenseeWLCO	* e.USD) AS MONEY) AS LicenseeWLCOUSD,
		CAST(SUM(w.PlayerComm	* e.USD) AS MONEY) AS PlayerCommUSD,
		CAST(SUM(w.BAComm		* e.USD) AS MONEY) AS BACommUSD,
		CAST(SUM(w.AmtDueToBA	* e.USD) AS MONEY) AS AmtDuetoBAUSD,
		CAST(SUM(w.CashOutComm	* e.USD) AS MONEY) AS CashOutCommUSD,

		CAST(SUM(w.TurnoverSB	* e.EUR) AS MONEY) AS TurnoverSBEUR,
		CAST(SUM(w.TurnoverBA	* e.EUR) AS MONEY) AS TurnoverBAEUR,
		CAST(SUM(w.WinLost		* e.EUR) AS MONEY) AS WinLostEUR,
		CAST(SUM(w.LicenseeWLSB	* e.EUR) AS MONEY) AS LicenseeWLSBEUR,
		CAST(SUM(w.LicenseeWLCO	* e.EUR) AS MONEY) AS LicenseeWLCOEUR,
		CAST(SUM(w.PlayerComm	* e.EUR) AS MONEY) AS PlayerCommEUR,
		CAST(SUM(w.BAComm		* e.EUR) AS MONEY) AS BACommEUR,
		CAST(SUM(w.AmtDueToBA	* e.EUR) AS MONEY) AS AmtDuetoBAEUR,
		CAST(SUM(w.CashOutComm	* e.EUR) AS MONEY) AS CashOutCommEUR,

		CAST(SUM(w.TurnoverSB	* e.GBP) AS MONEY) AS TurnoverSBGBP, 
		CAST(SUM(w.TurnoverBA	* e.GBP) AS MONEY) AS TurnoverBAGBP,
		CAST(SUM(w.WinLost		* e.GBP) AS MONEY) AS WinLostGBP,
		CAST(SUM(w.LicenseeWLSB	* e.GBP) AS MONEY) AS LicenseeWLSBGBP,
		CAST(SUM(w.LicenseeWLCO	* e.GBP) AS MONEY) AS LicenseeWLCOGBP,
		CAST(SUM(w.PlayerComm	* e.GBP) AS MONEY) AS PlayerCommGBP,
		CAST(SUM(w.BAComm		* e.GBP) AS MONEY) AS BACommGBP,
		CAST(SUM(w.AmtDueToBA	* e.GBP) AS MONEY) AS AmtDuetoBAGBP,
		CAST(SUM(w.CashOutComm	* e.GBP) AS MONEY) AS CashOutCommGBP,
	
		CAST(SUM(w.TurnoverSB	* e.DefaultRate) AS MONEY) AS TurnoverSB,
		CAST(SUM(w.TurnoverBA	* e.DefaultRate) AS MONEY) AS TurnoverBA,
		CAST(SUM(w.WinLost		* e.DefaultRate) AS MONEY) AS WinLost,
		CAST(SUM(w.LicenseeWLSB	* e.DefaultRate) AS MONEY) AS LicenseeWLSB,
		CAST(SUM(w.LicenseeWLCO	* e.DefaultRate) AS MONEY) AS LicenseeWLCO,
		CAST(SUM(w.PlayerComm	* e.DefaultRate) AS MONEY) AS PlayerComm,
		CAST(SUM(w.BAComm		* e.DefaultRate) AS MONEY) AS BAComm,
		CAST(SUM(w.AmtDueToBA	* e.DefaultRate) AS MONEY) AS AmtDuetoBA,
		CAST(SUM(w.CashOutComm	* e.DefaultRate) AS MONEY) AS CashOutComm,
		SUM(w.BetCount) AS Betcount
	FROM
		(SELECT
			Recommend,
			Currency,
			WinLostDate,
			SUM(BetCount) AS BetCount,
			SUM(TurnoverSB) AS TurnoverSB,
			SUM(TurnoverBA) AS TurnoverBA,
			SUM(WinLost) AS WinLost,
			SUM(LicenseeWLSB) AS LicenseeWLSB,
			SUM(LicenseeWLCO) AS LicenseeWLCO,
			SUM(PlayerComm) AS PlayerComm,
			SUM(BAComm) AS BAComm,
			SUM(AmtDueToBA) AS AmtDueToBA,
			SUM(CashOutComm) AS CashOutComm
		FROM @Data
		GROUP BY
			Recommend,
			Currency,
			WinLostDate) AS w
		INNER JOIN @ExchangeRate e
			ON w.WinLostDate BETWEEN e.FromDate AND e.ToDate
				AND w.currency = e.ExchangeId

	DROP TABLE #TempAg
	DROP TABLE #SabaVirtualSportsLeague
END
GO
