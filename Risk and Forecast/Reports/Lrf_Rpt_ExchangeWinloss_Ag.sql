/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExchangeWinloss_Ag]
	  @FromDate		DATE
	, @ToDate		DATE
	, @LicenseeId	INT
	, @AgentList	VARCHAR(MAX)
AS

/*
	Created: 20171215@Harper
	Description: LRF - Implement Exchange winloss for exchange product
	DB: DBEXT.bodb02 
	Revisions: 
		- 20171215@Harper: Create new report Exchange Winloss [RedmineID: #86640]
		- 20180323@Amanda: Get data from raw table that data is not sum [Redmine: #92495]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]

	Param's Explanation:

	exec Lrf_Rpt_ExchangeWinloss_Ag @fromdate='2017-04-24 00:00:00',@todate='2017-04-24 00:00:00',@LicenseeId = 1,@AgentList=N'<ROOT><Agent AgentId="791088" Currency="3"/><Agent AgentId="860379" Currency="6"/><Agent AgentId="2428981" Currency="6"/><Agent AgentId="2812696" Currency="6"/><Agent AgentId="3575140" Currency="6"/><Agent AgentId="4362999" Currency="6"/></ROOT>'
 
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (
		CustID		INT, 
		Winlostdate DATE, 
		CurrencyID	INT, 
		TotalTrans	INT, 
		TurnOver	MONEY,
		NETTurnOver MONEY, 
		Winlost		MONEY, 
		LicWinlost	MONEY, 
		LicNetWL	MONEY, 
		CustComm	MONEY, 
		AmountDueTo MONEY, 
		AgentComm	MONEY
	)
		
	CREATE TABLE #Exchange (
		ExchangeID	INT, 
		ExchageDate DATE, 
		GBP			FLOAT, 
		USD			FLOAT, 
		EUR			FLOAT)
	
	DECLARE @ProductID			INT
		,	@FDate				DATE
		,	@TDate				DATE
		,	@ProductPrefix		VARCHAR(2)
		
	DECLARE @RawWinLostDate AS TABLE (WinLostDate DATE, StartWLDate DATETIME, EndWLDate DATETIME)

	SELECT @FDate = @FromDate,
		   @TDate = @ToDate

	SET @ProductPrefix = 'BX'
	
	INSERT INTO @RawWinLostDate(WinLostDate, StartWLDate, EndWLDate)
	SELECT DISTINCT WinlostDate, WinlostDate, DATEADD(Day, 1, WinlostDate)
	FROM bodb_3rdProduct.dbo.Product3rd_SummarizedDateHistory WITH (NOLOCK)
	WHERE WinlostDate >= @FDate AND WinlostDate <= @TDate AND SumToThirdPartyDate IS NULL

	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = @ProductPrefix	

	-- #Region: Get list custIDs
	DECLARE @tmpCust	AS TABLE (CustID INT, Currency INT, Recommend INT)	
	DECLARE @tempAg		AS TABLE (custID INT, currency INT)
	DECLARE @DocHandler	INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @tempAg ( custID, currency )
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	INSERT INTO @tmpCust ( CustID, Currency, Recommend )
	SELECT ci.custid, ci.currency, ag.custID
	FROM dbo.custInfo ci WITH (NOLOCK)
		INNER JOIN @tempAg ag ON ci.recommend = ag.custID AND ci.currency = ag.currency
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
		
		INSERT INTO #sumBet(SettledDate,
							CustID,
							UserID,
							EventID,
							MarketID,
							CurrencyID,
							TurnOver,	
							Winlost,	
							CustComm,
							AgentComm,
							ExVirtualRate
			)
		SELECT	CONVERT(DATE, sumbet.settledDate),
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
		FROM bodb_3rdProduct.dbo.Sum_winloss_Exchange sumbet WITH (NOLOCK)
			INNER JOIN @RawWinLostDate wldate ON sumbet.settledDate >= wldate.StartWLDate AND sumbet.settledDate < wldate.EndWLDate
			INNER JOIN @tmpCust cust ON cust.Custid = sumbet.CustID AND cust.Currency = sumbet.Currency
		GROUP BY sumbet.settledDate, cust.Recommend, sumbet.userId, sumbet.eventID, sumbet.marketID, sumbet.currency, sumbet.ExVirtualRate
		
		CREATE TABLE #detailBet (
				SettledDate		DATE,
				UserID			VARCHAR(20),
				EventID			INT,
				MarketID		VARCHAR(50),
				BetCount		INT,
				Lay				MONEY,
				Back			MONEY,
		)
		
		INSERT INTO #detailBet(SettledDate, UserID, EventID, MarketID, BetCount, Lay, Back)
		SELECT sumbet.SettledDate, bet.userId, bet.eventID, bet.marketID
			, COUNT(bet.betID) AS Betcount
			, SUM(CASE WHEN bet.matchType = 'Lay' THEN (bet.matchStake/sumbet.ExVirtualRate) ELSE 0 END) AS Lay
			, SUM(CASE WHEN bet.matchType = 'Back' THEN (bet.matchStake/sumbet.ExVirtualRate) ELSE 0 END) AS Back
		FROM bodb_3rdProduct.dbo.Bettrans_Exchange bet WITH (NOLOCK)
			INNER JOIN #sumBet sumbet ON bet.userId = sumbet.UserID AND bet.eventID = sumbet.EventID AND bet.marketID = sumbet.MarketID
		WHERE bet.betstatus = 'Settled'				
		GROUP BY sumbet.SettledDate, bet.userId, bet.eventID, bet.marketID
		
		INSERT INTO #tmpResult( CustID,
								Winlostdate,
								CurrencyID,
								TurnOver,
								NetTurnOver,
								TotalTrans,
								Winlost,
								LicWinlost,
								LicNetWL,
								CustComm,
								AmountDueTo,
								AgentComm
			)
		SELECT	sumbet.CustID 
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
		LEFT JOIN #detailBet bet on sumbet.userId	= bet.userId 
								AND sumbet.eventID	= bet.eventID 
								AND sumbet.marketID	= bet.marketID
								AND sumbet.SettledDate = bet.SettledDate
		LEFT JOIN @ChargeRates rate ON sumbet.SettledDate BETWEEN rate.FromDate AND rate.ToDate
		GROUP BY sumbet.SettledDate, sumbet.CurrencyID, sumbet.CustID

		DROP TABLE #sumBet
		DROP TABLE #detailBet
	END
	-- #EndRegion: Get data has not been moved to sum table yet(yesterday and today)

	-- #Region: Handle Data	from Sum Table
	IF @FDate <= @TDate
	BEGIN
		INSERT INTO #tmpResult( CustID,
								Winlostdate,
								CurrencyID,
								TurnOver,
								NetTurnOver,
								TotalTrans,
								Winlost,
								LicWinlost,
								LicNetWL,
								CustComm,
								AmountDueTo,
								AgentComm
							)
		SELECT c.Recommend, b.Winlostdate, b.Currency
			, SUM(b.Turnover), SUM(ValidBetAmount), SUM(b.BetCount)
			, SUM(b.Winlost), -SUM(b.Winlost), SUM(b.WinLostA), SUM(CommissionP)
			, -SUM(( b.Winlost + b.CommissionP) + ( b.WinLostA + CommissionA)) -- (LicWL - NetLicWL) + (LicComm - NetLicComm)
			, SUM(CommissionA)
		FROM bodb_LicenseeReport.dbo.rptDepWinlost_ThirdParty b WITH (NOLOCK)
			INNER JOIN @tmpCust c ON b.Custid = c.CustID AND b.Currency = c.Currency
		WHERE b.Winlostdate BETWEEN @FDate AND @TDate
			AND b.ProductId = @ProductID
			AND NOT EXISTS (SELECT 1 FROM @RawWinLostDate r WHERE b.Winlostdate = r.WinLostDate)
		GROUP BY b.Winlostdate, b.Currency, c.Recommend
	END
	-- #EndRegion: Handle Data	from Sum Table

	-- #Region: Handle Exchange Rate
	;WITH Currency_CTE (CurrencyID) AS (
											SELECT DISTINCT CurrencyID 
											FROM #tmpResult
										)
	INSERT INTO #Exchange( ExchangeID ,
							ExchageDate ,
							GBP ,
							USD ,
							EUR
						)
	SELECT ExchangeId, ExchangeDate, GBP, USD, EUR
	FROM dbo.Lrf_f_GetExchangeDaily(@FDate, @ToDate) exc
	INNER JOIN Currency_CTE cur ON exc.ExchangeId = cur.CurrencyID

	-- #Region: Return data
	SELECT r.CustID
		, ci.username		
		, r.CurrencyID
		, SUM(r.TurnOver)			AS TurnOver
		, SUM(r.NETTurnOver)		AS NetTurnOver
		, SUM(r.TotalTrans)			AS TotalTrans
		, SUM(r.Winlost)			AS Winlost
		, SUM(r.CustComm)			AS CustComm
		, SUM(r.LicWinlost)			AS LicenseeWinlost
		, SUM(r.AmountDueTo)		AS AmountDueTo
		, SUM(r.AgentComm)			AS AgentComm
		, SUM(r.LicNetWL)			AS LicNetWL
		---USD
		, SUM(r.TurnOver * e.USD)			AS TurnOverUSD
		, SUM(r.NETTurnOver * e.USD)		AS NetTurnOverUSD
		, SUM(r.TotalTrans * e.USD)			AS TotalTransUSD
		, SUM(r.Winlost * e.USD)			AS WinlostUSD
		, SUM(r.CustComm * e.USD)			AS CustCommUSD
		, SUM(r.LicWinlost * e.USD)			AS LicenseeWinlostUSD
		, SUM(r.AmountDueTo * e.USD)		AS AmountDueToUSD
		, SUM(r.AgentComm * e.USD)			AS AgentCommUSD
		, SUM(r.LicNetWL * e.USD)			AS LicNetWLUSD
		---EUR
		, SUM(r.TurnOver * e.EUR)			AS TurnOverEUR
		, SUM(r.NETTurnOver * e.EUR)		AS NetTurnOverEUR
		, SUM(r.TotalTrans * e.EUR)			AS TotalTransEUR
		, SUM(r.Winlost * e.EUR)			AS WinlostEUR
		, SUM(r.CustComm * e.EUR)			AS CustCommEUR
		, SUM(r.LicWinlost * e.EUR)			AS LicenseeWinlostEUR
		, SUM(r.AmountDueTo * e.EUR)		AS AmountDueToEUR
		, SUM(r.AgentComm * e.EUR)			AS AgentCommEUR
		, SUM(r.LicNetWL * e.EUR)			AS LicNetWLEUR
		---GBP
		, SUM(r.TurnOver * e.GBP)			AS TurnOverGBP
		, SUM(r.NETTurnOver * e.GBP)		AS NetTurnOverGBP
		, SUM(r.TotalTrans * e.GBP)			AS TotalTransGBP
		, SUM(r.Winlost * e.GBP)			AS WinlostGBP
		, SUM(r.CustComm * e.GBP)			AS CustCommGBP
		, SUM(r.LicWinlost * e.GBP)			AS LicenseeWinlostGBP
		, SUM(r.AmountDueTo * e.GBP)		AS AmountDueToGBP
		, SUM(r.AgentComm * e.GBP)			AS AgentCommGBP
		, SUM(r.LicNetWL * e.GBP)			AS LicNetWLGBP
	FROM #tmpResult r
		INNER JOIN #Exchange e ON r.Winlostdate = e.ExchageDate AND r.CurrencyID = e.ExchangeId
		INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = r.CustID
	GROUP BY --r.Winlostdate
		 r.CustID, ci.username
		, r.CurrencyID
		, e.Code
	ORDER BY ci.username
	-- #EndRegion: Return data

	DROP TABLE #tmpResult
	DROP TABLE #Exchange
END
GO