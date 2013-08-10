ALTER PROCEDURE [dbo].[Lrf_Rpt_CustomerBalance]  
	@LicenseeID INT ,  
	@LicenseeType VARCHAR(100) = NULL,
	@UserID		INT,	
	@CurrencyID INT,  
	@FromDate  SMALLDATETIME,    
	@ToDate  SMALLDATETIME,     
	@OrderItem tinyint = 1,   
	@TopCount INT = 0,  
	@excludeTest BIT = 1,  
	@PageSize INT = 1000 ,  
	@PageIndex INT = 1,  
	@showSB  BIT=0,    
	@ShowRB  BIT=0,    
	@ShowNG  BIT=0,   
	@ShowLC  BIT=0,  
	@ShowVS  BIT=0,
	@ShowCS  BIT=0, -- RNG Casino  
	@ShowBG  BIT=0  -- Bingo     
  
AS /*  
Created: 20120917@Henry  
Task : Report Customer Balance  
DB: DBRPT/bodb02  
Original: Lrf_Rpt_CustomerTurnOver  
  
Revisions:  
   -20120917@henry: change SP name Lrf_Rpt_CustomerTurnOver to Lrf_Rpt_CustomerBalance + split column  
   -20121004@Jim: replace @currency input param by @currencyID  
   -20130117@henry: enhance performance  
   -20130123@Daniel: Change link server alias  
   -20130225@Scott: support RNG Casino ,Bingo     
   -20130618@Jim:  Restrict permission of Licensee Users by currency
   -20130809@Jim: offer Virtual Horse Racing
Param's Explanation:  
 + @excludeTest: remove currency UUS  
 + @TopCount:   
  0: get all  
  100: get 100 top by @OrderItem  
  500: get 500 top by @OrderItem  
 + @OrderItem:  
  1: Deposit  
  2: Withdrawal  
  3: Turnover  
  4: Winloss desc  
  5: Winloss asc  
   
   
*/  
SET NOCOUNT ON  
DECLARE @CutDate datetime  
DECLARE @tmpAg TABLE(custID INT)  
DECLARE @RowStart INT, @RowEnd INT  
DECLARE @sporttype TABLE(sporttype INT)  
DECLARE @tmpdate smalldatetime, @fdate smalldatetime, @tdate smalldatetime  
SELECT @CutDate =  min(winlostdate)   
 ,@fdate = @FromDate  
 ,@tdate = @ToDate  
FROM bodb_report.dbo.rptdepwinlost with(nolock)   
  
SELECT  @PageIndex = @PageIndex - 1 ,  
        @RowStart = @PageSize * @PageIndex + 1 ,  
        @RowEnd = @RowStart + @PageSize - 1  
   
IF @ShowSB = 1 INSERT INTO @sporttype(sporttype) VALUES(0)  
IF @ShowRB = 1 INSERT INTO @sporttype(sporttype) VALUES(151)   
IF @ShowNG = 1 INSERT INTO @sporttype(sporttype) VALUES(161)  
IF @ShowLC = 1 INSERT INTO @sporttype(sporttype) VALUES(162)  
IF @ShowVS = 1 INSERT INTO @sporttype(sporttype)
				SELECT 180
				UNION ALL 
				SELECT 181 
				
IF @ShowCS = 1 INSERT INTO @sporttype(sporttype) VALUES(251) -- RNG Casino  
IF @ShowBG = 1 INSERT INTO @sporttype(sporttype) VALUES(252) -- Bingo    


SELECT CurrencyID,LicenseeID
INTO #Currency
FROM  DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
WHERE  usrID=@userID 
AND LicenseeID=@LicenseeID 
AND SystemID=1 -- System is default=1 (LRF)
AND (@CurrencyID=0 OR (CurrencyID=@CurrencyID))
  
INSERT INTO @tmpAg  
SELECT CustID   
FROM DBLIC.bodb_Licensee.dbo.LicenseeCust lc WITH( NOLOCK )  
	INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE  [Description] = COALESCE(@LicenseeType,[Description])   
 AND (@CurrencyID=0 OR (@CurrencyID<>0 AND Currency = @CurrencyID))  
 AND (@excludeTest = 0 OR (@excludeTest=1 AND Currency<>20))  
 
 DROP TABLE #Currency 
  
CREATE TABLE #SumWinlost  
(  
 Custid int,  
 Deposit money,  
 AffiliateTransfer money,   
 Withdrawal money,   
 Turnover money,  
 Winloss money,   
 Bonus money,  
 Adjustment money,  
 Outstanding money,  
 OpeningBalance money,  
 ClosingBalance money,  
 DrawGame money,  
 TurnoverBA money,  
 CommBA money,  
 PlayerComm MONEY,  
 AmountDueToBA money  
)   
  
IF @fdate < @CutDate   
BEGIN  
 select @tmpdate = case when @tdate >= @CutDate then DATEADD(dd,-1,@CutDate) else @tdate end    
 INSERT INTO #SumWinlost  
 SELECT b.custid, sum(b.Deposit) as Deposit,   
   sum(b.Aff2MemTransfer) as AffiliateTransfer,   
   sum(b.Withdrawal) as Withdrawal,   
   0 as Turnover,  
   0 as winloss,  
   sum(b.Bonus) as Bonus,   
   sum(b.Adjustment) as Adjustment,   
   0 as Outstanding,  
   sum(case b.winlostdate when @fdate then b.OpeningBalance else 0 end) OpeningBalance,  
   sum(case b.winlostdate when @tdate then b.ClosingBalance else 0 end) ClosingBalance,  
   0 as DrawGame,  
   CASE WHEN @showSB=1 THEN sum(isnull(Turnover_BA,0)) ELSE 0 END TurnoverBA,  
   CASE WHEN @showSB=1 THEN sum(isnull(Comm_BA,0)) ELSE 0 END CommBA,  
   0 as PlayerComm,  
   CASE WHEN @showSB=1 THEN sum(isnull(AmountDueTo_BA,0)) ELSE 0 END AmountDueToBA   
 FROM bodb_Report.dbo.rptDepWinlost_bk b with(nolock)  
 WHERE b.winlostdate between @fdate AND @tmpdate  
   and b.recommend in (select custid from @tmpAg)  
 group by b.custid  
  
 ;WITH sourceDATA as (  
   SELECT   
    p.custid   
    ,SUM(isnull(p.turnover,0)) as Turnover  
    ,SUM(isnull(p.outstanding,0)) as outstanding  
    ,SUM(isnull(p.winlost,0)) as Winloss   
    ,SUM(isnull(p.drawTO,0)) as DrawGame  
    ,SUM(isnull(p.playercomm,0)) as PlayerComm  
   FROM bodb_Report.dbo.rptDepWinlostByProduct_bk p WITH (NOLOCK)   
    INNER JOIN #SumWinlost d ON p.custid = d.custid       
   WHERE p.winlostdate between @fdate and @tmpdate  
    and sporttype IN (SELECT sporttype FROM @sporttype)       
   GROUP BY p.custid  
 )   
 UPDATE #SumWinlost  
 SET turnover = isnull(s.turnover,0)  
  ,outstanding = isnull(s.outstanding,0)  
  ,winloss = isnull(s.winloss,0)  
  ,drawgame = isnull(s.drawgame,0)  
  ,playercomm = isnull(s.playercomm, 0)  
 FROM sourceDATA s  
 WHERE #SumWinlost.custid = s.custid  
END   
IF @tdate >= @CutDate  
BEGIN  
 select @tmpdate = case when @fdate < @CutDate then @CutDate else @fdate end   
 SELECT b.custid, sum(b.Deposit) as Deposit,   
   sum(b.Aff2MemTransfer) as AffiliateTransfer,   
   sum(b.Withdrawal) as Withdrawal,   
   cast(0 as money) as Turnover,  
   cast(0 as money) as winloss,  
   sum(b.Bonus) as Bonus,   
   sum(b.Adjustment) as Adjustment,   
   cast(0 as money) as Outstanding,  
   sum(case b.winlostdate when @fdate then b.OpeningBalance else 0 end) OpeningBalance,  
   sum(case b.winlostdate when @tdate then b.ClosingBalance else 0 end) ClosingBalance,  
   cast(0 as money) as DrawGame,  
   CASE WHEN @showSB=1 THEN sum(isnull(Turnover_BA,0)) ELSE 0 END TurnoverBA,  
   CASE WHEN @showSB=1 THEN sum(isnull(Comm_BA,0)) ELSE 0 END CommBA,  
   cast(0 as money) as PlayerComm,  
   CASE WHEN @showSB=1 THEN sum(isnull(AmountDueTo_BA,0)) ELSE 0 END AmountDueToBA  
 INTO #SumWinlost2  
 FROM   bodb_Report.dbo.rptDepWinlost b with (nolock)  
 WHERE b.winlostdate between @tmpdate AND @tdate  
   and b.recommend in (select custid from @tmpAg)  
 group by b.custid   
  
 ;WITH sourceDATA as (  
   SELECT   
    p.custid   
    ,SUM(isnull(p.turnover,0)) as Turnover  
    ,SUM(isnull(p.outstanding,0)) as outstanding  
    ,SUM(isnull(p.winlost,0)) as Winloss   
    ,SUM(isnull(p.drawTO,0)) as DrawGame  
    ,SUM(isnull(p.playercomm,0)) as PlayerComm  
   FROM bodb_Report.dbo.rptDepWinlostByProduct p WITH (NOLOCK)   
    INNER JOIN #SumWinlost2 d ON p.custid = d.custid  
   WHERE p.winlostdate between @tmpdate AND @tdate  
    and sporttype IN (SELECT sporttype FROM @sporttype)       
   GROUP BY p.custid  
 )   
 UPDATE #SumWinlost2  
 SET turnover = isnull(s.turnover,0)  
  ,outstanding = isnull(s.outstanding,0)  
  ,winloss = isnull(s.winloss,0)  
  ,drawgame = isnull(s.drawgame,0)  
  ,playercomm = isnull(s.playercomm, 0)  
 FROM sourceDATA s  
 WHERE #SumWinlost2.custid = s.custid  
   
 UPDATE #SumWinlost  
 SET Deposit = #SumWinlost.Deposit + s.Deposit  
  ,AffiliateTransfer  = #SumWinlost.AffiliateTransfer  + s.AffiliateTransfer   
  ,Withdrawal = #SumWinlost.Withdrawal + s.Withdrawal  
  ,Turnover = #SumWinlost.Turnover + s.Turnover  
  ,Winloss  = #SumWinlost.Winloss  + s.Winloss   
  ,Bonus = #SumWinlost.Bonus + s.Bonus  
  ,Adjustment = #SumWinlost.Adjustment + s.Adjustment  
  ,Outstanding = #SumWinlost.Outstanding + s.Outstanding  
  ,OpeningBalance = #SumWinlost.OpeningBalance + s.OpeningBalance  
  ,ClosingBalance = #SumWinlost.ClosingBalance + s.ClosingBalance  
  ,DrawGame = #SumWinlost.DrawGame + s.DrawGame  
  ,TurnoverBA = #SumWinlost.TurnoverBA + s.TurnoverBA  
  ,CommBA = #SumWinlost.CommBA + s.CommBA  
  ,PlayerComm = #SumWinlost.PlayerComm + s.PlayerComm  
  ,AmountDueToBA = #SumWinlost.AmountDueToBA + s.AmountDueToBA  
 FROM #SumWinlost2 s  
 WHERE #SumWinlost.custid = s.custid  
  
 INSERT INTO #SumWinlost  
 select Custid  
  ,Deposit  
  ,AffiliateTransfer   
  ,Withdrawal  
  ,Turnover  
  ,Winloss   
  ,Bonus  
  ,Adjustment  
  ,Outstanding  
  ,OpeningBalance  
  ,ClosingBalance  
  ,DrawGame  
  ,TurnoverBA  
  ,CommBA  
  ,PlayerComm  
  ,AmountDueToBA  
 FROM #SumWinlost2   
 WHERE custid NOT IN (select custid from #SumWinlost)  
END  
  
IF @OrderItem=5  
BEGIN  
 IF @TopCount=0  
 BEGIN  
  select   
   c.username,   
   SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,  
   toptbl.*  
  from   
  (  
   select  
    rpt.*,  
    ROW_NUMBER() OVER ( ORDER BY rpt.Winloss,rpt.Custid ) AS RowNum  
   from #SumWinlost rpt  
   --where rpt.Winloss <> 0  
  ) as toptbl  
  inner join Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid  
  WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd   
  ORDER BY RowNum ASC  
    
  SELECT   
   COUNT(DISTINCT CustID) as TotalRows,  
   sum(Deposit) as SumDeposit,  
   sum(AffiliateTransfer) as SumAffiliateTransfer,  
   sum(Withdrawal) as SumWithdrawal,  
   sum(Turnover) AS SumTurnover,  
   sum(Winloss) AS SumWinloss,  
   sum(Bonus) as SumBonus,  
   sum(Adjustment) as SumAdjustment,  
   sum(Outstanding) AS SumOutstanding,  
   sum(OpeningBalance) as SumOpeningBalance,  
   sum(ClosingBalance) as SumClosingBalance,  
   sum(DrawGame) AS SumDrawGame,  
   sum(TurnoverBA) as SumTurnoverBA ,  
   sum(CommBA) as SumCommBA,  
   sum(PlayerComm) AS SumPlayerComm,  
   sum(AmountDueToBA) as SumAmountDueToBA  
  FROM #SumWinlost rpt  
  --where rpt.Winloss <> 0  
 END  
 ELSE  
 BEGIN  
  select   
   c.username,   
   SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,  
   toptbl.*  
  from   
  (  
   select   
    top(@TopCount) rpt.*,  
    ROW_NUMBER() OVER ( ORDER BY rpt.Winloss,rpt.Custid ) AS RowNum  
   from #SumWinlost rpt  
   --where rpt.Winloss <> 0  
  ) as toptbl  
  inner join Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid  
  WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd   
  ORDER BY RowNum ASC  
    
    
  SELECT   
   COUNT(DISTINCT CustID) as TotalRows,  
   sum(Deposit) as SumDeposit,  
   sum(AffiliateTransfer) as SumAffiliateTransfer,  
   sum(Withdrawal) as SumWithdrawal,  
   sum(Turnover) AS SumTurnover,  
   sum(Winloss) AS SumWinloss,  
   sum(Bonus) as SumBonus,  
   sum(Adjustment) as SumAdjustment,  
   sum(Outstanding) AS SumOutstanding,  
   sum(OpeningBalance) as SumOpeningBalance,  
   sum(ClosingBalance) as SumClosingBalance,  
   sum(DrawGame) AS SumDrawGame,  
   sum(TurnoverBA) as SumTurnoverBA ,  
   sum(CommBA) as SumCommBA,  
   sum(PlayerComm) AS SumPlayerComm,  
   sum(AmountDueToBA) as SumAmountDueToBA  
     
  FROM    
   (  
    select   
     top(@TopCount) rpt.*,  
     ROW_NUMBER() OVER ( ORDER BY rpt.Winloss ) AS RowNum  
    from #SumWinlost rpt  
    --where rpt.Winloss <> 0  
    ORDER BY RowNum ASC  
   ) A  
 END  
END  
ELSE  
BEGIN  
 IF @TopCount=0  
 BEGIN  
  select   
   c.username,   
   SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,  
   toptbl.*  
  from   
  (  
   select rpt.*,  
   ROW_NUMBER() OVER ( ORDER BY   
         case @orderItem  
         when 1 then rpt.Deposit  
         when 2 then rpt.Withdrawal  
         when 3 then rpt.Turnover  
         when 4 then rpt.Winloss  
    end desc,rpt.Custid  ) AS RowNum  
   from #SumWinlost rpt  
   /*  
   where    
    case   
     when @orderItem=1 and rpt.Deposit > 0 then 1  
     when @orderItem=2 and rpt.Withdrawal > 0 then 1  
     when @orderItem=3 and rpt.Turnover > 0 then 1  
     when @orderItem=4 and rpt.Winloss <> 0 then 1  
     end = 1  
   */    
       
  ) as toptbl  
   inner join Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid  
  WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd   
  ORDER BY RowNum ASC  
    
  SELECT   
   COUNT(DISTINCT CustID) as TotalRows,  
   sum(Deposit) as SumDeposit,  
   sum(AffiliateTransfer) as SumAffiliateTransfer,  
   sum(Withdrawal) as SumWithdrawal,  
   sum(Turnover) AS SumTurnover,  
   sum(Winloss) AS SumWinloss,  
   sum(Bonus) as SumBonus,  
   sum(Adjustment) as SumAdjustment,  
   sum(Outstanding) AS SumOutstanding,  
   sum(OpeningBalance) as SumOpeningBalance,  
   sum(ClosingBalance) as SumClosingBalance,  
   sum(DrawGame) AS SumDrawGame,  
   sum(TurnoverBA) as SumTurnoverBA ,  
   sum(CommBA) as SumCommBA,  
   sum(PlayerComm) AS SumPlayerComm,  
   sum(AmountDueToBA) as SumAmountDueToBA  
     
  FROM  #SumWinlost rpt  
  /*  
  where    
   case   
    when @orderItem=1 and rpt.Deposit > 0 then 1  
    when @orderItem=2 and rpt.Withdrawal > 0 then 1  
    when @orderItem=3 and rpt.Turnover > 0 then 1  
    when @orderItem=4 and rpt.Winloss <> 0 then 1  
    end = 1   
  */    
 END   
 ELSE  
 BEGIN  
  select   
   c.username,   
   SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1,LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname ,  
   toptbl.*  
  from   
  (  
   select   
    top(@TopCount) rpt.*,  
    ROW_NUMBER() OVER ( ORDER BY   
         case @orderItem  
         when 1 then rpt.Deposit  
         when 2 then rpt.Withdrawal  
         when 3 then rpt.Turnover  
         when 4 then rpt.Winloss  
         end desc,rpt.Custid  ) AS RowNum  
   from #SumWinlost rpt  
   /*  
   where  
    case   
     when @orderItem=1 and rpt.Deposit >0 then 1  
     when @orderItem=2 and rpt.Withdrawal >0 then 1  
     when @orderItem=3 and rpt.Turnover >0 then 1  
     when @orderItem=4 and rpt.Winloss <>0 then 1  
     end = 1  
   */  
     
  ) as toptbl  
  inner join bodb02.dbo.Customer c WITH ( NOLOCK ) ON c.custid=toptbl.custid  
  WHERE   toptbl.RowNum BETWEEN @RowStart AND @RowEnd   
  ORDER BY RowNum ASC  
    
  SELECT   
   COUNT(DISTINCT CustID) as TotalRows,  
   sum(Deposit) as SumDeposit,  
   sum(AffiliateTransfer) as SumAffiliateTransfer,  
   sum(Withdrawal) as SumWithdrawal,  
   sum(Turnover) AS SumTurnover,  
   sum(Winloss) AS SumWinloss,  
   sum(Bonus) as SumBonus,  
   sum(Adjustment) as SumAdjustment,  
   sum(Outstanding) AS SumOutstanding,  
   sum(OpeningBalance) as SumOpeningBalance,  
   sum(ClosingBalance) as SumClosingBalance,  
   sum(DrawGame) AS SumDrawGame,  
   sum(TurnoverBA) as SumTurnoverBA ,  
   sum(CommBA) as SumCommBA,  
   sum(PlayerComm) AS SumPlayerComm,  
   sum(AmountDueToBA) as SumAmountDueToBA  
  FROM  
  (  
   select   
    top(@TopCount) rpt.*,  
    ROW_NUMBER() OVER ( ORDER BY   
         case @orderItem  
         when 1 then rpt.Deposit  
         when 2 then rpt.Withdrawal  
         when 3 then rpt.Turnover  
         when 4 then rpt.Winloss  
         end desc,rpt.Custid  ) AS RowNum  
   from #SumWinlost rpt  
   ORDER BY RowNum ASC  
   /*  
   where  
    case   
     when @orderItem=1 and rpt.Deposit >0 then 1  
     when @orderItem=2 and rpt.Withdrawal >0 then 1  
     when @orderItem=3 and rpt.Turnover >0 then 1  
     when @orderItem=4 and rpt.Winloss <>0 then 1  
     end = 1  
   ORDER BY RowNum ASC  
   */  
  ) A  
 END  
END  
  
DROP TABLE #SumWinlost 
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CustomerBalance] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CustomerBalance] TO [vnteam] AS [dbo]