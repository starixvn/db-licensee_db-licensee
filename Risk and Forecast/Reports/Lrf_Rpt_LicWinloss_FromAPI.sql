/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_LicWinloss_FromAPI]  	
	@LicenseeID		INT,
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,   
	@ShowSB			BIT,
	@ShowNG			BIT,
	@ReportType		TINYINT = 1,
	@AgentList		VARCHAR(MAX)
AS 
/*  Created: 20180820@Amanda
    Description: LAP - LAP - Implement new Licensee Win Loss report for Ivorybet and Opal88
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20180820@Amanda: Created new Licensee Winloss SP for Ivorybet and Opal88 [RedmineID: #99777]

	Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>
					   <Agent AgentId="12345" Currency="5"/> 
					  </ROOT>
	exec Lrf_Rpt_LicWinloss_FromAPI @reporttype=1,@licenseeid=185,@AgentList=N'<ROOT><Agent AgentId="24942757" Currency="9"/><Agent AgentId="0" Currency="13"/><Agent AgentId="24942816" Currency="41"/><Agent AgentId="0" Currency="15"/><Agent AgentId="24942841" Currency="51"/><Agent AgentId="0" Currency="51"/><Agent AgentId="24942791" Currency="2"/><Agent AgentId="0" Currency="2"/><Agent AgentId="24942774" Currency="4"/><Agent AgentId="0" Currency="4"/></ROOT>',@fromdate='2018-01-01 00:00:00',@todate='2018-03-01 00:00:00',@productcodes='SB,NG'
*/  
BEGIN  

	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss
	(  
		winlostdate			DATETIME,  
		Currency			INT,
		ProductCode			VARCHAR(10),
		Turnover			MONEY,
		Winlost				MONEY,
		LicenseeWL			MONEY,  
		PlayerComm			MONEY,
		Betcount			BIGINT, 
		WLBetTicket			MONEY,
		BuyBackAmtSB		MONEY
	) 
 
	DECLARE @RealAgentCurrency	TABLE(ID INT IDENTITY, Currency INT, AgentID INT)  
	DECLARE @SourceIDs			TABLE (LicenseeID INT, LicenseeeName NVARCHAR(50), CustID INT, CurrencyID INT, RoleID TINYINT, EffectiveDate SMALLDATETIME, EndDate SMALLDATETIME)
	CREATE TABLE #tmpCust		(CustID INT, AgentID INT, Currency INT, EffectiveDate SMALLDATETIME, EndDate SMALLDATETIME)
	
	DECLARE @products			TABLE (Code VARCHAR(50))
	DECLARE @sporttype			TABLE (Sporttype INT, ProductCode VARCHAR(10))

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
	
	-- Delete setting for Real Agent/Member - to make sure no duplication when combining Fake and Real Agent/Member
	DELETE s
	FROM @SourceIDs s
	WHERE s.LicenseeID = @LicenseeID OR NOT EXISTS (SELECT 1 FROM @RealAgentCurrency c WHERE s.CurrencyID = c.Currency)
	
	-- Include Real Agents to SourceIDs
	INSERT INTO @SourceIDs (LicenseeID, CustID, RoleID, CurrencyID, EffectiveDate, EndDate)
	SELECT @LicenseeID, r.AgentID, 2, r.Currency, @FromDate, @ToDate
	FROM @RealAgentCurrency r
	
	-- Get custId list
	INSERT INTO #tmpCust (CustID, AgentID, Currency, EffectiveDate, EndDate)
	SELECT c.custid, c.recommend, a.CurrencyID, a.EffectiveDate, a.EndDate
	FROM @SourceIDs a
	INNER JOIN dbo.custInfo c WITH (NOLOCK) ON a.CustID = c.recommend
	WHERE a.RoleID = 2
	UNION ALL
	SELECT c.custid, c.recommend, a.CurrencyID, a.EffectiveDate, a.EndDate
	FROM @SourceIDs a
	INNER JOIN dbo.custInfo c WITH (NOLOCK) ON a.CustID = c.custid
	WHERE a.RoleID = 1

	-- Retrive data from rptDep_atTickets
	INSERT INTO #SAgWinLoss
		(  
			winlostdate, Currency, ProductCode, Turnover,
			Winlost, LicenseeWL, Betcount
		)
	SELECT	a.Settlement_date,
			c.Currency,
			a.Game_Type,
			SUM(a.Bet_Amount),
			- SUM(a.Net_Amount),
			SUM(a.Net_Amount),
			COUNT(a.Transaction_Id)
	FROM bodb_LicenseeReport.dbo.rptDep_atTickets a
	INNER JOIN #tmpCust c ON a.player_no = c.CustID AND a.Settlement_date >= c.EffectiveDate AND a.Settlement_date <= c.EndDate
	WHERE (@ShowSB = 1 AND a.Game_Type = 'SB') OR (@ShowNG = 1 AND a.Game_Type = 'NG')
	GROUP BY a.Settlement_date, c.Currency, a.Game_Type
	
	-- Exchange Rate
	CREATE TABLE #Exchange (ExFromDate DATE, ExToDate DATE, ExchangeID INT, RateUSD FLOAT, RateMYR FLOAT, RateEUR FLOAT)
	
	;WITH Currency_CTE (CurrencyID) AS (
											SELECT DISTINCT Currency 
											FROM @RealAgentCurrency
										)
	INSERT INTO #Exchange(ExFromDate, ExToDate, ExchangeID, RateUSD, RateMYR, RateEUR)
	SELECT	FirstExchangeDateByMonth, 
			LastExchangeDateByMonth,
			ExchangeID,
			USD,
			MYR,
			EUR
	FROM dbo.Lrf_f_GetSubExchangeDaily(@FromDate, @ToDate) exc
	INNER JOIN Currency_CTE cur ON exc.ExchangeId = cur.CurrencyID
	
	
	-- Return data
	SELECT
		CASE
			WHEN @ReportType = 1 THEN w.winlostdate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, w.Winlostdate), w.Winlostdate)
			ELSE '0'
		END															AS ReportType,
		Currency,
		SUM(Betcount)												AS Betcount,
		
		--- Orginal ---
		SUM(CASE ProductCode WHEN 'SB' THEN Turnover ELSE 0 END)	AS TurnoverSB,
		SUM(CASE ProductCode WHEN 'NG' THEN Turnover ELSE 0 END)	AS TurnoverNG,
		SUM(CASE ProductCode WHEN 'SB' THEN LicenseeWL ELSE 0 END)	AS LicenseeWLSB,
		SUM(CASE ProductCode WHEN 'NG' THEN LicenseeWL ELSE 0 END)	AS LicenseeWLNG,
		SUM(Winlost)												AS Winlost,
		
		--- USD ---
		SUM(CASE ProductCode WHEN 'SB' THEN Turnover*e.RateUSD ELSE 0 END)		AS TurnoverSBUSD,
		SUM(CASE ProductCode WHEN 'NG' THEN Turnover*e.RateUSD ELSE 0 END)		AS TurnoverNGUSD,
		SUM(CASE ProductCode WHEN 'SB' THEN LicenseeWL*e.RateUSD ELSE 0 END)	AS LicenseeWLSBUSD,
		SUM(CASE ProductCode WHEN 'NG' THEN LicenseeWL*e.RateUSD ELSE 0 END)	AS LicenseeWLNGUSD,
		SUM(Winlost*e.RateUSD)													AS WinlostUSD,
		
		--- EUR ---
		SUM(CASE ProductCode WHEN 'SB' THEN Turnover*e.RateEUR ELSE 0 END)		AS TurnoverSBEUR,
		SUM(CASE ProductCode WHEN 'NG' THEN Turnover*e.RateEUR ELSE 0 END)		AS TurnoverNGEUR,
		SUM(CASE ProductCode WHEN 'SB' THEN LicenseeWL*e.RateEUR ELSE 0 END)	AS LicenseeWLSBEUR,
		SUM(CASE ProductCode WHEN 'NG' THEN LicenseeWL*e.RateEUR ELSE 0 END)	AS LicenseeWLNGEUR,
		SUM(Winlost*e.RateEUR)													AS WinlostEUR,
		
		--- MYR ---
		SUM(CASE ProductCode WHEN 'SB' THEN Turnover*e.RateMYR ELSE 0 END)		AS TurnoverSBMYR,
		SUM(CASE ProductCode WHEN 'NG' THEN Turnover*e.RateMYR ELSE 0 END)		AS TurnoverNGMYR,
		SUM(CASE ProductCode WHEN 'SB' THEN LicenseeWL*e.RateMYR ELSE 0 END)	AS LicenseeWLSBMYR,
		SUM(CASE ProductCode WHEN 'NG' THEN LicenseeWL*e.RateMYR ELSE 0 END)	AS LicenseeWLNGMYR,
		SUM(Winlost*e.RateMYR)													AS WinlostMYR
	FROM #SAgWinLoss w
	INNER JOIN #Exchange e ON w.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND w.Currency = e.ExchangeId
	GROUP BY   
		Currency,
		CASE
			WHEN @ReportType = 1 THEN w.winlostdate
			WHEN @ReportType = 2 THEN DATEADD(DAY, 1 - DATEPART(DAY, w.Winlostdate), w.Winlostdate)
			ELSE '0'
		END		
			
	DROP TABLE #SAgWinLoss
	DROP TABLE #Exchange
	DROP TABLE #tmpCust
END
GO