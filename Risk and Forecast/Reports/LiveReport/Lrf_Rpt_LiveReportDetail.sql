/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportDetail]
	@AgentList		VARCHAR(MAX),
	@ProductCodes	VARCHAR(MAX)	= NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@Liveindicator	INT				= 1,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20242503@Evan
	Task: Live Report Summary by Sport
	DB: DBEXT.bodb02

	Revisions:
		Return 3 tables:
		WinlostBySport
		WinlostByCurrency
		WinlostByBetType

		- 20242503@Evan: Initial SP  [RedmineID: #199843]
	Param's Explanation:
		+ @Liveindicator: indicate that whether the report will get live data or not
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

	--Declare variable:
	DECLARE @ExcludedBetType TABLE (
		  ProductCode VARCHAR(10)
		, BetType INT
	)
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode
		 , BetType
	FROM Lrf_f_SelExcludedBetType()

	--
	DROP TABLE IF EXISTS #tmpWinloss
	DROP TABLE IF EXISTS #TempExchange
	DROP TABLE IF EXISTS #tmpBettype
	DROP TABLE IF EXISTS #TempAg

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX CIX_TempAg ON #TempAg (CustId);

	CREATE TABLE #tmpWinloss (
		  winlostdate DATETIME
		, Currency INT
		, ProductCode VARCHAR(10)
		, BetType INT
		, TurnOver MONEY
		, Winlost MONEY
		, LicenseeWL MONEY
		, Comm MONEY
		, PlayerComm MONEY
		, AmtDueTo3rd MONEY
		, Betcount INT
	)
	DECLARE @DocHandler INT

	--insert agentIds to temp table
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
								  , @AgentList
		INSERT INTO #TempAg (custID, currency)
		SELECT AgentId
			 , Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data
		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100
			 , ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH;

	IF @ProductCodes IS NULL
		SET @ProductCodes = ''
	
	DECLARE @SBBACheck TINYINT;
	SELECT @SBBACheck = (POWER(2*1, 1)
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,SB,%' THEN 1 ELSE 0 END, 2) 
				+ POWER(2*CASE WHEN ISNULL(@ProductCodes, 'ALL') = 'ALL'  OR ',' + @ProductCodes + ',' LIKE '%,BA,%' THEN 1 ELSE 0 END, 3))
	
	CREATE TABLE #tmpBettype ( Bettype INT, ProductCode VARCHAR(10), RefTable TINYINT)
	INSERT INTO #tmpBettype
	SELECT a.Bettype,IIF(a.ProductId IN (63,69),'SB',b.ProductCode) AS ProductCode, a.RefTable
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
		INSERT INTO #tmpWinloss (winlostdate, Currency, ProductCode, BetType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.winlostdate
				, t.currency
				, CASE WHEN s.IsBA = 1 THEN 'BA' ELSE bt.ProductCode END AS ProductCode
				, b.bettype
				, SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake / 2 ELSE stake END)
				, SUM(b.winlost - b.actual_stake) AS Winlost
				, - SUM(CASE WHEN s.IsBA = 1 THEN 0 ELSE (b.winlost - b.actual_stake) END) AS LicenseeWL
				, SUM(
				comm) AS Comm
				, SUM(b.playercomm) AS PlayerComm
				, -SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd
				, COUNT(b.TransId) BetCount
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN #TempAg t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.bettype = bt.Bettype AND bt.RefTable NOT IN (1,2)
			LEFT JOIN bodb_licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON t.custid = BA.recommend AND b.TransId = BA.TransId
			OUTER APPLY
			(
				SELECT	CASE WHEN BA.TransID IS NOT NULL THEN 1 ELSE 0 END AS IsBA,
						ISNULL(CASE WHEN b.bettype IN (9,29,2799,10449) THEN b.livehomescore ELSE b.liveindicator END, 0) AS liveindicator
			) s
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)
			AND (s.liveindicator = @Liveindicator OR @Liveindicator = 2)
			AND 1 = CASE WHEN @SBBACheck & 8 != 8 AND s.IsBA = 1 THEN 0 ELSE 1 END 
		GROUP BY b.winlostdate
				, t.currency
				, CASE WHEN s.IsBA = 1 THEN 'BA' ELSE bt.ProductCode END
				, b.bettype

		--Get ticket on bettransRnG
		INSERT INTO #tmpWinloss (winlostdate, Currency, ProductCode, BetType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT
			b.winlostdate,
			t.currency,
			bt.ProductCode,
			bt.Bettype,
			SUM(stake) turnover,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM(b.comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
			COUNT(b.transid) BetCount
		FROM
			dbo.bettransRnG AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.gameID = bt.Bettype AND bt.RefTable = 1
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)
			AND @Liveindicator IN (0,2)
			AND 1 = CASE
				WHEN bt.bettype BETWEEN 1611 AND 1697 AND b.productID = 150 THEN 0
				WHEN bt.bettype BETWEEN 3801 AND 3899 AND b.productID = 173 THEN 0
				ELSE 1
			END
		GROUP BY
			b.winlostdate,
			t.currency,
			bt.ProductCode,
			bt.Bettype
		
		--Get ticket on bettransLC
		INSERT INTO #tmpWinloss (winlostdate, Currency, ProductCode, BetType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT
			b.winlostdate,
			t.currency,
			bt.ProductCode,
			bt.Bettype,
			SUM(stake) turnover,
			SUM(b.winlost - b.actual_stake) AS Winlost,
			- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
			SUM(b.comm) AS Comm,
			SUM(b.playercomm) AS PlayerComm,
			- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
			COUNT(b.transid) BetCount
		FROM
			dbo.bettransLC AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS t ON b.recommend = t.custid
			INNER JOIN #tmpBettype bt ON b.gameID = bt.Bettype AND bt.RefTable = 2
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @TDate
			AND b.statusID IN (111, 112, 113)
			AND @Liveindicator IN (0,2)
		GROUP BY
			b.winlostdate,
			t.currency,
			bt.ProductCode,
			bt.Bettype

	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @TDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @TDate
			
		INSERT INTO #tmpWinloss (winlostdate, Currency, ProductCode, BetType, TurnOver, Winlost, LicenseeWL, Comm, PlayerComm, AmtDueTo3rd, Betcount)
		SELECT b.WinlostDate
			 , l.Currency
			 , IIF(b.Product3rdId = 3,'BA',bt.ProductCode)
			 , b.bettype
			 , SUM(b.turnover) turnover
			 , SUM(b.Winlost) winlost
			 , -SUM(CASE WHEN b.Product3rdId = 3 THEN 0 ELSE b.Winlost END) AS LicenseeWL
			 , SUM(b.AComm) Comm
			 , SUM(b.PComm) PlayerComm
			 , -SUM(b.Winlost + b.AWinlost + b.AComm) AmountDueTo3rd
			 , SUM(b.betcount) BetCount
		FROM bodb_licenseereport.dbo.rptLicenseeWinloss b WITH (NOLOCK)
			INNER JOIN #TempAg l ON b.Recommend = l.CustId
			INNER JOIN #tmpBettype bt ON b.Bettype = bt.Bettype
		WHERE b.WinlostDate BETWEEN @FDate AND @TempToDate
			AND b.StatusId NOT IN (-1, 103)
			AND (b.LiveIndicator = @Liveindicator OR @Liveindicator = 2)
			AND 1 = CASE WHEN b.bettype BETWEEN 1611 AND 1697 AND b.Sporttype = 150 THEN 0
						WHEN b.bettype BETWEEN 3801 AND 3899 AND b.Sporttype = 173 THEN 0
					ELSE 1 END	
			AND 1 = CASE WHEN @SBBACheck & 8 != 8 AND b.Product3rdId = 3 THEN 0 ELSE 1 END 
		GROUP BY b.WinlostDate
			   , l.Currency
			   , IIF(b.Product3rdId = 3,'BA',bt.ProductCode)
			   , b.bettype
	END

	-- Get winlost by currency  
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

	-- Get winlost by currency  
	SELECT b.currency AS Currency
		 , SUM(Betcount) AS Betcount
		 , CAST(SUM(TurnOver * e.Rate) AS MONEY) AS Turnover
		 , CAST(SUM(Winlost * e.Rate) AS MONEY) AS Winlost
		 , CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		 , CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm
		 , CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		 , CAST(SUM(AmtDueto3rd * e.Rate) AS MONEY) AS AmtDueto3rd
	FROM #tmpWinloss b WITH (NOLOCK)
		INNER JOIN #TempExchange e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND e.ExchangeId = b.currency
	GROUP BY b.currency

	-- Get winlost by bettype  
	SELECT b.ProductCode
		 , CASE
			   WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
			   ELSE b.bettype
		   END bettype
		 , SUM(Betcount) AS Betcount
		 , CAST(SUM(TurnOver * e.Rate) AS MONEY) AS Turnover
		 , CAST(SUM(Winlost * e.Rate) AS MONEY) AS Winlost
		 , CAST(SUM(LicenseeWL * e.Rate) AS MONEY) AS LicenseeWL
		 , CAST(SUM(Comm * e.Rate) AS MONEY) AS Comm
		 , CAST(SUM(PlayerComm * e.Rate) AS MONEY) AS PlayerComm
		 , CAST(SUM(AmtDueto3rd * e.Rate) AS MONEY) AS AmtDueto3rd
	FROM #tmpWinloss b WITH (NOLOCK)
		LEFT JOIN dbo.Lrf_f_GroupBettype() ss ON b.bettype = ss.bettype
		INNER JOIN bettype bt WITH (NOLOCK) ON b.bettype = bt.typeid
		INNER JOIN #TempExchange e ON b.winlostdate BETWEEN e.FromDate AND e.ToDate
			AND e.ExchangeId = b.currency
	GROUP BY b.ProductCode
		   , CASE
				 WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
				 ELSE b.bettype
			 END
	ORDER BY CASE
		WHEN ISNULL(ss.bettype, 0) <> 0 THEN ss.GroupTypeId
		ELSE b.bettype
	END

END
GO
