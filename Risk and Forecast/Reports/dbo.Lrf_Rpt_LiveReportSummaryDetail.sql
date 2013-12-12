USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER  PROCEDURE [dbo].[Lrf_Rpt_LiveReportSummaryDetail]      
	@LicenseeID INT , 
	@UserID		INT,	
	@CurrencyID INT = NULL ,  
	@ProductCode VARCHAR(20) = NULL,  
	@FromDate  SMALLDATETIME,    
	@ToDate  SMALLDATETIME,  
	@MoveBetsDay SMALLDATETIME ,
	@Debug		BIT = 0
	 
AS /*  
Created: 20111115@Henry  
Task : Live Report Summary by Sport  
DB: DB052.bodb02  
  
Revisions:  
  
	Return 3 tables:  
	WinlostBySport  
	WinlostByCurrency  
	WinlostByBetType  
	
-20111208@Jim: change bettype condition 
-20120110@Henry: remove Licensee Type + Get data from rpt_Betting + remove currency UUS
-20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
-20120614@Jim: optimize code 	 
-20120725@Jim: add playercomm value 
-20120815@Henry: add Live casino
-20120831@Henry: add Virtual Sports
-20121128@Henry: use new table LicenseeBATransaction_active to get bettrans BA tickets
-20130328@Scott: Support RNG Casino and Bingo
-20130618@Jim:  Restrict permission of Licensee Users by currency
-20130625@Jim: support to view Currency UUS
-20131203@Jim: offer Virtual Greyhound, Virtual Motor Racing
     
Param's Explanation:  
  
Example:  
  
DECLARE @FromDate DATETIME  
DECLARE @ToDate DATETIME  
DECLARE @MoveBetsDay DATETIME  
SELECT @FromDate = DATEADD(DAY, -15, GETDATE())  
SELECT @ToDate = GETDATE()  
SELECT @MoveBetsDay = MAX(eventdate) FROM match14 WITH(NOLOCK)
  
EXEC [Lrf_Rpt_LiveReportSummaryDetail_xtest]  @LicenseeId = 1, @CurrencyID = 0, @FromDate=@FromDate, @ProductCode= NULL, @ToDate=@ToDate, @MoveBetsDay = @MoveBetsDay  
  
*/  



DECLARE @TempFromDate DATETIME   
DECLARE @TempToDate DATETIME   
declare @sql varchar(MAX)
DECLARE @FDate SMALLDATETIME  
DECLARE @TDate SMALLDATETIME 
	
--to Deal With Parameter Sniffing
SELECT @FDate=@FromDate,@TDate=@ToDate 
  
IF @CurrencyID IS NULL
	SET @CurrencyID = 0  

DECLARE @site VARCHAR(50)
SELECT @site=LicenseeName FROM bodb_licensee.dbo.Licensees (NOLOCK) 
WHERE LicenseeID=@LicenseeID	
 
SELECT @sql = 'SET NOCOUNT ON  ' + char(13)

--declare
SELECT @sql = @sql + '--Declare variable:' + char(13)

SELECT @sql = @sql + 'DECLARE @TempAg AS TABLE ( CustId INT )' + char(13) +
			'CREATE TABLE #tmpWinloss (winlostdate  DATETIME,Currency  INT,BetType INT,TurnOver  MONEY,Winlost   MONEY,LicenseeWL  MONEY,Comm   MONEY,PlayerComm MONEY,AmtDueTo3rd  MONEY,Betcount  INT ) '+ char(13)
			
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

SELECT @sql = @sql + 'DECLARE @Super AS TABLE (custid int primary key, currency int)' + char(13) 

--insert superIds to temp table
SELECT @sql = @sql + 'INSERT INTO @Super(custid,currency)  ' + char(13) +
			'SELECT CustID,currency 
			FROM Dep_CustSuper dc WITH (NOLOCK) 
			INNER JOIN #Currency c ON dc.Currency=c.CurrencyID
			WHERE site = ''' + convert(varchar(100),@site) + '''' + char(13)
      
IF @ProductCode IS NULL  
	SET @ProductCode = ''      
    
IF @TDate > @MoveBetsDay  
BEGIN  
	IF @FDate <= @MoveBetsDay   
		SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)  
	ELSE  
		SET @TempFromDate = @FDate  
	

	
	--BA
	IF @ProductCode = '' OR @ProductCode ='BA'
	BEGIN
		SELECT @sql = @sql + '--Get data from bettrans for BA' + char(13)
		SELECT @sql = @sql + 'INSERT INTO #tmpWinloss' + char(13) +
					'SELECT ' + char(13) +
						'b.winlostdate, '  + char(13) +
						's.currency,'  + char(13) +
						'b.bettype,'  + char(13) +
						'SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END) turnover,'  + char(13) +
						'SUM(b.winlost - b.actual_stake) AS Winlost,'  + char(13) +
						'0 AS LicenseeWL,'  + char(13) +
						'SUM (comm ) AS Comm,'  + char(13) +
						'SUM (b.playercomm  ) AS PlayerComm,'  + char(13) +
						'- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,  '  + char(13) +
						'COUNT(b.transid) BetCount'  + char(13) +
					'FROM bettrans b  WITH (NOLOCK,INDEX=IX_srecommend)'  + char(13) +
						'INNER JOIN @TempAg t  ON b.recommend =t.custid'  + char(13) +
						'INNER JOIN @Super s ON b.srecommend = s.custid' + char(13) +
						'INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON s.custid=ba.srecommend and b.transid = ba.transid'  + char(13) +
					'WHERE b.winlostdate BETWEEN ''' + convert(varchar(10),@TempFromDate, 120) + ''' AND ''' + convert(varchar(10),@TDate, 120) + '''' + char(13) +
						'AND b.statusID IN (111,112,113)'  + char(13) +
					'GROUP BY  b.winlostdate, s.currency, b.bettype'  + char(13) 
	END
	
	--Not BA
	IF @ProductCode = '' OR @ProductCode='NG' OR @ProductCode='SB' OR @ProductCode='RB' OR @ProductCode='LC' OR @ProductCode='VS' OR @ProductCode='CS' OR @ProductCode='BG'
	BEGIN
		SELECT @sql = @sql + '--Get data from bettrans for non - BA' + char(13)
		
		SELECT @sql = @sql + 'INSERT INTO #tmpWinloss' + char(13) +
					'SELECT ' + char(13) +
						'b.winlostdate, '  + char(13) +
						's.currency,'  + char(13) +
						'b.bettype,'  + char(13) +
						'SUM(CASE WHEN b.bettype = 33 AND b.liveawayscore = 0 THEN stake/2 ELSE stake END) turnover,'  + char(13) +
						'SUM(b.winlost - b.actual_stake) AS Winlost,'  + char(13) +
						'SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.awinlost ELSE  -1 * (b.winlost - b.actual_stake) END) AS LicenseeWL,' + char(13) +
						'SUM (comm ) AS Comm,' + char(13) +
						'SUM ( b.playercomm  ) AS PlayerComm,' + char(13) +
						'- SUM(b.awinlost + b.winlost - b.actual_stake + b.comm) AmountDueTo3rd  ,  ' + char(13) +
						'COUNT(b.transid) BetCount' + char(13) +
					'FROM bettrans b  WITH (NOLOCK,INDEX=IX_srecommend)'  + char(13) +
						'INNER JOIN @TempAg t  ON b.recommend =t.custid'  + char(13) +
						'INNER JOIN @Super s ON b.srecommend = s.custid' + char(13) +
						'LEFT JOIN dbo.match m WITH (NOLOCK) ON b.matchID=m.matchID' + char(13) +
						'LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active BA WITH (NOLOCK) ON s.custid=ba.srecommend and  b.transid = BA.transid' + char(13) +
					'WHERE b.winlostdate BETWEEN ''' + convert(varchar(10),@TempFromDate, 120) + ''' AND ''' + convert(varchar(10),@TDate, 120) + '''' + char(13) +
						'AND b.Bettype <= 19999' + char(13) +
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
							
							ELSE '' END + char(13) +
					'GROUP BY  b.winlostdate, s.currency, b.bettype
								' + char(13)
					 
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
						'b.bettype,' + char(13) +
						'sum(b.turnover) turnover,' + char(13) +
						'sum(b.winloss) winlost,' + char(13) +
						'0 AS LicenseeWL,' + char(13) +
						'SUM (CommissionA) as Comm,' + char(13) +
						'SUM (CommissionP  ) as PlayerComm,' + char(13) +
						'- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + char(13) +
						'sum(b.betcount) BetCount' + char(13) +
					'FROM bodb_Licensee.dbo.rpt_Betting_BA b WITH ( NOLOCK )' + char(13) +	
					'INNER JOIN #Currency c ON b.siteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID'+char(13)+
					'WHERE b.rptDate BETWEEN ''' + convert(varchar(10),@FDate, 120) + ''' AND ''' + convert(varchar(10),@TempToDate, 120) + '''' + char(13) + 
						'AND b.status NOT IN (-1,103)' + char(13) +
						'AND b.siteID ='  + convert(varchar(10), @LicenseeID ) + char(13) +
						--'AND b.CurrencyID <> 20 '  + char(13) +
						CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID ='  + convert(varchar(10), @CurrencyID ) ELSE '' END + char(13) +
					'GROUP BY b.rptDate, b.currencyID, b.bettype' + char(13) 
	END
	
	--Not BA
	IF @ProductCode = '' OR @ProductCode='RB' OR @ProductCode='NG' OR @ProductCode='SB' OR @ProductCode='LC' OR @ProductCode='VS' OR @ProductCode='CS' OR @ProductCode='BG'
	BEGIN
	
		SELECT @sql = @sql + 'INSERT INTO #tmpWinloss' + char(13) +
					'SELECT ' + char(13) +
						'b.rptDate,' + char(13) +
						'b.currencyID,' + char(13) +
						'b.bettype,' + char(13) +
						'SUM(b.turnover * CASE WHEN b.bettype=33 AND b.status IN (114,115) THEN 0.5 ELSE 1 END) turnover,' + char(13) + 	
						'sum(b.winloss) winlost,' + char(13) +
						'SUM(CASE WHEN bettype BETWEEN 31 AND 33 THEN b.WinlossA ELSE  -1 * b.winloss END) AS LicenseeWL,' + char(13) + 
						'sum(b.CommissionA) Comm,' + char(13) +
						'sum( b.CommissionP ) PlayerComm,' + char(13) +
						'- SUM (b.winloss+b.WinlossA+b.CommissionA) AmountDueTo3rd,' + char(13) + 	
						'sum(b.betcount) BetCount' + char(13) + 
					'FROM bodb_Licensee.dbo.rpt_Betting b WITH ( NOLOCK )' + char(13) +	
					'INNER JOIN #Currency c ON b.SiteID=c.LicenseeID AND b.CurrencyID=c.CurrencyID'+char(13)+
					'WHERE b.rptDate BETWEEN ''' + convert(varchar(10),@FDate, 120) + ''' AND ''' + convert(varchar(10),@TempToDate, 120) + '''' + char(13) + 
						'AND b.status NOT IN (-1,103)' + char(13) +
						'AND b.siteID ='  + convert(varchar(10), @LicenseeID ) + char(13) +
						---'AND b.CurrencyID <> 20 '  + char(13) +
						CASE WHEN @CurrencyID <> 0 THEN 'AND b.CurrencyID ='  + convert(varchar(10), @CurrencyID ) ELSE '' END + char(13) +	
						CASE 
							WHEN @ProductCode='NG' THEN 'AND b.bettype BETWEEN 81 AND 120 '
							WHEN @ProductCode='SB' THEN 'AND (b.bettype <= 30 OR (b.bettype BETWEEN 121 AND 999))'
							WHEN @ProductCode='RB' THEN 'AND b.bettype BETWEEN 31 AND 33'
							WHEN @ProductCode='LC' THEN 'AND b.bettype BETWEEN 1101 AND 1199'
							WHEN @ProductCode='VS' THEN 'AND b.bettype BETWEEN 1201 AND 1299'
							WHEN @ProductCode='CS' THEN 'AND b.bettype = 71'
							WHEN @ProductCode='BG' THEN 'AND b.bettype = 73'
							ELSE '' END + char(13) +
					'GROUP BY b.rptDate, b.currencyID, b.bettype' + char(13)  	
			
	END

END   


-- Get winlost by currency  

SELECT @sql = @sql + 'CREATE NONCLUSTERED INDEX IX_tmpWinloss ON #tmpWinloss (Currency)' + char(13)
SELECT @sql = @sql + ' SELECT * INTO #TempExchange
						FROM Lrf_f_GetExchangeDaily('''+convert(varchar(10),@FDate,120)+''','''+convert(varchar(10),@TDate,120)+''')'+char(13)+
						'WHERE exchangeid IN (SELECT DISTINCT Currency FROM #tmpWinloss ) ' + char(13)
SELECT @sql = @sql + '-- Get winlost by currency  ' + char(13)
SELECT @sql = @sql + 'select CASE WHEN e.Code = ''VND'' THEN ''INH'' ELSE e.code END AS Currency, ' + char(13) + 
						'SUM(TurnOver) AS Turnover,' + char(13) + 
						'SUM(Winlost)  AS Winlost,' + char(13) + 
						'SUM(LicenseeWL) AS LicenseeWL,' + char(13) + 
						'SUM(Comm) AS Comm,' + char(13) + 
						'SUM(PlayerComm) AS PlayerComm,' + char(13) + 
						'SUM(AmtDueto3rd) AS AmtDueto3rd, ' + char(13) + 
						'SUM(Betcount) AS Betcount,' + char(13) + 
						
						--BaseEUR
						'CAST(SUM(TurnOver*e.EUR) AS MONEY) AS TurnoverEUR,' + char(13) + 
						'CAST(SUM(Winlost*e.EUR) AS MONEY) AS WinlostEUR,' + char(13) + 
						'CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,' + char(13) + 
						'CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,' + char(13) + 
						'CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR,' + char(13) + 
						'CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,' + char(13) + 
						
						--BaseUSD
						'CAST(SUM(TurnOver*e.USD) AS MONEY) AS TurnoverUSD,' + char(13) + 
						'CAST(SUM(Winlost*e.USD) AS MONEY) AS WinlostUSD,' + char(13) + 
						'CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,' + char(13) + 
						'CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD, ' + char(13) + 
						'CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD, ' + char(13) + 
						'CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD ' + char(13) + 
					'from #tmpWinloss b  WITH (NOLOCK)  ' + char(13) + 
						'INNER JOIN #TempExchange e '+char(13)+
						'ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency ' + char(13) + 
					'group by CASE WHEN e.Code = ''VND'' THEN ''INH'' ELSE e.code END' + char(13) + 
					'Order By CASE WHEN e.Code = ''VND'' THEN ''INH'' ELSE e.code END ' + char(13) 
		 
		 
  
-- Get winlost by bettype   
SELECT @sql = @sql + '-- Get winlost by bettype  ' + char(13)

SELECT @sql = @sql + 'SELECT b.bettype,' + char(13) +
						'SUM(TurnOver) AS Turnover,' + char(13) +
						'SUM(Winlost)  AS Winlost,' + char(13) +
						'SUM(LicenseeWL) AS LicenseeWL,' + char(13) +
						'SUM(Comm) AS Comm,' + char(13) +
						'SUM(PlayerComm) AS PlayerComm,' + char(13) +
						'SUM(AmtDueto3rd) AS AmtDueto3rd,' + char(13) +
						'SUM(Betcount) AS Betcount,' + char(13) +
						--BaseEUR
						'CAST(SUM(TurnOver*e.EUR) AS MONEY) AS TurnoverEUR, ' + char(13) +
						'CAST(SUM(Winlost*e.EUR) AS MONEY) AS WinlostEUR,' + char(13) +
						'CAST(SUM(LicenseeWL*e.EUR) AS MONEY) AS LicenseeWLEUR,' + char(13) +
						'CAST(SUM(Comm * e.EUR) AS MONEY) AS CommEUR,' + char(13) +
						'CAST(SUM(PlayerComm * e.EUR) AS MONEY) AS PlayerCommEUR,' + char(13) +
						'CAST(SUM(AmtDueto3rd*e.EUR) AS MONEY) AS AmtDueto3rdEUR,' + char(13) +
						--baseUSD
						'CAST(SUM(TurnOver*e.USD) AS MONEY) AS TurnoverUSD,' + char(13) +
						'CAST(SUM(Winlost*e.USD) AS MONEY) AS WinlostUSD,' + char(13) +
						'CAST(SUM(LicenseeWL*e.USD) AS MONEY) AS LicenseeWLUSD,' + char(13) +
						'CAST(SUM(Comm * e.USD) AS MONEY) AS CommUSD,' + char(13) +
						'CAST(SUM(PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD,' + char(13) +
						'CAST(SUM(AmtDueto3rd*e.USD) AS MONEY) AS AmtDueto3rdUSD' + char(13) +
					'FROM #tmpWinloss b  WITH (NOLOCK) ' + char(13) +
						'INNER JOIN bettype bt WITH (nolock) ON b.bettype = bt.typeid ' + char(13) +
						'INNER JOIN #TempExchange e'+char(13)+
						'ON e.ExchangeDate = b.winlostdate   AND e.exchangeid = b.currency ' + char(13) +
						'group by b.bettype' + char(13) +
'DROP TABLE #tmpWinloss' + char(13)+ 
'DROP TABLE #TempExchange' + char(13)+
'DROP TABLE #Currency' + char(13)
			
IF (@debug = 1) PRINT @sql
ELSE EXEC(@sql)
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_LiveReportSummaryDetail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_LiveReportSummaryDetail] TO [vnteam] AS [dbo]