/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].Lrf_Rpt_ExchangeWinloss_ByResettledDate_Mem
	@LicenseeId				INT,
	@AgentList				VARCHAR(MAX),
	@CustId					INT = 0,
	@UserName				VARCHAR(50)	= '',
	@FromDate				DATE,
	@ToDate					DATE,
	@BaseCurrency			VARCHAR(12),
	@DefaultBaseCurrency	VARCHAR(12)
AS

/*
	Created: 20221111@Evan 
	Description: LAP - Exchange WL report by Resettled Date - Member level
	DB: DBEXT.bodb02

	Revisions:
		- 20221111@Evan: Create new report Exchange Winloss by Resettled Date [RedmineID: #179079]		 
		- 20230516@Evan: Change the "Amount Due To" formula & Add output column "Licensee Total"  [Redmine: #186609]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @tempAg ( custID, currency )
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
		WinLostDate DATE,
		CurrencyId	INT,
		TotalTrans	INT,
		Turnover	MONEY,
		NetTurnover MONEY,
		WinLost		MONEY,
		LicWinLost	MONEY,
		LicNetWL	MONEY,
		CustComm	MONEY,
		AmountDueTo MONEY,
		AgentComm	MONEY,
		LicTotal	MONEY
	)

	DECLARE @ProductID			INT
		,	@FDate				DATE
		,	@TDate				DATE
		,	@ProductPrefix		VARCHAR(2)
	
	SELECT @FDate = @FromDate,
		   @TDate = @ToDate
 
	SET @ProductPrefix = 'BX'
	
	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = @ProductPrefix

	-- #Region: Get list custIDs
	DECLARE @TmpCust AS TABLE (CustId INT)

	IF @Username = ''
	BEGIN
		INSERT INTO @TmpCust (CustId)
		SELECT c.custid
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
		WHERE @CustId = 0 OR ag.CustId = @CustId
	END
	ELSE
	BEGIN
		INSERT INTO @TmpCust (CustId)
		SELECT c.custid
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
		WHERE c.username = @Username
			AND (@CustId = 0 OR ag.CustId = @CustId)

		IF NOT EXISTS (SELECT 1 FROM @TmpCust)
		BEGIN
			INSERT INTO @TmpCust (CustId)
			SELECT c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
			WHERE c.username2 LIKE + '%$' + @Username
				AND (@CustId = 0 OR ag.CustId = @CustId)
		END
	END
	-- #EndRegion: Get list custIDs

	-- #Region: Handle Data	from Sum Table

	DECLARE @PartyID	VARCHAR(10)
	DECLARE @ChargeRates AS TABLE(Rate MONEY, FromDate DATE, ToDate DATE)
		
	SELECT @PartyID = CAST(PartyID AS VARCHAR)
	FROM bodb_licensee.dbo.OAS_Party WITH(NOLOCK)
	WHERE OldRefID = @LicenseeId AND PartyType = 1
		
	INSERT INTO @ChargeRates(Rate, FromDate, ToDate)
	SELECT DI_Rate, Fromdate, Todate
	FROM bodb_licensee.dbo.LA_f_ChargeInfo(@PartyID, @FDate, @TDate, @ProductPrefix, 'OA', 1)
	WHERE ChargeType = 1 AND DI_Rate > 0
		
	IF NOT EXISTS (SELECT 1 FROM @ChargeRates)
	BEGIN
		INSERT INTO @ChargeRates(Rate, FromDate, ToDate)
		SELECT DI_Rate, Fromdate, Todate
		FROM bodb_licensee.dbo.LA_f_GetChargeInfoWithTrialTime(@PartyID, @FDate, @TDate, @ProductPrefix, 'OA', 1)
		WHERE ChargeType = 1 AND DI_Rate > 0
	END
	
	-- CutoffDate apply new term, Change AmountDueTo formula 
	DECLARE @CutoffDate SMALLDATETIME
	SET	@CutoffDate = '2023-05-01'
	
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
		CONVERT(DATE, ISNULL(sumbet.resettledDate,sumbet.settledDate)),
		sumbet.CustID,
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
		INNER JOIN @tmpCust cust ON cust.Custid = sumbet.CustID
	WHERE ISNULL(sumbet.resettledDate,sumbet.settledDate) >= @FDate 
		AND ISNULL(sumbet.resettledDate,sumbet.settledDate) < DATEADD(dd,1,@TDate) 
	GROUP BY
		ISNULL(sumbet.resettledDate,sumbet.settledDate),
		sumbet.CustID,
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
		CustID,
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
		AgentComm,
		LicTotal )
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
		, CASE WHEN sumbet.SettledDate >= @CutoffDate 
					THEN - SUM((sumbet.Winlost + sumbet.CustComm) * ( ISNULL(rate.Rate, 0)))  -- - (Customer Total * (1-Licensee rate))
					ELSE - SUM((sumbet.Winlost + sumbet.CustComm) + (-sumbet.Winlost*(1-ISNULL(rate.Rate,1)) + sumbet.AgentComm)) -- (LicWL - NetLicWL) + (LicComm - NetLicComm)
				END AS AmountDueTo 
		, SUM(sumbet.AgentComm)
		, SUM(-(sumbet.Winlost + sumbet.CustComm) * (1 - ISNULL(rate.Rate, 1)))  LicTotal -- Customer Total * (1- House's rate) 
	FROM #sumBet sumbet
		LEFT JOIN #detailBet bet on sumbet.userId	= bet.userId 
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
	
	-- #EndRegion: Handle Data	from Sum Table

	-- #Region: Handle Exchange Rate
	CREATE TABLE #Exchange (
		ExchangeID	INT,
		FromDate	DATE,
		ToDate		DATE,
		GBP			FLOAT,
		USD			FLOAT,
		EUR			FLOAT,
		Rate		FLOAT,
		DefaultRate	FLOAT
	)

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
	SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
		, c.username
		, c.custid
		, r.CurrencyID
		, SUM(r.TotalTrans)			AS TotalTrans
		
		, SUM(r.TurnOver * e.Rate)		AS TurnOver
		, SUM(r.NETTurnOver * e.Rate)	AS NetTurnOver
		, SUM(r.Winlost * e.Rate)		AS Winlost
		, SUM(r.CustComm * e.Rate)		AS CustComm
		, SUM(r.LicWinlost * e.Rate)	AS LicenseeWinlost
		, SUM(r.AmountDueTo * e.Rate)	AS AmountDueTo
		, SUM(r.LicTotal * e.Rate)		AS LicTotal
		---USD
		, SUM(r.TurnOver * e.USD)		AS TurnOverUSD
		, SUM(r.NETTurnOver * e.USD)	AS NetTurnOverUSD
		, SUM(r.Winlost * e.USD)		AS WinlostUSD
		, SUM(r.CustComm * e.USD)		AS CustCommUSD
		, SUM(r.LicWinlost * e.USD)		AS LicenseeWinlostUSD
		, SUM(r.AmountDueTo * e.USD)	AS AmountDueToUSD
		, SUM(r.LicTotal * e.USD)		AS LicTotalUSD
		---EUR
		, SUM(r.TurnOver * e.EUR)		AS TurnOverEUR
		, SUM(r.NETTurnOver * e.EUR)	AS NetTurnOverEUR
		, SUM(r.Winlost * e.EUR)		AS WinlostEUR
		, SUM(r.CustComm * e.EUR)		AS CustCommEUR
		, SUM(r.LicWinlost * e.EUR)		AS LicenseeWinlostEUR
		, SUM(r.AmountDueTo * e.EUR)	AS AmountDueToEUR
		, SUM(r.LicTotal * e.EUR)		AS LicTotalEUR
		---GBP
		, SUM(r.TurnOver * e.GBP)		AS TurnOverGBP
		, SUM(r.NETTurnOver * e.GBP)	AS NetTurnOverGBP
		, SUM(r.Winlost * e.GBP)		AS WinlostGBP
		, SUM(r.CustComm * e.GBP)		AS CustCommGBP
		, SUM(r.LicWinlost * e.GBP)		AS LicenseeWinlostGBP
		, SUM(r.AmountDueTo * e.GBP)	AS AmountDueToGBP
		, SUM(r.LicTotal * e.GBP)		AS LicTotalGBP
		---Default Base currency
		, SUM(r.TurnOver * e.DefaultRate)		AS TurnOverBase
		, SUM(r.NETTurnOver * e.DefaultRate)	AS NetTurnOverBase
		, SUM(r.Winlost * e.DefaultRate)		AS WinlostBase
		, SUM(r.CustComm * e.DefaultRate)		AS CustCommBase
		, SUM(r.LicWinlost * e.DefaultRate)		AS LicenseeWinlostBase
		, SUM(r.AmountDueTo * e.DefaultRate)	AS AmountDueToBase
		, SUM(r.LicTotal * e.DefaultRate)		AS LicTotalBase
	FROM #tmpResult r
		INNER JOIN #Exchange e ON r.CurrencyID = e.ExchangeId AND r.Winlostdate BETWEEN e.FromDate AND e.ToDate
		INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = r.CustID
	GROUP BY SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2))
		, c.username
		, c.CustID
		, r.CurrencyID
	ORDER BY c.username
	-- #EndRegion: Return data

	DROP TABLE #Exchange
	DROP TABLE #tmpResult
END
GO