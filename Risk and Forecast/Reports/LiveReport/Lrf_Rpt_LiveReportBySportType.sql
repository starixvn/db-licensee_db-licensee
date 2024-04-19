/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_LiveReportBySportType]
	@AgentList		VARCHAR(MAX),
	@ProductCodes	VARCHAR(MAX)	= NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@LiveIndicator	INT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20111031@
	Task: Live Report Summary BY Sport
	DB: DBEXT.bodb02

	Revisions:
				- 20242503@Evan: Initial SP  [RedmineID: #199843]


	Param's Explanation:
		@Liveindicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
		+ @AgentList: XML structure
			<ROOT>
				<Agent AgentId="12345" Currency="3"/>
				<Agent AgentId="12345" Currency="5"/>
			</ROOT>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempFromDate	DATETIME,
			@TempToDate		DATETIME,
			@FDate			SMALLDATETIME,
			@TDate			SMALLDATETIME

	--to Deal With Parameter Sniffing
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate	

	DECLARE @ExcludedBetType TABLE (
			  ProductCode VARCHAR(10)
			, BetType INT
		)
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode
		 , BetType
	FROM Lrf_f_SelExcludedBetType()

	--
	DROP TABLE IF EXISTS #TempAg
	DROP TABLE IF EXISTS #tmpWinloss
	DROP TABLE IF EXISTS #TempExchange
	DROP TABLE IF EXISTS #tmpBettype
	DROP TABLE IF EXISTS #tmpVS

	CREATE TABLE #tmpVS (Orid INT,SportType SMALLINT) 
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX CIX_TempAg ON #TempAg (CustId);

	CREATE TABLE #tmpWinloss (
		  winlostdate DATETIME
		, Currency INT
		, SportType INT
		, TurnOver MONEY
		, Winlost MONEY
		, LicenseeWL MONEY
		, Comm MONEY
		, PlayerComm MONEY
		, AmtDueTo3rd MONEY
		, Betcount INT
	)

	DECLARE @DocHandler INT
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT,@AgentList

		INSERT INTO #TempAg (CustId, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH; 

	IF @ProductCodes IS NULL
		SET @ProductCodes = ''

	DECLARE @SBBACheck TINYINT, @NASportType SMALLINT = 0;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2) 
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 3))
	
	CREATE TABLE #tmpBettype ( Bettype INT, EventType TINYINT, RefTable TINYINT)
	INSERT INTO #tmpBettype (Bettype, EventType, RefTable)
	SELECT DISTINCT a.Bettype,a.EventType, a.RefTable
	FROM dbo.LAP_f_WinlossAnalysis_BettypeMatrix (@ProductCodes,null,null,@SBBACheck) a 
		INNER JOIN (SELECT DISTINCT ProductID, ProductCode FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductCodes)) b ON a.ProductId = b.ProductID
	WHERE NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = a.Bettype) AND a.Bettype <> 72
			AND (a.bettype < 901 OR a.bettype > 904)
			AND (a.bettype < 911 OR a.bettype > 914)

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		--Get data from bettrans 

		INSERT INTO #tmpVS (Orid, SportType)
		SELECT DISTINCT o.Orid
			, r.SportType
		FROM VSOutright o WITH (NOLOCK)
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE EventDate BETWEEN @TempFromDate AND @TDate

		INSERT INTO #tmpWinloss (winlostdate, Currency, SportType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.winlostdate
			, t.Currency
			, CASE 
				WHEN b.bettype = 10 THEN 103 --Outright
				WHEN b.bettype = 9 THEN 101 --Mix Parlay
				WHEN b.bettype = 29 THEN 102 --System Parlay
				WHEN b.bettype IN (2799, 10449) THEN 104 --VS Parlay
				WHEN bt.EventType = 0 THEN ISNULL(b.matchid, @NASportType)
				WHEN bt.EventType = 1 THEN ISNULL(m.sporttype,@NASportType)
				WHEN bt.EventType = 3 THEN ISNULL(vs.SportType,@NASportType)
				WHEN bt.EventType = 5 THEN ISNULL(m3rd.SportType,@NASportType)
			ELSE @NASportType END
			, SUM(stake) turnover
			, SUM(b.winlost - b.actual_stake) AS Winlost
			, -SUM(CASE WHEN s.IsBA = 1 THEN 0 ELSE (b.winlost - b.actual_stake) END) AS LicenseeWL
			, SUM(comm) AS Comm
			, SUM(playercomm) AS PlayerComm
			, -SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
			, COUNT(b.TransId) BetCount
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN #TempAg t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.bettype = bt.Bettype AND bt.RefTable NOT IN (1,2)
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend = BA.recommend AND b.TransId = BA.TransId 
			LEFT JOIN [match] m WITH (NOLOCK) ON b.matchid = m.matchid 
			LEFT JOIN [bodb02].[dbo].[Match3rd] m3rd WITH(NOLOCK) ON m3rd.Match3rdId = b.matchid
			LEFT JOIN #tmpVS vs ON b.oddsid = vs.Orid
			OUTER APPLY
			(
				SELECT	CASE WHEN BA.TransID IS NOT NULL THEN 1 ELSE 0 END AS IsBA,
						ISNULL(CASE WHEN b.bettype IN (9,29,2799,10449) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
			) s
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND (@Liveindicator = s.liveindicator OR @Liveindicator = 2)
			AND b.statusID IN (111, 112, 113)
			AND 1 = CASE WHEN @SBBACheck & 8 != 8 AND s.IsBA = 1 THEN 0 ELSE 1 END
		GROUP BY b.winlostdate
				, t.Currency
				, CASE 
					WHEN b.bettype = 10 THEN 103 --Outright
					WHEN b.bettype = 9 THEN 101 --Mix Parlay
					WHEN b.bettype = 29 THEN 102 --System Parlay
					WHEN b.bettype IN (2799, 10449) THEN 104 --VS Parlay
					WHEN bt.EventType = 0 THEN ISNULL(b.matchid, @NASportType)
					WHEN bt.EventType = 1 THEN ISNULL(m.sporttype,@NASportType)
					WHEN bt.EventType = 3 THEN ISNULL(vs.SportType,@NASportType)
					WHEN bt.EventType = 5 THEN ISNULL(m3rd.SportType,@NASportType)
				ELSE @NASportType END

		--Get data from bettransRnG 
		INSERT INTO #tmpWinloss (winlostdate, Currency, SportType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.winlostdate
			, t.Currency
			, b.productID 
			, SUM(stake) turnover
			, SUM(b.winlost - b.actual_stake) AS Winlost
			, -SUM(b.winlost - b.actual_stake)  AS LicenseeWL
			, SUM(comm) AS Comm
			, SUM(playercomm) AS PlayerComm
			, -SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
			, COUNT(b.TransId) BetCount
		FROM bettransRnG b WITH (NOLOCK)
			INNER JOIN #TempAg t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.gameID = bt.Bettype AND bt.RefTable = 1
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND @Liveindicator IN (0,2)
			AND b.statusID IN (111, 112, 113)
			AND 1 = CASE WHEN bt.bettype BETWEEN 1611 AND 1697 AND b.productID = 150 THEN 0
						WHEN bt.bettype BETWEEN 3801 AND 3899 AND b.productID = 173 THEN 0
					ELSE 1 END	
		GROUP BY b.winlostdate
				, t.Currency
				, b.productID

		--Get data from bettransLC 
		INSERT INTO #tmpWinloss (winlostdate, Currency, SportType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.winlostdate
			, t.Currency
			, b.productID 
			, SUM(stake) turnover
			, SUM(b.winlost - b.actual_stake) AS Winlost
			, -SUM(b.winlost - b.actual_stake)  AS LicenseeWL
			, SUM(comm) AS Comm
			, SUM(playercomm) AS PlayerComm
			, -SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
			, COUNT(b.TransId) BetCount
		FROM bettransLC b WITH (NOLOCK)
			INNER JOIN #TempAg t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.gameID = bt.Bettype AND bt.RefTable = 2
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND @Liveindicator IN (0,2)
			AND b.statusID IN (111, 112, 113)
		GROUP BY b.winlostdate
				, t.Currency
				, b.productID

		DROP TABLE IF EXISTS #tmpVS
	END
	
	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate
		
		INSERT INTO #tmpWinloss (winlostdate, Currency, SportType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.WinlostDate
			 , t.Currency
			 , CASE
				   WHEN b.bettype = 10 THEN 103
				   WHEN b.bettype = 9 THEN 101
				   WHEN b.bettype = 29 THEN 102
				   WHEN b.bettype IN (2799, 10449) THEN 104
				   ELSE b.sporttype
			   END AS SportType
			 , SUM(b.turnover) turnover
			 , SUM(b.Winlost) winlost
			 , -SUM(CASE WHEN b.Product3rdId = 3 THEN 0 ELSE b.Winlost END) AS LicenseeWL
			 , SUM(b.AComm) Comm
			 , SUM(b.PComm) PlayerComm
			 , -SUM(b.Winlost + b.AWinlost + b.AComm) AmountDueTo3rd
			 , SUM(b.betcount) BetCount
		FROM bodb_licenseereport.dbo.rptLicenseeWinloss b WITH (NOLOCK)
			INNER JOIN #TempAg t ON b.Recommend = t.CustId
			INNER JOIN #tmpBettype bt ON b.Bettype = bt.Bettype
		WHERE b.WinlostDate BETWEEN @FDate AND @TempToDate
			AND b.StatusId NOT IN (-1, 103)
			AND (b.LiveIndicator = @Liveindicator OR @Liveindicator = 2)
			AND 1 = CASE WHEN b.bettype BETWEEN 1611 AND 1697 AND b.Sporttype = 150 THEN 0
						WHEN b.bettype BETWEEN 3801 AND 3899 AND b.Sporttype = 173 THEN 0
					ELSE 1 END	
			AND 1 = CASE WHEN @SBBACheck & 8 != 8 AND b.Product3rdId = 3 THEN 0 ELSE 1 END 
		GROUP BY b.WinlostDate
			   , t.Currency
			   , CASE
					WHEN b.bettype = 10 THEN 103
					WHEN b.bettype = 9 THEN 101
					WHEN b.bettype = 29 THEN 102
					WHEN b.bettype IN (2799, 10449) THEN 104
					ELSE b.sporttype
			   	END 
	END
	
	-- Get winlost by Sport  
	CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)

	CREATE TABLE #TempExchange (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT);
	CREATE CLUSTERED INDEX CIX_TempExchange ON #TempExchange(ExchangeID);

	INSERT INTO #TempExchange (FromDate , ToDate , ExchangeId , Rate)
	SELECT FromDate
		 , ToDate
		 , ExchangeId
		 , Rate
	FROM Lrf_f_GetExchangeRate(@FDate, @TDate, @BaseCurrency, '')
	WHERE ExchangeId IN (SELECT DISTINCT Currency FROM #tmpWinloss)

	SELECT b.SportType
		 , SUM(Betcount) AS Betcount
		 , CAST(SUM(TurnOver * e.Rate) AS MONEY) AS Turnover
		 , CAST(SUM(Winlost * e.Rate) AS MONEY) AS Winlost
		 , CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		 , CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm
		 , CAST(SUM(Playercomm * e.Rate) AS MONEY) AS PlayerComm
		 , CAST(SUM(AmtDueto3rd * e.Rate) AS MONEY) AS AmtDueto3rd
	FROM #tmpWinloss b
		INNER JOIN #TempExchange e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND e.ExchangeId = b.currency
	GROUP BY b.SportType

END
GO
