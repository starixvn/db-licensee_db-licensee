/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_LicWinloss_FromAPI]  	
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,
	@ProductCodes	VARCHAR(100),
	@Currency		INT,
	@ReportType		TINYINT = 1,
	@AgentList		VARCHAR(MAX)
AS 
/*  Created: 20180820@Amanda
    Description: LAP - LAP - Implement new Licensee Win Loss report for Ivorybet and Opal88
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20180820@Amanda: Created new Licensee Winloss SP for Ivorybet and Opal88 [RedmineID: #99777]

	Developer's Notes:
		- Notes: If product is NG, search tickets with GameType is RNG
		
	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>
					   <Agent AgentId="12345" Currency="5"/> 
					  </ROOT>
	exec Lrf_Rpt_LicWinloss_FromAPI @reporttype=1,@licenseeid=185,@AgentList=N'<ROOT><Agent AgentId="24942757" Currency="9"/><Agent AgentId="0" Currency="13"/><Agent AgentId="24942816" Currency="41"/><Agent AgentId="0" Currency="15"/><Agent AgentId="24942841" Currency="51"/><Agent AgentId="0" Currency="51"/><Agent AgentId="24942791" Currency="2"/><Agent AgentId="0" Currency="2"/><Agent AgentId="24942774" Currency="4"/><Agent AgentId="0" Currency="4"/></ROOT>',@fromdate='2018-01-01 00:00:00',@todate='2018-03-01 00:00:00',@productcodes='SB,NG',@currency=0
*/  
BEGIN  

	SET NOCOUNT ON
	
	IF @ProductCodes IS NULL
		SET @ProductCodes = ''
	
	DECLARE @Product TABLE (ProductCode VARCHAR(10))

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	DECLARE @RealAgentCurrency	TABLE(ID INT IDENTITY, Currency INT, AgentID INT)  
	DECLARE @SourceIDs			TABLE (LicenseeID INT, LicenseeeName NVARCHAR(50), CustID INT, CurrencyID INT, RoleID TINYINT, EffectiveDate SMALLDATETIME, EndDate SMALLDATETIME)
	CREATE TABLE #tmpCust		(CustID INT, Currency INT, EffectiveDate DATE, EndDate DATE)

	-- Get Real Agents for Ivory, Opal88
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @RealAgentCurrency (Currency, AgentID)
		SELECT DISTINCT Currency, AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	
	-- Get SourceID: Agent for Ivory, Member for Opal88
	INSERT INTO @SourceIDs (LicenseeID, LicenseeeName, CustID, RoleID, CurrencyID, EffectiveDate, EndDate)	
	EXEC bodb_Licensee.dbo.LRF_LicenseeSourcedSel @LicenseeID = @LicenseeID, @FromDate = @FromDate, @ToDate = @ToDate	
	
	IF (@Currency <> 0)
	BEGIN
		DELETE s
		FROM @SourceIDs s
		WHERE s.CurrencyID <> @Currency
	END
	
	-- Include Real Agents to SourceIDs
	DECLARE @tempToDate DATETIME
	SET @tempToDate = DATEADD(DAY, 1, @ToDate)
	
	INSERT INTO @SourceIDs (LicenseeID, CustID, RoleID, CurrencyID, EffectiveDate, EndDate)
	SELECT @LicenseeID, r.AgentID, 2, r.Currency, @FromDate, @tempToDate
	FROM @RealAgentCurrency r
	
	-- Get custId list
	INSERT INTO #tmpCust (CustID, Currency, EffectiveDate, EndDate)
	SELECT c.custid, a.CurrencyID, a.EffectiveDate, DATEADD(DAY, 1, a.EndDate)
	FROM @SourceIDs a
	INNER JOIN dbo.custInfo c WITH (NOLOCK) ON a.CustID = c.recommend
	WHERE a.RoleID = 2
	UNION ALL
	SELECT a.custid, a.CurrencyID, a.EffectiveDate, DATEADD(DAY, 1, a.EndDate)
	FROM @SourceIDs a
	WHERE a.RoleID = 1

	CREATE TABLE #SAgWinLoss
	(  
		winlostdate			DATE,
		Currency			INT,
		TurnoverSB			MONEY,
		TurnoverNG			MONEY,
		Winlost				MONEY,
		LicenseeWLSB		MONEY,
		LicenseeWLNG		MONEY,
		Betcount			BIGINT
	)

	DECLARE @showSB BIT = 0,
			@showNG BIT = 0
	
	SELECT @showSB = 1 FROM @Product WHERE ProductCode = '' OR ProductCode = 'SB'
	SELECT @showNG = 1 FROM @Product WHERE ProductCode = '' OR ProductCode = 'NG'

	-- Retrive data from rptDep_AuditTickets		
	INSERT INTO #SAgWinLoss
		(  
			winlostdate, Currency, TurnoverSB, TurnoverNG, Winlost, LicenseeWLSB, LicenseeWLNG, Betcount
		)
	SELECT	CASE
				WHEN @ReportType = 1 THEN CAST(a.SettlementDate AS DATE)
				ELSE DATEADD(DAY, 1 - DATEPART(DAY, a.SettlementDate), CAST(a.SettlementDate AS DATE))
			END,
			c.Currency,			
			SUM(CASE WHEN a.GameType = 'SB' THEN a.BetAmount ELSE 0 END),
			SUM(CASE WHEN a.GameType = 'RNG' THEN a.BetAmount ELSE 0 END),
			- SUM(a.NetAmount),
			SUM(CASE WHEN a.GameType = 'SB' THEN a.NetAmount ELSE 0 END),
			SUM(CASE WHEN a.GameType = 'RNG' THEN a.NetAmount ELSE 0 END),
			COUNT(a.TransactionId)
	FROM bodb_LicenseeReport.dbo.rptDep_AuditTickets a WITH (NOLOCK)
	INNER JOIN #tmpCust c ON a.PlayerNo = c.CustID AND a.SettlementDate >= c.EffectiveDate AND a.SettlementDate <= c.EndDate
	WHERE (@showSB = 1 AND a.GameType = 'SB') OR (@showNG = 1 AND a.GameType = 'RNG')
	GROUP BY
		CASE
			WHEN @ReportType = 1 THEN CAST(a.SettlementDate AS DATE)
			ELSE DATEADD(DAY, 1 - DATEPART(DAY, a.SettlementDate), CAST(a.SettlementDate AS DATE))
		END,
		c.Currency

	-- Exchange Rate
	CREATE TABLE #Exchange (ExFromDate DATE, ExToDate DATE, ExchangeID INT, RateUSD FLOAT, RateMYR FLOAT, RateEUR FLOAT)
	
	INSERT INTO #Exchange(ExFromDate, ExToDate, ExchangeID, RateUSD, RateMYR, RateEUR)
	SELECT	FirstExchangeDateByMonth, 
			LastExchangeDateByMonth,
			ExchangeID,
			USD,
			MYR,
			EUR
	FROM dbo.Lrf_f_GetSubExchangeDaily(@FromDate, @ToDate) exc
	
	-- Return data
	SELECT
		w.winlostdate			AS ReportType,
		w.Currency,
		w.Betcount			AS Betcount,
		
		--- Orginal ---
		w.TurnoverSB			AS TurnoverSB,
		w.TurnoverNG			AS TurnoverNG,
		w.LicenseeWLSB			AS LicenseeWLSB,
		w.LicenseeWLNG			AS LicenseeWLNG,
		w.Winlost				AS Winlost,
		
		--- USD ---
		w.TurnoverSB*e.RateUSD		AS TurnoverSBUSD,
		w.TurnoverNG*e.RateUSD		AS TurnoverNGUSD,
		w.LicenseeWLSB*e.RateUSD	AS LicenseeWLSBUSD,
		w.LicenseeWLNG*e.RateUSD	AS LicenseeWLNGUSD,
		w.Winlost*e.RateUSD			AS WinlostUSD,
		
		--- EUR ---
		w.TurnoverSB*e.RateEUR		AS TurnoverSBEUR,
		w.TurnoverNG*e.RateEUR		AS TurnoverNGEUR,
		w.LicenseeWLSB*e.RateEUR	AS LicenseeWLSBEUR,
		w.LicenseeWLNG*e.RateEUR	AS LicenseeWLNGEUR,
		w.Winlost*e.RateEUR			AS WinlostEUR,
		
		--- MYR ---
		w.TurnoverSB*e.RateMYR		AS TurnoverSBMYR,
		w.TurnoverNG*e.RateMYR		AS TurnoverNGMYR,
		w.LicenseeWLSB*e.RateMYR	AS LicenseeWLSBMYR,
		w.LicenseeWLNG*e.RateMYR	AS LicenseeWLNGMYR,
		w.Winlost*e.RateMYR			AS WinlostMYR

	FROM #SAgWinLoss w
	INNER JOIN #Exchange e ON w.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND w.Currency = e.ExchangeId	
			
	DROP TABLE #SAgWinLoss
	DROP TABLE #Exchange
	DROP TABLE #tmpCust
END
GO