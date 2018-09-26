/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_WinlossByProductDetail_Ag]  
	 @CustID		INT = 0, --memberID
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
	Task : Winloss By Product Detail Report for Licensee Agent Level
	DB: DB052.bodb02  
   
	Revisions:  
	- 20111013@Henry: Change to use rptLicWinlost2	
	- 20111208@Jim: chang bettype condition 
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20120529@Henry: enhance performance
	- 20120730@Jim: Add Player Comm Value  
	- 20120815@Jim: add live casino
	- 20120905@Jim: add virtual sport
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20121115@Henry: Only Sportsbook needs to exclude BA
	- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	- 20130222@Jim : support RNG Casino ,Bingo
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
	- 20150612@Jim: support MicroGaming
	- 20150623@Winnie: exclude 3 transactions SOLD/BOUGHT/BetTrade Commission
	- 20151001@Jim: remove MicroGaming
	- 20151228@Bobby: Include MBC RNG Casino sporttype(208,209,210)
	- 20160331@Walter: Support Voidbridge single wallet [Redmine: #55057]
	- 20160413@Victor: support MKK currency code [Redmine: #55745]
	- 20160727@Jim:  LRF - Commercial terms changed for Bet Trade [Redmine: #61342]
	- 20161022@Jim:move table to bodb_licenseereport [RedmineID :#60449]
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20170327@Paul: Implement Cash Out [RedmineID :#71727]
	- 20170704@Harper: LRF - Integrate Bet Radar Virtual Sports [RedmineID: #78241]
	- 20170721@Sophia: Change to call Alias DBWH instead of DBDW2 
	- 20170731@Harper: LRF - Integrate Lottery [RedmineID: #79997]
	- 20180205@Harper: LRF - Fix handle for getting data only invidual member at Licensee level [RedmineID: #90485]
	- 20180129@Harper: Remove LC from product list [RedmineID: #85965]
	- 20180409@Joseph: Implement new sports for VS2: BasketBall - Virual Soccer World Cup [Redmine: #90881]
	- 20180509@Joseph: Remove cheat currency name for special currencies [RedmineID: #94845]
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

	CREATE TABLE #SAgWinLoss(  
		winlostdate		DATETIME,  
		CustID			INT,   
		Currency		INT,
		ProductCode 	VARCHAR(10),
		TurnOver		MONEY,   	
		Winlost			MONEY,  
		LicenseeWL		MONEY, 
		Comm			MONEY, 
		PlayerComm 		MONEY,
		AmtDueTo3rd		MONEY,
		Betcount		BIGINT
	)  

	CREATE TABLE #tmpVS			(Orid INT, SportType TINYINT)
	DECLARE @bettype			TABLE (bettype INT PRIMARY KEY, ProductCode VARCHAR(10))
	DECLARE @sporttype			TABLE (sporttype INT, ProductCode VARCHAR(10))
	DECLARE @RecommendID		INT

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

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	---#1: Begin: Get AgentList
	SET @RecommendID = 0 
	IF (@CustID <> 0) 
	BEGIN 
		SELECT @RecommendID = recommend
		FROM dbo.Custinfo WITH (NOLOCK) 
		WHERE CustId = @CustID	
	END	

	DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@AgentList
		INSERT INTO @TempAg (custID, currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data
		WHERE @RecommendID = 0 OR AgentId = @RecommendID

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
		FROM f_LicWinLoss_ProductSportType_Sel(@ProductList)
		WHERE ProductCode NOT IN ('VS', 'VS2')
	END
	---#2: End: Get SportBettypeMatrix

	DECLARE @TempFromDate DATETIME 
	DECLARE @TempToDate DATETIME 
	DECLARE @MaxOldDate DATETIME
	DECLARE @FDate SMALLDATETIME  
	DECLARE @TDate SMALLDATETIME 
	
	SELECT @FDate = @FromDate, @TDate = @ToDate -- To Deal With Parameter Sniffing

	---#3: Begin: Get Sum data from bettrans After Move Bets Day
	IF @TDate > @MoveBetsDay
	BEGIN
		IF @FDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FDate
	
		---#3.1: Begin: Get data for BA product
		IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0  ---- BA Product
		BEGIN
			SELECT DISTINCT transid, r.Currency	, r.CustId
			INTO #tmpBA		
			FROM 
				bodb_licensee.dbo.LicenseeBATransaction_active BA WITH(NOLOCK)
				INNER JOIN @tempAg r ON BA.recommend = r.custID 
			
			INSERT INTO #SAgWinLoss  
			SELECT   
				b.winlostdate,  
				ba.custid,
				ba.currency,
				'BA' ProductCode,
				SUM( stake
					*				
					CASE WHEN b.statusID = 111 THEN 0|@sumTurnOver
						WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN (1|@sumTurnOver)/(~@sumTurnOver+1.0)
						ELSE 1 END
				)Turnover, 
				SUM(b.winlost - b.actual_stake) AS Winlost,  
				0 as LicenseeWL,
				SUM (comm) as Comm,
				SUM(PlayerComm) AS PlayerComm,
				- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd,
				SUM(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount	
			FROM 
				#tmpBA ba
				CROSS APPLY (	SELECT TOP 1 tmp.winlostdate, tmp.statusID, tmp.modds, tmp.bettype
											, tmp.winlost, tmp.actual_stake, tmp.comm, tmp.playercomm, tmp.awinlost, tmp.stake
								FROM dbo.bettrans tmp WITH ( NOLOCK)
								WHERE tmp.transid = ba.TransID AND tmp.currency = ba.Currency	
									AND tmp.winlostdate BETWEEN @TempFromDate AND @TDate 
									AND tmp.statusID IN (111, 112, 113) 								
									AND (@CustId = 0 OR tmp.CustId = @CustID)			
							) AS b	
			GROUP BY   
				b.winlostdate, ba.custid, ba.currency
		END
	
		---#3.2: Begin: Get data for VS Parlay
		IF EXISTS (SELECT 1 FROM @bettype WHERE ProductCode = 'VS2')
		BEGIN					
			INSERT INTO #SAgWinLoss
			SELECT   
				b.winlostdate,
				b.recommend,
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
				SUM(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount	
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				CROSS APPLY (	SELECT TOP 1 m.sporttype
								FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
									INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
								WHERE b.refno = bm.refno AND b.custid = bm.custid
							) AS s
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency 							
			WHERE b.bettype = 2799 -- Betradar VS Parlay
				AND b.winlostdate BETWEEN @TempFromDate AND @TDate   
				AND (@CustId = 0 OR b.CustId = @CustID) 
				AND b.statusID  IN (111, 112, 113)
				AND b.matchid = 2799
			GROUP BY b.winlostdate,	b.recommend, b.currency, 'VS2' + CONVERT(varchar(10), s.sporttype)
		END		

		---#3.3: Begin: Get data for all products, Exclude VS2 parlay ticket and BA
		IF EXISTS (SELECT 1 FROM @bettype)
		BEGIN	
			IF EXISTS (SELECT 1 FROM @bettype WHERE ProductCode IN ('VS', 'VS2'))
			BEGIN
				INSERT INTO #tmpVS ( Orid, SportType )				
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
				b.winlostdate, 
				b.recommend,
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
				SUM(1 * (CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)) AS BetCount	
			FROM 
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @TempAg a ON b.recommend = a.custid AND b.Currency = a.Currency 
				INNER JOIN @bettype bt ON b.bettype = bt.bettype AND b.bettype <> 2799
				LEFT JOIN [match] m WITH(NOLOCK) ON b.matchid = m.matchid AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
				LEFT JOIN #tmpVS vs ON b.oddsid = vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)	
			WHERE 
				b.winlostdate BETWEEN @TempFromDate AND @TDate 				
				AND (@CustId = 0 OR b.CustId = @CustID)
				AND b.statusID  IN (111, 112, 113)
				AND b.matchID > 0 
				AND (CASE WHEN bt.ProductCode ='SB' THEN b.tpositiontaking ELSE 1 END <> 0 )  --- EXCLUDE BA 
			GROUP BY   
				b.winlostdate
				,b.recommend
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
	---#3: END: Get Sum data from bettrans After Move Bets Day


	---#4: BEGIN: Get Sum data from Sum Table Before Move Bets Day
	IF @FDate <= @MoveBetsDay 
	BEGIN
		IF @TDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET  @TempToDate = @TDate
		
		---#4.1: Begin: Get data for BA product
		IF PATINDEX('%,BA,%', ',' + @ProductList + ',') > 0
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,  
				b.recommend,
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
				SUM(b.betcount * CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @TempAg ag ON b.Currency = ag.Currency AND b.recommend= ag.custID
			WHERE  
				  b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND (@CustId = 0 OR b.CustId = @CustID)  
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND ISNULL(b.isBA, 0) = 1
			GROUP BY  b.winlostdate,  b.currency, b.recommend
		END
		
		---#4.2: Begin: Get data for all products exclude VS, VS2
		IF EXISTS (SELECT 1 FROM @sporttype)
		BEGIN
			INSERT INTO #SAgWinLoss  
			SELECT 
				b.winlostdate,
				b.recommend,
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
				SUM(b.betcount * CASE WHEN b.statusID = 111 THEN 0|@sumBetCount ELSE 1 END)
			FROM 
				bodb_licenseereport.dbo.rptLicWinloss2 b WITH ( NOLOCK )  
				INNER JOIN @sporttype t ON b.sporttype = t.sporttype
				INNER JOIN @TempAg ag ON b.recommend = ag.custID AND b.Currency = ag.Currency
			WHERE  
				 b.Winlostdate BETWEEN @FDate AND @TempToDate  
				AND (@CustId = 0 OR b.CustId = @CustID)
				AND b.roleid = 1   
				AND b.statusID <> 101 --exclude REJECT bets
				AND (b.bettype < 901 OR b.bettype > 904)
				AND (b.bettype < 911 OR b.bettype > 914)
				AND ISNULL(b.isBA, 0) = 0				
			GROUP BY  
				b.winlostdate,  
				b.currency,
				b.recommend,
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
				,recommend	INT				
				,currency	INT				
				,turnover	MONEY
				,winloss	MONEY
				,commissionA MONEY
				,commissionP MONEY
				,WinlossA  	MONEY
				,betcount	INT )
			
			IF @CustID <> 0
			BEGIN				
				INSERT INTO @tblVS 
					(rptdate    
					,sportID	
					,recommend
					,currency	
					,turnover 
					,winloss  
					,commissionA 
					,commissionP 
					,WinlossA  	
					,betcount)
				SELECT 
					 winlostDate    
					,sportID	
					,t.CustId				
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
										AND b.CustID = @CustID										
									GROUP BY b.rptDate, b.SportID
								) AS vs			
				GROUP BY 
				winlostDate    
				,sportID	
				,t.CustId			
				,t.currency	 		
				OPTION (OPTIMIZE FOR (@n = 1))
			END
			ELSE
			BEGIN				
				INSERT INTO @tblVS 
					(rptdate    
					,sportID	
					,recommend
					,currency	
					,turnover 
					,winloss  
					,commissionA 
					,commissionP 
					,WinlossA  	
					,betcount)
				SELECT 
					 winlostDate    
					,sportID	
					,t.CustId				
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
									GROUP BY b.rptDate, b.SportID
								) AS vs			
				GROUP BY 
				winlostDate    
				,sportID	
				,t.CustId			
				,t.currency	 		
				OPTION (OPTIMIZE FOR (@n = 1))
			END

			INSERT INTO #SAgWinLoss  
			SELECT 	b.rptdate
					,b.recommend
					,b.currency
					,ts.ProductPrefix + CONVERT(varchar(10), ISNULL(b.sportID,0)) AS ProductCode				
					,SUM(b.turnover)
					,SUM(b.winloss)
					,-SUM(b.winloss) AS LicenseeWL
					,SUM(commissionA) AS Comm
					,SUM( commissionP ) AS PlayerComm,
					- SUM (b.WinlossA + b.Winloss + b.commissionA) as AmountDueTo3rd,
					SUM(b.betcount)					
			FROM @tblVS b	
				INNER JOIN #tmpSport ts ON b.sportID = ts.SportType			
			GROUP BY 
					b.rptdate
					,b.recommend
					,b.currency					
					,ts.ProductPrefix + CONVERT(varchar(10), ISNULL(b.sportID,0))
		
		END	
	END 
	---#4: END: Get Sum data from Sum Table Before Move Bets Day 

	---#5: BEGIN: Return final data set
	CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)

	DECLARE @MinDate SMALLDATETIME, @MaxDate SMALLDATETIME
	
	SELECT @MinDate = MIN (winlostdate),
		   @MaxDate = MAX (winlostdate)
	FROM   #SAgWinLoss
	
	CREATE TABLE #Exchange	(FirstExchangeDateByMonth SMALLDATETIME, LastExchangeDateByMonth SMALLDATETIME, ExchangeID INT, Code VARCHAR(5) , MYR FLOAT, USD FLOAT, EUR FLOAT, CNY FLOAT, GBP FLOAT, HKD FLOAT, THB FLOAT, IDR FLOAT )
	
	INSERT INTO #Exchange(FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID, Code, MYR, USD, EUR, CNY, GBP, HKD, THB, IDR)
	SELECT FirstExchangeDateByMonth, LastExchangeDateByMonth, ExchangeID, Code, MYR, USD, EUR, CNY, GBP, HKD, THB, IDR
	FROM dbo.Lrf_f_GetSubExchangeDaily(@MinDate, @MaxDate)
	WHERE exchangeid IN (SELECT Currency FROM @TempAg)	

	SELECT   
		c.username,  
		w.custid,
		w.Currency ,   
		ProductCode, 		
		SUM(TurnOver)	AS Turnover,   
		SUM(Winlost)	AS Winlost,  
		SUM(LicenseeWL) AS LicenseeWL,
		SUM(Comm) AS Comm,
		SUM(PlayerComm) AS PlayerComm,
		SUM(AmtDueto3rd) AS AmtDueto3rd,
		SUM(Betcount)	AS Betcount,

		--BaseRM  
		CAST(SUM(TurnOver*e.MYR)			AS MONEY)	AS TurnoverMYR,   
		CAST(SUM(Winlost*e.MYR)				AS MONEY)	AS WinlostMYR,  
		CAST(SUM(LicenseeWL*e.MYR) 			AS MONEY)	AS LicenseeWLMYR,
		CAST(SUM(Comm * e.MYR) 				AS MONEY)	AS CommMYR,
		CAST(SUM(PlayerComm* e.MYR) 		AS MONEY)	AS PlayerCommMYR,
		CAST(SUM(AmtDueto3rd*e.MYR) 		AS MONEY)	AS AmtDueto3rdMYR,
	
		--BaseUSD  
		CAST(SUM(TurnOver*e.USD)			AS MONEY)	AS TurnoverUSD,   
		CAST(SUM(Winlost*e.USD)				AS MONEY)	AS WinlostUSD,  
		CAST(SUM(LicenseeWL*e.USD)			AS MONEY)	AS LicenseeWLUSD,
		CAST(SUM(Comm * e.USD) 				AS MONEY)	AS CommUSD,
		CAST(SUM(PlayerComm*e.USD)  		AS MONEY)	AS PlayerCommUSD,
		CAST(SUM(AmtDueto3rd*e.USD) 		AS MONEY)	AS AmtDueto3rdUSD,

		--BaseEUR  
		CAST(SUM(TurnOver*e.EUR)			AS MONEY)	AS TurnoverEUR,   
		CAST(SUM(Winlost*e.EUR)				AS MONEY)	AS WinlostEUR,  
		CAST(SUM(LicenseeWL*e.EUR) 			AS MONEY)	AS LicenseeWLEUR,
		CAST(SUM(Comm * e.EUR) 				AS MONEY)	AS CommEUR,
		CAST(SUM(PlayerComm*e.EUR) 			AS MONEY)	AS PlayerCommEUR,
		CAST(SUM(AmtDueto3rd*e.EUR) 		AS MONEY)	AS AmtDueto3rdEUR,
		--BaseGBP  
		CAST(SUM(TurnOver*e.GBP)			AS MONEY)	AS TurnoverGBP,   
		CAST(SUM(Winlost*e.GBP)				AS MONEY)	AS WinlostGBP,  
		CAST(SUM(LicenseeWL*e.GBP) 			AS MONEY)	AS LicenseeWLGBP,
		CAST(SUM(Comm * e.GBP) 				AS MONEY)	AS CommGBP,
		CAST(SUM(PlayerComm*e.GBP) 			AS MONEY)	AS PlayerCommGBP,
		CAST(SUM(AmtDueto3rd*e.GBP) 		AS MONEY)	AS AmtDueto3rdGBP
	FROM	
		#SAgWinLoss w   
		INNER JOIN Customer c WITH (NOLOCK) ON w.custid = c.custid
		INNER JOIN #Exchange e  
			ON e.ExchangeID = w.Currency AND w.winlostdate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth	
	GROUP BY   
		w.custid, c.username, 
		w.Currency,
		ProductCode
	ORDER BY w.currency

	DROP TABLE #SAgWinLoss
	DROP TABLE #Exchange
 
END
GO