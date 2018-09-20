/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByProductDetail]  
	 @CustID		INT = 0, --AgentID
	 @MemberID		INT = 0, --memberID
	 @FromDate		SMALLDATETIME,  
	 @ToDate		SMALLDATETIME,   
	 @ProductList	VARCHAR(MAX) = '',
	 @MoveBetsDay	SMALLDATETIME,
	 @drawfilter	SMALLINT = 1  ,
	 @AgentList		VARCHAR(MAX)
WITH RECOMPILE
AS  
/*  Created: Henry  
	Date: 2011-07-06
	Task : Winloss By Product Detail Report for Licensee Member Level 
	DB: DB052.bodb02  
   
	Revisions:  
	-20111013@Henry: change to use rptLicWinloss2
	-20111208@Jim: change bettype condition
	-20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	-20120529@Henry: enhance performance
	-20120731@Jim: add playercomm value 
	-20120815@Jim: add live casino
	-20120905@Jim: add virtual sport
	-20121004@Jim: replace @currency input param by @currencyID
	-20121022@Jim:  re-calculate AmountDueTo3rd's value 
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130222@Jim: support RNG Casino,Bingo
	- 20130402@Jim: support base currency USD 
	- 20130514@Jim: Restrict permission of Licensee Users by currency
	- 20130809@Jim: offer Virtual Horse Racing
	- 20131007@Jim: offer Virtual Tennis
	- 20131213@Jim: support to Display win loss of individual sports with Virtual Sports
	- 20140304@Florent: offer Keno
	- 20140620@Florent: offer 14 new bettypes and Sporting Solution (36 new bettypes)
	- 20140915@Florent: hotfix duplicated VS bettype
	- 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150107@Jim: add more input param @CustID
	- 20150123@Jim: support base on Currency GBP
	- 20150211@Don: remove index hint
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
	- 201508215@Winnie: Revever KeenOcean currency
	- 20151001@Jim: remove MicroGaming
	- 20151228@Bobby: Support MBC RNG Casino sporttype(208,209,210)
	- 20160331@Walter: Support Voidbridge single wallet [Redmine: #55057]
	- 20160413@Victor: support MKK currency code [Redmine: #55745]
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
	- 20170704@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170721@Sophia: Change to call Alias DBWH instead of DBDW2 
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
	- 20180515@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
	- 20180723@Harper: Improve performance for winloss by product report [RedmineID: #98358]

	Param's Explanation:  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @excludeTest: remove currency UUS	  
	  + @MoveBetsDay: The day we move tickets to bettrans14
	  + @AgentList: xml structure
					  <ROOT>
					   <Agent AgentId="12345" Currency="3"/>  
					   <Agent AgentId="12345" Currency="5"/>  
					  </ROOT> 
*/  
BEGIN  
	SET NOCOUNT ON  

	CREATE TABLE #SAgWinLoss  (  		
		CustID			INT,   
		Currency		INT,
		ProductCode 	VARCHAR(10),
		TurnOver		MONEY,   	
		Winlost			MONEY,  
		LicenseeWL		MONEY, 
		Comm			MONEY, 
		PlayerComm 		MONEY,	
		AmtDueTo3rd		MONEY,
	
		TurnOverEUR		MONEY,   	
		WinlostEUR		MONEY,  
		LicenseeWLEUR	MONEY, 
		CommEUR			MONEY, 
		PlayerCommEUR 	MONEY,	
		AmtDueTo3rdEUR	MONEY,
	
		TurnOverUSD		MONEY,   	
		WinlostUSD		MONEY,  
		LicenseeWLUSD	MONEY, 
		CommUSD			MONEY, 
		PlayerCommUSD 	MONEY,	
		AmtDueTo3rdUSD	MONEY,
	
		TurnOverGBP		MONEY,   	
		WinlostGBP		MONEY,  
		LicenseeWLGBP	MONEY, 
		CommGBP			MONEY, 
		PlayerCommGBP 	MONEY,	
		AmtDueTo3rdGBP	MONEY,
	
		Betcount		BIGINT
	)  

	CREATE TABLE #tmpVS		(Orid INT, SportType TINYINT)
	DECLARE @bettype		TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype		TABLE (sporttype INT, ProductCode VARCHAR(10))
	
	CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)	

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	---#1: Begin: Get AgentList
	DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data
		WHERE AgentId = @CustID

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
				,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
	---#1: End: Get AgentList

	---#2: Begin: Get SportBettypeMatrix
	IF LEN(ISNULL(@ProductList, '')) > 0 
	BEGIN
		-- Insert Bettype
		INSERT INTO @bettype ( bettype, ProductCode )
		SELECT DISTINCT BetType, ProductPrefix
		FROM f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', @ProductList, @IsTest)

		IF CHARINDEX('CS', @ProductList) > 0
			DELETE @bettype
			WHERE bettype = 72 AND ProductCode = 'CS'

		IF CHARINDEX('SB', @ProductList) > 0
				DELETE @bettype
				WHERE (bettype BETWEEN 901 AND 904) OR (bettype BETWEEN 911 AND 914)
		
		-- Insert Sport Type
		INSERT INTO @sporttype ( sporttype, ProductCode )
		SELECT DISTINCT sporttype, ProductCode
		FROM dbo.f_LicWinLoss_ProductSportType_Sel(@ProductList)
		WHERE ProductCode NOT IN ('VS', 'VS2')
	END	
	---#2: End: Get SportBettypeMatrix

	---#3: Begin: Get Exchange Daily
	DECLARE @MinDate SMALLDATETIME, @MaxDate SMALLDATETIME
	
	SELECT @MinDate = @FromDate,
		   @MaxDate = @ToDate
	
	CREATE TABLE #Exchange	(FirstExchangeDateByMonth SMALLDATETIME, LastExchangeDateByMonth SMALLDATETIME, ExchangeID INT, Code VARCHAR(5) , MYR FLOAT, USD FLOAT, EUR FLOAT, CNY FLOAT, GBP FLOAT, HKD FLOAT, THB FLOAT, IDR FLOAT )
	
	INSERT INTO #Exchange(FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID, Code, MYR, USD, EUR, CNY, GBP, HKD, THB, IDR)
	SELECT FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID, Code, MYR, USD, EUR, CNY, GBP, HKD, THB, IDR
	FROM dbo.Lrf_f_GetSubExchangeDaily(@MinDate, @MaxDate)
	WHERE exchangeid IN (SELECT Currency FROM @TempAg)	

	CREATE NONCLUSTERED INDEX IX_Exchange ON #Exchange (FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID)
	---#3: End: Get Exchange Daily

	DECLARE @sumTurnOver		BIT
	DECLARE @sumBetCount		BIT
	DECLARE @RCount				INT
		
	SET @sumTurnOver = 1
	SET @sumBetCount = 1
	
	IF(@drawfilter=2)
	BEGIN
		SET @sumTurnOver = 0
		SET @sumBetCount = 0
	END

	IF(@drawfilter=3)
	BEGIN
		SET @sumTurnOver = 0
	END

	DECLARE @TempFromDate DATETIME 
	DECLARE @TempToDate DATETIME 
	DECLARE @MaxOldDate DATETIME
	DECLARE @FDate DATETIME 
	DECLARE @TDate DATETIME 

	-- To Deal With Parameter Sniffing
	SELECT @FDate=@FromDate,@TDate=@ToDate 
	
	---#4: Begin: Get Sum data from bettrans After Move Bets Day
	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate

		---#4.1: Begin: Get data for BA product
		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BA')  ---- BA Product
		BEGIN
			
			SELECT DISTINCT transid, r.Currency	
			INTO #tmpBA		
			FROM 
				bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
				INNER JOIN @tempAg r ON BA.recommend = r.custID 
			WHERE (@MemberID = 0 OR (@MemberID <> 0 AND BA.CustId = @MemberID))

			INSERT INTO #SAgWinLoss  
			SELECT   
				b.custid,
				ba.currency,
				'BA' AS ProductCode,
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
				)Turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				0 as LicenseeWL,
				SUM (comm ) as Comm,
				SUM ( PlayerComm ) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,
			
				------------------EUR
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.EUR
				) turnoverEUR, 
				SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
				0 as LicenseeWLEUR,
				SUM (comm * e.EUR) as CommEUR,
				SUM ( PlayerComm * e.EUR ) AS PlayerCommEUR,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) AmountDueTo3rdEUR  ,

				------------------USD
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.USD
				) turnoverUSD, 
				SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
				0 as LicenseeWLUSD,
				SUM (comm * e.USD) as CommUSD,
				SUM ( PlayerComm * e.USD ) AS PlayerCommUSD,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) AmountDueTo3rdUSD  ,

				---------------GBP
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.GBP
				) turnoverGBP, 
				SUM((b.winlost - b.actual_stake) * e.GBP) AS WinlostGBP,  
				0 as LicenseeWLGBP,
				SUM (comm * e.GBP) as CommGBP,
				SUM ( PlayerComm * e.GBP ) AS PlayerCommGBP,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.GBP) AmountDueTo3rdGBP  ,			
				COUNT(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount		
			FROM 				
				#tmpBA ba
				CROSS APPLY (	SELECT TOP 1 tmp.winlostdate, tmp.custid, tmp.statusID, tmp.modds, tmp.bettype
											, tmp.winlost, tmp.actual_stake, tmp.comm, tmp.playercomm, tmp.awinlost, tmp.stake
								FROM dbo.bettrans tmp WITH ( NOLOCK)
								WHERE tmp.transid = ba.TransID AND tmp.currency = ba.Currency	
									AND tmp.winlostdate BETWEEN @TempFromDate AND @TDate 
									AND tmp.statusID IN (111, 112, 113) 								
									AND (@MemberID = 0 OR (@MemberID <> 0 AND tmp.CustId = @MemberID)) 				
							) AS b 	 	
				INNER JOIN #Exchange e  
					ON e.ExchangeID = ba.Currency AND b.winlostdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth	
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate				
				AND b.statusID IN (111, 112, 113) 
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914) 
			GROUP BY   
				b.custid, ba.currency
		END
	
		---#4.2: Begin: Get data for VS Parlay
		IF EXISTS (SELECT 1 FROM @bettype WHERE ProductCode = 'VS2')
		BEGIN					
			INSERT INTO #SAgWinLoss
			SELECT   					
				b.custid,
				b.currency,
				'VS2' + CONVERT(varchar(10), s.sporttype) AS ProductCode,
				SUM(stake *			
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						ELSE 1 END
				) AS Turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM(comm) as Comm,
				SUM(PlayerComm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,

				------------------EUR
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.EUR
				) turnoverEUR, 
				SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
				0 as LicenseeWLEUR,
				SUM (comm * e.EUR) as CommEUR,
				SUM ( PlayerComm * e.EUR ) AS PlayerCommEUR,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) AmountDueTo3rdEUR  ,

				------------------USD
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.USD
				) turnoverUSD, 
				SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
				0 as LicenseeWLUSD,
				SUM (comm * e.USD) as CommUSD,
				SUM ( PlayerComm * e.USD ) AS PlayerCommUSD,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) AmountDueTo3rdUSD  ,

				---------------GBP
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.GBP
				) turnoverGBP, 
				SUM((b.winlost - b.actual_stake) * e.GBP) AS WinlostGBP,  
				0 as LicenseeWLGBP,
				SUM (comm * e.GBP) as CommGBP,
				SUM ( PlayerComm * e.GBP ) AS PlayerCommGBP,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.GBP) AmountDueTo3rdGBP  ,	

				COUNT(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount	
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				CROSS APPLY (	SELECT TOP 1 m.sporttype
								FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
									INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
								WHERE b.refno = bm.refno AND b.custid = bm.custid
							) AS s
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency 	
				INNER JOIN #Exchange e  
					ON e.ExchangeID = b.Currency AND b.winlostdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth				
			WHERE b.bettype = 2799 -- Betradar VS Parlay
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate   
				AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID)) 
				AND b.statusID  IN (111, 112, 113)
				AND b.matchid = 2799
			GROUP BY b.custid, b.currency, 'VS2' + CONVERT(varchar(10), s.sporttype)
		END	

		---#4.3: Begin: Get data for all products, Exclude VS2 parlay ticket and BA
		IF EXISTS (SELECT 1 FROM @bettype)
		BEGIN	
			IF EXISTS (SELECT 1 FROM @bettype WHERE ProductCode IN ('VS', 'VS2'))
			BEGIN
				INSERT INTO #tmpVS( Orid, SportType )				
				SELECT 
					DISTINCT
					o.Orid,
					r.SportType				
				FROM VSOutright o with (nolock)
					INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				WHERE EventDate BETWEEN @TempFromDate AND @TDate
			END

			INSERT INTO #SAgWinLoss
			SELECT  
				b.custid,
				a.currency,
				CASE WHEN bt.ProductCode LIKE 'VS%' THEN
					CASE WHEN ISNULL(vs.sporttype, 0) = 0  
						THEN bt.ProductCode + CONVERT(varchar(10), ISNULL(m.sporttype,0))
						ELSE bt.ProductCode + CONVERT(varchar(10), vs.sporttype)
					END					
				ELSE bt.ProductCode END AS ProductCode,
				SUM(stake *			
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
							WHEN bt.ProductCode = 'SB' AND (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
				) AS Turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				- SUM(b.winlost - b.actual_stake) AS LicenseeWL,
				SUM(comm) as Comm,
				SUM(PlayerComm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,

				------------------EUR
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.EUR
				) turnoverEUR, 
				SUM((b.winlost - b.actual_stake) * e.EUR) AS WinlostEUR,  
				0 as LicenseeWLEUR,
				SUM (comm * e.EUR) as CommEUR,
				SUM ( PlayerComm * e.EUR ) AS PlayerCommEUR,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.EUR) AmountDueTo3rdEUR  ,

				------------------USD
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.USD
				) turnoverUSD, 
				SUM((b.winlost - b.actual_stake) * e.USD) AS WinlostUSD,  
				0 as LicenseeWLUSD,
				SUM (comm * e.USD) as CommUSD,
				SUM ( PlayerComm * e.USD ) AS PlayerCommUSD,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.USD) AmountDueTo3rdUSD  ,

				---------------GBP
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.GBP
				) turnoverGBP, 
				SUM((b.winlost - b.actual_stake) * e.GBP) AS WinlostGBP,  
				0 as LicenseeWLGBP,
				SUM (comm * e.GBP) as CommGBP,
				SUM ( PlayerComm * e.GBP ) AS PlayerCommGBP,
				- SUM((b.awinlost + b.winlost - b.actual_stake + b.comm) * e.GBP) AmountDueTo3rdGBP  ,

				COUNT(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount	
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency 
				INNER JOIN @bettype bt ON b.bettype = bt.bettype AND b.bettype <> 2799
				LEFT JOIN [match] m WITH(NOLOCK) ON b.matchid = m.matchid AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
				LEFT JOIN #tmpVS vs ON b.oddsid = vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)	
				INNER JOIN #Exchange e  
					ON e.ExchangeID = b.Currency AND b.winlostdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth	
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate 				
				AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID)) 
				AND b.statusID  IN (111, 112, 113)
				AND b.matchID > 0 
				AND (CASE WHEN bt.ProductCode ='SB' THEN b.tpositiontaking ELSE 1 END <> 0 )  --- EXCLUDE BA 
			GROUP BY   
				b.custid
				,a.currency
				,CASE WHEN bt.ProductCode LIKE 'VS%' THEN
					CASE WHEN ISNULL(vs.sporttype, 0) = 0  
						THEN bt.ProductCode + CONVERT(varchar(10), ISNULL(m.sporttype,0))
						ELSE bt.ProductCode + CONVERT(varchar(10), vs.sporttype)
					END					
				ELSE bt.ProductCode END	
			
			DROP TABLE #tmpVS	
		END			
	END  
	---#4: END: Get Sum data from bettrans After Move Bets Day  

	---#5: BEGIN: Get Sum data from Sum Table Before Move Bets Day
	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @TDate
		
		---#5.1: Begin: Get data for BA product
		IF EXISTS (SELECT val FROM strSplit(@ProductList, ',') WHERE Val = 'BA')
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 				
				b.custid,
				b.currency,
				'BA' AS ProductCode,
				SUM(b.turnover
				*			
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
				),     
				SUM(b.winlost),  
				0 as LicenseeWL,
				SUM (comm) as Comm,
				SUM( PlayerComm ) AS PlayerComm,
				- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,

				------------------EUR
				SUM(b.turnover
				*			
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.EUR
				) turnoverEUR, 
				SUM((b.winlost) * e.EUR) AS WinlostEUR,  
				0 as LicenseeWLEUR,
				SUM (comm * e.EUR) as CommEUR,
				SUM ( PlayerComm * e.EUR ) AS PlayerCommEUR,
				- SUM((b.awinlost + b.winlost + b.comm) * e.EUR) AmountDueTo3rdEUR  ,

				------------------USD
				SUM(b.turnover
				*			
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.USD
				) turnoverUSD, 
				SUM(b.winlost * e.USD) AS WinlostUSD,  
				0 as LicenseeWLUSD,
				SUM (comm * e.USD) as CommUSD,
				SUM ( PlayerComm * e.USD ) AS PlayerCommUSD,
				- SUM((b.awinlost + b.winlost + b.comm) * e.USD) AmountDueTo3rdUSD  ,

				---------------GBP
				SUM(b.turnover
				*			
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.GBP
				) turnoverGBP, 
				SUM(b.winlost * e.GBP) AS WinlostGBP,  
				0 as LicenseeWLGBP,
				SUM (comm * e.GBP) as CommGBP,
				SUM ( PlayerComm * e.GBP ) AS PlayerCommGBP,
				- SUM((b.awinlost + b.winlost + b.comm) * e.GBP) AmountDueTo3rdGBP  ,

				SUM(b.betcount * CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.Currency = ag.Currency AND b.recommend= ag.custID
				INNER JOIN #Exchange e  
					ON e.ExchangeID = b.Currency AND b.winlostdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE  
				b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID)) 
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY  b.currency, b.custid
		END
		
		---#5.2: Begin: Get data for all products exclude VS, VS2
		IF EXISTS (SELECT 1 FROM @sporttype)
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 				
				b.custid,
				b.currency,
				t.ProductCode,
				SUM(b.turnover
				*				
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114,115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
				),     
				SUM(b.winlost),  
				SUM(CASE WHEN (b.sporttype in(0,161,251,252,202,203,205,208,209,210,212,220))  THEN -1 * b.winlost 
						WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END
					) AS LicenseeWL,
				SUM(comm ) as Comm,
				SUM( PlayerComm  ) AS PlayerComm, 
				- SUM (b.awinlost + b.winlost + b.comm) as AmountDueTo3rd,

				------------------EUR
				SUM(b.turnover
				*			
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.EUR
				) turnoverEUR, 
				SUM((b.winlost) * e.EUR) AS WinlostEUR,  
				0 as LicenseeWLEUR,
				SUM (comm * e.EUR) as CommEUR,
				SUM ( PlayerComm * e.EUR ) AS PlayerCommEUR,
				- SUM((b.awinlost + b.winlost + b.comm) * e.EUR) AmountDueTo3rdEUR  ,

				------------------USD
				SUM(b.turnover
				*			
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.USD
				) turnoverUSD, 
				SUM(b.winlost * e.USD) AS WinlostUSD,  
				0 as LicenseeWLUSD,
				SUM (comm * e.USD) as CommUSD,
				SUM ( PlayerComm * e.USD ) AS PlayerCommUSD,
				- SUM((b.awinlost + b.winlost + b.comm) * e.USD) AmountDueTo3rdUSD  ,

				---------------GBP
				SUM(b.turnover
				*			
					CASE WHEN b.statusID = 111  THEN 0|@sumTurnOver
						WHEN b.statusID IN (114, 115) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
					* e.GBP
				) turnoverGBP, 
				SUM(b.winlost * e.GBP) AS WinlostGBP,  
				0 as LicenseeWLGBP,
				SUM (comm * e.GBP) as CommGBP,
				SUM ( PlayerComm * e.GBP ) AS PlayerCommGBP,
				- SUM((b.awinlost + b.winlost + b.comm) * e.GBP) AmountDueTo3rdGBP  ,

				SUM(b.betcount * CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.Currency
				INNER JOIN #Exchange e  
					ON e.ExchangeID = b.Currency AND b.winlostdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE  
				 b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND (@MemberID = 0 OR (@MemberID <> 0 AND b.CustId = @MemberID))
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND ISNULL(b.isBA, 0) = 0				
			GROUP BY  				
				b.currency,
				b.custid,
				t.ProductCode				
		END		

		---#4.3: Begin: Get data for VS, VS2 from DW
		IF EXISTS (SELECT 1 FROM @bettype WHERE ProductCode IN ('VS', 'VS2'))
		BEGIN		
			DECLARE @n INT = 2147483647	
			
			SELECT s.SportType, s.ProductPrefix
			INTO #tmpSport
			FROM 
			(
				SELECT DISTINCT m.SportType, p.ProductPrefix		
				FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
					INNER JOIN dbo.Products p WITH (NOLOCK) ON m.ProductID = p.ProductID
				WHERE p.ProductPrefix IN ('VS', 'VS2')
			) s			

			DECLARE  @tblVS AS TABLE 
				(rptdate	DATETIME
				,sportID	INT
				,CustID		INT				
				,currency	INT				
				,turnover	MONEY
				,winloss	MONEY
				,commissionA MONEY
				,commissionP MONEY
				,WinlossA  	MONEY
				,betcount	INT )
			
			IF @MemberID <> 0
			BEGIN				
				INSERT INTO @tblVS 
					(rptdate   
					,CustID
					,sportID	
					,currency	
					,turnover 
					,winloss  
					,commissionA 
					,commissionP 
					,WinlossA  	
					,betcount)
				SELECT 
					 winlostDate 
					,vs.CustId	   
					,sportID									
					,t.currency	 				
					,SUM(vs.Turnover) 
					,SUM(winlossp)  
					,SUM(commissionA) 
					,SUM(commissionP) 
					,SUM(WinlossA)  	
					,SUM(Betcount)  
				FROM @tempAg t  
					CROSS APPLY ( 
									SELECT TOP (@n) DATEADD(MONTH, DATEDIFF(MONTH, 0, b.rptDate), 0) AS winlostDate
										, b.SportID
										, b.CustID
										, SUM(b.Stake *					
												CASE WHEN b.[status] = 3  THEN 0|@sumTurnOver
													 WHEN b.[Status] IN (13,12) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
												ELSE 1 END
											 ) AS Turnover
										, SUM(b.WinlossP) AS WinlossP, SUM(b.CommissionA) AS CommissionA
										, SUM(b.commissionP) AS commissionP, SUM(b.WinlossA) AS WinlossA
										, SUM(b.betcount * 
												CASE WHEN b.status = 3 THEN 0|@sumBetCount ELSE 1 END) AS Betcount
									FROM DBWH.bodb_Account.dbo.mcCustVirtualSport b WITH (NOLOCK) 
									WHERE t.CustID = b.recommend AND b.Currency = t.Currency 
										AND rptdate BETWEEN @FDate AND @TempToDate  			 
										AND status IN (8,3,4)
										AND b.CustID = @MemberID										
									GROUP BY b.rptDate,b.CustID, b.SportID
								) AS vs			
				GROUP BY 	
						vs.winlostDate, vs.CustId, sportID, t.currency		
				OPTION (OPTIMIZE FOR (@n = 1))
			END
			ELSE
			BEGIN				
				INSERT INTO @tblVS 
					(rptdate   
					,CustID
					,sportID	
					,currency	
					,turnover 
					,winloss  
					,commissionA 
					,commissionP 
					,WinlossA  	
					,betcount)
				SELECT 
					 winlostDate 
					,vs.CustId	
					,sportID			
					,t.currency	 				
					,SUM(vs.Turnover) 
					,SUM(winlossp)  
					,SUM(commissionA) 
					,SUM(commissionP) 
					,SUM(WinlossA)  	
					,SUM(Betcount)  
				FROM @tempAg t  
					CROSS APPLY ( 
									SELECT TOP (@n)
										DATEADD(MONTH, DATEDIFF(MONTH, 0, b.rptDate), 0) AS winlostDate										
										, b.CustID
										, b.SportID
										, SUM(b.Stake *					
												CASE WHEN b.[status] = 3  THEN 0|@sumTurnOver
													 WHEN b.[Status] IN (13,12) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
												ELSE 1 END
											 ) AS Turnover
										, SUM(b.WinlossP) AS WinlossP, SUM(b.CommissionA) AS CommissionA
										, SUM(b.commissionP) AS commissionP, SUM(b.WinlossA) AS WinlossA
										, SUM(b.betcount * 
												CASE WHEN b.status = 3 THEN 0|@sumBetCount ELSE 1 END) AS Betcount
									FROM DBWH.bodb_Account.dbo.mcCustVirtualSport b WITH (NOLOCK) 
									WHERE t.CustID = b.recommend AND b.Currency = t.Currency 
										AND rptdate BETWEEN @FDate AND @TempToDate  			 
										AND status IN (8,3,4)										
									GROUP BY b.rptDate, b.CustID, b.SportID
								) AS vs			
				GROUP BY 
					winlostDate  
					,vs.CustId	  
					,sportID							
					,t.currency	 		
				OPTION (OPTIMIZE FOR (@n = 1))
			END

			INSERT INTO #SAgWinLoss  
			SELECT 	
					b.CustID
					,b.currency
					,ts.ProductPrefix + CONVERT(varchar(10), ISNULL(b.sportID,0)) AS ProductCode				
					,SUM(b.turnover)
					,SUM(b.winloss)
					,-SUM(b.winloss) AS LicenseeWL
					,SUM(commissionA) AS Comm
					,SUM( commissionP ) AS PlayerComm,
					- SUM (b.WinlossA + b.Winloss + b.commissionA) as AmountDueTo3rd,

					------------------EUR
					SUM(b.turnover * e.EUR) turnoverEUR, 
					SUM(b.winloss * e.EUR) AS WinlostEUR,  
					-SUM(b.winloss * e.EUR) AS LicenseeWLEUR,
					SUM (commissionA * e.EUR) AS CommEUR,
					SUM ( commissionP * e.EUR ) AS PlayerCommEUR,
					- SUM((b.WinlossA + b.Winloss + b.commissionA) * e.EUR) AmountDueTo3rdEUR  ,

					------------------USD
					SUM(b.turnover * e.USD ) turnoverUSD, 
					SUM(b.winloss * e.USD) AS WinlostUSD,  
					-SUM(b.winloss * e.USD) AS LicenseeWLUSD,
					SUM (commissionA * e.USD) AS CommUSD,
					SUM ( commissionP * e.USD ) AS PlayerCommUSD,
					- SUM((b.WinlossA + b.Winloss + b.commissionA) * e.USD) AmountDueTo3rdUSD  ,

					---------------GBP
					SUM(b.turnover * e.GBP) turnoverGBP, 
					SUM(b.winloss * e.GBP) AS WinlostGBP,  
					-SUM(b.winloss * e.GBP) AS LicenseeWLGBP,
					SUM (commissionA * e.GBP) as CommGBP,
					SUM ( commissionP * e.GBP ) AS PlayerCommGBP,
					- SUM((b.WinlossA + b.Winloss + b.commissionA) * e.GBP) AmountDueTo3rdGBP  ,

					SUM(b.betcount)					
			FROM @tblVS b	
				INNER JOIN #tmpSport ts ON b.sportID = ts.SportType		
				INNER JOIN #Exchange e  
					ON e.ExchangeID = b.Currency AND b.rptdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth	
			GROUP BY 					
					b.CustID
					,b.currency					
					,ts.ProductPrefix + CONVERT(varchar(10), ISNULL(b.sportID,0))
		
		END	
	END 
	---#5: END: Get Sum data from Sum Table Before Move Bets Day 


SELECT   
	c.username,  
	SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,	   w.custid, 
	w.Currency ,
	ProductCode, 
	SUM(TurnOver)	  AS Turnover,   
	SUM(Winlost)	  AS Winlost,  
	SUM(LicenseeWL)   AS LicenseeWL,
	SUM(Comm) 		  AS Comm,
	SUM(PlayerComm)   AS PlayerComm, 
	SUM(AmtDueto3rd)  AS AmtDueto3rd,
	SUM(Betcount)	  AS Betcount,
	
	--BaseEUR  
	CAST(SUM(TurnOverEUR)			AS MONEY)	AS TurnoverEUR,   
	CAST(SUM(WinlostEUR)			AS MONEY)	AS WinlostEUR,  
	CAST(SUM(LicenseeWLEUR) 		AS MONEY)	AS LicenseeWLEUR,
	CAST(SUM(CommEUR) 				AS MONEY)	AS CommEUR,
	CAST(SUM(PlayerCommEUR) 		AS MONEY)	AS PlayerCommEUR,
	CAST(SUM(AmtDueto3rdEUR) 		AS MONEY)	AS AmtDueto3rdEUR,
	--BaseUSD  
	CAST(SUM(TurnOverUSD)			AS MONEY)	AS TurnoverUSD,   
	CAST(SUM(WinlostUSD)			AS MONEY)	AS WinlostUSD,  
	CAST(SUM(LicenseeWLUSD) 		AS MONEY)	AS LicenseeWLUSD,
	CAST(SUM(CommUSD) 				AS MONEY)	AS CommUSD,
	CAST(SUM(PlayerCommUSD) 		AS MONEY)	AS PlayerCommUSD,
	CAST(SUM(AmtDueto3rdUSD) 		AS MONEY)	AS AmtDueto3rdUSD,
	--BaseGBP
	CAST(SUM(TurnOverGBP)			AS MONEY)	AS TurnoverGBP,   
	CAST(SUM(WinlostGBP)			AS MONEY)	AS WinlostGBP,  
	CAST(SUM(LicenseeWLGBP) 		AS MONEY)	AS LicenseeWLGBP,
	CAST(SUM(CommGBP) 				AS MONEY)	AS CommGBP,
	CAST(SUM(PlayerCommGBP) 		AS MONEY)	AS PlayerCommGBP,
	CAST(SUM(AmtDueto3rdGBP) 		AS MONEY)	AS AmtDueto3rdGBP
FROM	
	#SAgWinLoss w   
	INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.custid = c.custid	
GROUP BY   
	w.custid, c.username,c.username2  , 
	w.Currency,
	Productcode
	
ORDER BY c.username

DROP TABLE #SAgWinLoss
 
END
GO