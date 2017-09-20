/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_SubsidiaryWinloss]  	
	@FromDate		SMALLDATETIME,  
	@ToDate			SMALLDATETIME,    
	@MoveBetsDay	SMALLDATETIME, 
	@ProductList	VARCHAR(1000),
	@AgentList		VARCHAR(MAX)
AS 
/*  Created: Sophia  
	Date: 20170829
    Task : Subsidiary Performance report [Redmine: #76246]
    DB: DBEXT.bodb02
   
    Revisions:  
    - 20170829@Sophia: Initial SP

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
		WinlostDate		SMALLDATETIME,
		recommend		INT,
		Currency		INT,
		ProductCode		VARCHAR(10),
		Betcount		INT,
		Turnover		MONEY,		
		Winlost			MONEY,
		LicenseeWL		MONEY	
	)
	

	DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME
	SELECT @FDate = @FromDate, @TDate = @ToDate

	DECLARE @VNDCurrencyName VARCHAR(20)
	SELECT @VNDCurrencyName = currency FROM dbo.exchange (NOLOCK) WHERE ExchangeId = 51

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
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT
				b.Winlostdate,	
				b.recommend,
				a.currency,
				'BA' ProductCode,  
				COUNT(CASE WHEN RAND() + 1 > 0 THEN b.transid ELSE 0 END) AS BetCount,
				SUM (CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END) AS Turnover, 
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeWL  ---- BA Comm
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a 
					ON a.CustID = b.recommend   
				INNER JOIN BA WITH (NOLOCK) 
					ON b.transid = BA.transid 	 	
			WHERE	
				b.winlostdate BETWEEN @FDate AND @TDate
				AND b.statusID IN (111, 112, 113) 				
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency
		END


		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BT')  ---- Bettrade Product
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT
				b.Winlostdate,	
				b.recommend,
				a.currency,
				'BT' ProductCode,  
				COUNT(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN NULL ELSE b.transid END) AS BetCount,
				0 AS Turnover, 
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS LicenseeWL   ----BetTradeComm
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a 
					ON a.CustID = b.recommend  					 	
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				  AND b.statusID IN (111, 112, 113) 				
				  AND b.bettype IN (901,902,903)
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency
		END


		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'CO')  ---- Cashout Product
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT
				b.Winlostdate,	
				b.recommend,
				a.currency,
				'CO' ProductCode,  
				COUNT(CASE WHEN RAND() + 1 > 0 THEN b.transid ELSE 0 END) AS BetCount,
				0 AS Turnover, 
				0 AS Winlost,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.awinlost ELSE 0 END) AS LicenseeWL   ----Cashout Comm
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a 
					ON a.CustID = b.recommend  					 	
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				  AND b.statusID IN (111, 112, 113) 				
				  AND b.bettype = 913
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency
		END

		
		IF EXISTS (SELECT TOP 1 1 FROM #BettypeProduct)  ---- exclude BA , BT, CO
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT
				b.Winlostdate,   
				b.recommend,
				a.currency,
				p.ProductCode,
				COUNT(CASE WHEN RAND() + 1 > 0 THEN b.transid ELSE 0 END) AS BetCount,
				SUM (CASE WHEN RAND() + 1 > 0 THEN stake ELSE 0 END) AS Turnover, 
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS Winlost,  
				- SUM (CASE WHEN RAND() + 1 > 0 THEN CASE WHEN p.ProductCode ='RB' THEN - b.comm ELSE b.winlost - b.actual_stake END ELSE 0 END) AS LicenseeWL  ---- Licensee Winlost or RB Comm 
			FROM 
				dbo.bettrans b WITH (NOLOCK)  
				INNER JOIN @TempAg a ON b.recommend = a.custid 
				INNER JOIN #BettypeProduct p ON p.bettype = b.bettype
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND b.statusID IN (111, 112, 113)	
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
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT  
				b.Winlostdate, 
				b.recommend,
				a.currency,
				'BA' AS ProductCode,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.betcount ELSE 0 END) AS BetCount,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END) AS Turnover, 
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost,  
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
				INNER JOIN @TempAg a ON b.recommend = a.custid 
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND b.isBA = 1 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency 
		END	

		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BT')  
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT  
				b.Winlostdate, 
				b.recommend,
				a.currency,
				'BT' AS ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.BetCount END) AS BetCount,
				0 AS Turnover, 
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,     
				SUM(CASE WHEN RAND() + 1 > 0 AND b.bettype = 903 THEN b.awinlost ELSE 0 END) AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
				INNER JOIN @TempAg a ON b.recommend = a.custid 
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND b.roleid = 1   
				AND b.statusID IN (111,112,113) --exclude REJECT bets			 
				AND b.bettype IN (901,902,903)
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency 
		END	

		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'CO') 
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT  
				b.Winlostdate, 
				b.recommend,
				a.currency,
				'CO' AS ProductCode,
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.BetCount ELSE 0 END) AS BetCount,
				0 AS Turnover, 
				0 AS Winlost,  
				SUM(CASE WHEN RAND() + 1 > 0 THEN b.awinlost ELSE 0 END) AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
				INNER JOIN @TempAg a ON b.recommend = a.custid 
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate  				
				AND b.roleid = 1   
				AND b.statusID IN (111,112,113) --exclude REJECT bets			
				AND b.bettype = 913
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency 
		END	


		IF EXISTS (SELECT TOP 1 1 FROM #BettypeProduct)     --- exclude BA , BT, CO
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, recommend, Currency, ProductCode, BetCount, Turnover, Winlost, LicenseeWL)
			SELECT   
				b.Winlostdate,
				b.recommend,
				a.currency,
				p.ProductCode,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.betcount ELSE 0 END) AS BetCount,
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END) AS Turnover, 
				SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost,  
				-SUM(CASE WHEN RAND() + 1 > 0 THEN CASE WHEN p.ProductCode ='RB' THEN - b.comm ELSE b.winlost END ELSE 0 END) AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
				INNER JOIN @TempAg a ON b.recommend = a.custid 
				INNER JOIN #SporttypeProduct p ON b.sporttype = p.sporttype
			WHERE 
				b.winlostdate BETWEEN @FDate AND @TDate 					
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND b.roleid = 1   
				AND b.statusID IN (111,112,113,114,115) --exclude REJECT bets
				AND b.isBA = 0 
			GROUP BY   
				b.Winlostdate, b.recommend, a.currency, p.ProductCode
		END	 
	END
		
	SELECT * 
	INTO #TempExchange 
	FROM  dbo.Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Subsidiary)
			  
	SELECT   
		s.recommend,
		s.Currency,
		CASE WHEN Currency = 51 THEN @VNDCurrencyName 
			WHEN Currency = 70 THEN 'MKK'
		ELSE e.Code END CurrencyName,

		s.ProductCode,		 
		SUM (BetCount)	AS BetCount,
		SUM(Turnover)	AS Turnover, 
		SUM(Winlost)	AS Winlost,
		SUM(LicenseeWL)	AS LicenseeWL,

		SUM(Turnover*e.USD)	AS TurnoverUSD, 
		SUM(Winlost*e.USD)	AS WinlostUSD,
		SUM(LicenseeWL*e.USD) AS LicenseeWLUSD,

		SUM(Turnover*e.EUR)	AS TurnoverEUR, 
		SUM(Winlost*e.EUR)	AS WinlostEUR,
		SUM(LicenseeWL*e.EUR) AS LicenseeWLEUR,

		SUM(Turnover*e.GBP)	AS TurnoverGBP, 
		SUM(Winlost*e.GBP)	AS WinlostGBP,
		SUM(LicenseeWL*e.GBP) AS LicenseeWLGBP
	FROM	
		#Subsidiary s   
		INNER JOIN #TempExchange e ON s.winlostdate = e.ExchangeDate AND s.currency = e.ExchangeId
	GROUP BY  s.recommend, s.currency, s.ProductCode,	
			  CASE WHEN Currency = 51 THEN @VNDCurrencyName WHEN Currency = 70 THEN 'MKK' ELSE e.Code END  
	ORDER BY CurrencyName

	DROP TABLE #Subsidiary
	DROP TABLE #TempExchange
	DROP TABLE #BettypeProduct
	DROP TABLE #SporttypeProduct

END
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_SubsidiaryWinloss] TO [bodbLicenseeNet]
GO