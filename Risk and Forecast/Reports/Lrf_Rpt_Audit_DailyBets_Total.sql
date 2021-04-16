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
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20191104@Amanda: Created new SP [RedmineID: #122789]
		- 20200325@Bobby: Ploutos Integration - [redmine: #125252]
		- 20200917@Sol: Joinning with playerProfile - [redmine: #125252]
		- 20200924@Sol: Convert INH to VND - [redmine: #139910]
		- 20201201@Sol: Audit - Add mode sum by SettlementTime - [Redmine: #146188]
		- 20210517@Sol: Audit - show data with status = 0 orr 1 - [Redmine: #155266]
		- 20210416@Sol: Get data from archived table and main table - [Redmine: #152202]

	Developer's Notes:
		
    Param's Explanation:  
	  + @CurrencyList: xml structure
					  <ROOT>
					   <Agent Id="13" Code="CNY"/>
					   <Agent Id="51" Code="INH"/> 
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
	DECLARE @ArchivedDate DATE

	--get archived date -> last day of archived month => add 1 more day to cover time, such as: 23:59:59 
	SELECT @ArchivedDate = DATEADD(DAY, 1, CAST(s.VValue AS DATE))
	FROM dbo.SystemSettings s WITH(NOLOCK)
	WHERE s.VName = 'PloutosArchivedMonth'

	--get cutoffDate
	SELECT @cutoffDate = f.CutOffDate 
	FROM Lrf_f_GetCutOffDateBySite() f
	WHERE f.ReportType = 1 AND f.SiteName = @SiteName

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	;WITH CTE_Currency AS (
		SELECT T.C.value('./@Id', 'INT') AS Id
			,T.C.value('./@Code', 'VARCHAR(5)') AS Code
		FROM (
			VALUES (CAST(@CurrencyList AS XML))
		) AS xd(dataX)
		CROSS APPLY xd.dataX.nodes('/ROOT/CR') AS T(C)
	)
	INSERT INTO @Currency (Id, Code)
	SELECT 
		Id,
		CASE  
            WHEN Id = 20 THEN 'UUS' 
            WHEN Id = 51 THEN 'VND' 
            WHEN Id = 70 THEN 'MMK' 
            ELSE Code
        END
	FROM CTE_Currency

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
		WHERE  Brand = @SiteName
				AND ( 
					(@showSB = 1 AND a.GameType = 'SB') 
					OR (@showNG = 1 AND a.GameType = 'RNG' AND a.GameCode = '161')
					OR (@showCS = 1 AND a.GameType = 'RNG' AND a.GameCode <> '161')
					OR (@showLC = 1 AND a.GameType = 'CA')
				)
				AND a.SettlementDate >= @Date AND a.SettlementDate < @TempToDate 
				AND a.SettlementDate < @cutoffDate
				AND a.SettlementDate >= @ArchivedDate
		UNION ALL 
		SELECT
			COUNT(a.TransactionId)			AS TotalRows,
			SUM(a.BetAmount * c.ExRate)		AS TotalTurnover,
			- SUM(a.NetAmount * c.ExRate)	AS TotalWinLoss
		FROM bodb_licenseeReportArchive.dbo.rptDep_AuditTickets_BK a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		WHERE  Brand = @SiteName
				AND ( 
					(@showSB = 1 AND a.GameType = 'SB') 
					OR (@showNG = 1 AND a.GameType = 'RNG' AND a.GameCode = '161')
					OR (@showCS = 1 AND a.GameType = 'RNG' AND a.GameCode <> '161')
					OR (@showLC = 1 AND a.GameType = 'CA')
				)
				AND a.SettlementDate >= @Date AND a.SettlementDate < @TempToDate 
				AND a.SettlementDate < @cutoffDate
				AND a.SettlementDate < @ArchivedDate

		UNION ALL
		SELECT
			COUNT(a.TransactionId)			AS TotalRows,
			SUM(a.BetAmount * c.ExRate)		AS TotalTurnover,
			- SUM(a.NetAmount * c.ExRate)	AS TotalWinLoss
		FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
		WHERE  
			a.BrandCode = @SiteName
			AND a.StatusID IN (0, 1)
			AND a.SettlementDate >= @Date AND a.SettlementDate < @TempToDate 
			AND a.SettlementDate >= @cutoffDate
			AND ( 
				(@showSB = 1 AND a.GamePlatformCode = 'SB') 
				OR (@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
				OR (@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
				OR (@showLC = 1 AND a.GamePlatformCode = 'CA')
			)
			AND a.SettlementDate >= @ArchivedDate
		UNION ALL
		SELECT
			COUNT(a.TransactionId)			AS TotalRows,
			SUM(a.BetAmount * c.ExRate)		AS TotalTurnover,
			- SUM(a.NetAmount * c.ExRate)	AS TotalWinLoss
		FROM bodb_Ploutos.dbo.BetTicket a WITH (NOLOCK)
		INNER JOIN @Currency c ON c.Code = a.CurrencyCode
		INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.BrandCode = a.BrandCode AND pp.CustID = a.CustId
		WHERE  
			a.BrandCode = @SiteName
			AND a.StatusID = 1
			AND a.SettlementDate >= @Date AND a.SettlementDate < @TempToDate 
			AND a.SettlementDate >= @cutoffDate
			AND ( 
				(@showSB = 1 AND a.GamePlatformCode = 'SB') 
				OR (@showNG = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode = '0161')
				OR (@showCS = 1 AND a.GamePlatformCode = 'RNG' AND a.GameCode <> '0161')
				OR (@showLC = 1 AND a.GamePlatformCode = 'CA')
			)
			AND a.SettlementDate < @ArchivedDate

	) AS rpt

END
GO