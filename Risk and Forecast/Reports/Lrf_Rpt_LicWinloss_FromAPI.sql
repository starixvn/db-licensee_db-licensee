/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_LicWinloss_FromAPI]  	
	@SiteName		 VARCHAR(50),
	@FromDate		 SMALLDATETIME,  
	@ToDate		     SMALLDATETIME,
    @ProductCodes	 VARCHAR(100)='',	
	@CurrencyList    VARCHAR(500)='',
	@ReportType	     TINYINT = 1
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
	  + @CurrencyList: xml structure
					  <ROOT>
					   <Agent Id="13" Code="CNY"/>
					   <Agent Id="51" Code="IDR"/> 
					  </ROOT>
	  EXEC   [dbo].[Lrf_Rpt_LicWinloss_FromAPI]
		    @SiteName = N'IvorySport',
		    @FromDate = '2018-08-01',
		    @ToDate = '2018-08-24',
		    @ProductCodes = N'SB,NG',
		    @CurrencyList=N'<ROOT><CR Id="13" Code="CNY"/><CR Id="51" Code="IDR"/> </ROOT>'
		    @ReportType = 1
		    
*/
BEGIN  
    SET NOCOUNT ON
	DECLARE @Product TABLE (ProductCode VARCHAR(10))

	DECLARE @Currency TABLE (Id INT,Code VARCHAR(5))

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@CurrencyList
		INSERT INTO @Currency (Id, Code)
		SELECT DISTINCT Id, Code
		FROM OPENXML(@DocHandler, '/ROOT/CR', 1) WITH (Id [int], Code VARCHAR(5)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
    
    UPDATE @Currency
	SET     Code =  CASE  
                        WHEN Id = 20 THEN 'UUS' 
                        WHEN Id = 51 THEN 'VND' 
                        WHEN Id = 70 THEN 'MMK' 
                        ELSE Code
                    END 
	WHERE   Id IN (20,51,70)

	DECLARE @TempToDate DATE = DATEADD(DAY, 1, @ToDate)
     
	CREATE TABLE #SAgWinLoss
	(  
		winlostdate			DATE,
		CurrencyId			INT,
		TurnoverSB			MONEY,
		TurnoverNG			MONEY,
		Winlost				MONEY,
		LicenseeWLSB		MONEY,
		LicenseeWLNG		MONEY,
		Betcount			BIGINT
	)

	DECLARE @showSB BIT = 0,
			@showNG BIT = 0
	
	SELECT @showSB = 1 FROM @Product WHERE ProductCode = 'SB'
	SELECT @showNG = 1 FROM @Product WHERE ProductCode = 'NG'

	-- Retrive data from rptDep_AuditTickets		
	INSERT INTO #SAgWinLoss
		(  
			winlostdate,CurrencyId, TurnoverSB, TurnoverNG, Winlost, LicenseeWLSB, LicenseeWLNG, Betcount
		)
	SELECT	CASE
				WHEN @ReportType = 1 THEN CAST(a.SettlementDate AS DATE)
				ELSE DATEADD(DAY, 1 - DATEPART(DAY, a.SettlementDate), CAST(a.SettlementDate AS DATE))
			END,
			c.Id,
			SUM(CASE WHEN a.GameType = 'SB' THEN a.BetAmount ELSE 0 END),
			SUM(CASE WHEN a.GameType = 'RNG' THEN a.BetAmount ELSE 0 END),
			- SUM(a.NetAmount),
			SUM(CASE WHEN a.GameType = 'SB' THEN a.NetAmount ELSE 0 END),
			SUM(CASE WHEN a.GameType = 'RNG' THEN a.NetAmount ELSE 0 END),
			COUNT(a.TransactionId)
	FROM bodb_LicenseeReport.dbo.rptDep_AuditTickets a WITH (NOLOCK)
	INNER JOIN @Currency c ON c.Code = a.CurrencyCode
	WHERE a.SettlementDate >= @FromDate AND a.SettlementDate < @TempToDate 
	AND Brand = @SiteName
	AND (@showSB = 1 AND a.GameType = 'SB') OR (@showNG = 1 AND a.GameType = 'RNG')
	GROUP BY
		CASE
			WHEN @ReportType = 1 THEN CAST(a.SettlementDate AS DATE)
			ELSE DATEADD(DAY, 1 - DATEPART(DAY, a.SettlementDate), CAST(a.SettlementDate AS DATE))
		END,
		c.Id


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
		w.CurrencyId,
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
	INNER JOIN #Exchange e ON w.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND w.CurrencyId = e.ExchangeID	
			
	DROP TABLE #SAgWinLoss
	DROP TABLE #Exchange

END
GO