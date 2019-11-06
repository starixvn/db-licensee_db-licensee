/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_Rpt_Audit_DailyBets_Total]  	
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
    SET NOCOUNT ON
	DECLARE @Product TABLE (ProductCode VARCHAR(10))

	DECLARE @Currency AS TABLE(Id INT, Code VARCHAR(5), ExRate FLOAT)

	INSERT INTO @Product (ProductCode)
	SELECT ISNULL(Val,'') 	
	FROM dbo.strSplit(@ProductCodes,',')

	-- Get Currency
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@CurrencyList
		INSERT INTO @Currency (Id, Code)
		SELECT 
			Id,
			CASE  
                WHEN Id = 20 THEN 'UUS' 
                WHEN Id = 51 THEN 'VND' 
                WHEN Id = 70 THEN 'MMK' 
                ELSE Code
            END
		FROM OPENXML(@DocHandler, '/ROOT/CR', 1) WITH (Id [int], Code VARCHAR(5)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'
		RETURN
	END CATCH;

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
	DECLARE @Sql NVARCHAR(MAX)
	
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
END
GO