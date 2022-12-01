/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_ExchangeWinloss_ByResettledDate]
	@LicenseeId				INT,
	@AgentList				VARCHAR(MAX),
	@UserName				VARCHAR(50)	= '',
	@FromDate				DATE,
	@ToDate					DATE,
	@ReportType				TINYINT		= 1,
	@BaseCurrency			VARCHAR(12),
	@DefaultBaseCurrency	VARCHAR(12)
AS

/*
	Created: 20221111@Evan 
	Description: LAP - Exchange WL report by Resettled Date
	DB: DBEXT.bodb02

	Revisions:
		- 20221111@Evan: Create new report Exchange Winloss by Resettled Date [RedmineID: #179079]		 

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

	CREATE TABLE #TmpResult (
		WinLostDate		DATE,
		CurrencyId		INT,
		TotalTrans		INT,
		Turnover		MONEY,
		NetTurnover		MONEY,
		WinLost			MONEY,
		LicWinLost		MONEY,
		LicNetWL		MONEY,
		CustComm		MONEY,
		AmountDueTo		MONEY,
		AgentComm		MONEY)

	DECLARE @ProductId			INT
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
	DECLARE @TmpCust AS TABLE (CustId INT PRIMARY KEY)

	IF @Username = ''
	BEGIN
		INSERT INTO @TmpCust (CustId)
		SELECT c.custid
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
	END
	ELSE
	BEGIN
		INSERT INTO @TmpCust (CustId)
		SELECT c.custid
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
		WHERE c.username = @Username

		IF NOT EXISTS (SELECT 1 FROM @TmpCust)
		BEGIN
			INSERT INTO @TmpCust (CustId)
			SELECT c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN @TempAg AS ag ON ag.CustId = c.recommend
			WHERE c.username2 LIKE + '%$' + @Username
		END
	END
	-- #EndRegion: Get list custIDs

	-- #Region: Handle Data from Sum Table
	
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
		
	CREATE TABLE #sumBet (
		SettledDate		DATE,
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
		INNER JOIN @tmpCust AS cust ON cust.Custid = sumbet.CustID
	WHERE ISNULL(sumbet.resettledDate,sumbet.settledDate) >= @FDate 
		AND ISNULL(sumbet.resettledDate,sumbet.settledDate) < DATEADD(dd,1,@TDate) 
	
	GROUP BY
		ISNULL(sumbet.resettledDate,sumbet.settledDate),
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
		Back )
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
		
	INSERT INTO #tmpResult(
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
		sumbet.SettledDate WinLostDate
		, sumbet.CurrencyID CurrencyId
		, SUM(sumbet.Turnover) Turnover
		, SUM(ABS(ISNULL(bet.Lay, 0) - ISNULL(bet.Back, 0))) NetTurnover
		, SUM(ISNULL(bet.BetCount, 0)) TotalTrans
		, SUM(sumbet.Winlost) WinLost
		, - SUM(sumbet.Winlost) LicWinLost
		, - SUM(sumbet.Winlost * (1 - ISNULL(rate.Rate, 1))) LicNetWL
		, SUM(sumbet.CustComm) CustComm
		, - SUM((sumbet.Winlost + sumbet.CustComm) + (-sumbet.Winlost*(1-ISNULL(rate.Rate,1)) + sumbet.AgentComm)) AmountDueTo -- (LicWL - NetLicWL) + (LicComm - NetLicComm) 
		, SUM(sumbet.AgentComm) AgentComm
	FROM #sumBet sumbet
		LEFT JOIN #detailBet bet ON sumbet.userId	= bet.userId 
								AND sumbet.eventID	= bet.eventID 
								AND sumbet.marketID	= bet.marketID
								AND sumbet.SettledDate = bet.SettledDate
		LEFT JOIN @ChargeRates rate ON sumbet.SettledDate BETWEEN rate.FromDate AND rate.ToDate
	GROUP BY
		sumbet.SettledDate,
		sumbet.CurrencyID
		
	DROP TABLE #sumBet
	DROP TABLE #detailBet
	
	-- #EndRegion: Handle Data from Sum Table
	
	-- #Region: Handle Exchange Rate
	CREATE TABLE #Exchange (ExchangeId INT, FromDate DATE, ToDate DATE, USD FLOAT, EUR FLOAT, GBP FLOAT, Rate FLOAT, DefaultRate FLOAT)

	;WITH Currency_CTE (CurrencyID) AS ( SELECT DISTINCT CurrencyID FROM #tmpResult )
	INSERT INTO #Exchange (
		ExchangeId,
		FromDate,
		ToDate,
		USD,
		EUR,
		GBP,
		Rate,
		DefaultRate )
	SELECT ExchangeID, FromDate, ToDate, USD, EUR, GBP, Rate, DefaultRate
	FROM dbo.Lrf_f_GetExchangeRate(@FDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) exc
	INNER JOIN Currency_CTE cur ON exc.ExchangeID = cur.CurrencyID
	
	-- #Region: Return data
	SELECT
		CASE 
			WHEN @ReportType = 1 THEN r.winlostdate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
			ELSE '0'
		END AS Winlostdate
		, r.CurrencyID
		, SUM(r.TotalTrans)	AS TotalTrans

		, SUM(r.TurnOver * e.Rate)		AS TurnOver
		, SUM(r.NETTurnOver * e.Rate)	AS NetTurnOver
		, SUM(r.Winlost * e.Rate)		AS Winlost
		, SUM(r.CustComm * e.Rate)		AS CustComm
		, SUM(r.LicWinlost * e.Rate)	AS LicenseeWinlost
		, SUM(r.AmountDueTo * e.Rate)	AS AmountDueTo
		, SUM(r.AgentComm * e.Rate)		AS AgentComm
		, SUM(r.LicNetWL * e.Rate)		AS LicNetWL
		---USD
		, SUM(r.TurnOver * e.USD)		AS TurnOverUSD
		, SUM(r.NETTurnOver * e.USD)	AS NetTurnOverUSD
		, SUM(r.Winlost * e.USD)		AS WinlostUSD
		, SUM(r.CustComm * e.USD)		AS CustCommUSD
		, SUM(r.LicWinlost * e.USD)		AS LicenseeWinlostUSD
		, SUM(r.AmountDueTo * e.USD)	AS AmountDueToUSD
		, SUM(r.AgentComm * e.USD)		AS AgentCommUSD
		, SUM(r.LicNetWL * e.USD)		AS LicNetWLUSD
		---EUR
		, SUM(r.TurnOver * e.EUR)		AS TurnOverEUR
		, SUM(r.NETTurnOver * e.EUR)	AS NetTurnOverEUR
		, SUM(r.Winlost * e.EUR)		AS WinlostEUR
		, SUM(r.CustComm * e.EUR)		AS CustCommEUR
		, SUM(r.LicWinlost * e.EUR)		AS LicenseeWinlostEUR
		, SUM(r.AmountDueTo * e.EUR)	AS AmountDueToEUR
		, SUM(r.AgentComm * e.EUR)		AS AgentCommEUR
		, SUM(r.LicNetWL * e.EUR)		AS LicNetWLEUR
		---GBP
		, SUM(r.TurnOver * e.GBP)		AS TurnOverGBP
		, SUM(r.NETTurnOver * e.GBP)	AS NetTurnOverGBP
		, SUM(r.Winlost * e.GBP)		AS WinlostGBP
		, SUM(r.CustComm * e.GBP)		AS CustCommGBP
		, SUM(r.LicWinlost * e.GBP)		AS LicenseeWinlostGBP
		, SUM(r.AmountDueTo * e.GBP)	AS AmountDueToGBP
		, SUM(r.AgentComm * e.GBP)		AS AgentCommGBP
		, SUM(r.LicNetWL * e.GBP)		AS LicNetWLGBP
		---Default Base Currency
		, SUM(r.TurnOver * e.DefaultRate)		AS TurnOverBase
		, SUM(r.NETTurnOver * e.DefaultRate)	AS NetTurnOverBase
		, SUM(r.Winlost * e.DefaultRate)		AS WinlostBase
		, SUM(r.CustComm * e.DefaultRate)		AS CustCommBase
		, SUM(r.LicWinlost * e.DefaultRate)		AS LicenseeWinlostBase
		, SUM(r.AmountDueTo * e.DefaultRate)	AS AmountDueToBase
		, SUM(r.AgentComm * e.DefaultRate)		AS AgentCommBase
		, SUM(r.LicNetWL * e.DefaultRate)		AS LicNetWLBase
	FROM #tmpResult AS r
		INNER JOIN #Exchange AS e ON r.CurrencyId = e.ExchangeId AND r.Winlostdate BETWEEN e.FromDate AND e.ToDate
	GROUP BY --r.Winlostdate
		CASE
			WHEN @ReportType = 1 THEN r.WinLostDate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.WinLostDate), r.WinLostDate)
			ELSE '0'
		END
		, r.CurrencyID
	ORDER BY
		CASE
			WHEN @ReportType = 1 THEN r.WinLostDate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.WinLostDate), r.WinLostDate)
			ELSE '0'
		END
	-- #EndRegion: Return data

	DROP TABLE #TmpResult
	DROP TABLE #Exchange
END
GO
