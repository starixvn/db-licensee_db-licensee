ALTER PROCEDURE [dbo].[Lrf_Statement_Mem]  
    @CustID INT ,  
    @FromDate DATETIME ,  
    @ToDate DATETIME ,  
    @BalanceUpDay DATETIME ,  
    @MoveBetsDay DATETIME = NULL ,  
    @PageSize INT = 50 ,  
    @PageIndex INT = 1 ,  
    @TotalRows INT = 0 OUTPUT  
AS /*  
Created:   
Task : Daily Statement  
DB: DBEXT.bodb02 (DB052.bodb02)
Original: [Age_Statement_Mem]   
Revisions:  
 -- 20110304@Henry: suppport based currency  
 -- 20110510@Henry: fix bug not display outright bet  
 -- 20110616@Amy: modify to retrieve voided ticket from zzzbettrans before Move Bet Day  
 -- 20110725@Henry: Get refund tickets
 -- 20120222@Henry: get turnover from rptDepwinlost and rptDepwinlost_bk for before balanceup
 -- 20120706@Henry: Fix bug due to exchange rate, should get exchange rate from balanceup date instead of @FromDate
 -- 20120710@Henry: When get min winlostdate from @Data, should get only date (remove time)
 -- 20121207@Henry: Comment transdesc for bettype>19999
 -- 20131010@winnie: if @ToDate-@FromDate> 3 months => just get data report in 3 last months+ current month.
 -- 20131016@Don: Use the right server alias name
 -- 20131108@Victor: Enhance performance, use rptlicwinloss2 instead of rptDepwinlost
 -- 20140310@Florent: Add Keno product
 -- 20140310@Florent: remove  Bingo & RNG Casino Transfer and Outstanding 
 -- 20141002@Don: Fixed bug (Redmine ID #23380), if cannot get BU date of a specific customer in table Statement, the error will be happened
 -- 20150130@Winnie: Add base currency GBP  
 -- 20150507@Winnie: fix bug #35365
 -- 201506125@Winnie: support BetTrade
Param's Explanation:   
• @ErrCode:  
    = 0: add new member successfully.  
    > 0: Specific Error.  
    
• @ErrMsg: Error description.  
*/  
    SET NOCOUNT ON  
IF(SELECT DATEDIFF(mm,@FromDate,@ToDate))>3
SET @FromDate= DATEADD(MONTH, DATEDIFF(MONTH, 0, @ToDate) - 3, 0) -- GET
  
declare @fdate datetime, @tdate datetime

select @fdate = @FromDate, @tdate = @ToDate

    DECLARE @bet TABLE  
        (  
          winlostdate DATETIME ,  
          bettype SMALLINT ,  
          statusID SMALLINT ,  
          transdate DATETIME ,  
          transdesc NVARCHAR(300) ,  
          stake MONEY ,  
          actual_stake MONEY ,  
          winlost MONEY ,  
          playercomm MONEY  
        )   
  
    DECLARE @Data TABLE  
        (  
          OrderKey INT ,  
          winlostdate DATETIME ,  
          transtype NVARCHAR(100) ,  
          transdesc NVARCHAR(300) ,  
          TurnOver MONEY ,  
          totalAmt MONEY ,  
          Commission MONEY  
        )    
	DECLARE @DepWL TABLE
	(
		winlostdate DATETIME ,
		Turnover money
	)
    IF @tdate >= @BalanceUpDay   
        BEGIN   
            IF @fdate > @BalanceUpDay   
                SELECT  @fdate = @BalanceUpDay   
  
            INSERT  INTO @bet  
                    SELECT  winlostdate ,  
                            bettype ,  
                            CASE WHEN statusID IN (101,102) THEN 102  
                                 WHEN statusID IN (0,1) THEN 0  
                                 ELSE 131  
                            END ,  
                            CASE WHEN bettype <= 19999 THEN NULL  
                                 ELSE transdate  
                            END ,  
                            /*
                            CASE WHEN bettype <= 19999 THEN ''  
                                 ELSE transdesc  
                            END ,  
                            */
                            '' as transdesc, 
                            SUM(CASE WHEN bettrans.bettype IN ( 33, 43 )  
                                          AND bettrans.liveawayscore = 0  
                                          AND bettrans.livehomescore <> 0  
                                          AND ruben = 1  
                                     THEN bettrans.stake / 2  
                                     ELSE bettrans.stake  
                                END) ,  
                            SUM(actual_stake) ,  
                            SUM(winlost) ,  
                            SUM(playercomm)  
                    FROM    bettrans with(nolock)  
                    WHERE   custid = @custid  
                            AND winlostdate BETWEEN @fdate AND @tdate  
                            AND bettype <>903
                    GROUP BY winlostdate ,  
                            bettype ,  
                            CASE WHEN statusID IN (101,102) THEN 102  
                                 WHEN statusID IN (0,1) THEN 0  
                                 ELSE 131  
                            END ,  
                            CASE WHEN bettype <= 19999 THEN NULL  
                                 ELSE transdate  
                            END 
	--include running Keno bet
	   INSERT  INTO @bet  
                    SELECT  winlostdate ,  
                            gameid ,  
                            0 ,   --running bet
                            NULL ,  
                            '' as transdesc, 
                            SUM(t.stake ) ,  
                            SUM(actual_stake) ,  
                            0 ,  --winlost
                            0  --playcomm
                    FROM    bodb02.dbo.translog t with(nolock)  
                    WHERE   custid = @custid  
                            AND winlostdate BETWEEN @fdate AND @tdate                              
							and statusID =0 -- get only running game _ Keno
							--and t.productID=202 --Keno
                    GROUP BY winlostdate ,gameid 
   IF @fdate <= @MoveBetsDay  
   INSERT INTO @bet  
   select distinct   
    winlostdate,  
    bettype,  
    102 statusID,  
    transdate,     
    'Cancelled/Deleted Bets' transdesc,   
    stake,  
    stake,  
    0,  
    0   
   from zzzbettrans with (nolock)  
   where bettype between 1 and 19999   
    and custid=@CustID   
    and winlostdate between @fdate and @MoveBetsDay    
	AND bettype <>903
            INSERT  INTO @Data  
                    SELECT  0 ,  
    winlostdate ,  
                            'BAL' ,  
                            'OPENING BALANCE' ,  
                            0 ,  
                            SUM(winlost - actual_stake) ,  
                            0  
                    FROM    @bet  
                    WHERE   bettype = 20000  
                    GROUP BY winlostdate    
     
            INSERT  INTO @Data  
                    SELECT  1 ,  
                            winlostdate ,  
                            'BET' ,  
                            'Betting Statement' ,  
                            SUM(stake) ,  
                            SUM(winlost - actual_stake) ,  
                            SUM(playercomm) Commission  
                    FROM    @bet  
                    WHERE   bettype <= 19999  
                            AND statusID = 131  
                    GROUP BY winlostdate    
     
            INSERT  INTO @Data  
                    SELECT  2 ,  
                            winlostdate ,  
                            'BET' ,  
                            'Void/Cancelled Bet' ,  
                            SUM(stake) ,  
                            0 ,  
                            0  
                    FROM    @bet  
                    WHERE   statusID = 102  
                    GROUP BY winlostdate    
     
            INSERT  INTO @Data  
                    SELECT  3 ,  
                            winlostdate ,  
                            'BET' ,  
                            'Outstanding Bet' ,  
                            SUM(stake) ,  
                            0 ,  
                            0  
                    FROM    @bet  
                    WHERE   statusID = 0 
					and bettype not in (23001,23002,23101,23102,23201,23202)
                    GROUP BY winlostdate    
     
            INSERT  INTO @Data  
                    SELECT  2 ,  
                            transdate ,  
                            UPPER(typenamee) ,  
                            TransDesc ,  
                            0 ,  
                            ( winlost - actual_stake ) ,  
                            0  
                    FROM    @bet AS B  
                            INNER JOIN dbo.bettype (NOLOCK) ON B.bettype = bettype.typeid  
                    WHERE   bettype > 20000  
                            AND bettype NOT IN (23001,23002,23101,23102,23201,23202)
                            AND ( winlost - actual_stake ) <> 0   
     
        END   
    IF @fdate < @BalanceUpDay   
        BEGIN   
            DECLARE @PreBalanceUpDay DATETIME  
            IF @tdate >= DATEADD(dd, -1, @BalanceUpDay)   
                SELECT  @tdate = DATEADD(dd, -1, @BalanceUpDay) + ' 23:59:59'  
            SELECT TOP 1  
                    @PreBalanceUpDay = accdate  
            FROM    DBRPT.bodb_report.dbo.Statement WITH ( NOLOCK )  
            WHERE   custid = @custid  
                    AND accdate <= @fdate  
                    AND transdesc = 'OPENING BALANCE'  
            ORDER BY accdate DESC  
   
			-- If cannot find any old BU row, get BUDate from last BUDate before @fdate
			IF (@PreBalanceUpDay IS NULL) 
			BEGIN
				SET @PreBalanceUpDay = @fdate
				WHILE(DATEPART(WEEKDAY, @PreBalanceUpDay) <> 7) SET @PreBalanceUpDay = DATEADD(dd, -1, @PreBalanceUpDay)  
			END
			SELECT @fdate = @PreBalanceUpDay

			declare @recommend int
			SELECT @recommend = recommend FROM Customer (nolock) WHERE custID = @custid

			INSERT INTO @DepWL(winlostdate,turnover)
			SELECT winlostdate,SUM(turnover) as turnover
			FROM bodb_Licensee.dbo.rptLicWinloss2 (nolock)
			WHERE recommend = @recommend 
				AND custid = @custid
				AND statusID NOT IN (101,102,103) 
				AND winlostdate between @fdate and @tdate
				AND bettype <>903
			GROUP BY winlostdate
  
            INSERT  INTO @Data  
                    SELECT  1 ,  
                            a.AccDate ,  
                            'BET' ,  
                            'Betting Statement' ,  
                            ISNULL(SUM(b.turnover),0) AS turnover ,  
                            SUM(CASE a.transtype  
                                  WHEN 'BET' THEN a.totalamt  
                                  ELSE 0  
                                END) ,  
                            SUM(CASE a.transtype  
                                  WHEN 'COM' THEN a.totalamt  
                                  ELSE 0  
                                END)  
                    FROM    DBRPT.bodb_report.dbo.Statement a WITH ( NOLOCK )  
						LEFT JOIN @DepWL b ON a.AccDate = b.winlostdate
                    WHERE   a.custid = @custid  
                            AND a.accdate BETWEEN @fdate AND @tdate  
                            AND a.transtype IN ( 'BET', 'COM' )  
                    GROUP BY a.AccDate     
  
            INSERT  INTO @Data  
                    SELECT  CASE transtype  
                       WHEN 'BAL' THEN 0  
                              ELSE 2  
                            END ,  
                            AccDate ,  
                            UPPER(transtype) ,  
                            transdesc ,  
                            0 ,  
                            totalAmt ,  
                            0  
                    FROM    DBRPT.bodb_report.dbo.Statement WITH ( NOLOCK )  
                    WHERE   custid = @custid  
                            AND accdate BETWEEN @fdate AND @tdate  
                            AND transtype NOT IN ( 'BET', 'COM' )  
        END   
  
    DECLARE @RowStart INT ,  
        @RowEnd INT    
    SELECT  @PageIndex = @PageIndex - 1 ,  
            @RowStart = @PageSize * @PageIndex + 1 ,  
            @RowEnd = @RowStart + @PageSize - 1  
  
    IF @TotalRows = 0   
        BEGIN    
            SELECT  @TotalRows = COUNT(winlostdate)  
            FROM    @Data  
        END  
  
 DECLARE @currency INT  
 SELECT @currency=currency from custinfo (nolock)  
 WHERE custid = @custid  
  
 DECLARE @Today smalldatetime   
 SET @Today = convert(VARCHAR(10), CURRENT_TIMESTAMP, 120)   
 
 SELECT @FromDate = MIN (winlostdate) FROM @Data
 
 SELECT @FromDate =  convert(VARCHAR(10), @FromDate, 120) 
 
 SELECT * INTO #TempExchange 
FROM Lrf_f_GetExchangeDaily(@FromDate,@Today)
WHERE exchangeid = @currency
  
    SELECT  c.*  
    FROM    ( SELECT    ROW_NUMBER() OVER ( ORDER BY winlostdate, OrderKey ) AS RowNum ,  
                        winlostdate ,  
                        transtype ,  
                        transdesc ,  
                        turnover ,  
                        turnover * e.USD turnoverUSD,  
                        turnover * e.EUR turnoverEUR,  
						turnover * e.GBP turnoverGBP,
                        totalAmt ,  
                        totalAmt * e.USD totalAmtUSD ,  
                        totalAmt * e.EUR totalAmtEUR , 
						totalAmt * e.GBP totalAmtGBP , 
                        commission,  
                        commission * e.USD commissionUSD,  
                        commission * e.EUR commissionEUR,
						commission * e.GBP commissionGBP   
              FROM        
    @Data b INNER JOIN #TempExchange e ON e.exchangedate = convert(VARCHAR(10), b.winlostdate, 120)    
            ) c  
    WHERE   c.RowNum BETWEEN @RowStart AND @RowEnd
    
   DROP TABLE #TempExchange
GO
GRANT EXECUTE ON [dbo].[Lrf_Statement_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_Statement_Mem] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Statement_Mem] TO [vnteam] AS [dbo]