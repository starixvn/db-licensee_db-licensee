/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinloss_FromAPI]  	
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
		- 20190815@Amanda: Add product CS & LC [RedmineID: #117900]
		- 20200320@Bobby: Ploutos Integration - [redmine: #125252]
		- 20200917@Sol: Joinning with playerProfile - [redmine: #125252]

	Developer's Notes:
		- Notes: If product is NG, search tickets with GameType is RNG
		
    Param's Explanation:  
	  + @ReportType: 1-Daily; 2-Monthly;  
	  + @CurrencyList: XML(<ROOT><CR Id="13" Code="CNY"/><CR Id="51" Code="IDR"/> </ROOT>)

	  EXEC   [dbo].[Lrf_Rpt_LicWinloss_FromAPI]
		    @SiteName = N'IvorySport',
		    @FromDate = '2018-08-01',
		    @ToDate = '2018-08-24',
		    @ProductCodes = N'SB,NG',
		    @CurrencyList=N'<ROOT><CR Id="13" Code="CNY"/><CR Id="51" Code="IDR"/> </ROOT>'
		    @ReportType = 1
		    
*/
BEGIN  
    SET NOCOUNT ON;

	DECLARE @cutoffDate DATE;
	DECLARE @Product TABLE (ProductCode VARCHAR(10))
	DECLARE @Currency TABLE (Id INT,Code VARCHAR(5))

	--get cutoffDate
	SELECT @cutoffDate = f.CutOffDate 
	FROM Lrf_f_GetCutOffDateBySite() f
	WHERE f.ReportType = 1 AND f.SiteName = @SiteName

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM bodb02.dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	INSERT INTO @Currency (Id, Code)
	SELECT T.C.value('./@Id', 'INT') AS Id
		,T.C.value('./@Code', 'VARCHAR(5)') AS Code
	FROM (
		VALUES (CAST(@CurrencyList AS XML))
	) AS xd(dataX)
	CROSS APPLY xd.dataX.nodes('/ROOT/CR') AS T(C)
    
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
		TurnoverCS			MONEY,
		TurnoverLC			MONEY,
		Winlost				MONEY,
		LicenseeWLSB		MONEY,
		LicenseeWLNG		MONEY,
		LicenseeWLCS		MONEY,
		LicenseeWLLC		MONEY,
		Betcount			BIGINT,
		SourceName			VARCHAR(20)
	)

	CREATE CLUSTERED INDEX CIX_Winlostdate ON #SAgWinLoss (Winlostdate DESC)

	DECLARE @showSB BIT = 0,
			@showNG BIT = 0,
			@showCS BIT = 0,
			@showLC BIT = 0
	
	SELECT @showSB = 1 FROM @Product WHERE ProductCode = 'SB'
	SELECT @showNG = 1 FROM @Product WHERE ProductCode = 'NG'
	SELECT @showCS = 1 FROM @Product WHERE ProductCode = 'CS'
	SELECT @showLC = 1 FROM @Product WHERE ProductCode = 'LC'

	-- Retrive data from rptDep_AuditTickets		
	INSERT INTO #SAgWinLoss
		(  
			winlostdate,
			CurrencyId,
			TurnoverSB,
			TurnoverNG,
			TurnoverCS,
			TurnoverLC,
			Winlost,
			LicenseeWLSB,
			LicenseeWLNG,
			LicenseeWLCS,
			LicenseeWLLC,
			Betcount,
			SourceName
		)
	SELECT	a.WinLostDate,
			c.Id AS CurrencyId,
			SUM(CASE WHEN a.GameType = 'SB' THEN a.BetAmount ELSE 0 END) AS TurnoverSB,
			SUM(CASE WHEN a.GameType = 'RNG' AND a.GameCode = '161' THEN a.BetAmount ELSE 0 END) AS TurnoverNG,
			SUM(CASE WHEN a.GameType = 'RNG' AND a.GameCode <> '161' THEN a.BetAmount ELSE 0 END) AS TurnoverCS,
			SUM(CASE WHEN a.GameType = 'CA' THEN a.BetAmount ELSE 0 END) AS TurnoverLC,
			- SUM(a.NetAmount) AS Winlost,
			SUM(CASE WHEN a.GameType = 'SB' THEN a.NetAmount ELSE 0 END) AS LicenseeWLSB,
			SUM(CASE WHEN a.GameType = 'RNG' AND a.GameCode = '161' THEN a.NetAmount ELSE 0 END) AS LicenseeWLNG,
			SUM(CASE WHEN a.GameType = 'RNG' AND a.GameCode <> '161' THEN a.NetAmount ELSE 0 END) AS LicenseeWLCS,
			SUM(CASE WHEN a.GameType = 'CA' THEN a.NetAmount ELSE 0 END) AS LicenseeWLLC,
			COUNT(1) AS Betcount,
			'AuditTicket' AS SourceName
	FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK)
	INNER JOIN @Currency c ON c.Code = a.CurrencyCode
	WHERE  a.WinLostDate >= @FromDate AND a.WinLostDate < @TempToDate 
			AND Brand = @SiteName
			AND (
					(@showSB = 1 AND a.GameType = 'SB') 
				OR	(@showNG = 1 AND a.GameType = 'RNG' AND a.GameCode = '161')
				OR	(@showCS = 1 AND a.GameType = 'RNG' AND a.GameCode <> '161')
				OR	(@showLC = 1 AND a.GameType = 'CA')
			)
			AND a.WinlostDate < @cutoffDate
	GROUP BY
		a.WinLostDate,
		c.Id

	UNION ALL
	SELECT	a.WinLostDate,
			c.Id,
			SUM(CASE WHEN a.GamePlatformCode = 'SB' THEN a.BetAmount ELSE 0 END),
			SUM(CASE WHEN a.GamePlatformCode = 'RNG' AND a.GameCode = '0161' THEN a.BetAmount ELSE 0 END),
			SUM(CASE WHEN a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161' THEN a.BetAmount ELSE 0 END),
			SUM(CASE WHEN a.GamePlatformCode = 'CA' THEN a.BetAmount ELSE 0 END),
			- SUM(a.NetAmount),
			SUM(CASE WHEN a.GamePlatformCode = 'SB' THEN a.NetAmount ELSE 0 END),
			SUM(CASE WHEN a.GamePlatformCode = 'RNG' AND a.GameCode = '0161' THEN a.NetAmount ELSE 0 END),
			SUM(CASE WHEN a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161' THEN a.NetAmount ELSE 0 END),
			SUM(CASE WHEN a.GamePlatformCode = 'CA' THEN a.NetAmount ELSE 0 END),
			COUNT(1),
			'BetTicket' AS SourceName
	FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
	WHERE  a.WinLostDate >= @FromDate AND a.WinLostDate < @TempToDate 
			AND a.BrandCode = @SiteName
			AND (
					(@showSB = 1 AND a.GamePlatformCode = 'SB') 
				OR	(@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
				OR	(@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
				OR	(@showLC = 1 AND a.GamePlatformCode = 'CA')
			)
			AND a.WinlostDate >= @cutoffDate
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
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @BaseCurrency, @DefaultBaseCurrency) exc

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
			w.TurnoverCS*e.Rate		AS TurnoverCS,
			w.TurnoverLC*e.Rate		AS TurnoverLC,
			w.LicenseeWLSB*e.Rate	AS LicenseeWLSB,
			w.LicenseeWLNG*e.Rate	AS LicenseeWLNG,
			w.LicenseeWLCS*e.Rate	AS LicenseeWLCS,
			w.LicenseeWLLC*e.Rate	AS LicenseeWLLC,
			w.Winlost*e.Rate		AS Winlost,
			
			--- USD ---
			w.TurnoverSB*e.USD		AS TurnoverSBUSD,
			w.TurnoverNG*e.USD		AS TurnoverNGUSD,
			w.TurnoverCS*e.USD		AS TurnoverCSUSD,
			w.TurnoverLC*e.USD		AS TurnoverLCUSD,
			w.LicenseeWLSB*e.USD	AS LicenseeWLSBUSD,
			w.LicenseeWLNG*e.USD	AS LicenseeWLNGUSD,
			w.LicenseeWLCS*e.USD	AS LicenseeWLCSUSD,
			w.LicenseeWLLC*e.USD	AS LicenseeWLLCUSD,
			w.Winlost*e.USD			AS WinlostUSD,
			
			--- EUR ---
			w.TurnoverSB*e.EUR		AS TurnoverSBEUR,
			w.TurnoverNG*e.EUR		AS TurnoverNGEUR,
			w.TurnoverCS*e.EUR		AS TurnoverCSEUR,
			w.TurnoverLC*e.EUR		AS TurnoverLCEUR,
			w.LicenseeWLSB*e.EUR	AS LicenseeWLSBEUR,
			w.LicenseeWLNG*e.EUR	AS LicenseeWLNGEUR,
			w.LicenseeWLCS*e.EUR	AS LicenseeWLCSEUR,
			w.LicenseeWLLC*e.EUR	AS LicenseeWLLCEUR,
			w.Winlost*e.EUR			AS WinlostEUR,
			
			--- GBP ---
			w.TurnoverSB*e.GBP		AS TurnoverSBGBP,
			w.TurnoverNG*e.GBP		AS TurnoverNGGBP,
			w.TurnoverCS*e.GBP		AS TurnoverCSGBP,
			w.TurnoverLC*e.GBP		AS TurnoverLCGBP,
			w.LicenseeWLSB*e.GBP	AS LicenseeWLSBGBP,
			w.LicenseeWLNG*e.GBP	AS LicenseeWLNGGBP,
			w.LicenseeWLCS*e.GBP	AS LicenseeWLCSGBP,
			w.LicenseeWLLC*e.GBP	AS LicenseeWLLCGBP,
			w.Winlost*e.GBP			AS WinlostGBP,

			--- Default Base currency ---
			w.TurnoverSB*e.DefaultRate		AS TurnoverSBBase,
			w.TurnoverNG*e.DefaultRate		AS TurnoverNGBase,
			w.TurnoverCS*e.DefaultRate		AS TurnoverCSBase,
			w.TurnoverLC*e.DefaultRate		AS TurnoverLCBase,
			w.LicenseeWLSB*e.DefaultRate	AS LicenseeWLSBBase,
			w.LicenseeWLNG*e.DefaultRate	AS LicenseeWLNGBase,
			w.LicenseeWLCS*e.DefaultRate	AS LicenseeWLCSBase,
			w.LicenseeWLLC*e.DefaultRate	AS LicenseeWLLCBase,
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
			SUM(w.TurnoverCS*e.Rate)	AS TurnoverCS,
			SUM(w.TurnoverLC*e.Rate)	AS TurnoverLC,
			SUM(w.LicenseeWLSB*e.Rate)	AS LicenseeWLSB,
			SUM(w.LicenseeWLNG*e.Rate)	AS LicenseeWLNG,
			SUM(w.LicenseeWLCS*e.Rate)	AS LicenseeWLCS,
			SUM(w.LicenseeWLLC*e.Rate)	AS LicenseeWLLC,
			SUM(w.Winlost*e.Rate)		AS Winlost,
			
			--- USD ---
			SUM(w.TurnoverSB*e.USD)		AS TurnoverSBUSD,
			SUM(w.TurnoverNG*e.USD)		AS TurnoverNGUSD,
			SUM(w.TurnoverCS*e.USD)		AS TurnoverCSUSD,
			SUM(w.TurnoverLC*e.USD)		AS TurnoverLCUSD,
			SUM(w.LicenseeWLSB*e.USD)	AS LicenseeWLSBUSD,
			SUM(w.LicenseeWLNG*e.USD)	AS LicenseeWLNGUSD,
			SUM(w.LicenseeWLCS*e.USD)	AS LicenseeWLCSUSD,
			SUM(w.LicenseeWLLC*e.USD)	AS LicenseeWLLCUSD,
			SUM(w.Winlost*e.USD)		AS WinlostUSD,
			
			--- EUR ---
			SUM(w.TurnoverSB*e.EUR)		AS TurnoverSBEUR,
			SUM(w.TurnoverNG*e.EUR)		AS TurnoverNGEUR,
			SUM(w.TurnoverCS*e.EUR)		AS TurnoverCSEUR,
			SUM(w.TurnoverLC*e.EUR)		AS TurnoverLCEUR,
			SUM(w.LicenseeWLSB*e.EUR)	AS LicenseeWLSBEUR,
			SUM(w.LicenseeWLNG*e.EUR)	AS LicenseeWLNGEUR,
			SUM(w.LicenseeWLCS*e.EUR)	AS LicenseeWLCSEUR,
			SUM(w.LicenseeWLLC*e.EUR)	AS LicenseeWLLCEUR,
			SUM(w.Winlost*e.EUR)		AS WinlostEUR,
			
			--- GBP ---
			SUM(w.TurnoverSB*e.GBP)		AS TurnoverSBGBP,
			SUM(w.TurnoverNG*e.GBP)		AS TurnoverNGGBP,
			SUM(w.TurnoverCS*e.GBP)		AS TurnoverCSGBP,
			SUM(w.TurnoverLC*e.GBP)		AS TurnoverLCGBP,
			SUM(w.LicenseeWLSB*e.GBP)	AS LicenseeWLSBGBP,
			SUM(w.LicenseeWLNG*e.GBP)	AS LicenseeWLNGGBP,
			SUM(w.LicenseeWLCS*e.GBP)	AS LicenseeWLCSGBP,
			SUM(w.LicenseeWLLC*e.GBP)	AS LicenseeWLLCGBP,
			SUM(w.Winlost*e.GBP)		AS WinlostGBP,
			
			--- Default Base currency ---
			SUM(w.TurnoverSB*e.DefaultRate)		AS TurnoverSBBase,
			SUM(w.TurnoverNG*e.DefaultRate)		AS TurnoverNGBase,
			SUM(w.TurnoverCS*e.DefaultRate)		AS TurnoverCSBase,
			SUM(w.TurnoverLC*e.DefaultRate)		AS TurnoverLCBase,
			SUM(w.LicenseeWLSB*e.DefaultRate)	AS LicenseeWLSBBase,
			SUM(w.LicenseeWLNG*e.DefaultRate)	AS LicenseeWLNGBase,
			SUM(w.LicenseeWLCS*e.DefaultRate)	AS LicenseeWLCSBase,
			SUM(w.LicenseeWLLC*e.DefaultRate)	AS LicenseeWLLCBase,
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