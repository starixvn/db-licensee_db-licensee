USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_Aff_MemberDailySummary_IA]    Script Date: 04/09/2014 21:05:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Task_Aff_MemberDailySummary_IA    Script Date: 3/15/2013 2:07:21 PM ******/
ALTER PROCEDURE [dbo].[Task_Aff_MemberDailySummary_IA]  
 @winlostdate datetime  
AS  
/*  
 Created: 20090701@Peter  
 Task : Summary data from 12BET Affiliates Income Access members, This task will occurs every 2 hours and every day at 00:00  
 DB: DB06.bodb02  
  
 Revisions:     
  20111031@Peter : Exclude Number Game from Sportsbook commission (bettype from [81-120])  
  20120712@Peter : replace ExchangeDaily -> ExchangeDailyOanda    
  20120904@Peter : support to delete only sportsbook and HR data wehn reimport when casino data is launch from another script  
         20130306@Peter: Sportbook bettype is less than 999 and exclude bettype from 31 to 120  
     20130307@Peter:  Get data from  DB052.bodb_Licensee  
  
 Param's Explanation:  
 • @winlostdate: The data need to summary  
*/  
  
-- HARD CODE: not cal before 1st June 2011 (Start time to support Income Access Platform)  
-- HARD CODE: not cal before 1st Nov 2011 (Exclude Number Game from Sportsbook commission)  
SET NOCOUNT ON  
  
IF @Winlostdate < '1 Nov 2011' or @Winlostdate>current_timestamp RETURN  
  
DECLARE @CutDate SMALLDATETIME, @MoveBetsDay SMALLDATETIME , @DepositPercent float, @WithdrawalPercent float  
  
SELECT @CutDate =  min(winlostdate)   
FROM DBRPT.bodb_report.dbo.rptdepwinlost with(nolock)     
  
SELECT @MoveBetsDay = max(eventdate) FROM bodb02.dbo.match14 WITH(NOLOCK)       
    
  
  
--Hard code Deposit Percent =0.06 and WithdrawalPercent=0.03  
  
Select @DepositPercent=0.06,@WithdrawalPercent=0.03  
   
  
DECLARE @AffExchange table(ExchangeID int primary key,ActualRate float,ActualRate2 float, DepositPercent float,WithdrawalPercent float)  
INSERT INTO @AffExchange(ExchangeID,ActualRate,ActualRate2,DepositPercent,WithdrawalPercent)  
SELECT exchangeid, actualrate, eur, @DepositPercent, @WithdrawalPercent   
FROM ExchangeDailyOanda with(nolock)  
WHERE exchangedate = @Winlostdate  
  
  --Table contains all 12BET deposit Income Access Member  
CREATE TABLE #Member(  
 CustID int primary key,       
 Currency int,  
 UserName nvarchar(30),  
 IBCUserName varchar(30),  
 IBCAgentID int,  
 DepositCustID int   
)    
  
Insert into #Member(CustID,Currency,UserName,IBCUserName,IBCAgentID,DepositCustID)  
Select CustID,Currency, REPLACE(UserName2,'12bet$',''),username,recommend,refcode2  
from customer with(nolock) where roleid=1  
 and recommend in (  
  select custid  
  from customer c with(nolock)  
  where roleid = 2  
  and username in (select '12bet'+cast(currency as varchar(4))+'04' from exchange)  
 )  
  
--select * from #MemberInfo (nolock)  
  
CREATE TABLE #Data(  
 IBCCustID int primary key,       
 Currency int,   
 Deposit money,  
 Withdrawal money,    
 Bonus money,  
 Adjustment money,   
 TurnOver money,  
 Outstanding money,  
 Winlost money,  
 DrawGame money,     
 TurnOverHR money,  
 OutstandingHR money,  
 WinlostHR money,  
 DrawGameHR money,     
 AffExRate float,  
 MemberExRate float,      
 PSP money,  
 Marketing money  
   
)  
IF @Winlostdate > @MoveBetsDay    
 BEGIN       
  insert into #Data(    
  IBCCustID,      
  Deposit,        
  Withdrawal,       
  Bonus,    
  Adjustment,    
  TurnOver,    
  DrawGame,    
  Outstanding,    
  Winlost,     
  Currency,    
  AffExRate,    
  MemberExRate   
 )    
 select b.custid,    
    isnull(sum(case bettype when 22001 then isnull(winlost,0)-isnull(abs(actual_stake),0) else 0 end),0) as Deposit,        
    -isnull(sum(case when bettype in (22002,22003) then isnull(winlost,0)-isnull(abs(actual_stake),0) else 0 end),0) as Withdrawal,    
    isnull(sum(case bettype when 22004 then isnull(winlost,0)-isnull(abs(actual_stake),0) else 0 end),0) as Bonus,    
    isnull(sum(case when bettype in (21001, 21002, 21003, 21004, 21005, 22005) then isnull(winlost,0)-isnull(abs(actual_stake),0) else 0 end),0) as Adjustment,        
    isnull(sum(case when bettype < 999 then isnull(abs(stake),0) else 0 end),0) as Turnover,    
    isnull(sum(case when bettype < 999 and StatusID=111/*status in ('DRAW')*/ then isnull(abs(stake),0) else 0 end),0) as DrawGame,    
    isnull(sum(case when bettype < 999 and ruben=0 then isnull(abs(actual_stake),0) else 0 end),0) as Outstanding,    
    isnull(sum(case when bettype < 999 and ruben=1 then isnull(winlost,0)-isnull(abs(actual_stake),0)+ isnull(playercomm,0) else 0 end),0) as Winlost,    
        
    b.currency,    
    e.ActualRate2,    
    e.ActualRate      
         
  from bodb02.dbo.bettrans b with (nolock)      
   INNER JOIN #Member m  on m.CustID=b.custid    
   INNER JOIN @AffExchange e on e.ExchangeID=b.currency    
  where winlostdate = @winlostdate    
    and (bettype<999 or bettype in (22001,22004,22002,22003,21001, 21002, 21003, 21004, 21005, 22005))    
    and bettype not between 31 and 120 --Not include Casino and Number Game and finance  
 --and bettype not in (31,32,33,41,42,43)     
    and StatusID not in (101, 102, 103, 121, 1)    
    --and status not in ('VOID', 'REJECT', 'REFUND','DONE') and 'waiting'    
    and b.custid > 0   
  group by b.custid, b.currency,    
    e.ActualRate2,    
    e.ActualRate  
END    
  
ELSE IF @Winlostdate < @CutDate  
BEGIN    
 INSERT INTO #Data (  
         IBCCustID,        
         TurnOver,    
         DrawGame,    
         Outstanding,    
         Winlost,     
         Currency,    
         AffExRate,    
         MemberExRate  
 )  
 SELECT   
        b.CustID  
  ,isnull(b.turnover,0)  
        ,isnull(b.drawTO,0)  
  ,isnull(b.Outstanding,0)  
  ,isnull(b.winlost,0)  
        ,m.Currency  
        ,e.ActualRate2    
        ,e.ActualRate    
            
 FROM DBRPT.bodb_Report.dbo.rptDepWinlostByProduct_bk b with(nolock)    
    INNER JOIN  #Member m on m.CustID=b.custid    
    INNER JOIN @AffExchange e on e.ExchangeID=m.currency     
 WHERE b.winlostdate = @Winlostdate    
        AND b.SportType=0  
  
   update d  
   set  Deposit=isnull(b.deposit,0)  
  ,Withdrawal=isnull(b.withdrawal,0)  
  ,Bonus=isnull(b.Bonus,0)  
  ,Adjustment=isnull(b.Adjustment,0)  
   from #Data d  
     inner join DBRPT.bodb_Report.dbo.rptDepWinlost_bk b with(nolock) on b.CustID=d.IBCCustID  
     where b.winlostdate = @Winlostdate  
  
  
  INSERT INTO #Data (  
         IBCCustID,        
         TurnOver,    
         DrawGame,    
         Outstanding,    
         Winlost,     
         Currency,    
         AffExRate,    
         MemberExRate,           
         Deposit,  
   Withdrawal,  
   Bonus,  
   Adjustment   
 )  
  
    Select m.CustID  
          ,0  
          ,0  
          ,0  
          ,0  
          ,m.Currency  
          ,e.ActualRate2    
          ,e.ActualRate             
          ,isnull(b.deposit,0)  
          ,isnull(b.withdrawal,0)  
          ,isnull(b.Bonus,0)  
          ,isnull(b.Adjustment,0)    
    FROM DBRPT.bodb_Report.dbo.rptDepWinlost_bk b with(nolock)  
          INNER JOIN  #Member m on m.CustID=b.Custid    
          INNER JOIN @AffExchange e on e.ExchangeID=m.currency    
    WHERE b.winlostdate = @Winlostdate   
         and b.CustID not in (select IBCCustID from #Data with (nolock))   
  
            
   
END  
  
ELSE IF @Winlostdate >= @CutDate  
BEGIN  
 INSERT INTO #Data (  
         IBCCustID,        
         TurnOver,    
         DrawGame,    
         Outstanding,    
         Winlost,     
         Currency,    
         AffExRate,    
         MemberExRate  
 )  
 SELECT   
        b.CustID  
  ,isnull(b.turnover,0)  
        ,isnull(b.drawTO,0)  
  ,isnull(b.Outstanding,0)  
  ,isnull(b.winlost,0)  
        ,m.Currency  
        ,e.ActualRate2    
        ,e.ActualRate    
        
    
 FROM DBRPT.bodb_Report.dbo.rptDepWinlostByProduct b with(nolock)    
    INNER JOIN  #Member m on m.CustID=b.custid    
    INNER JOIN @AffExchange e on e.ExchangeID=m.currency     
 WHERE b.winlostdate = @Winlostdate    
        AND b.SportType=0  
  
   update d  
   set  Deposit=isnull(b.deposit,0)  
  ,Withdrawal=isnull(b.withdrawal,0)  
  ,Bonus=isnull(b.Bonus,0)  
  ,Adjustment=isnull(b.Adjustment,0)  
   from #Data d  
     inner join DBRPT.bodb_Report.dbo.rptDepWinlost b with(nolock) on b.CustID=d.IBCCustID  
     where b.winlostdate = @Winlostdate  
  
   INSERT INTO #Data (  
         IBCCustID,        
         TurnOver,    
         DrawGame,    
         Outstanding,    
         Winlost,     
         Currency,    
         AffExRate,    
         MemberExRate,          
         Deposit,  
   Withdrawal,  
   Bonus,  
   Adjustment   
 )  
  
    Select m.CustID  
          ,0  
          ,0  
          ,0  
          ,0  
          ,m.Currency  
          ,e.ActualRate2    
          ,e.ActualRate             
          ,isnull(b.deposit,0)  
          ,isnull(b.withdrawal,0)  
          ,isnull(b.Bonus,0)  
          ,isnull(b.Adjustment,0)    
    FROM DBRPT.bodb_Report.dbo.rptDepWinlost b with(nolock)  
          INNER JOIN  #Member m on m.CustID=b.Custid    
          INNER JOIN @AffExchange e on e.ExchangeID=m.currency    
    WHERE b.winlostdate = @Winlostdate   
         and b.CustID not in (select IBCCustID from #Data with (nolock))   
  
  
END   
  
  
  
  
DELETE FROM DBRPT.bodb_Report.dbo.MemberDailyIA WHERE winlostdate = @winlostdate and SportType = 1  
  
INSERT INTO DBRPT.bodb_Report.dbo.MemberDailyIA(  
 WinlostDate,  
 IBCCustID,  
 Sporttype,  
 UserName,  
 IBCUserName,  
 IBCAgentID,  
 DepositCustID,  
 Currency,  
 Deposit,  
 Withdrawal,   
 Bonus,  
 Adjustment,  
 Turnover,  
 Outstanding,  
 Winlost,  
 AffExRate,  
 MemberExRate,   
 DrawGame,  
 PSP,  
 Marketing,  
 MemOddsFee     
)  
SELECT   
 @WinlostDate,  
 d.IBCCustID,   
 1 as SportType, --SportsBook  
 m.UserName,  
 m.IBCUserName,  
 m.IBCAgentID,  
 m.DepositCustID,  
 d.Currency,  
 Deposit,   
 Withdrawal,    
 Bonus,   
 Adjustment,   
 Turnover,   
 Outstanding,  
 Winlost,  
 AffExRate,  
 MemberExRate,   
 DrawGame,  
 (abs(Deposit) * e.DepositPercent + abs(Withdrawal) * e.WithdrawalPercent) as PSP,  
 abs(Winlost) * 0.05 as Marketing,   
 abs(Winlost) * 0.17 as MemOddsFee  
   
FROM #Data d with (nolock)  
  inner join  @AffExchange e on e.ExchangeID=d.currency  
  inner join #Member m on m.CustID=d.IBCCustID  
WHERE  Deposit<>0 or       
    Withdrawal<>0 or    
    Bonus<>0 or   
    Adjustment<>0 or    
    TurnOver<>0 or   
  DrawGame<>0 or   
  Outstanding<>0 or   
  Winlost<>0           
  
  
drop table #Data  
drop table #Member