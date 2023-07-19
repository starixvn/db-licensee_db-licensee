/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_SubsidiaryWinloss]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(1000),
	@SeparateSabaVS	BIT				= 0,
	@IncludeRaw		BIT,
	@BaseCurrency	VARCHAR(12)
AS

/*
	Created: 20170829@Sophia
	Task: Subsidiary Performance report [Redmine: #76246]
	DB: DBEXT.bodb02

	Revisions:
		- 20170829@Sophia: Initial SP [Redmine: #76246]
		- 20171226@Harper: Return more column for report [RedmineID: #88398]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20180808@Amanda: Remove Racing [RedmineID: #99378]
		- 20180905@Amanda: Add new params [Redmine: #95177]
		- 20181228@Joseph: Remove vnteam [RedmineID: #103698]
		- 20190620@Amanda: Centralize function to get exchange rate [Redmine: #112531]
		- 20200707@Kos: Support all products [Redmine: #136568]
		- 20200714@Hogan: Add 7 games for Jackpot and 2 bettype for Contribution (4297) and Jackpot Prize (4298) [RedmineID: #137290]
		- 20200924@Louis: Control BA status for subsidiary [RedmineID: #142038]
		- 20201016@Hogan: Integrate Arcadia Gaming Bonus [RedmineID: #143648]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20201104@Hogan: Add new sport Saba.club Free Bets [RedmineID: #142369]
		- 20201229@Kos: Support separate Saba Virtual Sports from SB [RedmineID: #146776]
		- 20210119@Hogan: Integrate Four Guardians [RedmineID: #148100]
		- 20210521@Mark: Support Saba Soccer PinGoal [RedmineID: #155335]
		- 20210531@Hogan: Integrate Vgaming [RedmineID: #151583]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20220222@Kos: Support Saba Basketball PinGoal [RedmineID: #167859]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20221207@Evan: Support Saba E-Sports PinGoal [RedmineID: #181224]
		- 20230702@Evan: Support Saba Virtual Tennis [RedmineID: #190465]

	Param's Explanation:
		+ @MoveBetsDay: The day we move tickets to bettrans14
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Subsidiary
	(
		WinLostDate	SMALLDATETIME,
		Recommend	INT,
		Currency	INT,
		ProductCode	VARCHAR(10),
		BetCount	INT,
		Turnover	MONEY,
		WinLost		MONEY,
		LicenseeWL	MONEY
	)

	CREATE TABLE #BettypeProduct (BetType INT PRIMARY KEY, ProductCode VARCHAR(10))
	CREATE TABLE #SporttypeProduct (SportType SMALLINT, ProductCode VARCHAR(10))
	CREATE TABLE #Date (Date SMALLDATETIME, PRIMARY KEY(Date))
	
	DECLARE @ExcludedBetType TABLE (ProductCode VARCHAR (10), BetType INT)
	-- Insert Excluded BetType
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType FROM Lrf_f_SelExcludedBetType()

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME

	SELECT @FDate = @FromDate,
		@TDate = @ToDate

	-- Get AgentList
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
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	-- Get SportBettypeMatrix
	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @CutoffDate SMALLDATETIME;
	SELECT @CutoffDate = CutoffDate
	FROM dbo.Lrf_f_GetCutOffDate()
	WHERE TypeName = 'SabaTennis'

	DECLARE @ShowBA BIT = 0,
		@ShowSB BIT = 0

	SELECT @ShowBA = CASE WHEN ',' + @ProductList + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END
	SELECT @ShowSB = CASE WHEN ',' + @ProductList + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	-- Insert Bettype
	INSERT INTO #BettypeProduct (BetType, ProductCode)		-- Don't have ProductCode IN (BT, CO)
	SELECT DISTINCT BetType, ProductPrefix
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
			AND Bettype NOT IN (SELECT BetType FROM @ExcludedBetType e WHERE e.ProductCode = ProductPrefix)

	-- Insert Sport Type
	INSERT INTO #SporttypeProduct (SportType, ProductCode)		-- Don't have ProductCode IN (BT, CO)
	SELECT DISTINCT SportType, ProductCode
	FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
	WHERE SportType NOT IN (150, 173)
	-----End Get SportBettypeMatrix

	-- Group products under SB into SB
	DECLARE @SBProductList VARCHAR(100) = 'SB'

	SET @SBProductList = dbo.Lrf_f_GroupProductCode(@SBProductList)

	UPDATE #BettypeProduct
	SET ProductCode = 'SB'
	WHERE ProductCode <> 'SB'
		AND ',' + @SBProductList + ',' LIKE '%,' + ProductCode + ',%'

	UPDATE #SporttypeProduct
	SET ProductCode = 'SB'
	WHERE ProductCode <> 'SB'
		AND ',' + @SBProductList + ',' LIKE '%,' + ProductCode + ',%'

	CREATE TABLE #SabaVirtualSportsLeague (LeagueId INT, PRIMARY KEY (LeagueId), SportType TINYINT, LeagueGroupID SMALLINT)

	INSERT INTO #SabaVirtualSportsLeague
	SELECT LeagueId, SportType, LeagueGroupID
	FROM dbo.League WITH (NOLOCK)
	WHERE (sporttype = 1 AND LeagueGroupID IN (42, 74, 108, 113))
		OR (sporttype = 2 AND LeagueGroupID IN (42, 122))
		OR (sporttype = 50 AND LeagueGroupID IN (42))
		OR (sporttype = 43 AND LeagueGroupID IN (151))
		OR (sporttype = 5 AND LeagueGroupID IN (42))

	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TDate = @ToDate

		IF @FromDate <= @MoveBetsDay
			SET @FDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @FDate = @FromDate
		
		IF EXISTS (SELECT TOP(1) 1 FROM #BettypeProduct)	-- exclude BT, CO
		BEGIN
			INSERT INTO #Subsidiary (
				WinLostDate,
				Recommend,
				Currency,
				ProductCode,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL)
			SELECT
				b.winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 'BA'
					ELSE p.ProductCode
				END AS ProductCode,
				COUNT(b.transid) AS BetCount,
				SUM(b.stake) AS Turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				- SUM(CASE
						WHEN p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
						ELSE b.winlost - b.actual_stake
					END) AS LicenseeWL
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.recommend = a.custid 
				INNER JOIN #BettypeProduct AS p ON p.bettype = b.bettype
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.statusID IN (112, 113)
					OR (@IncludeRaw = 1 AND b.statusID = 111))
				AND b.matchid > 0 
				AND (b.bettype NOT BETWEEN 1611 AND 1697 OR b.matchid <> 150)
				AND (b.bettype NOT BETWEEN 3801 AND 3899 OR b.matchid <> 173)
				AND (CASE
						WHEN @ShowBA = 0 AND p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 0
						WHEN @ShowSB = 0 AND p.ProductCode = 'SB' AND b.tpositiontaking <> 0 THEN 0
						ELSE 1
					END <> 0)
			GROUP BY
				b.winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.tpositiontaking = 0 THEN 'BA'
					ELSE p.ProductCode
				END
		END

		IF @ShowSB = 1 AND @SeparateSabaVS = 1
		BEGIN
			INSERT INTO #Subsidiary (
				WinLostDate,
				Recommend,
				Currency,
				ProductCode,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL)
			SELECT
				b.winlostdate,
				b.recommend,
				a.currency,
				'SBVS' AS ProductCode,
				COUNT(b.transid) AS BetCount,
				SUM(b.stake) AS Turnover,
				SUM(b.winlost - b.actual_stake) AS Winlost,
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.recommend = a.custid
				INNER JOIN #BettypeProduct AS p ON p.bettype = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.MatchId = b.matchid
				INNER JOIN #SabaVirtualSportsLeague AS l ON l.LeagueId = m.leagueid
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.statusID IN (112, 113)
					OR (@IncludeRaw = 1 AND b.statusID = 111))
				AND b.bettype <> 10
				AND b.tpositiontaking <> 0
			GROUP BY
				b.winlostdate,
				b.recommend,
				a.currency

			MERGE INTO #Subsidiary AS t
			USING (
				SELECT
					b.winlostdate,
					b.recommend,
					a.currency,
					'SBVS' AS ProductCode,
					COUNT(b.transid) AS BetCount,
					SUM(b.stake) AS Turnover,
					SUM(b.winlost - b.actual_stake) AS Winlost,
					- SUM(b.winlost - b.actual_stake) AS LicenseeWL
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN #TempAg AS a ON b.recommend = a.custid
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid
					INNER JOIN #SabaVirtualSportsLeague AS l ON l.LeagueId = o.leagueid
				WHERE 
					b.winlostdate BETWEEN @FDate AND @TDate
					AND (b.statusID IN (112, 113)
						OR (@IncludeRaw = 1 AND b.statusID = 111))
					AND b.bettype = 10
					AND b.tpositiontaking <> 0
				GROUP BY
					b.winlostdate,
					b.recommend,
					a.currency
			) AS s ON t.WinLostDate = s.winlostdate
				AND t.Recommend = s.recommend
				AND t.Currency = s.Currency
				AND t.ProductCode = s.ProductCode
			WHEN MATCHED THEN
				UPDATE
				SET
					t.BetCount = t.BetCount + s.BetCount,
					t.Turnover = t.Turnover + s.Turnover,
					t.Winlost = t.Winlost + s.Winlost,
					t.LicenseeWL = t.LicenseeWL + s.LicenseeWL
			WHEN NOT MATCHED THEN
				INSERT (
					WinLostDate,
					Recommend,
					Currency,
					ProductCode,
					BetCount,
					Turnover,
					WinLost,
					LicenseeWL)
				VALUES (
					s.winlostdate,
					s.recommend,
					s.Currency,
					s.ProductCode,
					s.BetCount,
					s.Turnover,
					s.WinLost,
					s.LicenseeWL);
		END
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @FDate = @FromDate

		IF @ToDate >= @MoveBetsDay
			SET @TDate = @MoveBetsDay
		ELSE
			SET @TDate = @ToDate

		IF EXISTS (SELECT TOP(1) 1 FROM #BettypeProduct)		-- exclude BT, CO
		BEGIN
			INSERT INTO #Subsidiary (
				WinLostDate,
				Recommend,
				Currency,
				ProductCode,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL)
			SELECT
				b.winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.isBA = 1 THEN 'BA'
					ELSE p.ProductCode
				END AS ProductCode,
				SUM(b.BetCount) AS BetCount,
				SUM(b.turnover) AS Turnover,
				SUM(b.winlost) AS Winlost,
				- SUM(CASE
						WHEN p.ProductCode = 'SB' AND b.isBA = 1 THEN 0
						ELSE b.winlost
					END) AS LicenseeWL
			FROM bodb_LicenseeReport.dbo.rptLicWinloss2 AS b WITH (NOLOCK)
				INNER JOIN #SporttypeProduct AS p ON b.sporttype = p.sporttype
				INNER JOIN #TempAg AS a ON b.recommend = a.custid
			WHERE
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = b.BetType)
				AND b.roleid = 1
				AND (b.statusID IN (112, 113, 114, 115)
					OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
				AND (b.isBA = 0 OR (b.isBA = 1 AND @ShowBA = 1))
				AND (CASE
						WHEN @ShowBA = 0 AND p.ProductCode = 'SB' AND b.isBA = 1 THEN 0
						WHEN @ShowSB = 0 AND p.ProductCode = 'SB' AND b.isBA = 0 THEN 0
						ELSE 1
					END <> 0)
			GROUP BY
				b.Winlostdate,
				b.recommend,
				a.currency,
				CASE
					WHEN p.ProductCode = 'SB' AND b.isBA = 1 THEN 'BA'
					ELSE p.ProductCode
				END
		END

		IF @ShowSB = 1 AND @SeparateSabaVS = 1
		BEGIN
			
			INSERT INTO #Date
			SELECT [Date]
			FROM f_GetDateBetweenTwoDates (@FDate, @TDate)

			INSERT INTO #Subsidiary (
				WinLostDate,
				Recommend,
				Currency,
				ProductCode,
				BetCount,
				Turnover,
				WinLost,
				LicenseeWL)
			SELECT b.*
			FROM
				#Date AS d
				CROSS APPLY (
					SELECT
						b.winlostdate,
						b.recommend,
						a.currency,
						'SBVS' AS ProductCode,
						SUM(b.BetCount) AS BetCount,
						SUM(b.stake) AS Turnover,
						SUM(b.winlost) AS Winlost,
						- SUM(b.winlost) AS LicenseeWL
					FROM bodb_LicenseeReport.dbo.rptWinlostbyLeague AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON b.recommend = a.custid
						INNER JOIN #SabaVirtualSportsLeague AS l ON l.LeagueId = b.leagueid
					WHERE
						b.winlostdate = d.Date
						AND b.bettype NOT IN (901, 902, 903, 904, 914, 9, 29)
						AND (b.statusID IN (112, 113, 114, 115)
							OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
						AND 1 = CASE 
									WHEN l.SportType = 5 AND l.LeagueGroupID = 42 AND b.winlostdate < @CutoffDate THEN 0 
									ELSE 1
								END
						AND b.isBA = 0
					GROUP BY
						b.Winlostdate,
						b.recommend,
						a.currency
				) AS b
		END
	END

	IF @ShowSB = 1 AND @SeparateSabaVS = 1
	BEGIN
		UPDATE d
		SET
			d.BetCount = d.BetCount - s.BetCount,
			d.Turnover = d.Turnover - s.Turnover,
			d.WinLost = d.WinLost - s.WinLost,
			d.LicenseeWL = d.LicenseeWL - s.LicenseeWL
		FROM #Subsidiary AS d
			INNER JOIN #Subsidiary AS s
				ON d.WinLostDate = s.WinLostDate
					AND d.Recommend = s.Recommend
					AND d.Currency = s.Currency
		WHERE d.ProductCode = 'SB' AND s.ProductCode = 'SBVS'

		DELETE FROM #Subsidiary
		WHERE ProductCode = 'SB' AND BetCount = 0
	END

	CREATE TABLE #Exchange (
		ExFromDate	SMALLDATETIME,
		ExToDate	SMALLDATETIME,
		ExchangeId	INT,
		Rate		FLOAT)

	;WITH Currency_CTE (CurrencyID) AS ( SELECT DISTINCT currency FROM #TempAg )
	INSERT INTO #Exchange (
		ExFromDate,
		ExToDate,
		ExchangeId,
		Rate)
	SELECT
		e.FromDate,
		e.ToDate,
		e.ExchangeID,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, '') e
		INNER JOIN Currency_CTE c ON e.ExchangeId = c.CurrencyID

	SELECT
		s.Recommend,
		s.Currency,
		s.ProductCode,
		SUM(s.BetCount)		AS BetCount,
		SUM(s.Turnover)		AS Turnover,
		SUM(s.WinLost)		AS Winlost,
		SUM(s.LicenseeWL)	AS LicenseeWL,
		SUM(s.Turnover		* e.Rate)	AS TurnoverBase,
		SUM(s.WinLost		* e.Rate)	AS WinlostBase,
		SUM(s.LicenseeWL	* e.Rate)	AS LicenseeWLBase
	FROM
		#Subsidiary AS s
		INNER JOIN #Exchange AS e ON s.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND s.currency = e.ExchangeId
	GROUP BY
		s.Recommend,
		s.Currency,
		s.ProductCode
	ORDER BY
		s.Recommend ASC,
		s.Currency ASC,
		CASE
			WHEN s.ProductCode = 'SBVS' THEN 'SB0'
			ELSE s.ProductCode
		END ASC

	DROP TABLE #Subsidiary
	DROP TABLE #Exchange
	DROP TABLE #BettypeProduct
	DROP TABLE #SporttypeProduct
	DROP TABLE #TempAg
	DROP TABLE #SabaVirtualSportsLeague
	DROP TABLE #Date
END
GO
