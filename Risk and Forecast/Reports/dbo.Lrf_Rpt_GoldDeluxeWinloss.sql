/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_GoldDeluxeWinloss]
	@LicenseeId		INT
	, @FromDate		SMALLDATETIME
	, @ToDate		SMALLDATETIME
	, @ReportType	TINYINT			= 1
	, @AgentList	VARCHAR(MAX)

AS  

/*  Created: Winnie
	Date: 2015-03-16
    Task : GD Win Loss report 
    DB: DBEXT.bodb02  
    Revisions:  		
		- 20160413@Victor: support MKK currency code [Redmine: #55745]
		- 20170302@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, @LicenseeID, Remove @excludeTest [Redmine: #71679]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20181114@Joseph: Integrate Bidme games (GD product) [#101599]

	Param's Explanation:  

	  + @ReportType : 1 Daily, 2 Monthly
*/  

SET NOCOUNT ON
BEGIN
	DECLARE @ProductID			INT
		,	@FDate				DATE
		,	@TDate				DATE
		,	@ProductPrefix		VARCHAR(2)

	SELECT @FDate = @FromDate,
		   @TDate = @ToDate,
		   @ProductPrefix = 'GD'

	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = @ProductPrefix	

	CREATE   TABLE #tmpResult (
		Winlostdate DATETIME, 
		Currency INT,
		TurnOver MONEY,
		TotalTrans INT,
		Winlost MONEY,
		LicenseeWinlost MONEY,
		TipsAmount MONEY,
		TipsSharing MONEY,
		AmountDue MONEY)						
	DECLARE  @tmpCust TABLE (CustId INT, Currency INT)
	DECLARE  @TempExchange TABLE(ExchangeDate DATETIME, ExchangeId INT, Code NVARCHAR(5), USD FLOAT, EUR FLOAT,GBP FLOAT)
	
	DECLARE @Temp AS TABLE ( CustId INT,Currency INT )

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO @Temp(CustId, Currency)
		SELECT AgentId, Currency 
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	-- Get Charge rates
	DECLARE @PartyID	VARCHAR(10)
	DECLARE @ChargeRates AS TABLE(Rate MONEY, FromDate DATE, ToDate DATE, ChargeType TINYINT)

	SELECT @PartyID = CAST(PartyID AS VARCHAR)
	FROM bodb_licensee.dbo.OAS_Party WITH(NOLOCK)
	WHERE OldRefID = @LicenseeId AND PartyType = 1
	
	INSERT INTO @ChargeRates(Rate, FromDate, ToDate, ChargeType)
	SELECT DI_Rate, Fromdate, Todate, ChargeType
	FROM bodb_licensee.dbo.LA_f_ChargeInfo(@PartyID, @FDate, @TDate, @ProductPrefix, 'OA', 1)
	WHERE (ChargeType = 1 OR ChargeType = 12) AND DI_Rate > 0
	
	IF NOT EXISTS (SELECT 1 FROM @ChargeRates)
	BEGIN
		INSERT INTO @ChargeRates(Rate, FromDate, ToDate, ChargeType)
		SELECT DI_Rate, Fromdate, Todate, ChargeType
		FROM bodb_licensee.dbo.LA_f_GetChargeInfoWithTrialTime(@PartyID, @FDate, @TDate, @ProductPrefix, 'OA', 1)
		WHERE (ChargeType = 1 OR ChargeType = 12) AND DI_Rate > 0
	END
	
	-- Get data
	INSERT INTO @tmpCust (CustID, Currency)
	SELECT co.CustID, lc.Currency 
	FROM dbo.custInfo co WITH (NOLOCK)
		INNER JOIN @Temp lc ON co.recommend = lc.CustId AND lc.Currency = co.Currency	

	INSERT INTO #tmpResult (
		Winlostdate
		,Currency
		,TurnOver
		,TotalTrans
		,Winlost
		,LicenseeWinlost
		,TipsAmount
		,TipsSharing
		,AmountDue)
		(
			SELECT c.Winlostdate, ct.Currency
					, SUM(CASE WHEN c.bettype = -1
									THEN c.TurnOver ELSE 0 END) AS TurnOver
					, SUM(CASE WHEN c.bettype = -1
									THEN c.BetCount ELSE 0 END) AS TotalTrans
					, SUM(CASE WHEN c.bettype = -1 
									THEN c.Winlost ELSE 0 END) AS Winlost
					, -SUM(CASE WHEN c.bettype = -1 
									THEN c.Winlost ELSE 0 END) AS LicenseeWinlost
					, -SUM(CASE WHEN c.bettype = 1706 -- GD Tips
									THEN c.Winlost ELSE 0 END) AS TipsAmount
					, -SUM(CASE WHEN c.bettype = 1706 -- GD Tips
						  			THEN c.Winlost * (1-ISNULL(rate.Rate,1)) ELSE 0 END) AS TipsSharing
					, SUM(-c.Winlost * ISNULL(rate.Rate,1)) AS AmountDue
			FROM [bodb_LicenseeReport].dbo.rptDepWinlost_ThirdParty c WITH (NOLOCK)
				INNER JOIN @tmpCust ct ON c.Custid = ct.CustId AND c.Currency = ct.Currency
				LEFT JOIN @ChargeRates rate ON c.Winlostdate BETWEEN rate.FromDate AND rate.ToDate AND 
						((c.bettype = -1 AND rate.ChargeType = 1) OR (c.bettype = 1706 AND rate.ChargeType = 12))
			WHERE c.ProductId=@ProductID AND c.Winlostdate BETWEEN @FDate AND @TDate 
			GROUP BY c.Winlostdate, ct.Currency
		)

	INSERT INTO @TempExchange(ExchangeDate, ExchangeId, Code, USD, EUR,GBP)
		(
			SELECT ExchangeDate, ExchangeId, Code, USD, EUR	,GBP 
			FROM dbo.Lrf_f_GetExchangeDaily(@FDate, @TDate)
			WHERE ExchangeId IN (SELECT DISTINCT Currency FROM #tmpResult)
		)
	
	SELECT --r.Winlostdate
		   CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			END AS Winlostdate
		, r.Currency
		, SUM(r.TurnOver)			AS TurnOver
		, SUM(r.TotalTrans)			AS TotalTrans
		, SUM(r.Winlost)			AS Winlost
		, SUM(r.LicenseeWinlost)	AS LicenseeWinlost
		, SUM(r.TipsAmount)			AS TipsAmount
		, SUM(r.TipsSharing)		AS TipsSharing
		, SUM(r.AmountDue)			AS AmountDue
		---USD
		, SUM(r.TurnOver * e.USD)	AS TurnOverUSD
		, SUM(r.Winlost * e.USD)	AS WinlostUSD
		, SUM(r.LicenseeWinlost * e.USD) AS LicenseeWinlostUSD
		, SUM(r.TipsAmount * e.USD)			AS TipsAmountUSD
		, SUM(r.TipsSharing * e.USD)		AS TipsSharingUSD
		, SUM(r.AmountDue * e.USD)			AS AmountDueUSD
		---EUR
		, SUM(r.TurnOver * e.EUR)	AS TurnOverEUR
		, SUM(r.Winlost * e.EUR)	AS WinlostEUR
		, SUM(r.LicenseeWinlost * e.EUR) AS LicenseeWinlostEUR
		, SUM(r.TipsAmount * e.EUR)			AS TipsAmountEUR
		, SUM(r.TipsSharing * e.EUR)		AS TipsSharingEUR
		, SUM(r.AmountDue * e.EUR)			AS AmountDueEUR
		---GBP
		, SUM(r.TurnOver * e.GBP)	AS TurnOverGBP
		, SUM(r.Winlost * e.GBP)	AS WinlostGBP
		, SUM(r.LicenseeWinlost * e.GBP) AS LicenseeWinlostGBP
		, SUM(r.TipsAmount * e.GBP)			AS TipsAmountGBP
		, SUM(r.TipsSharing * e.GBP)		AS TipsSharingGBP
		, SUM(r.AmountDue * e.GBP)			AS AmountDueGBP
	FROM #tmpResult r
	INNER JOIN @TempExchange e ON r.Winlostdate = e.ExchangeDate AND r.Currency = e.ExchangeId
	GROUP BY --r.Winlostdate
		 CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			 END
		, r.Currency
	--ORDER BY r.Winlostdate
	ORDER BY CASE 
				WHEN @ReportType = 1
					THEN r.winlostdate
				WHEN @ReportType = 2					
					THEN DATEADD(DAY, 1 - DATEPART(DAY, r.Winlostdate), r.Winlostdate)
				ELSE '0'
			 END
	---------
	
	
END
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO