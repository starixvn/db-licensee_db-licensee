/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExchangeWinloss_Ag]
	  @FromDate		DATE
	, @ToDate		DATE	
	, @AgentList	VARCHAR(MAX)
AS

/*
	Created: 20171215@Harper
	Description: LRF - Implement Exchange winloss for exchange product
	DB: DBEXT.bodb02 
	Revisions: 
		- 20171215@Harper: Create new report Exchange Winloss [RedmineID: #86640]
		- 20180323@Amanda: Support today's data [Redmine: #92495]

	Param's Explanation:

	exec Lrf_Rpt_ExchangeWinloss_Ag @fromdate='2017-04-24 00:00:00',@todate='2017-04-24 00:00:00',@AgentList=N'<ROOT><Agent AgentId="791088" Currency="3"/><Agent AgentId="860379" Currency="6"/><Agent AgentId="2428981" Currency="6"/><Agent AgentId="2812696" Currency="6"/><Agent AgentId="3575140" Currency="6"/><Agent AgentId="4362999" Currency="6"/></ROOT>'
 
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
		Code		VARCHAR(5), 
		GBP			FLOAT, 
		USD			FLOAT, 
		EUR			FLOAT)
	
	DECLARE @VNDCurrencyNAME VARCHAR(20)
		, @ProductID		INT
		, @FDate			DATE
		, @TDate			DATE
		, @PartyIds			VARCHAR(4000)
		, @Today			DATE
		, @ProductPrefix	VARCHAR(2)
	
	SELECT @FDate = @FromDate,
		   @TDate = @ToDate
		   
	SET @Today = GETDATE()
	SET @ProductPrefix = 'BX'

	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = 'BX'	

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

	-- #Region: Get today's data
	IF @TDate = @Today
	BEGIN
		SET @TDate = DATEADD(DAY, -1, @TDate)
		
		DECLARE @Site			VARCHAR(10)
			,	@LicenseeId		INT
			,	@PartyList		VARCHAR(4000)
			,	@ChargeRate		MONEY
			,	@HasChargeRate	BIT = 0
		
		SELECT TOP 1 @Site = [Site]
		FROM dbo.Customer cust WITH (NOLOCK)
		INNER JOIN @tempAg agen ON cust.custid = agen.custID AND cust.roleid = 2
		WHERE cust.[site] IS NOT NULL
		
		SELECT TOP 1 @LicenseeId = [site].SiteID
		FROM dbo.[Site] ibcsite WITH (NOLOCK)
		INNER JOIN bodb_licensee.dbo.view_site_list [site] WITH (NOLOCK) ON ibcsite.siteid = [Site].IbcSiteID
		WHERE ibcsite.[site] = @Site
		
		SET @LicenseeId = ISNULL(@LicenseeId, -1)
		
		SELECT @PartyList = COALESCE(@PartyList + ',' + CAST(FromParty AS VARCHAR), CAST(FromParty AS VARCHAR))
		FROM (
			SELECT FromParty
			FROM bodb_licensee.dbo.OAS_ChargeInfo WITH(NOLOCK)
			WHERE ProductId = @ProductId
			GROUP BY FromParty
		)tmp
		
		SELECT TOP 1 @ChargeRate = DI_Rate, @HasChargeRate = 1
		FROM bodb_licensee.dbo.LA_f_ChargeInfo(@PartyList, @ToDay, @ToDay, @ProductPrefix, 'OA', 1)
		WHERE LicenseeId = @LicenseeId AND ChargeType = 1 AND DI_Rate > 0 AND @ToDay >= FromDate AND @ToDay <= ToDate
		
		IF @ChargeRate IS NULL
		BEGIN
			SELECT TOP 1 @ChargeRate = DI_Rate, @HasChargeRate = 1
			FROM bodb_licensee.dbo.LA_f_GetChargeInfoWithTrialTime(@PartyList, @ToDay, @ToDay, @ProductPrefix, 'OA', 1)
			WHERE LicenseeId = @LicenseeId AND ChargeType = 1 AND DI_Rate > 0 AND  @ToDay >= FromDate AND @ToDay <= ToDate
		END
		
		IF @HasChargeRate = 1
		BEGIN
			SET @ChargeRate = ISNULL(@ChargeRate,0)
		END
		ELSE
		BEGIN
			SET @ChargeRate = 1
		END
		
		CREATE TABLE #sumBet (
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
		
		INSERT INTO #sumBet(CustID,
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
		SELECT	cust.Recommend,
				sumbet.userId,
				sumbet.eventID,
				sumbet.marketID,
				sumbet.currency,
				sumbet.stakeTotal/sumbet.ExVirtualRate,		-- TurnOver
				sumbet.marketTotal/sumbet.ExVirtualRate,	-- winloss
				sumbet.commission/sumbet.ExVirtualRate,		-- CustComm 
				sumbet.agentCommission/sumbet.ExVirtualRate,-- AgentComm
				sumbet.ExVirtualRate
		FROM bodb_3rdProduct.dbo.Sum_winloss_Exchange sumbet WITH (NOLOCK)
		INNER JOIN @tmpCust cust ON cust.Custid = sumbet.CustID AND cust.Currency = sumbet.Currency
		WHERE CONVERT(DATE, sumbet.settledDate) = @ToDay
		
		CREATE TABLE #detailBet (
				UserID			VARCHAR(20),
				EventID			INT,
				MarketID		VARCHAR(50),
				BetCount		INT,
				Lay				MONEY,
				Back			MONEY,
		)
		
		INSERT INTO #detailBet(UserID, EventID, MarketID, BetCount, Lay, Back)
		SELECT bet.userId, bet.eventID, bet.marketID
			, COUNT(bet.betID) AS Betcount
			, SUM(CASE WHEN bet.matchType = 'Lay' THEN (bet.matchStake/sumbet.ExVirtualRate) ELSE 0 END) AS Lay
			, SUM(CASE WHEN bet.matchType = 'Back' THEN (bet.matchStake/sumbet.ExVirtualRate) ELSE 0 END) AS Back
		FROM bodb_3rdProduct.dbo.Bettrans_Exchange bet WITH (NOLOCK)
		INNER JOIN #sumBet sumbet ON bet.userId = sumbet.UserID AND bet.eventID = sumbet.EventID AND bet.marketID = sumbet.MarketID
		WHERE bet.betstatus = 'Settled'				
		GROUP BY bet.userId, bet.eventID, bet.marketID
		
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
				, @Today
				, sumbet.CurrencyID
				, SUM(sumbet.Turnover)
				, SUM(ABS(ISNULL(bet.Lay, 0) - ISNULL(bet.Back, 0)))
				, SUM(ISNULL(bet.BetCount, 0))
				, SUM(sumbet.Winlost)
				, - SUM(sumbet.Winlost)
				, - SUM(sumbet.Winlost) * (1 - @ChargeRate)
				, SUM(sumbet.CustComm)
				, - SUM((sumbet.Winlost + sumbet.CustComm) + (-sumbet.Winlost*(1-@ChargeRate) + sumbet.AgentComm)) -- (LicWL - NetLicWL) + (LicComm - NetLicComm)
				, SUM(sumbet.AgentComm)
		FROM #sumBet sumbet
		LEFT JOIN #detailBet bet on sumbet.userId	= bet.userId 
								AND sumbet.eventID	= bet.eventID 
								AND sumbet.marketID	= bet.marketID
		GROUP BY sumbet.CurrencyID, sumbet.CustID
	
		DROP TABLE #sumBet
		DROP TABLE #detailBet
	END
	-- #EndRegion: Get today's data

	-- #Region: Handle Raw Data
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
		GROUP BY b.Winlostdate, b.Currency, c.Recommend
	END
	-- #EndRegion: Handle Raw Data

	-- #Region: Handle Exchange Rate
	INSERT INTO #Exchange( ExchangeID ,
							ExchageDate ,
							Code ,
							GBP ,
							USD ,
							EUR
						)
	SELECT ExchangeId, ExchangeDate, Code, GBP, USD, EUR
	FROM dbo.Lrf_f_GetExchangeDaily(@FDate, @ToDate)
	WHERE ExchangeId IN (SELECT DISTINCT CurrencyID FROM #tmpResult)
	
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
	SELECT r.CustID
		, ci.username		
		, r.CurrencyID
		, e.Code AS CurrencyName
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