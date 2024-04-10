/*<info serverAlias="DBACC-bodb02" executers="ow_12bet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[DOT_Dep_Rpt_DailySummaryCurrency_Agent]
	@currency int,
	@fromDate datetime,
	@toDate datetime,
	@agentid NVARCHAR(3500)
AS
/*
DB: DB061.bodb02
Revisions:
-- 20120914@Viet: revise SP
-- 20121029@Cooper(DB06):performance tuning assing index = IX_custid  
-- 20130103@Cooper(DB06):performance tuning about rptDepWinlost_bk table query
-- 20191218@Benson: Add select promotion column
-- 20210422@Sol: enhance performance - [Redmine: #153015]
-- 20240410@Eddie: Change metadata 'Dot_Admin' to 'ow_12bet' - [Redmine: #202118]
*/
DECLARE @CutDate datetime
SELECT @CutDate =  min(winlostdate) from bodb_report.dbo.rptdepwinlost with(nolock) 

DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME
SELECT @FDate = @fromDate, @TDate = @toDate

CREATE TABLE #customers (custid int PRIMARY KEY )
insert into #customers (custid)
select c.custid
from customer a with(nolock)
	inner join customer c with(nolock) on a.custid = c.recommend
where a.custid in (SELECT val FROM strSplit(@agentid,','))
and a.currency = @currency
and a.roleid = 2
and c.roleid = 1
						
IF @FromDate < @CutDate
BEGIN
	IF @ToDate < @CutDate
	BEGIN
		select winlostdate, e.currency, e.exchangeid,
			sum(OpeningBalance) as OpeningBalance,
			sum(Deposit) as Deposit,
			sum(Aff2MemTransfer) as Aff2MemTransfer,
			sum(Withdrawal) as Withdrawal,		
			Sum(Bonus) as Bonus,
			sum(Adjustment) as Adjustment,
			sum(Turnover) as Turnover,
			sum(Outstanding) as Outstanding,
			sum(Winloss) as Winloss,
			sum(ClosingBalance) as ClosingBalance,
			sum(Promotion) as Promotion
		 from (	select currency ,winlostdate, OpeningBalance, Deposit, Aff2MemTransfer,
						Withdrawal, Bonus, Adjustment, Turnover, Outstanding, Winloss, ClosingBalance, Promotion
				from bodb_Report.dbo.rptDepWinlost_bk  with(nolock,index = CIX_rptDepWinlost_bk)
				where winlostdate between @FDate and @TDate	
						AND currency = @currency
						and custid in (select custid from #customers) 
				) b
				inner join exchange e with(nolock) on b.currency = e.exchangeid 	
		group by winlostdate, e.currency, e.exchangeid
		order by winlostdate 
	END
	ELSE
	BEGIN
		select winlostdate, currency, exchangeid,
			sum(OpeningBalance) as OpeningBalance,
			sum(Deposit) as Deposit,
			sum(Aff2MemTransfer) as Aff2MemTransfer,
			sum(Withdrawal) as Withdrawal,		
			Sum(Bonus) as Bonus,
			sum(Adjustment) as Adjustment,
			sum(Turnover) as Turnover,
			sum(Outstanding) as Outstanding,
			sum(Winloss) as Winloss,
			sum(ClosingBalance) as ClosingBalance,
			sum(Promotion) as Promotion
		from
			(select winlostdate, e.currency, e.exchangeid, OpeningBalance, Deposit, Aff2MemTransfer,
				    Withdrawal, Bonus, Adjustment, Turnover, Outstanding, Winloss, ClosingBalance, Promotion
			 from (	select currency ,winlostdate, OpeningBalance, Deposit, Aff2MemTransfer,
							Withdrawal, Bonus, Adjustment, Turnover, Outstanding, Winloss, ClosingBalance, Promotion
					from bodb_Report.dbo.rptDepWinlost_bk  with(nolock,index = CIX_rptDepWinlost_bk)
					where winlostdate between @FDate and @TDate
							AND currency = @currency
							and custid in (select custid from #customers) 
					) b
					inner join exchange e with(nolock) on b.currency = e.exchangeid 			
			 UNION ALL 
			 SELECT winlostdate, e.currency, e.exchangeid, OpeningBalance, Deposit, Aff2MemTransfer,
				    Withdrawal, Bonus, Adjustment, Turnover, Outstanding, Winloss, ClosingBalance, Promotion
			 FROM bodb_Report.dbo.rptDepWinlost b with (nolock)
				inner join exchange e with(nolock) on b.currency = e.exchangeid
			 where winlostdate between @FDate and @TDate
				AND b.currency = @currency
				and b.custid in (select custid from #customers) 
			) AS DB 
		group by winlostdate, currency, exchangeid
		order by winlostdate	
	END
END
ELSE
BEGIN
	select winlostdate, e.currency, e.exchangeid,
		sum(OpeningBalance) as OpeningBalance,
		sum(Deposit) as Deposit,
		sum(Aff2MemTransfer) as Aff2MemTransfer,
		sum(Withdrawal) as Withdrawal,		
		Sum(Bonus) as Bonus,
		sum(Adjustment) as Adjustment,
		sum(Turnover) as Turnover,
		sum(Outstanding) as Outstanding,
		sum(Winloss) as Winloss,
		sum(ClosingBalance) as ClosingBalance,
		sum(Promotion) as Promotion
	from bodb_Report.dbo.rptDepWinlost b with(nolock)
		inner join exchange e with(nolock) on b.currency = e.exchangeid
	where winlostdate between @FDate and @TDate
		AND b.currency = @currency
		and b.custid in (select custid from #customers) 
	group by winlostdate, e.currency, e.exchangeid
	order by winlostdate
END
GO