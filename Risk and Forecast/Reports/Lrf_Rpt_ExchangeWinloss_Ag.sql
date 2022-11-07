/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExchangeWinloss_Ag]
	@LicenseeId				INT,
	@AgentList				VARCHAR(MAX),
	@UserName				VARCHAR(50)	= '',
	@FromDate				DATE,
	@ToDate					DATE,
	@BaseCurrency			VARCHAR(12),
	@DefaultBaseCurrency	VARCHAR(12)
AS

/*
	Created: 20171215@Harper
	Description: LAP - Exchange WL report - Agent level
	DB: DBEXT.bodb02

	Revisions:
		- 20171215@Harper: Create new report Exchange Winloss [RedmineID: #86640]
		- 20180323@Amanda: Get data from raw table that data is not sum [Redmine: #92495]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20190621@Amanda: Add @BaseCurrency parameter [Redmine: #112531]
		- 20201110@Kos: Enhance performance [Redmine: #145055]
		- 20220308@Kos: Support filter by customer [RedmineID: #169283]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
		- 20221104@Sol: Deposit - AWS - Modify jobs of separated wallet - Move columns setting to new table - [RedmineID: #176479]

	exec Lrf_Rpt_ExchangeWinloss_Ag @fromdate='2017-04-24 00:00:00',@todate='2017-04-24 00:00:00',@LicenseeId = 1,
		@AgentList=N'<ROOT><Agent AgentId="791088" Currency="3"/><Agent AgentId="860379" Currency="6"/><Agent AgentId="2428981" Currency="6"/><Agent AgentId="2812696" Currency="6"/><Agent AgentId="3575140" Currency="6"/><Agent AgentId="4362999" Currency="6"/></ROOT>'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @tempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;

	CREATE TABLE #tmpResult (
		CustId		INT,
		WinLostDate	DATE,
		CurrencyId	INT,
		TotalTrans	INT,
		Turnover	MONEY,
		NetTurnover	MONEY,
		WinLost		MONEY,
		LicWinLost	MONEY,
		LicNetWL	MONEY,
		CustComm	MONEY,
		AmountDueTo	MONEY,
		AgentComm	MONEY
	)

	DECLARE @ProductID			INT
		,	@FDate				DATE
		,	@TDate				DATE
		,	@ProductPrefix		VARCHAR(2)

	DECLARE @RawWinLostDate AS TABLE (WinLostDate DATE, StartWLDate DATETIME, EndWLDate DATETIME)

	SELECT @FDate = @FromDate,
		   @TDate = @ToDate

	SET @ProductPrefix = 'BX'
	
	INSERT INTO @RawWinLostDate(WinLostDate, StartWLDate, EndWLDate)
	SELECT DISTINCT s.WinlostDate, s.WinlostDate, DATEADD(Day, 1, s.WinlostDate)
	FROM bodb_3rdProduct.dbo.Product3rd_SummarizedDateHistory s WITH (NOLOCK)
		INNER JOIN bodb_LicenseeReport.dbo.Product3rd_SummarizedDateHistory_Tracking st WITH(NOLOCK)
			ON s.ID = st.ID
	WHERE s.WinlostDate >= @FDate AND s.WinlostDate <= @TDate
		AND st.SumToThirdPartyDate IS NULL

	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = @ProductPrefix

	-- #Region: Get list custIDs
	DECLARE @TmpCust AS TABLE (CustId INT, Recommend INT)

	IF @Username = ''
	BEGIN
		INSERT INTO @TmpCust (CustId, Recommend)
		SELECT c.custid, c.recommend
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
	END
	ELSE
	BEGIN
		INSERT INTO @TmpCust (CustId, Recommend)
		SELECT c.custid, c.recommend
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
		WHERE c.username = @Username

		IF NOT EXISTS (SELECT 1 FROM @TmpCust)
		BEGIN
			INSERT INTO @TmpCust (CustId, Recommend)
			SELECT c.custid, c.recommend
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
			WHERE c.username2 LIKE + '%$' + @Username
		END
	END
	-- #EndRegion: Get list custIDs

	-- #Region: Get data has not been moved to sum table yet(yesterday and today)
	IF EXISTS (SELECT 1 FROM @RawWinLostDate)
	BEGIN
		DECLARE @RawFDate	DATE,
				@RawTDate	DATE,
				@PartyID	VARCHAR(10)
		DECLARE @ChargeRates AS TABLE(Rate MONEY, FromDate DATE, ToDate DATE)

		SELECT @RawFDate = MIN(WinLostDate), @RawTDate = MAX(WinLostDate)
		FROM @RawWinLostDate

		SELECT @PartyID = CAST(PartyID AS VARCHAR)
		FROM bodb_licensee.dbo.OAS_Party WITH(NOLOCK)
		WHERE OldRefID = @LicenseeId AND PartyType = 1
		
		INSERT INTO @ChargeRates(Rate, FromDate, ToDate)
		SELECT DI_Rate, Fromdate, Todate
		FROM bodb_licensee.dbo.LA_f_ChargeInfo(@PartyID, @RawFDate, @RawTDate, @ProductPrefix, 'OA', 1)
		WHERE ChargeType = 1 AND DI_Rate > 0
		
		IF NOT EXISTS (SELECT 1 FROM @ChargeRates)
		BEGIN
			INSERT INTO @ChargeRates(Rate, FromDate, ToDate)
			SELECT DI_Rate, Fromdate, Todate
			FROM bodb_licensee.dbo.LA_f_GetChargeInfoWithTrialTime(@PartyID, @RawFDate, @RawTDate, @ProductPrefix, 'OA', 1)
			WHERE ChargeType = 1 AND DI_Rate > 0
		END

		CREATE TABLE #sumBet (
			SettledDate		DATE,
			CustID			INT,
			UserID			VARCHAR(20),
			EventID			INT,
			MarketID		VARCHAR(50),
			CurrencyID		INT,
			TurnOver		MONEY,
			Winlost			MONEY,
			CustComm		MONEY,
			AgentComm		MONEY,
			ExVirtualRate	FLOAT
		)

		INSERT INTO #sumBet (
			SettledDate,
			CustID,
			UserID,
			EventID,
			MarketID,
			CurrencyID,
			TurnOver,
			Winlost,
			CustComm,
			AgentComm,
			ExVirtualRate )
		SELECT
			CONVERT(DATE, sumbet.settledDate),
			cust.Recommend,
			sumbet.userId,
			sumbet.eventID,
			sumbet.marketID,
			sumbet.currency,
			SUM(sumbet.stakeTotal/sumbet.ExVirtualRate),		-- TurnOver
			SUM(sumbet.marketTotal/sumbet.ExVirtualRate),		-- winloss
			SUM(sumbet.commission/sumbet.ExVirtualRate),		-- CustComm 
			SUM(sumbet.agentCommission/sumbet.ExVirtualRate),	-- AgentComm
			sumbet.ExVirtualRate
		FROM bodb_3rdProduct.dbo.Sum_winloss_Exchange AS sumbet WITH (NOLOCK)
			INNER JOIN @RawWinLostDate AS wldate ON sumbet.settledDate >= wldate.StartWLDate AND sumbet.settledDate < wldate.EndWLDate
			INNER JOIN @tmpCust AS cust ON cust.Custid = sumbet.CustID
		GROUP BY
			sumbet.settledDate,
			cust.Recommend,
			sumbet.userId,
			sumbet.eventID,
			sumbet.marketID,
			sumbet.currency,
			sumbet.ExVirtualRate
		
		CREATE TABLE #detailBet (
			SettledDate	DATE,
			UserID		VARCHAR(20),
			EventID		INT,
			MarketID	VARCHAR(50),
			BetCount	INT,
			Lay			MONEY,
			Back		MONEY,
		)
		
		INSERT INTO #detailBet (
			SettledDate,
			UserID,
			EventID,
			MarketID,
			BetCount,
			Lay,
			Back)
		SELECT
			sumbet.SettledDate,
			bet.userId,
			bet.eventID,
			bet.marketID,
			COUNT(bet.betID) AS Betcount,
			SUM(CASE WHEN bet.matchType = 'Lay' THEN (bet.matchStake/sumbet.ExVirtualRate) ELSE 0 END) AS Lay,
			SUM(CASE WHEN bet.matchType = 'Back' THEN (bet.matchStake/sumbet.ExVirtualRate) ELSE 0 END) AS Back
		FROM bodb_3rdProduct.dbo.Bettrans_Exchange bet WITH (NOLOCK)
			INNER JOIN #sumBet sumbet ON bet.userId = sumbet.UserID AND bet.eventID = sumbet.EventID AND bet.marketID = sumbet.MarketID
		WHERE bet.betstatus = 'Settled'
		GROUP BY
			sumbet.SettledDate,
			bet.userId,
			bet.eventID,
			bet.marketID
		
		INSERT INTO #tmpResult (
			CustId,
			WinLostDate,
			CurrencyId,
			Turnover,
			NetTurnover,
			TotalTrans,
			WinLost,
			LicWinLost,
			LicNetWL,
			CustComm,
			AmountDueTo,
			AgentComm
			)
		SELECT
			sumbet.CustID 
			, sumbet.SettledDate
			, sumbet.CurrencyID
			, SUM(sumbet.Turnover)
			, SUM(ABS(ISNULL(bet.Lay, 0) - ISNULL(bet.Back, 0)))
			, SUM(ISNULL(bet.BetCount, 0))
			, SUM(sumbet.Winlost)
			, - SUM(sumbet.Winlost)
			, - SUM(sumbet.Winlost * (1 - ISNULL(rate.Rate, 1)))
			, SUM(sumbet.CustComm)
			, - SUM((sumbet.Winlost + sumbet.CustComm) + (-sumbet.Winlost*(1-ISNULL(rate.Rate,1)) + sumbet.AgentComm)) -- (LicWL - NetLicWL) + (LicComm - NetLicComm)
			, SUM(sumbet.AgentComm)
		FROM #sumBet sumbet
			LEFT JOIN #detailBet bet ON sumbet.userId	= bet.userId 
									AND sumbet.eventID	= bet.eventID 
									AND sumbet.marketID	= bet.marketID
									AND sumbet.SettledDate = bet.SettledDate
			LEFT JOIN @ChargeRates rate ON sumbet.SettledDate BETWEEN rate.FromDate AND rate.ToDate
		GROUP BY
			sumbet.SettledDate,
			sumbet.CurrencyID,
			sumbet.CustID

		DROP TABLE #sumBet
		DROP TABLE #detailBet
	END
	-- #EndRegion: Get data has not been moved to sum table yet(yesterday and today)

	-- #Region: Handle Data	from Sum Table
	IF @FDate <= @TDate
	BEGIN
		INSERT INTO #tmpResult (
			CustId,
			WinLostDate,
			CurrencyId,
			Turnover,
			NetTurnover,
			TotalTrans,
			WinLost,
			LicWinLost,
			LicNetWL,
			CustComm,
			AmountDueTo,
			AgentComm )
		SELECT
			c.Recommend,
			b.Winlostdate,
			b.Currency,
			SUM(b.Turnover),
			SUM(ValidBetAmount),
			SUM(b.BetCount),
			SUM(b.Winlost),
			-SUM(b.Winlost),
			SUM(b.WinLostA),
			SUM(CommissionP),
			-SUM(( b.Winlost + b.CommissionP) + ( b.WinLostA + CommissionA)), -- (LicWL - NetLicWL) + (LicComm - NetLicComm)
			SUM(CommissionA)
		FROM bodb_LicenseeReport.dbo.rptDepWinlost_ThirdParty b WITH (NOLOCK)
			INNER JOIN @tmpCust c ON b.Custid = c.CustID
		WHERE b.Winlostdate BETWEEN @FDate AND @TDate
			AND b.ProductId = @ProductID
			AND NOT EXISTS (SELECT 1 FROM @RawWinLostDate r WHERE b.Winlostdate = r.WinLostDate)
		GROUP BY
			b.Winlostdate,
			b.Currency,
			c.Recommend
	END
	-- #EndRegion: Handle Data	from Sum Table

	-- #Region: Handle Exchange Rate
	CREATE TABLE #Exchange (
		ExchangeId	INT,
		FromDate	DATE,
		ToDate		DATE,
		GBP			FLOAT,
		USD			FLOAT,
		EUR			FLOAT,
		Rate		FLOAT,
		DefaultRate	FLOAT)

	;WITH Currency_CTE (CurrencyID) AS (SELECT DISTINCT CurrencyID FROM #tmpResult)
	INSERT INTO #Exchange (
		ExchangeID,
		FromDate,
		ToDate,
		GBP,
		USD,
		EUR,
		Rate,
		DefaultRate )
	SELECT ExchangeID, FromDate, ToDate, GBP, USD, EUR, Rate, DefaultRate
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) exc
		INNER JOIN Currency_CTE cur ON exc.ExchangeID = cur.CurrencyID

	-- #Region: Return data
	SELECT r.CustId
		, ci.username
		, r.CurrencyId
		, SUM(r.TotalTrans)			AS TotalTrans
		
		, SUM(r.Turnover * e.Rate)		AS TurnOver
		, SUM(r.NetTurnover * e.Rate)	AS NetTurnOver
		, SUM(r.WinLost * e.Rate)		AS Winlost
		, SUM(r.CustComm * e.Rate)		AS CustComm
		, SUM(r.LicWinLost * e.Rate)	AS LicenseeWinlost
		, SUM(r.AmountDueTo * e.Rate)	AS AmountDueTo
		, SUM(r.AgentComm * e.Rate)		AS AgentComm
		, SUM(r.LicNetWL * e.Rate)		AS LicNetWL
		---USD
		, SUM(r.Turnover * e.USD)		AS TurnOverUSD
		, SUM(r.NetTurnover * e.USD)	AS NetTurnOverUSD
		, SUM(r.WinLost * e.USD)		AS WinlostUSD
		, SUM(r.CustComm * e.USD)		AS CustCommUSD
		, SUM(r.LicWinLost * e.USD)		AS LicenseeWinlostUSD
		, SUM(r.AmountDueTo * e.USD)	AS AmountDueToUSD
		, SUM(r.AgentComm * e.USD)		AS AgentCommUSD
		, SUM(r.LicNetWL * e.USD)		AS LicNetWLUSD
		---EUR
		, SUM(r.Turnover * e.EUR)		AS TurnOverEUR
		, SUM(r.NetTurnover * e.EUR)	AS NetTurnOverEUR
		, SUM(r.WinLost * e.EUR)		AS WinlostEUR
		, SUM(r.CustComm * e.EUR)		AS CustCommEUR
		, SUM(r.LicWinLost * e.EUR)		AS LicenseeWinlostEUR
		, SUM(r.AmountDueTo * e.EUR)	AS AmountDueToEUR
		, SUM(r.AgentComm * e.EUR)		AS AgentCommEUR
		, SUM(r.LicNetWL * e.EUR)		AS LicNetWLEUR
		---GBP
		, SUM(r.Turnover * e.GBP)		AS TurnOverGBP
		, SUM(r.NetTurnover * e.GBP)	AS NetTurnOverGBP
		, SUM(r.WinLost * e.GBP)		AS WinlostGBP
		, SUM(r.CustComm * e.GBP)		AS CustCommGBP
		, SUM(r.LicWinLost * e.GBP)		AS LicenseeWinlostGBP
		, SUM(r.AmountDueTo * e.GBP)	AS AmountDueToGBP
		, SUM(r.AgentComm * e.GBP)		AS AgentCommGBP
		, SUM(r.LicNetWL * e.GBP)		AS LicNetWLGBP
		---Default base currency
		, SUM(r.Turnover * e.DefaultRate)		AS TurnOverBase
		, SUM(r.NetTurnover * e.DefaultRate)	AS NetTurnOverBase
		, SUM(r.WinLost * e.DefaultRate)		AS WinlostBase
		, SUM(r.CustComm * e.DefaultRate)		AS CustCommBase
		, SUM(r.LicWinLost * e.DefaultRate)		AS LicenseeWinlostBase
		, SUM(r.AmountDueTo * e.DefaultRate)	AS AmountDueToBase
		, SUM(r.AgentComm * e.DefaultRate)		AS AgentCommBase
		, SUM(r.LicNetWL * e.DefaultRate)		AS LicNetWLBase
	FROM #tmpResult AS r
		INNER JOIN #Exchange AS e ON r.CurrencyID = e.ExchangeId AND r.Winlostdate BETWEEN e.FromDate AND e.ToDate
		INNER JOIN dbo.custInfo AS ci WITH (NOLOCK) ON ci.custid = r.CustID
	GROUP BY --r.Winlostdate
		r.CustId,
		ci.username,
		r.CurrencyID
	ORDER BY ci.username
	-- #EndRegion: Return data

	DROP TABLE #tmpResult
	DROP TABLE #Exchange
END
GO
