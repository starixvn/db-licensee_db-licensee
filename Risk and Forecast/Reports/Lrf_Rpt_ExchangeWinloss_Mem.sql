/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Rpt_ExchangeWinloss_Mem]
	  @CustID		INT
	, @FromDate		DATE
	, @ToDate		DATE	
	, @AgentList	VARCHAR(MAX)
AS

/*
	Created: 20171215@Harper
	Description: LRF - Implement Exchange winloss for exchange product
	DB: DBEXT.bodb02 
	Revisions: 
		- 20171215@Harper: Create new report Exchange Winloss [RedmineID: #86640]

	Param's Explanation:  		

	exec Lrf_Rpt_ExchangeWinloss_Mem @fromdate='2017-04-24 00:00:00',@todate='2017-04-24 00:00:00',@AgentList=N'<ROOT><Agent AgentId="791088" Currency="3"/><Agent AgentId="860379" Currency="6"/><Agent AgentId="2428981" Currency="6"/><Agent AgentId="2812696" Currency="6"/><Agent AgentId="3575140" Currency="6"/><Agent AgentId="4362999" Currency="6"/></ROOT>',@CustID = 4362999
 
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (CustID INT, Winlostdate DATE, CurrencyID INT, TotalTrans INT, TurnOver MONEY
							, NETTurnOver MONEY, Winlost MONEY, LicWinlost MONEY, CustComm MONEY, AmountDueTo MONEY, AgentComm MONEY)
	CREATE TABLE #Exchange (ExchangeID INT, ExchageDate DATE, Code VARCHAR(5), GBP FLOAT, USD FLOAT, EUR FLOAT)
	DECLARE @ChargeInfo TABLE (ProductID INT, Rate MONEY, Fromdate DATE, Todate DATE)
	DECLARE @PartyList  TABLE (PartyId INT, PartyName	VARCHAR(100), BranchName VARCHAR(100), ParentId	INT)
	
	DECLARE @VNDCurrencyNAME VARCHAR(20)
		, @ProductID		INT
		, @FDate			DATE
		, @TDate			DATE
		, @PartyIds			VARCHAR(4000)
	
	SELECT @FDate = @FromDate,
		   @TDate = @ToDate

	SELECT @VNDCurrencyName = currency 
	FROM  dbo.Exchange WITH (NOLOCK) 
	WHERE ExchangeId = 51

	SELECT @ProductID = ProductID
	FROM bodb_licensee.dbo.Product3rd WITH (NOLOCK)
	WHERE ProductPrefix = 'BX'

	-- #Region: Get Licensee Charge Rate
	INSERT INTO @PartyList (PartyId, PartyName, BranchName, ParentId)
	EXEC bodb_licensee.dbo.LA_PartyListSel

	SELECT @PartyIds = COALESCE(@PartyIds + ', ', '') + CONVERT(VARCHAR(10), PartyId)
	FROM @PartyList 

	INSERT INTO @ChargeInfo(ProductID, Rate, Fromdate, Todate)
	SELECT DISTINCT ProductID, DI_Rate, Fromdate, Todate
	FROM bodb_licensee.dbo.LA_f_ChargeInfo(@PartyIDs, @FromDate, @ToDate, 'BX', 'OA', 1)
	-- #EndRegion: Get Licensee Charge Rate

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

	-- #Region: Handle Raw Data

	INSERT INTO #tmpResult( CustID,
							Winlostdate ,
							CurrencyID ,
							TurnOver ,
							NetTurnOver,
							TotalTrans ,							
							Winlost ,							
							LicWinlost,
							CustComm,
							AmountDueTo,
							AgentComm
						)
	SELECT c.CustID, b.Winlostdate, b.Currency
		, SUM(b.Turnover), SUM(ValidBetAmount), SUM(b.BetCount)
		, SUM(b.Winlost), -SUM(b.Winlost), SUM(CommissionP)
		, SUM((-b.Winlost * (1 - ci.Rate)) + (CommissionP - CommissionA))
		, SUM(CommissionA)
	FROM bodb_LicenseeReport.dbo.rptDepWinlost_ThirdParty b WITH (NOLOCK)
		INNER JOIN @tmpCust c ON b.Custid = c.CustID AND b.Currency = c.Currency
		INNER JOIN @ChargeInfo ci ON b.ProductId = ci.ProductID AND b.Winlostdate BETWEEN ci.Fromdate AND ci.Todate
	WHERE b.Winlostdate BETWEEN @FDate AND @ToDate
		AND b.ProductId = @ProductID	
	GROUP BY b.Winlostdate, b.Currency, c.CustID
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
	-- #EndRegion: Handle Exchange Rate

	-- #Region: Return data
	SELECT SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname
		, c.username		
		, r.CurrencyID
		, CASE 
		 		WHEN r.CurrencyID = 51 THEN @VNDCurrencyName
				WHEN r.CurrencyID = 70 THEN 'MKK'
		 		ELSE e.Code
		END	AS CurrencyName
		, SUM(r.TurnOver)			AS TurnOver
		, SUM(r.NETTurnOver)		AS NetTurnOver
		, SUM(r.TotalTrans)			AS TotalTrans
		, SUM(r.Winlost)			AS Winlost
		, SUM(r.CustComm)			AS CustComm
		, SUM(r.LicWinlost)			AS LicenseeWinlost
		, SUM(r.AmountDueTo)		AS AmountDueTo
		, SUM(r.AgentComm)			AS AgentComm
		---USD
		, SUM(r.TurnOver * e.USD)			AS TurnOverUSD
		, SUM(r.NETTurnOver * e.USD)		AS NetTurnOverUSD
		, SUM(r.TotalTrans * e.USD)			AS TotalTransUSD
		, SUM(r.Winlost * e.USD)			AS WinlostUSD
		, SUM(r.CustComm * e.USD)			AS CustCommUSD
		, SUM(r.LicWinlost * e.USD)			AS LicenseeWinlostUSD
		, SUM(r.AmountDueTo * e.USD)		AS AmountDueToUSD
		, SUM(r.AgentComm * e.USD)			AS AgentCommUSD
		---EUR
		, SUM(r.TurnOver * e.EUR)			AS TurnOverEUR
		, SUM(r.NETTurnOver * e.EUR)		AS NetTurnOverEUR
		, SUM(r.TotalTrans * e.EUR)			AS TotalTransEUR
		, SUM(r.Winlost * e.EUR)			AS WinlostEUR
		, SUM(r.CustComm * e.EUR)			AS CustCommEUR
		, SUM(r.LicWinlost * e.EUR)			AS LicenseeWinlostEUR
		, SUM(r.AmountDueTo * e.EUR)		AS AmountDueToEUR
		, SUM(r.AgentComm * e.EUR)			AS AgentCommEUR
		---GBP
		, SUM(r.TurnOver * e.GBP)			AS TurnOverGBP
		, SUM(r.NETTurnOver * e.GBP)		AS NetTurnOverGBP
		, SUM(r.TotalTrans * e.GBP)			AS TotalTransGBP
		, SUM(r.Winlost * e.GBP)			AS WinlostGBP
		, SUM(r.CustComm * e.GBP)			AS CustCommGBP
		, SUM(r.LicWinlost * e.GBP)			AS LicenseeWinlostGBP
		, SUM(r.AmountDueTo * e.GBP)		AS AmountDueToGBP
		, SUM(r.AgentComm * e.GBP)			AS AgentCommGBP
	FROM #tmpResult r
		INNER JOIN #Exchange e ON r.Winlostdate = e.ExchageDate AND r.CurrencyID = e.ExchangeId
		INNER JOIN dbo.customer c WITH  (NOLOCK) ON c.CustID = r.CustID
	GROUP BY SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2))
		, c.username
		, r.CurrencyID
		, CASE 
			WHEN CurrencyID = 51 THEN @VNDCurrencyName
			WHEN CurrencyID = 70 THEN 'MKK'
			ELSE e.Code
		END	
	ORDER BY c.username	
			
	-- #EndRegion: Return data
	DROP TABLE #Exchange
	DROP TABLE #tmpResult
END
GO