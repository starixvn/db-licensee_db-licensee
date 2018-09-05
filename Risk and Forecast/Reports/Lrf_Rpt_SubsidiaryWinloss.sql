/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_SubsidiaryWinloss]  	
	@FromDate		DATE,  
	@ToDate			DATE,    
	@MoveBetsDay	DATE, 
	@ProductList	VARCHAR(1000),
	@IncludeRaw		BIT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)
AS 
/*  Created: Sophia  
	Date: 20170829
    Task : Subsidiary Performance report [Redmine: #76246]
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20170829@Sophia: Initial SP [Redmine: #76246]
		- 20171226@Harper: Return more column for report [RedmineID: #88398]
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]

	Param's Explanation:  
	
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT>
*/  
BEGIN  

	SET NOCOUNT ON  

	CREATE TABLE #Subsidiary
	(  
		WinlostDate		DATE,
		recommend		INT,
		Currency		INT,
		ProductCode		VARCHAR(10),
		Betcount		INT,
		Turnover		MONEY,		
		Winlost			MONEY,
		LicenseeWL	MONEY,
		SubsidiaryComm	MONEY
	)
	

	DECLARE @FDate DATE, @TDate DATE
	SELECT @FDate = @FromDate, @TDate = @ToDate

	-----Begin Get AgentList
	BEGIN 
		DECLARE @tempAg	TABLE (custID INT, currency INT)

		DECLARE @DocHandler INT

		BEGIN TRY
			EXEC sp_xml_preparedocument @DocHandler OUTPUT
					,@AgentList
			INSERT INTO @TempAg (custID, currency)
			SELECT AgentId, Currency
			FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

			EXEC sp_xml_removedocument @DocHandler
		END TRY

		BEGIN CATCH
			SELECT ErrCode = 100
					,ErrMsg = N'Paramter invalid.'

			RETURN
		END CATCH;
	END
	----- End Get AgentList

	----- Get SportBettypeMatrix
	BEGIN
		CREATE TABLE #BettypeProduct (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
		CREATE TABLE #SporttypeProduct (sporttype INT, ProductCode VARCHAR(10))

		DECLARE @IsTest BIT = 0
		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID) 
			
		-- Insert Bettype
		INSERT INTO #BettypeProduct ( bettype, ProductCode)		--- Don't have ProductCode IN (BA, BT, CO)
		SELECT DISTINCT BetType, ProductPrefix
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
		WHERE Bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)

		-- Insert Sport Type
		INSERT INTO #SporttypeProduct ( sporttype, ProductCode )   --- Don't have ProductCode IN (BA, BT, CO)
		SELECT DISTINCT sporttype, ProductCode
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)   
			 
	END	
	-----End Get SportBettypeMatrix
	

	IF @ToDate > @MoveBetsDay
	BEGIN
		SET @TDate = @ToDate
		IF @FromDate <= @MoveBetsDay 
			SET @FDate = DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @FDate = @FromDate
	   

		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BA')  ---- BA Product
		BEGIN
			;WITH BA AS
			(
				SELECT DISTINCT transid
				FROM
					bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
					INNER JOIN @tempAg r ON BA.recommend = r.custID
				UNION
				SELECT NULL
			)
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,	
				b.recommend,
				a.currency,
				'BA' ProductCode,  
				COUNT(CASE WHEN RAND() + 1 > 0 THEN b.transid ELSE 0 END) AS BetCount,
				SUM (CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END) AS Turnover, 
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS SubsidiaryComm,  ---- BA Comm
				0 AS LicenseeWL
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a 
					ON a.CustID = b.recommend   
				INNER JOIN BA WITH (NOLOCK) 
					ON b.transid = BA.transid 	 	
			WHERE	
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency
		END


		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BT')  ---- Bettrade Product
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,	
				b.recommend,
				a.currency,
				'BT' ProductCode,  
				COUNT(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS Turnover, 
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS SubsidiaryComm,   ----BetTradeComm
				0 AS LicenseeWL
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a 
					ON a.CustID = b.recommend  					 	
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				  AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
				  AND b.bettype IN (901,902,903)
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency
		END


		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'CO')  ---- Cashout Product
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,	
				b.recommend,
				a.currency,
				'CO' ProductCode,  
				COUNT(CASE WHEN RAND() + 1 > 0 THEN b.transid ELSE 0 END) AS BetCount,
				0 AS Turnover, 
				0 AS Winlost,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.awinlost ELSE 0 END) AS SubsidiaryComm,   ----Cashout Comm
				0 AS LicenseeWL
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a 
					ON a.CustID = b.recommend  					 	
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				  AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
				  AND b.bettype = 913
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency
		END

		
		IF EXISTS (SELECT TOP 1 1 FROM #BettypeProduct)  ---- exclude BA , BT, CO
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,   
				b.recommend,
				a.currency,
				p.ProductCode,
				COUNT(CASE WHEN RAND() + 1 > 0 THEN b.transid ELSE 0 END) AS BetCount,
				SUM (CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END) AS Turnover, 
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,  
				0 AS SubsidiaryComm,
				- SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost - b.actual_stake ELSE 0 END) AS LicenseeWL  ---- Licensee Winlost or RB Comm 
			FROM 
				dbo.bettrans b WITH (NOLOCK)  
				INNER JOIN @TempAg a ON b.recommend = a.custid 
				INNER JOIN #BettypeProduct p ON p.bettype = b.bettype
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
				AND b.matchID > 0 
				AND (CASE WHEN p.ProductCode ='SB' THEN b.tpositiontaking ELSE 1 END <> 0 )  --- EXCLUDE BA 
				
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency, 
				p.ProductCode
		END	

		 
	END
		
	IF @FromDate <= @MoveBetsDay 
	BEGIN
		SET @FDate = @FromDate
		IF @ToDate >= @MoveBetsDay
				SET @TDate = @MoveBetsDay
			ELSE
				SET @TDate = @ToDate
	

		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BA')  ---- BA 
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT  
				b.Winlostdate, 
				b.recommend,
				a.currency,
				'BA' AS ProductCode,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.betcount ELSE 0 END) AS BetCount,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END) AS Turnover, 
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost,  
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS SubsidiaryComm,
				0 AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
				INNER JOIN @TempAg a ON b.recommend = a.custid 
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND b.roleid = 1   
				AND ( b.statusID <> 101 AND (@IncludeRaw = 1 OR b.statusID <> 111 )) --exclude REJECT bets
				AND b.isBA = 1 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency 
		END	

		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BT')  
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT  
				b.Winlostdate, 
				b.recommend,
				a.currency,
				'BT' AS ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.BetCount END) AS BetCount,
				0 AS Turnover, 
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,     
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS SubsidiaryComm,
				0 AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
				INNER JOIN @TempAg a ON b.recommend = a.custid 
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND b.roleid = 1   
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
				AND b.bettype IN (901,902,903)
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency 
		END	

		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'CO') 
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT  
				b.Winlostdate, 
				b.recommend,
				a.currency,
				'CO' AS ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.BetCount ELSE 0 END) AS BetCount,
				0 AS Turnover, 
				0 AS Winlost,  
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.awinlost ELSE 0 END) AS SubsidiaryComm,
				0 AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
				INNER JOIN @TempAg a ON b.recommend = a.custid 
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND b.roleid = 1   
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
				AND b.bettype = 913
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency 
		END	


		IF EXISTS (SELECT TOP 1 1 FROM #BettypeProduct)     --- exclude BA , BT, CO
		BEGIN
				INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
						b.Winlostdate,
						b.recommend,
						b.currency,
						p.ProductCode,
						SUM ( b.betcount) AS BetCount,
						SUM (b.turnover) AS Turnover, 
						SUM (b.winlost) AS Winlost,  
						0 AS SubsidiaryComm,
						-SUM(b.winlost) AS LicenseeWL
			FROM	( 
						SELECT   
							b.Winlostdate,
							b.recommend,
							a.currency,
							b.sporttype,
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.betcount ELSE 0 END) AS BetCount,
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END) AS Turnover, 
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost,  
							SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS comm
						FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
							INNER JOIN @TempAg a ON b.recommend = a.custid 						 
						WHERE 
							b.winlostdate BETWEEN @FDate AND @TDate 					
							AND (b.bettype < 901 OR b.bettype > 904)
							AND (b.bettype < 911 OR b.bettype > 914)
							AND b.roleid = 1   
							AND (b.statusID IN (112,113,114,115) OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
							AND b.isBA = 0 
						GROUP BY   
							b.Winlostdate, b.recommend, a.currency, b.sporttype
					) b 
				INNER JOIN #SporttypeProduct p ON b.sporttype = p.sporttype
			GROUP BY b.Winlostdate, b.recommend, b.currency, p.ProductCode
		END	 
	END
		
	CREATE TABLE #Exchange (ExFromDate DATE, ExToDate DATE, ExchangeID INT, Rate FLOAT)
	
	;WITH Currency_CTE (CurrencyID) AS (
											SELECT DISTINCT currency
											FROM @tempAg
										)
	INSERT INTO #Exchange(ExFromDate, ExToDate, ExchangeID, Rate)
	SELECT	FirstExchangeDateByMonth, 
			LastExchangeDateByMonth,
			ExchangeID,
			CASE 
				WHEN @BaseCurrency = 'USD' THEN USD
				WHEN @BaseCurrency = 'EUR' THEN EUR
				WHEN @BaseCurrency = 'GBP' THEN GBP
				WHEN @BaseCurrency = 'MYR' THEN MYR
				WHEN @BaseCurrency = 'CNY' THEN CNY
				WHEN @BaseCurrency = 'THB' THEN THB
				WHEN @BaseCurrency = 'IDR' THEN IDR
				ELSE 1
			END
	FROM dbo.Lrf_f_GetSubExchangeDaily(@FromDate, @ToDate) e
	INNER JOIN Currency_CTE c ON e.ExchangeId = c.CurrencyID
			  
	SELECT   
		s.recommend,
		s.Currency,
		s.ProductCode,		 
		SUM (BetCount)	AS BetCount,
		SUM(Turnover)	AS Turnover, 
		SUM(Winlost)	AS Winlost,
		SUM(LicenseeWL)	AS LicenseeWL,
		SUM(SubsidiaryComm)	AS SubsidiaryComm,

		SUM(Turnover*e.Rate)		AS TurnoverBase, 
		SUM(Winlost*e.Rate)			AS WinlostBase,
		SUM(LicenseeWL*e.Rate)		AS LicenseeWLBase,
		SUM(SubsidiaryComm*e.Rate)	AS SubsidiaryCommBase
	FROM	
		#Subsidiary s   
		INNER JOIN #Exchange e ON s.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND s.currency = e.ExchangeId
	GROUP BY  s.recommend, s.currency, s.ProductCode

	DROP TABLE #Subsidiary
	DROP TABLE #Exchange
	DROP TABLE #BettypeProduct
	DROP TABLE #SporttypeProduct

END
GO