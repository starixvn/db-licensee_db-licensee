/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_Rpt_SubsidiaryWinlossDetail]
	@FromDate		DATE,
	@ToDate			DATE,
	@MoveBetsDay	DATE,
	@ProductList	VARCHAR(1000),
	@IncludeRaw		BIT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)
AS 
/*  Created: Amanada  
	Date: 20180905
    Task : Subsidiary Performance report - detail [Redmine: #95177]
    DB: DBEXT.bodb02
   
    Revisions:  
		- 20180905@Amanda: Initial SP [Redmine: #95177]

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
		custid			INT,
		Currency		INT,
		Betcount		INT,
		Turnover		MONEY,
		Winlost			MONEY,
		LicenseeWL		MONEY,
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
	
	----- Get Product code
	DECLARE @productCodes AS TABLE (Code VARCHAR(10))
	
	INSERT INTO @productCodes
	SELECT val 
	FROM strSplit(@ProductList, ',')
	
	----- End Get Product code

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
	   

		IF EXISTS (SELECT 1 FROM @productCodes WHERE Code = 'BA')  ---- BA Product
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,
				b.custid,
				a.currency,
				COUNT(b.transid) AS BetCount,
				SUM (stake) AS Turnover,
				SUM (b.winlost-b.actual_stake) AS Winlost,
				SUM (b.comm) AS SubsidiaryComm,  ---- BA Comm
				0 AS LicenseeWL
			FROM bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK) 
				INNER JOIN @TempAg a ON BA.recommend = a.custID
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = BA.transid AND b.recommend = BA.recommend
			WHERE
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
			GROUP BY
				b.winlostdate, b.custid, a.currency
		END


		IF EXISTS (SELECT 1 FROM @productCodes WHERE Code = 'BT')  ---- Bettrade Product
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,
				b.custid,
				a.currency,
				COUNT(CASE WHEN b.bettype = 903 THEN 0 ELSE b.transid END) AS BetCount,
				0 AS Turnover,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.winlost-b.actual_stake END) AS Winlost,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS SubsidiaryComm,   ----BetTradeComm
				0 AS LicenseeWL
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a ON a.CustID = b.recommend
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				  AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
				  AND b.bettype IN (901,902,903)
			GROUP BY
				b.Winlostdate, b.custid, a.currency
		END


		IF EXISTS (SELECT 1 FROM @productCodes WHERE Code = 'CO')  ---- Cashout Product
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,
				b.custid,
				a.currency,
				COUNT(b.transid) AS BetCount,
				0 AS Turnover,
				0 AS Winlost,
				SUM (b.awinlost) AS SubsidiaryComm,   ----Cashout Comm
				0 AS LicenseeWL
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a ON a.CustID = b.recommend
			WHERE b.winlostdate BETWEEN @FDate AND @TDate
				  AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
				  AND b.bettype = 913
			GROUP BY
				b.Winlostdate, b.custid, a.currency
		END

		
		IF EXISTS (SELECT TOP 1 1 FROM #BettypeProduct)  ---- exclude BA , BT, CO
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,
				b.custid,
				a.currency,
				COUNT(b.transid) AS BetCount,
				SUM (stake) AS Turnover,
				SUM (b.winlost-b.actual_stake) AS Winlost,
				0 AS SubsidiaryComm,
				- SUM (b.winlost - b.actual_stake) AS LicenseeWL
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid
				INNER JOIN #BettypeProduct p ON p.bettype = b.bettype
			WHERE
				b.winlostdate BETWEEN @FDate AND @TDate
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111))
				AND b.matchID > 0
				AND (p.ProductCode <> 'SB' OR b.tpositiontaking <> 0 )  --- EXCLUDE BA
			GROUP BY
				b.Winlostdate, b.custid, a.currency
		END	

		 
	END
		
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SET @FDate = @FromDate
		IF @ToDate >= @MoveBetsDay
				SET @TDate = @MoveBetsDay
			ELSE
				SET @TDate = @ToDate
	

		IF EXISTS (SELECT 1 FROM @productCodes WHERE Code = 'BA')  ---- BA
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,
				b.custid,
				a.currency,
				SUM (b.betcount) AS BetCount,
				SUM (b.turnover) AS Turnover,
				SUM (b.winlost) AS Winlost,
				SUM (b.comm) AS SubsidiaryComm,
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
				b.Winlostdate, b.custid, a.currency
		END

		IF EXISTS (SELECT 1 FROM @productCodes WHERE Code = 'BT')  
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,
				b.custid,
				a.currency,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.BetCount END) AS BetCount,
				0 AS Turnover,
				SUM(CASE WHEN b.bettype = 903 THEN 0 ELSE b.winlost END) AS Winlost,
				SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS SubsidiaryComm,
				0 AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid
			WHERE
				b.winlostdate BETWEEN @FDate AND @TDate
				AND b.roleid = 1
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
				AND b.bettype IN (901,902,903)
			GROUP BY
				b.Winlostdate, b.custid, a.currency
		END

		IF EXISTS (SELECT 1 FROM @productCodes WHERE Code = 'CO')
		BEGIN
			INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
			SELECT
				b.Winlostdate,
				b.custid,
				a.currency,
				SUM(b.BetCount) AS BetCount,
				0 AS Turnover,
				0 AS Winlost,
				SUM(b.awinlost) AS SubsidiaryComm,
				0 AS LicenseeWL
			FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid
			WHERE
				b.winlostdate BETWEEN @FDate AND @TDate
				AND b.roleid = 1
				AND (b.statusID IN (112, 113) OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
				AND b.bettype = 913
			GROUP BY
				b.Winlostdate, b.custid, a.currency
		END


		IF EXISTS (SELECT TOP 1 1 FROM #BettypeProduct)     --- exclude BA , BT, CO
		BEGIN
				INSERT INTO #Subsidiary (Winlostdate, custid, Currency, BetCount, Turnover, Winlost, SubsidiaryComm, LicenseeWL)
				SELECT
					b.Winlostdate,
					b.custid,
					a.currency,
					SUM (b.betcount) AS BetCount,
					SUM (b.turnover) AS Turnover,
					SUM (b.winlost) AS Winlost,
					0 AS SubsidiaryComm,
					-SUM (b.winlost) AS Winlost
				FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)
				INNER JOIN #SporttypeProduct p ON b.sporttype = p.sporttype
				INNER JOIN @TempAg a ON b.recommend = a.custid
				WHERE
					b.winlostdate BETWEEN @FDate AND @TDate
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND b.roleid = 1
					AND (b.statusID IN (112,113,114,115) OR (@IncludeRaw = 1 AND b.statusID = 111)) --exclude REJECT bets
					AND b.isBA = 0
				GROUP BY b.Winlostdate, b.custid, a.currency
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
		s.Currency,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
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
		INNER JOIN Customer c WITH (NOLOCK) ON s.custid = c.custid
		INNER JOIN #Exchange e ON s.winlostdate BETWEEN e.ExFromDate AND e.ExToDate AND s.currency = e.ExchangeId
	GROUP BY c.username, c.username2, s.currency
	
	DROP TABLE #Subsidiary
	DROP TABLE #Exchange
	DROP TABLE #BettypeProduct
	DROP TABLE #SporttypeProduct

END
GO