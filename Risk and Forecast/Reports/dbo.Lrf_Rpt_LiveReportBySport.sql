USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_LiveReportBySport]      
	@LicenseeID INT ,  
	@UserID		INT,
	@CurrencyID INT = NULL ,  
	@ProductCode VARCHAR(20) = NULL,  
	@FromDate  SMALLDATETIME,    
	@ToDate  SMALLDATETIME,  
	@MoveBetsDay SMALLDATETIME ,
	@Debug		BIT = 0 
AS /*  
Created: 20111031@  
Task : Live Report Summary BY Sport  
DB: DB052.bodb02  
  
Revisions:  
	-20111208@Jim: change bettype condition
	-20120110@Henry: remove Licensee Type + Get data from rpt_Betting + remove currency UUS
	-20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
    -20120614@Jim: optimize code  
	-20120726@Jim: add playercomm value 
	-20120814@Henry: add live casino
	-20120830@Henry: add Virtual Sports ...
	-20121004@Jim: replace @currency input param by @currencyID
	-20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
	-20130328@Scott: Support RNG Casino and Bingo
	-20130618@Jim:  Restrict permission of Licensee Users by currency
	-20130625@Jim: support to view currency UUS
	-20130809@Jim: offer Virtual Horse Racing
	-20131007@Jim: support Virtual Tennis
	- 20131129@Jim: support :
				182 – Virtual Greyhounds
				184 – Virtual Motor Racing
	-20140410@Jim: fix bug #14715 (wrong RNG Casino sporttype)			
Param's Explanation:  
  
Example:  
  
DECLARE @FromDate DATETIME  
DECLARE @ToDate DATETIME  
DECLARE @MoveBetsDay DATETIME  
SELECT @FromDate = DATEADD(DAY, -15, GETDATE())  
SELECT @ToDate = GETDATE()  
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)
  
EXEC [Lrf_Rpt_LiveReportBySport]  @LicenseeId = 1,  @CurrencyID = 0, @FromDate=@FromDate, @ProductCode= NULL, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay  
  
*/  
 

DECLARE @TempFromDate DATETIME   
DECLARE @TempToDate DATETIME   
DECLARE @FDate SMALLDATETIME  
DECLARE @TDate SMALLDATETIME 
	
--to Deal With Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 

declare @sql varchar(MAX)

IF @CurrencyID IS NULL
	SET @CurrencyID = 0

SELECT @sql = 'SET NOCOUNT ON  ' + char(13) 

--declare
SELECT @sql = @sql + '--Declare variable:' + char(13)  

SELECT @sql = @sql + 'DECLARE @TempAg AS TABLE ( CustId INT )' + char(13) +
			'CREATE TABLE #tmpWinloss (winlostdate  DATETIME,Currency  INT,SportType  INT,TurnOver  MONEY,Winlost   MONEY,LicenseeWL  MONEY,Comm   MONEY,PlayerComm MONEY,AmtDueTo3rd  MONEY,Betcount  INT)' + char(13)			
SELECT @sql = @sql + 
			'SELECT  currencyID,LicenseeID into #currency'+char(13)+
			'FROM  dbo.Lrf_f_GetCurrencybyUser('+convert(varchar(20),@licenseeID)+','+convert(varchar(20),@userID)+',1)'+char(13)+ -- System is default=1 (LRF)
			'WHERE ('+convert(varchar(10),@CurrencyID)+'=0  OR ('+convert(varchar(10),@CurrencyID)+'<>0 AND CurrencyID='+convert(varchar(20),@CurrencyID)+'))'+char(13)			

--insert agentIds to temp table
SELECT @sql = @sql + 'INSERT  INTO @TempAg ( CustId)' + char(13) +
			'SELECT  CustID  FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK ) ' + char(13) +
							'INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID'+char(13)+
			'WHERE lc.LicenseeID =' + convert(varchar(10), @LicenseeID ) + char(13) +
				--'AND lc.currency <> 20 ' + char(13) +
				CASE WHEN @CurrencyID<>0 THEN 'AND lc.Currency=' + convert(varchar(10), @CurrencyID) ELSE '' END + char(13) 
				
IF @ProductCode IS NULL  
	SET @ProductCode = ''      
  

IF @TDate > @MoveBetsDay  
BEGIN  
	IF @FDate <= @MoveBetsDay   
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)  
	ELSE  
		SET @TempFromDate = @FDate  
  
	IF @ProductCode = 'BA' OR @ProductCode = ''
	BEGIN  
		SELECT @sql = @sql + '--Get data from bettrans for BA' + char(13)
		
		SELECT @sql = @sql + 'INSERT INTO #tmpWinloss' + char(13) +
					'SELECT ' + char(13) +
						'b.winlostdate,' + char(13) +
						'b.currency,' + char(13) +
						'CASE' + char(13) +
							'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + char(13) +
							'WHEN b.bettype = 29 THEN 102 --System Parlay' + char(13) +
							'WHEN b.bettype = 10 THEN 103 -- Outright' + char(13) +
							'ELSE m.SportType END as Sporttype,' + char(13) +
						'SUM(Stake) turnover,' 	+ char(13) +	
						'SUM(b.winlost - b.actual_stake) AS Winlost, ' 	+ char(13) +
						'0 AS LicenseeWL,' 	+ char(13) +
						'SUM (comm) AS Comm,' 	+ char(13) +
						'SUM ( playercomm  ) AS PlayerComm,' 	+ char(13) +
						'- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,' 	+ char(13) +
						'COUNT(b.transid) BetCount' 	+ char(13) +
					'FROM bettrans b  WITH (NOLOCK) ' 	+ char(13) +	
						'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active ba WITH (NOLOCK) ON b.recommend=ba.recommend and b.transid = ba.transid' 	+ char(13) +
						'INNER JOIN @TempAg t  ON b.recommend =t.custid' 	+ char(13) +
						'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid' 	+ char(13) +
					'WHERE b.winlostdate BETWEEN ''' + convert(varchar(10),@TempFromDate, 120) + ''' AND ''' + convert(varchar(10),@TDate, 120) + '''' + char(13) +
						'AND b.statusID IN (111,112,113)' + char(13) +
					'GROUP BY  b.winlostdate, b.currency, ' 	+ char(13) +
						'CASE' + char(13) +
							'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + char(13) +
							'WHEN b.bettype = 29 THEN 102 --System Parlay' + char(13) +
							'WHEN b.bettype = 10 THEN 103 -- Outright' + char(13) +
							'ELSE m.SportType END ' + char(13) 
	END    
  
	IF @ProductCode = '' OR @ProductCode = 'RB' OR @ProductCode = 'NG' OR @ProductCode = 'SB' OR @ProductCode = 'LC' OR @ProductCode = 'VS' OR @ProductCode = 'CS' OR @ProductCode = 'BG'
	BEGIN  
		SELECT @sql = @sql + '--Get data from bettrans for non-BA' + char(13)
	 
		SELECT @sql = @sql + '--Get data for Virtual Horse Racing,Virtual Greyhounds,Virtual Motor Racing ' + char(13)
		SELECT @sql = @sql +'SELECT 
							DISTINCT
							o.Orid,	
							r.SportType
							INTO #tmpVS	
							 FROM VSOutright o with (nolock)
							 INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
							 WHERE EventDate BETWEEN ''' + convert(varchar(10),@TempFromDate, 120) + ''' AND ''' + convert(varchar(10),@TDate, 120) + '''' + char(13) 
	
		SELECT @sql = @sql + 'INSERT INTO #tmpWinloss' + char(13) +
					'SELECT ' + char(13) +
						'b.winlostdate,' + char(13) +
						'b.currency,' + char(13) +
						'CASE' + char(13) +
							'WHEN b.bettype BETWEEN 31 AND 33 THEN l.Sporttype' + char(13) +
							'WHEN b.bettype BETWEEN 81 AND 120 THEN 161 --NG' + char(13) +
							'WHEN b.bettype BETWEEN 1101 AND 1199 THEN 162 --LC' + char(13) +
							'WHEN (b.bettype BETWEEN 1201 AND 1299) AND b.bettype NOT IN (1231,1232,1233,1237,1238,1220,1235,1236) THEN 180 --VS' + char(13) +
							'WHEN b.bettype IN (1231,1232,1233,1237,1238) THEN vs.SportType ' + char(13) + --VHR+V.Greyhounds+V.Motor Racing
							'WHEN b.bettype IN (1220,1235,1236) THEN 186 ' + char(13) + --Virtual Tennis
							'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + char(13) +
							'WHEN b.bettype = 29 THEN 102 --System Parlay' + char(13) +
							'WHEN b.bettype = 10 THEN 103 -- Outright' + char(13) +
							'WHEN b.bettype = 71 THEN 251 -- RNG Casino' + char(13) +
							'WHEN b.bettype = 73 THEN 252 -- Bingo' + char(13) +
							'ELSE m.SportType END as Sporttype,' + char(13) +
						'SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END) turnover,' + char(13) +
						'SUM(b.winlost - b.actual_stake) AS Winlost,' + char(13) +
						'SUM(CASE WHEN b.bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE  -1 * (b.winlost - b.actual_stake) END) AS LicenseeWL,  ' + char(13) +
						'SUM (comm) AS Comm,' + char(13) +
						'SUM ( playercomm  ) AS PlayerComm,' + char(13) +
						'- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,' + char(13) +
						'COUNT(b.transid) BetCount' + char(13) +
					'FROM bettrans b  WITH (NOLOCK)' + char(13) +
						'INNER JOIN @TempAg t  ON b.recommend =t.custid' + char(13) +
						'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON b.recommend=BA.recommend AND b.transid = BA.transid' + char(13) +
						'LEFT JOIN outright o with(nolock) ON b.matchid = o.orid' + char(13) +
						'LEFT JOIN league l with(nolock) ON o.leagueid = l.leagueid' + char(13) +
						'LEFT JOIN [match] m with(nolock) ON b.matchid = m.matchid' + char(13) +
						'LEFT JOIN #tmpVS vs ON b.oddsid=vs.Orid AND b.bettype IN (1231,1232,1233,1237,1238,1220,1235,1236)'+char(13)+	
					'WHERE b.winlostdate BETWEEN ''' + convert(varchar(10),@TempFromDate, 120) + ''' AND ''' + convert(varchar(10),@TDate, 120) + '''' + char(13) +
						'AND b.statusID IN (111,112,113)' + char(13) +
						'AND BA.transid IS NULL' + char(13) +
						CASE 
							WHEN @ProductCode='NG' THEN 'AND b.bettype BETWEEN 81 AND 120 '
							WHEN @ProductCode='SB' THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999))'
							WHEN @ProductCode='RB' THEN 'AND b.bettype BETWEEN 31 AND 33'
							WHEN @ProductCode='LC' THEN 'AND b.bettype BETWEEN 1101 AND 1199'
							WHEN @ProductCode='VS' THEN 'AND b.bettype BETWEEN 1201 AND 1299'
							WHEN @ProductCode='CS' THEN 'AND b.bettype = 71'
							WHEN @ProductCode='BG' THEN 'AND b.bettype = 73'
							ELSE 'AND b.bettype NOT BETWEEN 1501 AND 1599' END + char(13) +
					'' + char(13) +		
					'GROUP BY  b.winlostdate, b.currency,' + char(13) +
						'CASE' + char(13) +
							'WHEN b.bettype BETWEEN 31 AND 33 THEN l.Sporttype' + char(13) +
							'WHEN b.bettype BETWEEN 81 AND 120 THEN 161 --NG' + char(13) +
							'WHEN b.bettype BETWEEN 1101 AND 1199 THEN 162 --LC' + char(13) +
							'WHEN (b.bettype BETWEEN 1201 AND 1299) AND b.bettype NOT IN (1231,1232,1233,1237,1238,1220,1235,1236) THEN 180 --VS' + char(13) +
							'WHEN b.bettype IN (1231,1232,1233,1237,1238) THEN vs.SportType '+char(13)+  --VHR+V.Greyhounds+V.Motor Racing
							'WHEN b.bettype IN (1220,1235,1236) THEN 186 ' +char(13) + --Virtual Tennis
							'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + char(13) +
							'WHEN b.bettype = 29 THEN 102 --System Parlay' + char(13) +
							'WHEN b.bettype = 10 THEN 103 -- Outright' + char(13) +
							'WHEN b.bettype = 71 THEN 251 -- RNG Casino' + char(13) +
							'WHEN b.bettype = 73 THEN 252 -- Bingo' + char(13) +
							'ELSE m.SportType END ' + char(13) 
		
				SELECT @sql = @sql + 'DROP TABLE #tmpVS' + char(13)
	END  
  
END  
  
IF @FDate <= @MoveBetsDay   
BEGIN  
	IF @TDate >= @MoveBetsDay  
		SET @TempToDate = @MoveBetsDay  
	ELSE  
		SET  @TempToDate = @TDate  
	
	--BA
	IF @ProductCode = '' OR @ProductCode ='BA'
	BEGIN
		SELECT @sql = @sql + '--Get data from rpt_Betting_BA for BA' + char(13)
		
		SELECT @sql = @sql + 'INSERT INTO #tmpWinloss' + char(13) +
					'SELECT ' + char(13) +
						'b.rptDate,' + char(13) +
						'b.currencyID,' + char(13) +
						'CASE' + char(13) +
							'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + char(13) +
							'WHEN b.bettype = 29 THEN 102 --System Parlay' + char(13) +
							'WHEN b.bettype = 10 THEN 103 -- Outright' + char(13) +
							'ELSE l.SportType END as Sporttype,' + char(13) +
						'sum(b.turnover) turnover,' + char(13) +
						'sum(b.winloss) winlost,' + char(13) +
						'0 AS LicenseeWL,' + char(13) +
						'SUM (CommissionA) as Comm,' + char(13) +
						'SUM (CommissionP  ) as PlayerComm,' + char(13) +
						'- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + char(13) +
						'sum(b.betcount) BetCount' + char(13) +
					'FROM bodb_Licensee.dbo.rpt_Betting_BA b WITH ( NOLOCK )' + char(13) +
						'INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID'+char(13)+
						'LEFT JOIN league l WITH (NOLOCK) ON b.LeagueID = l.LeagueID' + char(13) +
					'WHERE b.rptDate BETWEEN ''' + convert(varchar(10),@FDate, 120) + ''' AND ''' + convert(varchar(10),@TempToDate, 120) + '''' + char(13) + 
						'AND b.status NOT IN (-1,103)' + char(13) +
						'AND b.siteID ='  + convert(varchar(10), @LicenseeID ) + char(13) +
						--'AND b.CurrencyID <> 20 ' + char(13) +
						CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID ='  + convert(varchar(10), @CurrencyID ) ELSE '' END + char(13) +
					'GROUP BY b.rptDate, b.currencyID, ' + char(13) +
						'CASE' + char(13) +
							'WHEN b.bettype = 9 THEN 101 --Mix Parlay' + char(13) +
							'WHEN b.bettype = 29 THEN 102 --System Parlay' + char(13) +
							'WHEN b.bettype = 10 THEN 103 -- Outright' + char(13) +
							'ELSE l.SportType END ' + char(13) 
		
	END
	
	--Not BA
	IF @ProductCode = '' OR @ProductCode='RB' OR @ProductCode='NG' OR @ProductCode='SB' OR @ProductCode = 'LC' OR @ProductCode = 'VS' OR @ProductCode = 'CS' OR @ProductCode = 'BG'
	BEGIN
		SELECT @sql = @sql + '--Get data from rpt_Betting for non-BA' + char(13)
	
		SELECT @sql = @sql + 'INSERT INTO #tmpWinloss' + char(13) +
					'SELECT ' + char(13) +
						'b.rptDate,' + char(13) +
						'b.currencyID,' + char(13) +
						'CASE WHEN b.bettype = 9    THEN 101
							  WHEN b.bettype  = 29  THEN 102
							  WHEN b.bettype  = 10 	THEN 103
							  WHEN b.bettype  = 71  THEN 251 
							  WHEN b.bettype  = 73	THEN 252
							  WHEN b.bettype BETWEEN 81 AND 120 THEN 161
							  ELSE ISNULL(l.sporttype,0) 
							END		
						SportType,' + char(13) +
						'SUM(b.turnover * CASE WHEN b.bettype=33 AND b.status IN (114,115) THEN 0.5 ELSE 1 END) turnover,' 	+ char(13) +
						'sum(b.winloss) winlost,' 	+ char(13) +
						'SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.WinlossA ELSE  -1 * b.winloss END) AS LicenseeWL,' 	+ char(13) +
						'sum(b.CommissionA) Comm,' 	+ char(13) +
						'sum( b.CommissionP  ) PlayerComm,' 	+ char(13) +
						'- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' 	+ char(13) +
						'sum(b.betcount) BetCount' 	+ char(13) +
					'FROM bodb_Licensee.dbo.rpt_Betting b WITH ( NOLOCK )' 	+ char(13) +
						'INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID'+char(13)+
						'LEFT JOIN league l WITH (NOLOCK) ON b.LeagueID = l.LeagueID' 	+ char(13) +
					'WHERE b.rptDate BETWEEN ''' + convert(varchar(10),@FDate, 120) + ''' AND ''' + convert(varchar(10),@TempToDate, 120) + '''' + char(13) + 
						'AND b.status NOT IN (-1,103)' + char(13) +
						'AND b.siteID ='  + convert(varchar(10), @LicenseeID ) + char(13) +
						--'AND b.CurrencyID <> 20 ' + char(13) +
						CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID ='  + convert(varchar(10), @CurrencyID ) ELSE '' END + char(13) +
						CASE 
							WHEN @ProductCode='NG' THEN 'AND b.bettype BETWEEN 81 AND 120 '
							WHEN @ProductCode='SB' THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999))'
							WHEN @ProductCode='RB' THEN 'AND b.bettype BETWEEN 31 AND 33'
							WHEN @ProductCode='LC' THEN 'AND b.bettype BETWEEN 1101 AND 1199'
							WHEN @ProductCode='VS' THEN 'AND b.bettype BETWEEN 1201 AND 1299'
							WHEN @ProductCode='CS' THEN 'AND b.bettype = 71'
							WHEN @ProductCode='BG' THEN 'AND b.bettype = 73'
							ELSE 'AND b.bettype NOT BETWEEN 1501 AND 1599' END + char(13) +
					'GROUP BY b.rptDate, b.currencyID, ' 	+ char(13) +
						'CASE WHEN b.bettype = 9    THEN 101
							  WHEN b.bettype  = 29   THEN 102
							  WHEN b.bettype  = 10 	 THEN 103
							  WHEN b.bettype  = 71  THEN 251 
							  WHEN b.bettype  = 73	THEN 252
							  WHEN b.bettype BETWEEN 81 AND 120 THEN 161
							  ELSE ISNULL(l.sporttype,0)  
							END' + char(13) 
		
	END
END   
  
  
-- Get winlost BY Sport   
SELECT @sql = @sql + '-- Get winlost by Sport  ' + char(13)
SELECT @sql = @sql + ' CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)  ' + char(13)
SELECT @sql = @sql + '  SELECT * INTO #TempExchange
						FROM Lrf_f_GetExchangeDaily('''+convert(varchar(10),@FDate,120)+''','''+convert(varchar(10),@TDate,120)+''')'+char(13)+
						'WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss ) ' + char(13)

SELECT @sql = @sql + 'select b.SportType, ' + char(13) + 
						'SUM(TurnOver) AS Turnover,' + char(13) + 
						'SUM(Winlost)  AS Winlost,' + char(13) + 
						'SUM(LicenseeWL) AS LicenseeWL,' + char(13) + 
						'SUM(Comm) AS Comm,' + char(13) + 
						'SUM(Playercomm) AS PlayerComm,' + char(13) + 
						'SUM(AmtDueto3rd) AS AmtDueto3rd, ' + char(13) + 
						'SUM(Betcount) AS Betcount,' + char(13) + 
						
						--BaseEUR
						'CAST(SUM(TurnOver*e.EUR) AS MONEY) AS TurnoverEUR,' + char(13) + 
						'CAST(SUM(Winlost*e.EUR) AS MONEY) AS WinlostEUR,' + char(13) + 
						'CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,' + char(13) + 
						'CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,' + char(13) + 
						'CAST(SUM(Playercomm * e.EUR) AS MONEY) AS PlayerCommEUR,' + char(13) + 
						'CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,' + char(13) + 
						
						--BaseUSD
						'CAST(SUM(TurnOver*e.USD) AS MONEY) AS TurnoverUSD,' + char(13) + 
						'CAST(SUM(Winlost*e.USD) AS MONEY) AS WinlostUSD,' + char(13) + 
						'CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,' + char(13) + 
						'CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD, ' + char(13) + 
						'CAST(SUM(Playercomm * e.USD) AS MONEY) AS PlayerCommUSD, ' + char(13) + 
						'CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD ' + char(13) + 
					'FROM #tmpWinloss b ' + char(13) + 
					'INNER JOIN #TempExchange e '+char(13)+
					'ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency ' + char(13) + 
					'group by b.SportType' + char(13) + 
			
'DROP TABLE #tmpWinloss' + char(13)+
'DROP TABLE #TempExchange' + char(13)+
'DROP TABLE #Currency' + char(13)
 					
  
IF (@debug = 1) PRINT @sql
ELSE EXEC(@sql)