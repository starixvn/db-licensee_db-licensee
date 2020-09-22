/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets_Total]  	
	@SiteName		VARCHAR(50),
	@Date			DATE,
	@ProductCodes	VARCHAR(100),
	@CurrencyList   VARCHAR(500),
	@BaseCurrency	VARCHAR(3) = ''
AS 
/*  Created: 20191104@Amanda
    Description: LAP - Implement new report for auditing
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20191104@Amanda: Created new SP [RedmineID: #122789]
		- 20200325@Bobby: Ploutos Integration - [redmine: #125252]
		- 20200917@Sol: Joinning with playerProfile - [redmine: #125252]

	Developer's Notes:
		
    Param's Explanation:  
	  + @CurrencyList: xml structure
					  <ROOT>
					   <Agent Id="13" Code="CNY"/>
					   <Agent Id="51" Code="IDR"/> 
					  </ROOT>
	  EXEC   [dbo].[Lrf_Rpt_Audit_DailyBets]
		    @SiteName = N'Opal88',
		    @Date = '2019-06-20',
		    @ProductCodes = N'SB,NG',
		    @CurrencyList=N'<ROOT><CR Id="13" Code="CNY"/><CR Id="15" Code="IDR"/> </ROOT>'	    
*/
BEGIN  
    SET NOCOUNT ON;

	DECLARE @cutoffDate DATE;
	DECLARE @Product TABLE (ProductCode VARCHAR(10))
	DECLARE @Currency AS TABLE(Id INT, Code VARCHAR(5), ExRate FLOAT)

	--get cutoffDate
	SELECT @cutoffDate = f.CutOffDate 
	FROM Lrf_f_GetCutOffDateBySite() f
	WHERE f.ReportType = 1 AND f.SiteName = @SiteName

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	INSERT INTO @Currency (Id, Code)
	SELECT T.C.value('./@Id', 'INT') AS Id
		,T.C.value('./@Code', 'VARCHAR(5)') AS Code
	FROM (
		VALUES (CAST(@CurrencyList AS XML))
	) AS xd(dataX)
	CROSS APPLY xd.dataX.nodes('/ROOT/CR') AS T(C)

	UPDATE c
	SET c.ExRate = ISNULL(e.Rate, 1)
	FROM @Currency c
	LEFT JOIN dbo.Lrf_f_GetExchangeRate(@Date, @Date, @BaseCurrency, '') e ON c.Id = e.ExchangeId

	IF (@SiteName = 'IvoryBet')
	BEGIN
		SET @SiteName = 'ivorysport'
	END

	DECLARE @TempToDate DATE = DATEADD(DAY, 1, @Date)

	DECLARE @showSB BIT = 0,
			@showNG BIT = 0,
			@showCS BIT = 0,
			@showLC BIT = 0
	
	SELECT @showSB = 1 FROM @Product WHERE ProductCode = 'SB'
	SELECT @showNG = 1 FROM @Product WHERE ProductCode = 'NG'
	SELECT @showCS = 1 FROM @Product WHERE ProductCode = 'CS'
	SELECT @showLC = 1 FROM @Product WHERE ProductCode = 'LC'

	-- Return data	
	SELECT 
		SUM(TotalRows) AS TotalRows
		,SUM(TotalTurnover) AS TotalTurnover
		,SUM(TotalWinLoss) AS TotalWinLoss
	FROM (
		SELECT
			COUNT(a.TransactionId)			AS TotalRows,
			SUM(a.BetAmount * c.ExRate)		AS TotalTurnover,
			- SUM(a.NetAmount * c.ExRate)	AS TotalWinLoss
		FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		WHERE  a.WinLostDate >= @Date AND a.WinLostDate < @TempToDate 
				AND Brand = @SiteName
				AND ( 
					(@showSB = 1 AND a.GameType = 'SB') 
					OR (@showNG = 1 AND a.GameType = 'RNG' AND a.GameCode = '161')
					OR (@showCS = 1 AND a.GameType = 'RNG' AND a.GameCode <> '161')
					OR (@showLC = 1 AND a.GameType = 'CA')
				)
				AND a.WinLostDate < @cutoffDate

		UNION ALL
		SELECT
			COUNT(a.TransactionId)			AS TotalRows,
			SUM(a.BetAmount * c.ExRate)		AS TotalTurnover,
			- SUM(a.NetAmount * c.ExRate)	AS TotalWinLoss
		FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
		WHERE  a.WinLostDate >= @Date AND a.WinLostDate < @TempToDate 
				AND a.BrandCode = @SiteName
				AND ( 
					(@showSB = 1 AND a.GamePlatformCode = 'SB') 
					OR (@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
					OR (@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
					OR (@showLC = 1 AND a.GamePlatformCode = 'CA')
				)
				AND a.WinLostDate >= @cutoffDate
	) AS rpt

END
GO