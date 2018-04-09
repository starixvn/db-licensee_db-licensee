/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExchangeWinloss]
	  @FromDate		DATE
	, @ToDate		DATE
	, @ReportType	TINYINT = 1
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

	Param's Explanation:  		

	exec Lrf_Rpt_ExchangeWinloss @fromdate='2017-10-01',@todate='2017-10-24',@ReportType = 1,@LicenseeId = 1,@AgentList=N'<ROOT><Agent AgentId="791088" Currency="3"/><Agent AgentId="860379" Currency="6"/><Agent AgentId="2428981" Currency="6"/><Agent AgentId="2812696" Currency="6"/><Agent AgentId="3575140" Currency="6"/><Agent AgentId="4362999" Currency="6"/></ROOT>'
 
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (Winlostdate DATE, CurrencyID INT, TotalTrans INT, TurnOver MONEY
							, NETTurnOver MONEY, Winlost MONEY, LicWinlost MONEY, LicNetWL MONEY, CustComm MONEY, AmountDueTo MONEY, AgentComm MONEY)
	CREATE TABLE #Exchange (ExchangeID INT, ExchageDate DATE, Code VARCHAR(5), GBP FLOAT, USD FLOAT, EUR FLOAT)
	
	DECLARE @VNDCurrencyNAME	VARCHAR(20)
		,	@ProductID			INT
		,	@FDate				DATE
		,	@TDate				DATE
		,	@ProductPrefix		VARCHAR(2)
		
	DECLARE @RawWinLostDate AS TABLE (WinLostDate DATE)

	SELECT @FDate = @FromDate,
		   @TDate = @ToDate
	
	SET @ProductPrefix = 'BX'
	
	INSERT INTO @RawWinLostDate
	SELECT DISTINCT WinlostDate
	FROM bodb_3rdProduct.dbo.Product3rd_SummarizedDateHistory
	WHERE WinlostDate >= @FDate AND WinlostDate <= @ToDate AND SumToThirdPartyDate IS NULL

	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = @ProductPrefix	

	-- #Region: Get list custIDs
	DECLARE @tmpCust	AS TABLE (CustID INT, Currency INT)	
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

	INSERT INTO @tmpCust ( CustID, Currency )
	SELECT ci.custid, ci.currency
	FROM dbo.custInfo ci WITH (NOLOCK)
	INNER JOIN @tempAg ag ON ci.recommend = ag.custID AND ci.currency = ag.currency
	-- #EndRegion: Get list custIDs

	-- #Region: Get data has not been moved to sum table yet(yesterday and today)
	IF EXISTS (SELECT TOP 1 1 FROM @RawWinLostDate)
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
		
		IF NOT EXISTS (SELECT TOP 1 1 FROM @ChargeRates)
		BEGIN
			INSERT INTO @ChargeRates(Rate, FromDate, ToDate)
			SELECT DI_Rate, Fromdate, Todate
			FROM bodb_licensee.dbo.LA_f_GetChargeInfoWithTrialTime(@PartyID, @RawFDate, @RawTDate, @ProductPrefix, 'OA', 1)
			WHERE ChargeType = 1 AND DI_Rate > 0
		END

		CREATE TABLE #sumBet (
				SettledDate		DATETIME,
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
							UserID,
							EventID,
							MarketID,
							CurrencyID ,
							TurnOver ,
							Winlost ,
							CustComm,
							AgentComm,
							ExVirtualRate
			)
		SELECT	sumbet.settledDate,
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
		INNER JOIN @RawWinLostDate wldate ON CONVERT(DATE, sumbet.settledDate) = wldate.WinLostDate
		INNER JOIN @tmpCust cust ON cust.Custid = sumbet.CustID AND cust.Currency = sumbet.Currency
		GROUP BY sumbet.settledDate, sumbet.userId, sumbet.eventID, sumbet.marketID, sumbet.currency, sumbet.ExVirtualRate
		
		CREATE TABLE #detailBet (
				SettledDate		DATETIME,
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
		
		INSERT INTO #tmpResult( Winlostdate ,
								CurrencyID ,
								TurnOver ,
								NetTurnOver,
								TotalTrans ,
								Winlost ,
								LicWinlost,
								LicNetWL,
								CustComm,
								AmountDueTo,
								AgentComm
			)
		SELECT	CONVERT(DATE, sumbet.SettledDate)
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
		LEFT JOIN @ChargeRates rate ON CONVERT(DATE, sumbet.SettledDate) BETWEEN rate.FromDate AND rate.ToDate
		GROUP BY CONVERT(DATE, sumbet.SettledDate), sumbet.CurrencyID
	
		DROP TABLE #sumBet
		DROP TABLE #detailBet
	END
	-- #EndRegion: Get data has not been moved to sum table yet(yesterday and today)

	-- #Region: Handle Data	from Sum Table
	IF @FDate <= @TDate
	BEGIN
		INSERT INTO #tmpResult( Winlostdate,
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
		SELECT b.Winlostdate, b.Currency
			, SUM(b.Turnover), SUM(ValidBetAmount), SUM(b.BetCount)
			, SUM(b.Winlost), -SUM(b.Winlost), SUM(b.WinLostA), SUM(CommissionP)
			, -SUM(( b.Winlost + b.CommissionP) + ( b.WinLostA + CommissionA)) -- (LicWL - NetLicWL) + (LicComm - NetLicComm)
			, SUM(CommissionA)
		FROM bodb_LicenseeReport.dbo.rptDepWinlost_ThirdParty b WITH (NOLOCK)
			INNER JOIN @tmpCust c ON b.Custid = c.CustID AND b.Currency = c.Currency
			LEFT JOIN @RawWinLostDate rawdate ON b.Winlostdate = rawdate.WinLostDate
		WHERE b.Winlostdate BETWEEN @FDate AND @TDate AND b.ProductId = @ProductID AND rawdate.WinLostDate IS NULL
		GROUP BY b.Winlostdate, b.Currency
	END
	-- #EndRegion: Handle Data	from Sum Table

	-- #Region: Handle Exchange Rate
	;WITH Currency_CTE (CurrencyID)
	AS (
		SELECT DISTINCT CurrencyID FROM #tmpResult
	)
	INSERT INTO #Exchange( ExchangeID ,
							ExchageDate ,
							Code ,
							GBP ,
							USD ,
							EUR
						)
	SELECT ExchangeId, ExchangeDate, Code, GBP, USD, EUR
	FROM dbo.Lrf_f_GetExchangeDaily(@FDate, @ToDate) exc
	INNER JOIN Currency_CTE cur ON exc.ExchangeId = cur.CurrencyID
	
	-- update VND Currency Name	
	SELECT @VNDCurrencyName = currency 
	FROM  dbo.Exchange WITH (NOLOCK) 
	WHERE ExchangeId = 51
	
	UPDATE #Exchange
	SET Code = @VNDCurrencyName
	WHERE ExchangeID = 51
	
	-- update Myanmar Currency Name
	UPDATE #Exchange
	SET Code = 'MKK'
	WHERE ExchangeID = 70
	-- #EndRegion: Handle Exchange Rate

	-- #Region: Return data
	SELECT
		CASE 
			WHEN @ReportType = 1
				THEN r.winlostdate
			WHEN @ReportType = 2					
				THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
			ELSE '0'
		END AS Winlostdate
		, r.CurrencyID
		, e.Code					AS CurrencyName
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
	GROUP BY --r.Winlostdate
		 CASE 
			WHEN @ReportType = 1 THEN r.winlostdate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
			ELSE '0'
		END
		, r.CurrencyID
		, e.Code
	ORDER BY 
		CASE 
			WHEN @ReportType = 1 THEN r.winlostdate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
			ELSE '0'
			END
	-- #EndRegion: Return data
	
	DROP TABLE #tmpResult
	DROP TABLE #Exchange
END
GO