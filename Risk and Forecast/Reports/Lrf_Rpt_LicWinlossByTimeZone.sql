/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_LicWinlossByTimeZone]  	
	@FromDate			SMALLDATETIME,  
	@ToDate				SMALLDATETIME,   
	@TimeZone			SMALLINT = -4,
	@ProductList		VARCHAR(MAX) = '',	
	@MoveBetsDay		SMALLDATETIME,
	@AgentList			VARCHAR(MAX),
	@CurrencyId 		INT = 0,
	@IncludeDraw		BIT = 0,	
	@ReportBy			TINYINT = 1,  
	@GroupBy 			TINYINT = 1,
	@BaseCurrency		VARCHAR(3) = ''
AS

/*  Created: 20171201@Sophia
	Date: 2012-01-09
    Task : Winloss Report for Licensee by Time Zone [Redmine: #84932]
    DB: DBEXT.bodb02  
   
    Revisions:   
		- 20171201@Sophia: initial version. Apply for Sportsbook first [redmine: #84932]
		- 20171226@Percy: Remove redundant code [RedmineID: #88704] 
		- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
		- 20190614@Amanda: Add Base currency param [RedmineID: #112531]

	Param's Explanation:  
	  + @TimeZone: =-4: GMT-4
				   = 8: GMT+8
	  + @ProductCodes: = @ProductCodes (multiple selection) ('SB', 'BA')
 	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @ReportBy: = 1: Summary 
				   = 2: Daily
				   = 3: Monthly
	  + @GroupBy: = 1: Product
				  = 2: Currency 
	  +	@IncludeDraw: = 0: 
	  + @CurrencyId : = 0: All Currency
					  = @CurrencyId (Single selection) 
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12346" Currency="5"/>  
					  </ROOT>
*/ 

BEGIN  

	SET NOCOUNT ON  

	CREATE TABLE #WinLoss
	(	
		RptDateGMT			DATE,  
		RptDate				DATE,
		CurrencyId			INT,
		ProductCode			VARCHAR(10),
		BetCount			BIGINT,
		Turnover			MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,		
		LicenseeComm		MONEY
	)
	
	CREATE TABLE #Exchange	(FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeID INT, Rate FLOAT )
	
	---#1: Begin: Get AgentList 	
	DECLARE @TempAg AS TABLE(custID INT, currency INT)  
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList

		INSERT INTO @TempAg (CustID, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	---#1: End: Get AgentList 

	---#2: Begin: Get SportBettypeMatrix
	BEGIN
		CREATE TABLE #BettypeProduct (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
		CREATE TABLE #SporttypeProduct (sporttype INT, ProductCode VARCHAR(10))

		DECLARE @IsTest BIT = 0
		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID) 
			
		-- Insert Bettype
		INSERT INTO #BettypeProduct ( bettype, ProductCode)		--- Don't have ProductCode IN (BA, BT, CO) because SportBettypeMatrix don't have ProductPrefix = 'BA'
		SELECT DISTINCT BetType, ProductPrefix
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)  --- This phase @ProductList is only ('SB', 'BA')
		WHERE Bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)

		-- Insert Sport Type
		INSERT INTO #SporttypeProduct ( sporttype, ProductCode )   --- Don't have ProductCode IN (BA, BT, CO)
		SELECT DISTINCT sporttype, ProductCode
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)   
			 
	END	
	---#2: End: Get SportBettypeMatrix

	----------------- ######## Get data ########## ---------------
	DECLARE @FromDateLicWL2 SMALLDATETIME, @ToDateLicWL2 SMALLDATETIME, 
			@FromDateBettrans SMALLDATETIME, @ToDateBettrans SMALLDATETIME


	--------------## I: Begin :TimeZone = -4 ## -------------
	IF @TimeZone = -4  
	BEGIN 
			
		---#I.1: Begin : Get data from rptLicWinloss2 table
		IF @FromDate <= @MoveBetsDay
		BEGIN 			
			SELECT  @FromDateLicWL2 = @FromDate 

			IF @ToDate > @MoveBetsDay
				SELECT @ToDateLicWL2 = @MoveBetsDay
			ELSE 
				SELECT @ToDateLicWL2 = @ToDate

			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA 
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
						b.winlostdate,  
						b.winlostdate, 				
						a.currency,
						'BA' AS ProductCode,
						SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.Turnover ELSE 0 END
							*
							CASE WHEN @IncludeDraw = 0 THEN
								CASE
									WHEN b.statusID = 111 THEN 0
									WHEN b.statusID IN (114, 115) THEN 0.5
									ELSE 1 END
							ELSE 1 END) AS Turnover, 
						0 AS LicenseeWL,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM bodb_LicenseeReport.dbo.rptLicWinloss2 b WITH (NOLOCK)  
					INNER JOIN @TempAg a ON b.recommend = a.custID  
				WHERE 
					b.winlostdate BETWEEN @FromDateLicWL2 AND @ToDateLicWL2  		
					AND b.roleid = 2   
					AND b.statusID IN (111,112,113,114,115) --exclude REJECT bets
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND b.isBA = 1 
				GROUP BY   
					b.winlostdate, a.currency 
			END

			IF EXISTS (SELECT 1 FROM #BettypeProduct WHERE ProductCode = 'SB')     --- exclude BA , BT, CO
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
							b.winlostdate,	
							b.winlostdate,						 
							b.currency,
							p.ProductCode,
							SUM (b.betcount) AS BetCount,
							SUM (b.turnover) AS Turnover, 
							SUM (b.winlost) AS LicenseeWL,  
							SUM(b.PlayerComm) AS PlayerComm,
							SUM(b.comm) AS LicenseeComm						 
				FROM	( 
							SELECT   
								b.winlostdate, 
								a.currency,
								b.sporttype,
								SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
								SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
									*
									CASE WHEN @IncludeDraw = 0 THEN
										CASE
											WHEN b.statusID = 111 THEN 0
											WHEN b.statusID IN (114, 115) THEN 0.5
											ELSE 1 END
									ELSE 1 END) AS Turnover, 
								-SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost,  								
								SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
								SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS Comm
							FROM bodb_licenseereport.dbo.rptLicWinloss2 b WITH (NOLOCK)  				
								INNER JOIN @TempAg a ON b.recommend = a.custID 						 
							WHERE 
								b.winlostdate BETWEEN @FromDateLicWL2 AND @ToDateLicWL2 	
								AND b.roleid = 2   
								AND b.statusID IN (111,112,113,114,115) --exclude REJECT bets
								AND (b.bettype < 901 OR b.bettype > 904)
								AND (b.bettype < 911 OR b.bettype > 914)
								AND b.isBA = 0 
							GROUP BY   
								b.winlostdate, a.currency, b.sporttype
						) b 
					INNER JOIN #SporttypeProduct p ON b.sporttype = p.sporttype
				GROUP BY b.winlostdate, b.currency, p.ProductCode
			END	 

		END 
		---#I.1: End : Get data from rptLicWinloss2 table (Old data of SB GMT-4)  

		---#I.2: Begin : Get data from Bettrans table after Movebetsday 
		IF @ToDate > @MoveBetsDay
		BEGIN	
			SELECT @ToDateBettrans = @ToDate

			IF @Fromdate <= @MoveBetsDay
				SELECT @FromDateBettrans = DATEADD(DAY, 1, @MoveBetsDay)
			ELSE 
				SELECT @FromDateBettrans = @Fromdate
			
			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA Product
			BEGIN
				;WITH BA AS
				(
					SELECT DISTINCT transid
					FROM bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
						INNER JOIN @TempAg r ON BA.recommend = r.custID
				)
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT	b.Winlostdate,
						b.Winlostdate, 
						b.Currency,
						'BA' ProductCode,  
						COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
							*
							CASE WHEN @IncludeDraw = 0 THEN
								CASE
									WHEN b.statusID = 111 THEN 0
									WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
									ELSE 1 END
							ELSE 1 END) AS Turnover, 
						0 AS LicenseeWL,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM	dbo.bettrans b WITH (NOLOCK)
					INNER JOIN @TempAg a ON a.CustID = b.recommend
					INNER JOIN BA WITH (NOLOCK) 
						ON b.transid = BA.transid 	 	
				WHERE	b.winlostdate BETWEEN @FromDateBettrans AND @ToDateBettrans
						AND b.statusID IN (111, 112, 113)
				GROUP BY b.Winlostdate, b.recommend, b.currency
			END

			IF EXISTS (SELECT 1 FROM #BettypeProduct WHERE ProductCode = 'SB')  ---- SB exclude BA , BT, CO 
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					b.Winlostdate,  
					b.Winlostdate, 				
					b.currency,
					p.ProductCode,
					COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
						*
						CASE WHEN @IncludeDraw = 0 THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END) AS Turnover, 
					- SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWL,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  
				FROM dbo.bettrans b WITH (NOLOCK)  
					INNER JOIN @TempAg a ON b.recommend = a.custid
					INNER JOIN #BettypeProduct p 
						ON p.bettype = b.bettype
				WHERE	b.winlostdate BETWEEN @FromDateBettrans AND @ToDateBettrans				
						AND b.statusID IN (111, 112, 113)
						AND b.matchID > 0 
						AND (CASE WHEN p.ProductCode ='SB' THEN b.tpositiontaking ELSE 1 END <> 0 )  --- EXCLUDE BA 				
				GROUP BY   
					b.Winlostdate, b.currency, p.ProductCode
			END			
			
		END  
		---#I.2: End : Get data from Bettrans table after Movebetsday 
	END 
	---------## I: End :TimeZone = GMT-4 ## -------------
	
	---------## II: Begin :TimeZone <> GMT-4 ## -------------
	ELSE
	BEGIN 

		---#II.1: Begin : Get data from rptLicWinlossGMT table 
		BEGIN
			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA 
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
						b.RptDateGMT,   
						b.RptDate,				
						a.currency,
						'BA' AS ProductCode,
						SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.Turnover ELSE 0 END
							*
							CASE WHEN @IncludeDraw = 0 THEN
								CASE
									WHEN b.statusID = 111 THEN 0
									WHEN b.statusID IN (114, 115) THEN 0.5
									ELSE 1 END
							ELSE 1 END) AS Turnover, 
						0 AS LicenseeWL,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM bodb_LicenseeReport.dbo.rptLicWinlossGMT b WITH (NOLOCK)  
					INNER JOIN @TempAg a ON b.recommend = a.custID  
				WHERE 
					b.RptDateGMT BETWEEN @FromDate AND @ToDate
					AND b.TimeZone = @TimeZone  
					AND b.RptDate <= @MoveBetsDay
					AND b.roleid = 2   
					AND b.statusID IN (111,112,113,114,115) --exclude REJECT bets
					AND (b.bettype < 901 OR b.bettype > 904)
					AND (b.bettype < 911 OR b.bettype > 914)
					AND b.isBA = 1 
				GROUP BY   
					b.RptDateGMT, b.RptDate, a.currency 
			END

			IF EXISTS (SELECT 1 FROM #BettypeProduct WHERE ProductCode = 'SB')     --- exclude BA , BT, CO
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
							b.RptDateGMT,
							b.RptDate,						 
							b.currency,
							p.ProductCode,
							SUM (b.betcount) AS BetCount,
							SUM (b.turnover) AS Turnover, 
							SUM (b.winlost) AS LicenseeWL,  
							SUM(b.PlayerComm) AS PlayerComm,
							SUM(b.comm) AS LicenseeComm						 
				FROM	( 
							SELECT   
								b.RptDateGMT, 
								b.RptDate,
								a.currency,
								b.sporttype,
								SUM(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN 0 ELSE b.betcount END) AS BetCount,
								SUM (CASE WHEN RAND() + 1 > 0 THEN b.turnover ELSE 0 END
									*
									CASE WHEN @IncludeDraw = 0 THEN
										CASE
											WHEN b.statusID = 111 THEN 0
											WHEN b.statusID IN (114, 115) THEN 0.5
											ELSE 1 END
									ELSE 1 END) AS Turnover, 
								-SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost ELSE 0 END) AS Winlost,  								
								SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
								SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS Comm
							FROM bodb_licenseereport.dbo.rptLicWinlossGMT b WITH (NOLOCK)  				
								INNER JOIN @TempAg a ON b.recommend = a.custID 						 
							WHERE 
								b.RptDateGMT BETWEEN @FromDate AND @ToDate
								AND b.TimeZone = @TimeZone  
								AND b.RptDate <= @MoveBetsDay
								AND b.roleid = 2   
								AND b.statusID IN (111,112,113,114,115) --exclude REJECT bets
								AND (b.bettype < 901 OR b.bettype > 904)
								AND (b.bettype < 911 OR b.bettype > 914)
								AND b.isBA = 0 
							GROUP BY   
								b.RptDateGMT,RptDate, a.currency, b.sporttype
						) b 
					INNER JOIN #SporttypeProduct p ON b.sporttype = p.sporttype
				GROUP BY b.RptDateGMT,RptDate, b.currency, p.ProductCode
			END	 
		END
		---#II.1: End : Get data from rptLicWinlossGMT table 

		---#II.2: Begin : Get data from Bettrans table 
		BEGIN 
			IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA Product
			BEGIN
				;WITH BA AS
				(
					SELECT DISTINCT transid
					FROM bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
						INNER JOIN @TempAg r ON BA.recommend = r.custID
				)
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT	CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))), 
						b.Winlostdate,
						b.Currency,
						'BA' ProductCode,  
						COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
							*
							CASE WHEN @IncludeDraw = 0 THEN
								CASE
									WHEN b.statusID = 111 THEN 0
									WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
									ELSE 1 END
							ELSE 1 END) AS Turnover, 
						0 AS LicenseeWL,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
						SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm  ---- BA Comm
				FROM	dbo.bettrans b WITH (NOLOCK)
					LEFT JOIN dbo.Match m WITH (NOLOCK)
						ON m.MatchId = b.MatchId
					INNER JOIN @TempAg a 
						ON a.CustID = b.recommend   
					INNER JOIN BA WITH (NOLOCK) 
						ON b.transid = BA.transid 	 	
				WHERE	CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))) BETWEEN @FromDate AND @ToDate
						AND b.statusID IN (111, 112, 113)
				GROUP BY CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))), b.Winlostdate, b.recommend, b.currency
			END


			IF EXISTS (SELECT 1 FROM #BettypeProduct WHERE ProductCode = 'SB')  ---- SB exclude BA , BT, CO 
			BEGIN
				INSERT INTO #WinLoss (RptDateGMT, RptDate, CurrencyId, ProductCode, BetCount, Turnover, LicenseeWL, PlayerComm, LicenseeComm)
				SELECT
					CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))),   	
					b.Winlostdate,			
					b.currency,
					p.ProductCode,
					COUNT(CASE WHEN RAND() + 1 > 0 AND @IncludeDraw = 0 AND b.statusID = 111 THEN NULL ELSE b.transid END) AS BetCount,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.stake ELSE 0 END
						*
						CASE WHEN @IncludeDraw = 0 THEN
							CASE
								WHEN b.statusID = 111 THEN 0
								WHEN (b.statusID = 112 OR b.statusID = 113) AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5
								ELSE 1 END
						ELSE 1 END) AS Turnover, 
					- SUM (CASE WHEN RAND() + 1 > 0 THEN b.winlost-b.actual_stake ELSE 0 END) AS LicenseeWL,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.PlayerComm ELSE 0 END) AS PlayerComm,
					SUM (CASE WHEN RAND() + 1 > 0 THEN b.comm ELSE 0 END) AS LicenseeComm 
				FROM dbo.bettrans b WITH (NOLOCK)  
					LEFT JOIN dbo.Match m WITH (NOLOCK)
						ON m.MatchId = b.MatchId
					INNER JOIN @TempAg a 
						ON b.recommend = a.custid 
					INNER JOIN #BettypeProduct p 
						ON p.bettype = b.bettype
				WHERE	CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))) BETWEEN @FromDate AND @ToDate				
						AND b.statusID IN (111, 112, 113)
						AND b.matchID > 0 
						AND (CASE WHEN p.ProductCode = 'SB' THEN b.tpositiontaking ELSE 1 END <> 0 )  --- EXCLUDE BA 				
				GROUP BY   
					CONVERT(DATE,DATEADD(HOUR, @TimeZone + 4, ISNULL(m.GlobalShowTime, b.Winlostdate))), b.Winlostdate, b.currency, p.ProductCode
			END		
		END 
		---#II.2: End : Get data from Bettrans table 

	END 
	---------## II: End :TimeZone <> GMT-4 ## -------------
	----------#############################---------------
	 
	---3#: Start: Get Exchange Rate	
	IF EXISTS (SELECT TOP (1) 1 FROM #WinLoss)
	BEGIN
		DECLARE @MinDate SMALLDATETIME, @MaxDate SMALLDATETIME
		
		SELECT @MinDate = MIN (RptDate),
			   @MaxDate = MAX (RptDate)
		FROM   #WinLoss

		INSERT INTO #Exchange(FromDate, ToDate, ExchangeID, Rate)
		SELECT FromDate, ToDate, ExchangeID, Rate
		FROM dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @BaseCurrency, '')
	END
	-- #End: Get Exchange Rate

	-- #Start: Get Report
	SELECT 
			CASE WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(8),w.RptDateGMT,112)  ---- Daily
				 WHEN @ReportBy = 3 THEN CONVERT(VARCHAR(6),w.RptDateGMT,112)   ---Monthly
				 ELSE '' END ReportBy,  --- Summary

			CASE WHEN @GroupBy = 1 THEN CONVERT(VARCHAR(8),w.ProductCode)  ---- ProductCode
				 WHEN @GroupBy = 2 THEN CONVERT(VARCHAR(6),CurrencyId)
				 ELSE '0' 
			END GroupBy, 
			SUM(BetCount) AS BetCount,

			SUM(Turnover) AS Turnover,
			SUM(PlayerComm) AS PlayerComm, 
			SUM(LicenseeWL) AS LicenseeWL, 
			SUM(LicenseeComm) AS LicenseeComm,

			SUM(Turnover*e.Rate) AS TurnoverBase,
			SUM(PlayerComm*e.Rate) AS PlayerCommBase, 
			SUM(LicenseeWL*e.Rate) AS LicenseeWLBase, 
			SUM(LicenseeComm*e.Rate) AS LicenseeCommBase	
	FROM   #WinLoss w
		LEFT JOIN #Exchange e
			ON e.ExchangeID = w.CurrencyId AND w.RptDate BETWEEN e.FromDate AND e.ToDate		
	GROUP BY 
			CASE WHEN @ReportBy = 2 THEN CONVERT(VARCHAR(8),w.RptDateGMT,112)  ---- Daily
				 WHEN @ReportBy = 3 THEN CONVERT(VARCHAR(6),w.RptDateGMT,112)   ---Monthly
				 ELSE '' END,  --- Summary

			CASE WHEN @GroupBy = 1 THEN CONVERT(VARCHAR(8),w.ProductCode)  ---- ProductCode
				 WHEN @GroupBy = 2 THEN CONVERT(VARCHAR(6), CurrencyID)
				 ELSE '0' END
	ORDER BY ReportBy, GroupBy
	
	DROP TABLE #WinLoss 
	DROP TABLE #Exchange
 
	-- #End: Get Report


END
GO