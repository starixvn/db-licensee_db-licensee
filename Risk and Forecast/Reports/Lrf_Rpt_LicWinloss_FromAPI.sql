/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_LicWinloss_FromAPI]  	
	@SiteName		VARCHAR(50),
	@FromDate		DATE,
	@ToDate			DATE,
	@ProductCodes	VARCHAR(100)='',
	@CurrencyList   VARCHAR(500)='',
	@ReportType		TINYINT = 1,
	@BaseCurrency	VARCHAR(3) = '',
    @DefaultBaseCurrency	VARCHAR(3) = ''
AS 
/*  Created: 20180820@Amanda
    Description: LAP - LAP - Implement new Licensee Win Loss report for Ivorybet and Opal88
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20180820@Amanda: Created new Licensee Winloss SP for Ivorybet and Opal88 [RedmineID: #99777]
		- 20190622@Amanda: Add Base currency param [RedmineID: #112531]

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
	SELECT	a.WinLostDate,
			c.Id,
			SUM(CASE WHEN a.GameType = 'SB' THEN a.BetAmount ELSE 0 END),
			SUM(CASE WHEN a.GameType = 'RNG' THEN a.BetAmount ELSE 0 END),
			- SUM(a.NetAmount),
			SUM(CASE WHEN a.GameType = 'SB' THEN a.NetAmount ELSE 0 END),
			SUM(CASE WHEN a.GameType = 'RNG' THEN a.NetAmount ELSE 0 END),
			COUNT(a.TransactionId)
	FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK)
	INNER JOIN @Currency c ON c.Code = a.CurrencyCode
	WHERE  a.WinLostDate >= @FromDate AND a.WinLostDate < @TempToDate 
			AND Brand = @SiteName
			AND ((@showSB = 1 AND a.GameType = 'SB') OR (@showNG = 1 AND a.GameType = 'RNG'))
			
	GROUP BY
		a.WinLostDate,
		c.Id

	-- Exchange Rate
	CREATE TABLE #Exchange (ExFromDate DATE, ExToDate DATE, ExchangeID INT, USD FLOAT, GBP FLOAT, EUR FLOAT, Rate FLOAT, DefaultRate FLOAT )
	
	INSERT INTO #Exchange(ExFromDate, ExToDate, ExchangeID, USD, GBP, EUR, Rate, DefaultRate)
	SELECT	FromDate, 
			ToDate,
			ExchangeID,
			USD,
			GBP,
			EUR,
			Rate,
			DefaultRate
	FROM dbo.Lrf_f_GetExchangeDaily(@FromDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) exc

	-- Return data
	IF (@ReportType = 1)
	BEGIN
		SELECT
			w.winlostdate			AS ReportType,
			w.CurrencyId,
			w.Betcount			AS Betcount,
			
			--- Orginal ---
			w.TurnoverSB*e.Rate		AS TurnoverSB,
			w.TurnoverNG*e.Rate		AS TurnoverNG,
			w.LicenseeWLSB*e.Rate	AS LicenseeWLSB,
			w.LicenseeWLNG*e.Rate	AS LicenseeWLNG,
			w.Winlost*e.Rate		AS Winlost,
			
			--- USD ---
			w.TurnoverSB*e.USD		AS TurnoverSBUSD,
			w.TurnoverNG*e.USD		AS TurnoverNGUSD,
			w.LicenseeWLSB*e.USD	AS LicenseeWLSBUSD,
			w.LicenseeWLNG*e.USD	AS LicenseeWLNGUSD,
			w.Winlost*e.USD			AS WinlostUSD,
			
			--- EUR ---
			w.TurnoverSB*e.EUR		AS TurnoverSBEUR,
			w.TurnoverNG*e.EUR		AS TurnoverNGEUR,
			w.LicenseeWLSB*e.EUR	AS LicenseeWLSBEUR,
			w.LicenseeWLNG*e.EUR	AS LicenseeWLNGEUR,
			w.Winlost*e.EUR			AS WinlostEUR,
			
			--- GBP ---
			w.TurnoverSB*e.GBP		AS TurnoverSBGBP,
			w.TurnoverNG*e.GBP		AS TurnoverNGGBP,
			w.LicenseeWLSB*e.GBP	AS LicenseeWLSBGBP,
			w.LicenseeWLNG*e.GBP	AS LicenseeWLNGGBP,
			w.Winlost*e.GBP			AS WinlostGBP,

			--- Default Base currency ---
			w.TurnoverSB*e.DefaultRate		AS TurnoverSBBase,
			w.TurnoverNG*e.DefaultRate		AS TurnoverNGBase,
			w.LicenseeWLSB*e.DefaultRate	AS LicenseeWLSBBase,
			w.LicenseeWLNG*e.DefaultRate	AS LicenseeWLNGBase,
			w.Winlost*e.DefaultRate			AS WinlostBase
		FROM #SAgWinLoss w
		INNER JOIN #Exchange e ON w.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND w.CurrencyId = e.ExchangeID	
	END	
	ELSE
	BEGIN
		SELECT
			DATEADD(DAY, 1 - DATEPART(DAY, w.winlostdate), w.winlostdate)			AS ReportType,
			w.CurrencyId,
			SUM(w.Betcount)				AS Betcount,
			
			--- Orginal ---
			SUM(w.TurnoverSB*e.Rate)	AS TurnoverSB,
			SUM(w.TurnoverNG*e.Rate)	AS TurnoverNG,
			SUM(w.LicenseeWLSB*e.Rate)	AS LicenseeWLSB,
			SUM(w.LicenseeWLNG*e.Rate)	AS LicenseeWLNG,
			SUM(w.Winlost*e.Rate)		AS Winlost,
			
			--- USD ---
			SUM(w.TurnoverSB*e.USD)		AS TurnoverSBUSD,
			SUM(w.TurnoverNG*e.USD)		AS TurnoverNGUSD,
			SUM(w.LicenseeWLSB*e.USD)	AS LicenseeWLSBUSD,
			SUM(w.LicenseeWLNG*e.USD)	AS LicenseeWLNGUSD,
			SUM(w.Winlost*e.USD)		AS WinlostUSD,
			
			--- EUR ---
			SUM(w.TurnoverSB*e.EUR)		AS TurnoverSBEUR,
			SUM(w.TurnoverNG*e.EUR)		AS TurnoverNGEUR,
			SUM(w.LicenseeWLSB*e.EUR)	AS LicenseeWLSBEUR,
			SUM(w.LicenseeWLNG*e.EUR)	AS LicenseeWLNGEUR,
			SUM(w.Winlost*e.EUR)		AS WinlostEUR,
			
			--- GBP ---
			SUM(w.TurnoverSB*e.GBP)		AS TurnoverSBGBP,
			SUM(w.TurnoverNG*e.GBP)		AS TurnoverNGGBP,
			SUM(w.LicenseeWLSB*e.GBP)	AS LicenseeWLSBGBP,
			SUM(w.LicenseeWLNG*e.GBP)	AS LicenseeWLNGGBP,
			SUM(w.Winlost*e.GBP)		AS WinlostGBP,
			
			--- Default Base currency ---
			SUM(w.TurnoverSB*e.DefaultRate)		AS TurnoverSBBase,
			SUM(w.TurnoverNG*e.DefaultRate)		AS TurnoverNGBase,
			SUM(w.LicenseeWLSB*e.DefaultRate)	AS LicenseeWLSBBase,
			SUM(w.LicenseeWLNG*e.DefaultRate)	AS LicenseeWLNGBase,
			SUM(w.Winlost*e.DefaultRate)		AS WinlostBase

		FROM #SAgWinLoss w
		INNER JOIN #Exchange e ON w.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND w.CurrencyId = e.ExchangeID
		GROUP BY
			DATEADD(DAY, 1 - DATEPART(DAY, w.winlostdate), w.winlostdate),
			w.CurrencyId
	END
			
	DROP TABLE #SAgWinLoss
	DROP TABLE #Exchange

END
GO