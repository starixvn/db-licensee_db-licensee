set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_Rpt_MobileWinloss]  
 @LicenseeID	INT,
 @CurrencyID	INT = 0,
 @FromDate		SMALLDATETIME,  
 @ToDate		SMALLDATETIME,   
 @showSB		BIT=0,  
 @ShowRB		BIT=0,  
 @ShowNG		BIT=0, 
 @ShowBA		BIT=0,
 @ShowLC 		BIT=0,
 @ShowVS		BIT=0,
 @ShowCS		BIT=0,--- RNG Casino
 @ShowBG		BIT=0,--- Bingo
 @SiteType	TINYINT=1, 
 @MoveBetsDay SMALLDATETIME,
 @drawfilter SMALLINT = 1  ,
 @excludeTest BIT = 0,
 @Debug		BIT = 0
AS
/*  Created: Jim
	Date: 2012-02-02
    Task : Mobile WinLoss Report 
    DB: DB052.bodb02  
   
    Revisions:  
		-20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
		-20120529@Henry: enhance performance
		-20120730@Jim: add playercomm value 
		-20120814@Henry: add ShowLiveCasino 
		- 20120816@Henry: include betfrom "l" for smartphone
		- 20120905@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
		- 20130109@Henry: Split Mobile to WAP & Smartphone
		- 20130225@Jim: support RNG Casino, Bingo 
		- 20130414@Jim: support USD base currency 
		
	Param's Explanation:  
	  + @SiteType: 1-WAP; 2-Smartphone; 3: Others;0-All  
	  +	@drawfilter: 'No Draw' filter is supportted (1:Normal 2:No Draw 3:No Draw for Turnover only)
	  + @IsOld: 0 - query in table rptLicWinloss2, 1 - query in table rptLicWinloss_old
	  + @excludeTest: remove currency UUS
	  + @showSB: Show SportsBook bets
	  + @ShowRB: Show RB bets
	  + @ShowNG: Show Number game bets
	  + @ShowBA: Show Bet Aggregator bets (combined with Sportsbook or Number Game)
	  + @ShowLC: Show Live casino
	  + @ShowCS: Show RNG Casino
	  + @ShowBG: Show Bingo
	  + @MoveBetsDay: The day we move tickets to bettrans14
*/
    
BEGIN      

	DECLARE @sql varchar(max)
	DECLARE @sql1 varchar(max)
	DECLARE @TempFromDate DATETIME 
	DECLARE @TempToDate DATETIME 
	DECLARE @MaxOldDate DATETIME
	DECLARE @VNDCurrencyName VARCHAR(20)
	DECLARE @FDate DATETIME
	DECLARE @TDate DATETIME
	--to Deal With Parameter Sniffing
	SELECT @FDate=@FromDate,@TDate=@ToDate 
	
	SELECT @sql = 'SET NOCOUNT ON ' + char(13)
	SELECT @sql = @sql + '--Declare variable:' + char(13)

	SELECT @sql = @sql +	
					'CREATE TABLE #SAgWinLoss (Winlostdate DATETIME, Currency INT ,Turnover MONEY, Winlost MONEY, LicenseeWL MONEY,'+char(13)+
					'WinlossRB MONEY,AmtDueToBA MONEY,AmtDueToRB MONEY,CommBA MONEY,CommRB MONEY,playercomm MONEY,Company MONEY,BetCount BIGINT)'+char(13)+
					'DECLARE @TmpCondSumWL	TABLE( sporttype INT)'+char(13)+
					'DECLARE @tmpAg	TABLE( custID INT PRIMARY KEY, Currency INT)'+char(13)
	
	SELECT @VNDCurrencyName=currency FROM exchange WITH (NOLOCK) WHERE ExchangeID=51
	SELECT @sql=@sql+  'BEGIN'+char(13)+
								'INSERT INTO @tmpAg(custID,currency) SELECT custID,currency FROM bodb_Licensee.dbo.LicenseeCust (NOLOCK) WHERE LicenseeID = '+CONVERT(VARCHAR(10),@LicenseeID)+
								CASE WHEN @CurrencyID<>0 THEN 'AND Currency='+CONVERT(VARCHAR(10),@CurrencyID) ELSE '' END +char(13)+
								CASE WHEN @excludeTest=1 THEN 'AND Currency<>20'ELSE '' END +char(13)+
						'END'+char(13)
	IF	@ShowSB=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(0)'+char(13)+
						 'END'+char(13)
	IF @ShowRB=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(151)'+char(13)+
						 'END'+char(13)
	IF @ShowNG=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(161)'+char(13)+
						 'END'+char(13)
						 
						 
	IF @ShowLC=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(162)'+char(13)+
						 'END'+char(13)	
							 
	IF @ShowVS=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(180)'+char(13)+
						 'END'+char(13)							
	
	IF @ShowCS=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
									'INSERT INTO @TmpCondSumWL(sporttype) VALUES(251)'+char(13)+
						'END'+char(13)	
	IF @ShowBG=1
		SELECT @sql=@sql+'BEGIN'+char(13)+
								'INSERT INTO @TmpCondSumWL(sporttype) VALUES(252)'+char(13)+
						 'END'+char(13)														
	IF @TDate>@MoveBetsDay
		BEGIN
			IF @FDate <= @MoveBetsDay 
				SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
			ELSE
				SET @TempFromDate = @FDate
			IF @ShowBA=1
					BEGIN	
						SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
														'SELECT b.winlostdate,'+char(13)+  
															'b.currency,'+char(13)+
															'SUM( stake*'+char(13)+
																CASE WHEN @drawfilter IN (2,3) THEN
																	'CASE WHEN b.statusID = 111 THEN 0'+char(13)+
																	'WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5'+char(13)+
																	'ELSE 1 END'
																ELSE '1' END+') turnover,'+char(13)+
															'SUM(b.winlost - b.actual_stake) AS Winlost,'+char(13)+
															'0 as LicenseeWL,'+char(13)+
															'0 as WinlossRB,'+char(13)+
															'- SUM (b.winlost - b.actual_stake + b.awinlost + b.comm ) as AmountDueToBA,'+char(13)+
															'0 as AmountDueToRB,'+char(13)+
															'SUM (b.comm ) as CommBA,'+char(13)+
															'0 as CommRB,'+char(13)+
															'SUM(b.playercomm  ) as PlayerComm,'+char(13)+
															'0 as Company,'+char(13)+
															'(COUNT(b.transid)*'+char(13)+
															CASE WHEN @drawfilter = 2 THEN 'CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END'
															ELSE '1' END +')BetCount'+char(13)+
														'FROM dbo.bettrans b WITH (NOLOCK)'+char(13)+
															'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend and b.transid = BA.transid'+char(13)+
														'WHERE '+char(13)+' b.statusID  IN (111, 112, 113)'+char(13)+
															'AND (b.winlostdate BETWEEN'''+convert(varchar(10),@TempFromDate, 120)+'''AND '''+ convert(varchar(10),@Tdate,120)+''')'+char(13)+
															CASE 
																WHEN (@SiteType=0) THEN ''
																WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
															ELSE ''END+char(13)+
															'AND b.Recommend IN (SELECT custid FROM @tmpAg)'+char(13)+
														'GROUP BY  b.winlostdate, b.currency, b.bettype  , b.statusID'	+char(13)
					END
			IF (@ShowSB=1 or @ShowRB=1 or @ShowNG=1 OR @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
				BEGIN
					SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
													'SELECT b.winlostdate,'	+char(13)+
														'b.currency,' +char(13)+
														'SUM('+char(13)+
														'(CASE WHEN b.bettype in (33,34) AND b.liveawayscore=0 THEN b.stake/2 ELSE b.stake END'+char(13)+
														'*'+char(13)+ CASE WHEN @drawfilter IN (2,3) THEN 'CASE WHEN b.statusID=111 THEN 0'+char(13)+
																										   'WHEN (b.statusID = 112 OR b.statusID = 113)  AND ABS(modds) = 0.25 AND b.bettype IN(1,3,7,8,17,18) THEN 0.5'+char(13)+
																											'ELSE 1 END '
																									ELSE '1' END +'))turnover,'+char(13)+
														'SUM(b.winlost-b.actual_stake) AS Winlost,'	+char(13)+
														'- SUM(CASE WHEN (b.bettype NOT BETWEEN 31 AND 33)  THEN (b.winlost - b.actual_stake) ELSE 0 END) AS LicenseeWL ,'+char(13)+
														'SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE 0 END) AS WinlossRB,'+char(13)+					
														'0 as AmountDueToBA,'+char(13)+															
														'- SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN (b.winlost - b.actual_stake + awinlost + comm) ELSE 0 END) as AmountDueToRB,'+char(13)+
														'0 as CommBA,'+char(13)+
														'SUM ( CASE WHEN b.bettype BETWEEN 31 AND 33 THEN comm  ELSE 0 END)as CommRB,'	+char(13)+
														'SUM (   b.playercomm ) as PlayerComm,'	+char(13)+
														'- SUM(CASE WHEN b.bettype NOT BETWEEN 31 AND 33 THEN (b.awinlost + b.winlost - b.actual_stake + b.comm) ELSE 0 END)  as Company ,'+char(13)+
														'(COUNT(b.transid)*'	+char(13)+ CASE WHEN @drawfilter=2 THEN 'CASE WHEN b.statusID=111 THEN 0 ELSE 1 END'
																							ELSE '1' END +char(13)+') Betcount' +char(13)+
													'FROM '	+char(13)+'dbo.bettrans b WITH (NOLOCK)'+char(13)+
																 'LEFT JOIN bodb_Licensee.dbo.licenseeBAtransaction_active lb WITH (NOLOCK) ON b.recommend = lb.recommend AND b.TransID=lb.TransID'+char(13)+
													'WHERE '+char(13)+'b.statusID IN (111,112,113)'+char(13)+
																CASE 	
																	WHEN (@SiteType=0) THEN ''
																	WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																	WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																	WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
																 ELSE ''END+char(13)+	
																'AND b.matchid>0'+char(13)+
																'AND lb.TransID IS NULL'+char(13)+
																'AND (b.winlostdate BETWEEN'''+convert(varchar(10),@TempFromDate, 120) +'''AND'''+convert(varchar(10),@TDate, 120) +''')'+char(13)+
																'AND b.Recommend IN (SELECT custid FROM @tmpAg)'+char(13)+
																'AND ('+char(13)+'bettype<'+ CASE WHEN @ShowSB=1 THEN '31 OR b.bettype BETWEEN 121 AND 999' ELSE '0' END+char(13)+
																							 CASE WHEN @ShowNG=1 THEN 'OR b.bettype BETWEEN 81 AND 120' ELSE '' END+char(13)+
																							 CASE WHEN @ShowRB=1 THEN 'OR b.bettype BETWEEN 31 AND 33' ELSE ''END+char(13)+
																							 CASE WHEN @ShowLC=1 THEN 'OR b.bettype BETWEEN 1101 AND 1199' ELSE ''END+char(13)+
																							 CASE WHEN @ShowVS=1 THEN 'OR b.bettype BETWEEN 1201 AND 1299' ELSE ''END+char(13)+
																							 CASE WHEN @ShowCS=1 THEN 'OR b.bettype =71' ELSE ''END+char(13)+
																							 CASE WHEN @ShowBG=1 THEN 'OR b.bettype =73' ELSE ''END+char(13)+
																	')'+char(13)+
													'GROUP BY b.winlostdate, b.currency,b.bettype  ,b.statusID'					
				END
		END
	IF @FDate <= @MoveBetsDay 
	BEGIN
			IF @TDate >= @MoveBetsDay
					SET @TempToDate = @MoveBetsDay
				ELSE
					SET  @TempToDate = @TDate
			
			BEGIN
				IF @ShowBA=1 
					BEGIN	
						SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
														'SELECT b.winlostdate,b.currency,'+char(13)+
																'SUM(b.turnover *'+char(13)+ CASE WHEN @drawfilter IN (2,3) THEN 'CASE WHEN b.statusID=111 THEN 0'+char(13)+
																																	   'WHEN b.statusID IN (114,115) THEN 0.5 ELSE 1 END'
																							 ELSE '1' END+char(13)+')AS TurnOver ,'+char(13)+
																'SUM(b.winlost),0 as LicenseeWL,0 AS WinlossRB,- SUM (b.winlost+b.awinlost+b.comm) as AmtDueToBA,0 as AmtDueToRB,SUM (b.comm ) as CommBA,'+char(13)+
																'0 as CommRB,'+char(13)+
																'SUM( b.playerComm ) as PlayerComm,'+char(13)+
																'0 as Company,'+char(13)+
																'(SUM(b.betcount)*'	+char(13)+ CASE WHEN @drawfilter =2 THEN 'CASE WHEN b.statusID=111 THEN 0 ELSE 1 END'
																															ELSE '1' END +') as Betcount '+char(13)+  
														'FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK ) '+char(13)+
														'WHERE '+char(13)+'b.roleid = 2 '+char(13)+
																	  'AND b.Recommend IN (SELECT custid FROM @tmpAg)'	+char(13)+
																	  'AND b.statusID <> 101'+char(13)+
																	  'AND ISNULL(b.isBA,0) = 1'+char(13)+
																	  'AND (b.Winlostdate BETWEEN'''+convert(varchar(10),@FDate, 120)+'''AND'''+convert(varchar(10),@TempToDate, 120)+''')'+char(13)+
																	  CASE	WHEN (@SiteType=0) THEN ''
																			WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																			WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																			WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
																		 ELSE '' END +char(13)+
														'GROUP BY b.winlostdate,   b.currency, b.sporttype, b.statusID'							
										
					END	
				IF (@showSB = 1 or @ShowRB = 1 or @ShowNG = 1 OR  @ShowLC = 1 OR @ShowVS=1 OR @ShowCS=1 OR @ShowBG=1)
					BEGIN
						SELECT @sql=@sql+char(13)+'INSERT INTO #SAgWinLoss'+char(13)+
													'SELECT b.winlostdate,b.currency,SUM(b.turnover*'+char(13)+
															CASE WHEN @drawfilter IN (2,3) THEN 'CASE WHEN b.statusID = 111  THEN 0 '+char(13)+
																									  'WHEN b.statusID IN (114,115) THEN 0.5 ELSE 1 END'
																							ELSE '1' END +char(13)+ ') AS TurnOver,'+char(13)+
															'SUM(b.winlost),'+char(13)+
															'- SUM(CASE WHEN (b.sporttype <> 151) THEN b.winlost ELSE 0 END) AS LicenseeWL ,'+char(13)+--SB, NG, Livecasino, Virtual Sport
															'SUM(CASE WHEN b.sporttype = 151 THEN b.awinlost ELSE 0 END) AS WinlossRB,'+char(13)+
															'0 as AmtDueToBA,'+char(13)+
															'- SUM ( CASE WHEN b.sporttype = 151 THEN (b.winlost+b.awinlost+b.comm) ELSE 0 END) as AmtDueToRB,'+char(13)+
															'0 as CommBA,'+char(13)+
															'SUM ( CASE WHEN b.sporttype = 151 THEN b.comm  ELSE 0 END) as CommRB,'+char(13)+
															'SUM ( b.playercomm ) as PlayerComm,'+char(13)+
															'- SUM(CASE WHEN b.sporttype <> 151 THEN b.awinlost + b.winlost + b.comm ELSE 0 END)  as Company,'+char(13)+
															'(SUM(b.betcount)*'+char(13)+CASE WHEN @drawfilter = 2 THEN 'CASE WHEN b.statusID = 111 THEN 0 ELSE 1 END'
																							 ELSE '1' END+') AS Betcount'+char(13)+
													'FROM bodb_Licensee.dbo.rptLicWinloss2 b WITH ( NOLOCK ) '+char(13)+
													'WHERE  b.roleid = 2'+char(13)+
															'AND b.Recommend IN (SELECT custid FROM @tmpAg)'+char(13)+
															'AND b.sporttype IN (SELECT Sporttype FROM @TmpCondSumWL)'+char(13)+
															'AND b.statusID <> 101 '+char(13)+
															'AND ISNULL(b.isBA,0) = 0'+char(13)+
															'AND (b.Winlostdate BETWEEN'''+convert(varchar(10),@FDate, 120)+'''AND'''+convert(varchar(10),@TempToDate, 120)+''')'+char(13)+
															CASE	WHEN (@SiteType=0) THEN ''
																	WHEN (@SiteType=1) THEN 'AND b.betfrom = ''m'' '
																	WHEN (@SiteType=2) THEN 'AND b.betfrom IN (''s'',''l'')'
																	WHEN (@SiteType=3) THEN 'AND b.betfrom NOT IN (''s'',''m'',''l'')'
															     ELSE '' END +char(13)+
													'GROUP BY  b.winlostdate,   b.currency, b.sporttype, b.statusID'				
				
					END
					
			END
		
	END
	
	SELECT @sql = @sql  +char(13)+'CREATE NONCLUSTERED INDEX IDX_Index_SA ON #SAgWinLoss(Currency)'+char(13)+
								'SELECT * INTO #TempExchange FROM Lrf_f_GetExchangeDaily('''+convert(varchar(10),@FDate, 120)+''','''+convert(varchar(10),@TDate, 120)+''')'+char(13)+
								'WHERE exchangeid IN (SELECT DISTINCT Currency FROM #SAgWinLoss)'+char(13)
	
	SELECT @sql1= @sql+ char(13)+'SELECT w.winlostdate,Currency ,'+char(13)+
							
							'CASE WHEN Currency = 51 THEN'''+@VNDCurrencyName+''''+char(13)+
							'ELSE e.Code END currencyName,'+char(13)+
							'SUM(TurnOver)	AS Turnover,'+   +char(13)+
							'SUM(Winlost)		AS Winlost,'+char(13)+  
							'SUM(LicenseeWL) AS LicenseeWL,'+char(13)+
							'SUM(WinlossRB)	AS WinlossRB,'+char(13)+
							'SUM(CommBA) AS CommBA,'+char(13)+
							'SUM(CommRB) AS CommRB,'+char(13)+
							'SUM(PlayerComm) AS PlayerComm,'+char(13)+
							'SUM(AmtDuetoBA) AS AmtDuetoBA,'+char(13)+
							'SUM(AmtDuetoRB) AS AmtDuetoRB,'+char(13)+
							'SUM(Company) AS Company,'+char(13)+
							'SUM(Betcount)	AS Betcount,'+char(13)+
								
							--BaseEUR  
							'SUM(TurnOver*e.EUR)	AS TurnoverEUR,'+char(13)+   
							'SUM(Winlost*e.EUR)	AS WinlostEUR,'+char(13)+  
							'SUM(LicenseeWL*e.EUR) AS LicenseeWLEUR,'+char(13)+
							'SUM(WinlossRB*e.EUR)	AS WinlossRBEUR,'+char(13)+
							'SUM(CommBA * e.EUR) AS CommBAEUR,'+char(13)+
							'SUM(CommRB * e.EUR) AS CommRBEUR,'+char(13)+
							'SUM(PlayerComm*e.EUR) as PlayercommEUR,'+char(13)+
							'SUM(AmtDuetoBA*e.EUR) AS AmtDuetoBAEUR,'+char(13)+
							'SUM(AmtDuetoRB*e.EUR) AS AmtDuetoRBEUR,'+char(13)+
							'SUM(Company * e.EUR) AS CompanyEUR,'+char(13)+
							--BaseUSD  
							'SUM(TurnOver*e.USD)	AS TurnoverUSD,'+char(13)+   
							'SUM(Winlost*e.USD)	AS WinlostUSD,'+char(13)+  
							'SUM(LicenseeWL*e.USD) AS LicenseeWLUSD,'+char(13)+
							'SUM(WinlossRB*e.USD)	AS WinlossRBUSD,'+char(13)+
							'SUM(CommBA * e.USD) AS CommBAUSD,'+char(13)+
							'SUM(CommRB * e.USD) AS CommRBUSD,'+char(13)+
							'SUM(PlayerComm*e.USD) as PlayercommUSD,'+char(13)+
							'SUM(AmtDuetoBA*e.USD) AS AmtDuetoBAUSD,'+char(13)+
							'SUM(AmtDuetoRB*e.USD) AS AmtDuetoRBUSD,'+char(13)+
							'SUM(Company * e.USD) AS CompanyUSD'+char(13)+
							
						'FROM #SAgWinLoss w'+char(13)+
							'INNER JOIN #TempExchange e'+char(13)+
							--'INNER JOIN ExchangeDaily e WITH (NOLOCK)'+char(13)+
							'ON w.winlostdate = e.ExchangeDate AND w.currency = e.ExchangeId'+char(13)+
						'GROUP BY'+char(13)+
							'w.winlostdate,Currency,CONVERT(VARCHAR(8),w.winlostdate,112),'	+char(13)+
							'CASE WHEN Currency = 51 THEN'''+@VNDCurrencyName+'''ELSE e.Code END'+char(13)+
						'ORDER BY w.winlostdate'+char(13) +
						'DROP TABLE #SAgWinLoss'+char(13) +
						'DROP TABLE #TempExchange'+char(13) 
	--SET @sql=@sql+char(13)+@sql1			
	IF (@debug = 1) 
		PRINT (@sql1 )
	ELSE
		EXEC(@sql1 )
END	
GRANT EXECUTE ON [dbo].[Lrf_Rpt_MobileWinloss] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_MobileWinloss] TO [vnteam]  
	
	

	
	
	